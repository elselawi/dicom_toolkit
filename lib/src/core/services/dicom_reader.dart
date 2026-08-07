import '../../rust/api/core/config/dicom_config.dart';
import '../../rust/api/core/models/dicom_frame_result.dart';
import '../../rust/api/init.dart';
import '../dicom_metadata.dart';
import '../exceptions/dicom_exceptions.dart';

/// Lightweight DICOM metadata + file identity, returned by [readDicomInfo].
///
/// Use this when you only need header information without loading pixel data
/// or compiling GPU shaders.
class DicomFileInfo {
  /// Creates a [DicomFileInfo].
  const DicomFileInfo({
    required this.filePath,
    required this.fileName,
    required this.metadata,
  });

  /// The absolute path to the .dcm file on disk.
  final String filePath;

  /// The file name (including extension), extracted from [filePath].
  final String fileName;

  /// All extracted DICOM metadata fields.
  final DicomMetadata metadata;

  @override
  String toString() =>
      'DicomFileInfo(file: $fileName, modality: ${metadata.modality})';
}

/// Reads DICOM metadata from a file without loading pixel data or GPU shaders.
///
/// This is a lightweight, zero-setup API that parses the file header through
/// the Rust core and skips pixel extraction entirely.
///
/// **Prerequisite**: [RustLib.init()] must have been called once before.
///
/// Throws [DicomProcessingException] if the file cannot be opened or parsed.
Future<DicomFileInfo> readDicomInfo(final String filePath) async {
  final fileName = filePath.split(RegExp(r'[/\\]')).last;
  const config = DicomConfig(
    autoNormalize: false,
    skipPixels: true,
  );

  final DicomFrameResult result;
  try {
    result = await loadDicom(path: filePath, config: config);
  } catch (e) {
    throw DicomProcessingException(
      'Failed to read DICOM metadata from "$fileName"',
      e,
    );
  }

  return DicomFileInfo(
    filePath: filePath,
    fileName: fileName,
    metadata: DicomMetadata(inner: result.metadata),
  );
}
