import '../rust/api/core/models/dicom_frame_result.dart';
import '../tools/dicom_roi.dart';
import 'dicom_metadata.dart';
import 'dicom_pixel_data.dart';
import 'dicom_tag_id.dart';

/// The result of parsing a single DICOM file.
///
/// Provides access to [metadata] (all 28 typed getters + generic tag lookup)
/// and [pixelData] (a sealed [DicomPixelData] subtype). Multi-frame datasets
/// are represented via [frameCount] and [frame], though the initial release
/// only produces single-frame results.
class DicomParseResult {
  const DicomParseResult._({
    required this.metadata,
    required this.pixelData,
  }) : frameCount = 1;

  /// Creates from the generated [DicomFrameResult].
  factory DicomParseResult.fromFrame({
    required final DicomFrameResult frame,
    final Map<DicomTagId, String>? tags,
  }) {
    final innerMeta = frame.metadata;
    final wrappedMeta = DicomMetadata(inner: innerMeta, tags: tags);

    const defaultAllocated = 16;
    const defaultStored = 16;
    final isSigned = innerMeta.pixelRepresentation == 1;

    final pixelData = DicomInt16PixelData(
      buffer: frame.pixelData,
      width: innerMeta.width,
      height: innerMeta.height,
      bitsAllocated: innerMeta.bitsAllocated != 0
          ? innerMeta.bitsAllocated
          : defaultAllocated,
      bitsStored:
          innerMeta.bitsStored != 0 ? innerMeta.bitsStored : defaultStored,
      isSigned: isSigned,
    );

    return DicomParseResult._(
      metadata: wrappedMeta,
      pixelData: pixelData,
    );
  }

  /// All 28 extracted DICOM tags + generic lookup.
  final DicomMetadata metadata;

  /// The typed pixel buffer.
  final DicomPixelData pixelData;

  /// Number of frames in the dataset. Always 1 in the initial release.
  final int frameCount;

  /// Returns the frame at [index]. In the initial release, always returns
  /// `this` (single-frame datasets only).
  Future<DicomParseResult> frame(final int index) async {
    if (index < 0 || index >= frameCount) {
      throw RangeError.range(
          index, 0, frameCount - 1, 'frame', 'frameCount is $frameCount');
    }
    return this;
  }

  /// True if pixel data was extracted (i.e. [pixelData] is non-empty).
  bool get hasPixels => pixelData.length > 0;

  /// True if the image is monochrome (`samplesPerPixel == 1`).
  bool get isMonochrome => metadata.samplesPerPixel == 1;

  /// True if pixel values are signed (`pixelRepresentation == 1`).
  bool get isSigned => metadata.pixelRepresentation == 1;

  /// Convenience: compute ROI statistics over this result.
  RoiStatistics computeRoi(final DicomRoi roi) => roi.compute(this);
}
