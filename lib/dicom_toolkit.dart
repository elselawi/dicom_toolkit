library;

import 'dart:ui' as ui;

import 'src/core/dicom_parse_result.dart';
import 'src/rust/frb_generated.dart';
import 'src/tools/dicom_renderer.dart';

export 'src/backend/dicom_decoder.dart';
export 'src/core/constants/color_maps.dart';
export 'src/core/constants/lib_shaders.dart';
export 'src/core/dicom_metadata.dart';
export 'src/core/dicom_parse_result.dart';
export 'src/core/dicom_pixel_data.dart';
export 'src/core/dicom_tag_id.dart';
export 'src/core/exceptions/dicom_exceptions.dart';
export 'src/core/services/dicom_reader.dart';
export 'src/core/shader/dicom_shader_painter.dart';
export 'src/core/widgets/dicom_viewer.dart';
export 'src/rust/api/core/config/dicom_config.dart';
export 'src/rust/api/core/models/dicom_frame_result.dart';
export 'src/rust/api/core/models/dicom_metadata.dart' hide DicomMetadata;
export 'src/rust/frb_generated.dart' show RustLib;
export 'src/tools/dicom_export.dart';
export 'src/tools/dicom_parser.dart';
export 'src/tools/dicom_renderer.dart';
export 'src/tools/dicom_roi.dart';
export 'src/tools/dicom_ruler.dart';
export 'src/tools/dicom_window_preset.dart';
export 'src/viewer/dicom_viewer_controller.dart';

/// Entry point for the dicom_toolkit library.
///
/// Call [init] once before using any other toolkit API.
/// This loads the native Rust/WASM backend.
///
/// For a quick render, use the one-liner [render].
abstract class DicomToolkit {
  DicomToolkit._();

  /// Initializes the underlying native engine.
  /// Must be called once at application startup, before any parsing or rendering.
  static Future<void> init() => RustLib.init();

  /// One-liner: renders a [DicomParseResult] to a [dart:ui.Image].
  ///
  /// ```dart
  /// await DicomToolkit.init();
  /// final parser = DicomParser();
  /// final result = await parser.parse(bytes);
  /// final image = await DicomToolkit.render(result);
  /// ```
  static Future<ui.Image> render(
    final DicomParseResult result, {
    final double? windowCenter,
    final double? windowWidth,
    final int rotationSteps = 0,
  }) =>
      DicomRenderer().render(
        result,
        windowCenter: windowCenter,
        windowWidth: windowWidth,
        rotationSteps: rotationSteps,
      );
}
