import 'dart:typed_data';

/// The pixel data extracted from a DICOM file.
///
/// This is a sealed class hierarchy — pattern-match on the subtype to
/// access the underlying buffer in its native format.
///
/// Currently only [DicomInt16PixelData] is produced by the parser.
/// Other variants are reserved for future modality support.
sealed class DicomPixelData {
  const DicomPixelData();

  /// Total number of pixel elements (width × height × samplesPerPixel).
  int get length;

  /// Image width in pixels.
  int get width;

  /// Image height in pixels.
  int get height;

  /// Bits allocated per pixel sample (from DICOM tag 0028,0100).
  int get bitsAllocated;

  /// Bits actually used per pixel sample (from DICOM tag 0028,0101).
  int get bitsStored;

  /// True if pixel values are signed (pixelRepresentation == 1).
  bool get isSigned;
}

/// 16-bit signed monochrome pixel data — the most common modality for CT, MR, CR, DX.
class DicomInt16PixelData extends DicomPixelData {
  /// Creates 16-bit monochrome pixel data.
  ///
  /// [buffer] contains row-major 16-bit signed values.
  /// [width] is the image width in pixels.
  /// [height] is the image height in pixels.
  const DicomInt16PixelData({
    required this.buffer,
    required this.width,
    required this.height,
    required this.bitsAllocated,
    required this.bitsStored,
    required this.isSigned,
  });

  /// The raw 16-bit signed pixel values, laid out row-major.
  final Int16List buffer;

  @override
  int get length => buffer.length;

  @override
  final int width;

  @override
  final int height;

  @override
  final int bitsAllocated;

  @override
  final int bitsStored;

  @override
  final bool isSigned;
}
