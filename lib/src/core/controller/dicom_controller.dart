import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../../rust/api/core/config/dicom_config.dart';
import '../../rust/api/core/models/dicom_frame_result.dart';
import '../../rust/api/core/models/dicom_metadata.dart';
import '../constants/color_maps.dart';
import '../constants/lib_shaders.dart';
import '../exceptions/dicom_exceptions.dart';
import '../services/dicom_service.dart';

/// The central state manager and orchestrator for DICOM file processing and rendering.
///
/// `DicomController` is responsible for:
/// * Communicating with the high-performance Rust core to parse DICOM files.
/// * Managing the lifecycle of GPU textures (cleaning up when no longer needed).
/// * Keeping track of interactive states like **Windowing** (contrast/brightness) and **Zoom**.
/// * Notifying the UI of changes to facilitate a reactive experience.
///
/// For enterprise use, it uses the [DicomService] which can be swapped for
/// custom implementations (e.g., local storage vs. cloud-based DICOM PACS).
///
/// **Usage:**
/// ```dart
/// final controller = DicomController();
/// await controller.initialize();
/// await controller.loadFromBytes(bytes: fileBytes);
/// ```
class DicomController extends ChangeNotifier {
  /// Creates a [DicomController].
  ///
  /// Pass a custom [DicomService] to change how files are loaded (optional).
  DicomController({final DicomService? service})
      : _service = service ?? DicomService();
  final DicomService _service;

  // --- State Variables ---
  DicomFrameResult? _currentFrame;
  bool _isLoading = false;
  String? _errorMessage;
  ui.FragmentShader? _shader;
  ui.Image? _rawTexture;

  // --- Interactive State (Windowing) ---
  double? _currentWindowCenter;
  double? _currentWindowWidth;

  // --- Colorization State ---
  DicomColorMap _colorMap = DicomColorMap.grayscale;
  ui.Image? _colorLutTexture;

  // --- Invert & Display State ---
  bool _invert = false;

  // --- Getters ---

  /// Returns `true` while the Rust backend is busy parsing a file.
  bool get isLoading => _isLoading;

  /// Returns `true` if any step of the loading or processing pipeline failed.
  bool get hasError => _errorMessage != null;

  /// Returns `true` only if both the metadata and the GPU texture are ready for rendering.
  bool get hasData =>
      _currentFrame != null && _rawTexture != null && _shader != null;

  /// The latest error message produced by the controller or the underlying services.
  String? get errorMessage => _errorMessage;

  /// The medical metadata (Patient Name, SOP ID, Window defaults) for the current file.
  DicomMetadata? get metadata => _currentFrame?.metadata;

  /// The full result of the latest DICOM processing operation.
  DicomFrameResult? get currentFrame => _currentFrame;

  /// The internal 16-bit texture packed for GPU consumption.
  ui.Image? get rawTexture => _rawTexture;

  /// The GLSL shader instance used to compute windowing on the GPU.
  ui.FragmentShader? get shader => _shader;

  /// The current Window Center (Level) being applied to the image.
  double? get windowCenter => _currentWindowCenter;

  /// The current Window Width being applied to the image.
  double? get windowWidth => _currentWindowWidth;

  /// The active color map for image colorization.
  DicomColorMap get colorMap => _colorMap;

  /// The 256×1 RGBA color LUT texture, or null if grayscale.
  ui.Image? get colorLutTexture => _colorLutTexture;

  /// Whether grayscale inversion is active.
  bool get invert => _invert;

  /// Toggles the grayscale invert state and notifies listeners.
  void toggleInvert() {
    _invert = !_invert;
    notifyListeners();
  }

  /// Returns true if the current image uses MONOCHROME1 photometric interpretation.
  bool get isMonochrome1 =>
      _currentFrame?.metadata.photometricInterpretation == 'MONOCHROME1';

  /// Loads the necessary fragment shaders from the plugin assets.
  ///
  /// This must be called (directly or implicitly via [loadFromBytes]) before any rendering can happen.
  Future<void> initialize() async {
    if (_shader != null) return;
    try {
      final program = await ui.FragmentProgram.fromAsset(
        LibShaders.dicomWindow,
      );
      _shader = program.fragmentShader();
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to load shader: $e';
      notifyListeners();
    }
  }

