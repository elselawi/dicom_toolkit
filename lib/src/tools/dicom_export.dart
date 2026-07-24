import 'dart:typed_data';
import 'dart:ui' as ui;

import '../core/constants/color_maps.dart';
import '../core/dicom_parse_result.dart';
import 'dicom_renderer.dart';

/// Exports rendered DICOM images as PNG bytes.
///
/// Combines [DicomRenderer] for GPU rendering and [ui.Image.toByteData] for
/// PNG encoding.  Returns a [Uint8List] that works on all platforms — write
/// it to disk with `dart:io`, trigger a browser download on web, or hand it
/// to a sharing plugin.
class DicomExport {
  /// Creates an exporter.
  const DicomExport();

  /// Renders [result] with the given windowing and returns PNG bytes.
  ///
  /// [windowCenter] and [windowWidth] default to the values stored in the
  /// DICOM header.  [colorMap] defaults to grayscale; pass a different
  /// [DicomColorMap] for pseudocolor output.  [invert] toggles grayscale
  /// inversion.  [rotationSteps] rotates the output 0–3 steps of 90° CW.
  Future<Uint8List> toPngBytes(
    final DicomParseResult result, {
    final double? windowCenter,
    final double? windowWidth,
    final DicomColorMap colorMap = DicomColorMap.grayscale,
    final bool invert = false,
    final int rotationSteps = 0,
  }) async {
    // Use a throw-away renderer scoped to this call so we don't leak the
    // caller's color-map / invert state.
    final renderer = DicomRenderer(
      colorMap: colorMap,
      invert: invert,
    );
    try {
      final rendered = await renderer.render(
        result,
        windowCenter: windowCenter,
        windowWidth: windowWidth,
        rotationSteps: rotationSteps,
      );
      final byteData =
          await rendered.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw StateError('Failed to encode image');
      rendered.dispose();
      return byteData.buffer.asUint8List();
    } finally {
      renderer.dispose();
    }
  }
}
