import 'dart:typed_data';
import 'dart:ui' as ui;

/// Utility for exporting DICOM images.
abstract class DicomExport {
  DicomExport._();

  /// Converts a [ui.Image] to PNG bytes.
  ///
  /// Use this to save the current rendered frame.
  static Future<Uint8List> toPngBytes(ui.Image image) async {
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) throw StateError('Failed to encode image');
    return byteData.buffer.asUint8List();
  }
}
