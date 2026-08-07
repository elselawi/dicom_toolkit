import 'dart:typed_data';
import 'dart:ui' as ui;

import '../core/constants/color_maps.dart';
import '../core/dicom_parse_result.dart';
import 'dicom_renderer.dart';

/// Encodes a rendered [ui.Image] into PNG [ByteData].
///
/// Injectable for tests so PNG encoding failures can be simulated without a
/// real rasterizer. Defaults to [ui.Image.toByteData] with PNG format.
typedef PngEncoder = Future<ByteData?> Function(ui.Image image);

/// Exports rendered DICOM images as PNG bytes.
///
/// Combines [DicomRenderer] for GPU rendering and [ui.Image.toByteData] for
/// PNG encoding.  Returns a [Uint8List] that works on all platforms — write
/// it to disk with `dart:io`, trigger a browser download on web, or hand it
/// to a sharing plugin.
class DicomExport {
  /// Creates an exporter.
  ///
  /// [encodePng] overrides PNG encoding (used by tests to simulate encoding
  /// failures and verify disposal). When `null` (default), PNG encoding is
  /// performed with [ui.Image.toByteData].
  const DicomExport({final PngEncoder? encodePng}) : _encodePng = encodePng;

  final PngEncoder? _encodePng;

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
      try {
        final encode = _encodePng ?? _defaultEncodePng;
        final byteData = await encode(rendered);
        if (byteData == null) throw StateError('Failed to encode image');
        // Copy the PNG bytes explicitly (respecting offset/length) before
        // disposing the image. The ByteData view wraps a buffer owned by
        // `rendered`, which is released by dispose(), so returning a view
        // (e.g. buffer.asUint8List()) would hand back freed/garbled memory.
        return Uint8List.fromList(byteData.buffer
            .asUint8List(byteData.offsetInBytes, byteData.lengthInBytes));
      } finally {
        // Dispose the rendered image on every path — success, encoding
        // returning null, or encoding throwing. Never retain a large raster
        // allocation when export fails under memory pressure.
        rendered.dispose();
      }
    } finally {
      renderer.dispose();
    }
  }

  /// Default PNG encoder backed by the platform rasterizer.
  Future<ByteData?> _defaultEncodePng(final ui.Image rendered) {
    return rendered.toByteData(format: ui.ImageByteFormat.png);
  }
}