  /// Loads a DICOM object from raw bytes already in memory.
  ///
  /// This triggers the heavy lifting in the Rust engine on a background thread.
  /// Once parsed, the raw pixel data is automatically converted into a GPU-ready texture.
  ///
  /// Loading is bytes-only by design (there is no local file system on the
  /// Web). Pair this with a file picker configured to return bytes (e.g.
  /// `package:file_picker`'s `PlatformFile.bytes`, using `withData: true`).
  ///
  /// [bytes] - The raw contents of a .dcm file.
  /// [config] - Optional configuration to tune the Rust engine.
  Future<void> loadFromBytes({
    required final Uint8List bytes,
    final DicomConfig? config,
  }) async {
    if (_isLoading) return;
    if (_shader == null) await initialize();

    _setLoading(true);
    _clearError();

    try {
      final result = await _service.loadFrameFromBytes(bytes, config: config);
      _currentFrame = result;

      // Create GPU texture from raw pixel data
      if (result.pixelData.isNotEmpty) {
        _rawTexture = await _createTexture(
          result.pixelData,
          result.metadata.width,
          result.metadata.height,
        );
      }

      // Initialize interactive windowing values
      _currentWindowCenter = result.metadata.windowCenter;
      _currentWindowWidth = result.metadata.windowWidth;
    } catch (e) {
      _errorMessage = 'Failed to load DICOM: ${e.toString()}';
      notifyListeners();
      throw DicomProcessingException(_errorMessage!);
    } finally {
      _setLoading(false);
    }
  }

  /// Maps raw 16-bit integers to an 8-bit RGBA texture for Flutter/GPU compatibility.
  ///
  /// **Precision Preservation:** We pack the high byte into the Red channel
  /// and the low byte into the Green channel. The Fragment Shader then reconstructs
  /// the full 16-bit value.
  Future<ui.Image> _createTexture(
      final Int16List data, final int width, final int height) async {
    final rgbaData = Uint8List(width * height * 4);

    for (var i = 0; i < data.length; i++) {
      final val = data[i] + 32768; // Offset to make it unsigned u16
      rgbaData[i * 4 + 0] = (val >> 8) & 0xFF; // R: High byte
      rgbaData[i * 4 + 1] = val & 0xFF; // G: Low byte
      rgbaData[i * 4 + 2] = 0; // B: unused
      rgbaData[i * 4 + 3] = 255; // A: opaque
    }

    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      rgbaData,
      width,
      height,
      ui.PixelFormat.rgba8888,
      (final ui.Image img) => completer.complete(img),
    );
    return completer.future;
  }

  /// Adjusts the Window Center and Width relative to current values.
  ///
  /// This is typically called by touch/mouse drag gestures on the [DicomViewer].
  void adjustWindowing({
    required final double deltaX,
    required final double deltaY,
  }) {
    if (!hasData) return;

    const sensitivity = 1.5;
    updateWindowing(
      center: _currentWindowCenter! + (deltaY * sensitivity),
      width: _currentWindowWidth! + (deltaX * sensitivity),
    );
  }

  /// Updates the Window Center and Width to specific values.
  ///
  /// Useful for programmatic presets (e.g., "Bone Window", "Lung Window").
  void updateWindowing({final double? center, final double? width}) {
    if (!hasData) return;

    if (center != null) {
      _currentWindowCenter = center;
    }
    if (width != null) {
      _currentWindowWidth = width.clamp(1.0, 65536.0);
    }

    notifyListeners();
  }

  /// Resets the contrast and brightness to the defaults found in the DICOM headers.
  void resetWindowing() {
    if (!hasData) return;
    _currentWindowCenter = _currentFrame?.metadata.windowCenter;
    _currentWindowWidth = _currentFrame?.metadata.windowWidth;
    notifyListeners();
  }

  /// Sets the active color map and generates the corresponding LUT texture.
  ///
  /// Pass [DicomColorMap.grayscale] to disable colorization.
  Future<void> setColorMap(final DicomColorMap map) async {
    if (_colorMap == map && _colorLutTexture != null) return;
    _colorMap = map;

    // Dispose old LUT texture
    _colorLutTexture?.dispose();
    _colorLutTexture = null;

    if (map == DicomColorMap.grayscale) {
      notifyListeners();
      return;
    }

    // Generate LUT texture
    final lutBytes = ColorMapLut.generate(map);
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      lutBytes,
      256,
      1,
      ui.PixelFormat.rgba8888,
      (final ui.Image img) => completer.complete(img),
    );
    _colorLutTexture = await completer.future;
    notifyListeners();
  }

  /// Clears the current session data and frees memory.
  void clear() {
    _currentFrame = null;
    _rawTexture?.dispose();
    _rawTexture = null;
    _currentWindowCenter = null;
    _currentWindowWidth = null;
    _colorLutTexture?.dispose();
    _colorLutTexture = null;
    _colorMap = DicomColorMap.grayscale;
    _invert = false;
    _clearError();
    notifyListeners();
  }

  /// Disposes resources used by the controller, including GPU textures.
  @override
  void dispose() {
    _rawTexture?.dispose();
    _colorLutTexture?.dispose();
    super.dispose();
  }

  // --- Internal Helpers ---
  void _setLoading(final bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
  }
}
