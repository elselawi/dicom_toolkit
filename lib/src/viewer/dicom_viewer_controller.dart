import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../core/constants/color_maps.dart';
import '../core/dicom_parse_result.dart';
import '../tools/dicom_parser.dart';
import '../tools/dicom_renderer.dart';

/// Reactive state controller for the [DicomViewer] widget.
///
/// Orchestrates parsing (via [DicomParser]) and GPU rendering (via
/// [DicomRenderer]). Exposes reactive state for loading, errors, windowing,
/// colorization, and zoom. The [DicomViewer] widget listens via
/// [ChangeNotifier].
class DicomViewerController extends ChangeNotifier {
  /// Creates a controller.
  ///
  /// [parser] defaults to [DicomParser] (Rust-backed). [renderer] defaults to
  /// [DicomRenderer] (grayscale). Inject custom implementations for testing
  /// or alternative backends.
  DicomViewerController({
    final DicomParser? parser,
    final DicomRenderer? renderer,
  })  : _parser = parser ?? const DicomParser(),
        _renderer = renderer ?? DicomRenderer();

  final DicomParser _parser;
  final DicomRenderer _renderer;

  // --- State ---
  DicomParseResult? _result;
  ui.Image? _rawTexture;
  ui.Image? _colorLutTexture;
  ui.FragmentShader? _shader;
  bool _isLoading = false;
  String? _errorMessage;
  double? _windowCenter;
  double? _windowWidth;
  DicomColorMap _colorMap = DicomColorMap.grayscale;
  bool _invert = false;
  int _rotationSteps = 0; // 0=0°, 1=90°CW, 2=180°, 3=270°CW

  // --- Getters ---

  /// True while a DICOM file is being parsed or rendered.
  bool get isLoading => _isLoading;

  /// True if the last load operation failed.
  bool get hasError => _errorMessage != null;

  /// True when metadata, texture, and shader are all ready for display.
  bool get hasData => _result != null && _rawTexture != null && _shader != null;

  /// The last error message, or null if no error.
  String? get errorMessage => _errorMessage;

  /// The parsed DICOM result, or null if nothing loaded.
  DicomParseResult? get result => _result;

  /// The packed 16-bit texture for GPU consumption.
  ui.Image? get rawTexture => _rawTexture;

  /// The 256×1 color LUT texture, or null for grayscale.
  ui.Image? get colorLutTexture => _colorLutTexture;

  /// The current window center (level).
  double? get windowCenter => _windowCenter;

  /// The current window width.
  double? get windowWidth => _windowWidth;

  /// The active color map.
  DicomColorMap get colorMap => _colorMap;

  /// Whether grayscale inversion is active.
  bool get invert => _invert;

  /// True when the image uses MONOCHROME1 photometric interpretation.
  bool get isMonochrome1 =>
      _result?.metadata.photometricInterpretation == 'MONOCHROME1';

  /// Number of 90° clockwise rotation steps (0–3). 0 = upright, 1 = 90° CW, etc.
  int get rotationSteps => _rotationSteps;

  /// The cached fragment shader, or null if not yet compiled.
  ui.FragmentShader? get shader => _shader;

  /// True once the fragment shader has been compiled.
  bool get hasShader => _shader != null;

  /// Ensures the fragment shader is compiled.
  Future<void> ensureShader() async {
    if (_shader != null) return;
    _shader = await _renderer.shader;
    notifyListeners();
  }

  /// Parses DICOM [bytes] and creates the GPU texture.
  Future<void> loadFromBytes({
    required final Uint8List bytes,
  }) async {
    if (_isLoading) return;

    _setLoading(true);
    _clearError();

    try {
      await ensureShader();
      _result = await _parser.parse(bytes);
      _windowCenter ??= _result!.metadata.windowCenter;
      _windowWidth ??= _result!.metadata.windowWidth;
      _rawTexture = await _renderer.createTexture(_result!);
      if (_colorMap != DicomColorMap.grayscale) {
        await _buildColorLut();
      }
    } catch (e) {
      _errorMessage = 'Failed to load DICOM: $e';
    } finally {
      _setLoading(false);
    }
  }

  /// Adjusts window center/width relative to current values.
  void adjustWindowing({
    required final double deltaX,
    required final double deltaY,
  }) {
    if (!hasData) return;
    const sensitivity = 1.5;
    updateWindowing(
      center: _windowCenter! + (deltaY * sensitivity),
      width: _windowWidth! + (deltaX * sensitivity),
    );
  }

  /// Sets absolute window center/width.
  void updateWindowing({final double? center, final double? width}) {
    if (!hasData) return;
    if (center != null) _windowCenter = center;
    if (width != null) _windowWidth = width.clamp(1.0, 65536.0);
    notifyListeners();
  }

  /// Resets windowing to DICOM header defaults.
  void resetWindowing() {
    if (!hasData) return;
    _windowCenter = _result!.metadata.windowCenter;
    _windowWidth = _result!.metadata.windowWidth;
    notifyListeners();
  }

  /// Applies a [DicomWindowPreset] by its center and width.
  void applyPreset(
      {required final double center, required final double width}) {
    updateWindowing(center: center, width: width);
  }

  /// Sets the active color map.
  Future<void> setColorMap(final DicomColorMap map) async {
    if (_colorMap == map && _colorLutTexture != null) return;
    _colorMap = map;

    _colorLutTexture?.dispose();
    _colorLutTexture = null;

    if (map == DicomColorMap.grayscale) {
      notifyListeners();
      return;
    }

    await _buildColorLut();
    notifyListeners();
  }

  /// Toggles grayscale inversion.
  void toggleInvert() {
    _invert = !_invert;
    notifyListeners();
  }

  /// Rotates 90° clockwise. Cycles through 0 → 1 → 2 → 3 → 0.
  void rotateClockwise() {
    _rotationSteps = (_rotationSteps + 1) % 4;
    notifyListeners();
  }

  /// Rotates 90° counter-clockwise. Cycles through 0 → 3 → 2 → 1 → 0.
  void rotateCounterClockwise() {
    _rotationSteps = (_rotationSteps + 3) % 4;
    notifyListeners();
  }

  /// Clears current data and frees GPU resources.
  void clear() {
    _result = null;
    _rawTexture?.dispose();
    _rawTexture = null;
    _colorLutTexture?.dispose();
    _colorLutTexture = null;
    _windowCenter = null;
    _windowWidth = null;
    _invert = false;
    _rotationSteps = 0;
    _colorMap = DicomColorMap.grayscale;
    _clearError();
    notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _rawTexture?.dispose();
    _colorLutTexture?.dispose();
    _renderer.dispose();
    super.dispose();
  }

  bool _disposed = false;

  // --- Internal ---

  Future<void> _buildColorLut() async {
    final lutBytes = ColorMapLut.generate(_colorMap);
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      lutBytes,
      256,
      1,
      ui.PixelFormat.rgba8888,
      (final ui.Image img) => completer.complete(img),
    );
    _colorLutTexture = await completer.future;
  }

  void _setLoading(final bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
