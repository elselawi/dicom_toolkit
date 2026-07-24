import 'dart:typed_data';

import '../core/dicom_parse_result.dart';
import '../core/dicom_tag_id.dart';
import '../rust/api/core/config/dicom_config.dart';
import '../rust/api/init.dart' show loadDicomFromBytes;

/// Decodes raw DICOM bytes into a [DicomParseResult].
///
/// Implement this interface to plug in custom decoding strategies
/// (e.g. a PACS client, S3 fetcher, or alternative parser).
abstract class DicomDecoder {
  /// Decodes [bytes] into structured DICOM data.
  Future<DicomParseResult> decode(
    final Uint8List bytes, {
    final DicomConfig? config,
  });
}

/// The default decoder — delegates to the high-performance Rust FFI bridge.
class RustDecoder implements DicomDecoder {
  /// Creates a [RustDecoder] backed by the native Rust DICOM engine.
  const RustDecoder();

  @override
  Future<DicomParseResult> decode(
    final Uint8List bytes, {
    final DicomConfig? config,
  }) async {
    final finalConfig = config ?? await DicomConfig.default_();
    final frameResult = await loadDicomFromBytes(
      bytes: bytes.toList(),
      config: finalConfig,
    );

    // Build a tag map from the typed getters on the generated metadata.
    final innerMeta = frameResult.metadata;
    final tags = <DicomTagId, String>{
      DicomTagId.patientName: innerMeta.patientName,
      DicomTagId.patientId: innerMeta.patientId,
      DicomTagId.studyDate: innerMeta.studyDate,
      DicomTagId.studyDescription: innerMeta.studyDescription,
      DicomTagId.modality: innerMeta.modality,
      DicomTagId.manufacturer: innerMeta.manufacturer,
      DicomTagId.manufacturerModelName: innerMeta.manufacturerModelName,
      DicomTagId.institutionName: innerMeta.institutionName,
      DicomTagId.studyInstanceUid: innerMeta.studyInstanceUid,
      DicomTagId.seriesInstanceUid: innerMeta.seriesInstanceUid,
      DicomTagId.sopInstanceUid: innerMeta.sopInstanceUid,
      DicomTagId.seriesDescription: innerMeta.seriesDescription,
      DicomTagId.bodyPartExamined: innerMeta.bodyPartExamined,
      DicomTagId.sliceThickness: innerMeta.sliceThickness.toString(),
      DicomTagId.instanceNumber: innerMeta.instanceNumber,
      DicomTagId.width: innerMeta.width.toString(),
      DicomTagId.height: innerMeta.height.toString(),
      DicomTagId.samplesPerPixel: innerMeta.samplesPerPixel.toString(),
      DicomTagId.bitsAllocated: innerMeta.bitsAllocated.toString(),
      DicomTagId.bitsStored: innerMeta.bitsStored.toString(),
      DicomTagId.highBit: innerMeta.highBit.toString(),
      DicomTagId.pixelRepresentation: innerMeta.pixelRepresentation.toString(),
      DicomTagId.pixelSpacing: innerMeta.pixelSpacing,
      DicomTagId.photometricInterpretation: innerMeta.photometricInterpretation,
      DicomTagId.windowCenter: innerMeta.windowCenter.toString(),
      DicomTagId.windowWidth: innerMeta.windowWidth.toString(),
      DicomTagId.rescaleIntercept: innerMeta.rescaleIntercept.toString(),
      DicomTagId.rescaleSlope: innerMeta.rescaleSlope.toString(),
    };

    return DicomParseResult.fromFrame(frame: frameResult, tags: tags);
  }
}
