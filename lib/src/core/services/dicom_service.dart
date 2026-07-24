import 'dart:typed_data';

import '../../rust/api/core/config/dicom_config.dart';
import '../../rust/api/core/models/dicom_frame_result.dart';
import '../../rust/api/init.dart';

/// An abstract interface defining how DICOM files are loaded.
///
/// By using this interface, the SDK allows for pluggable loading strategies.
/// For example, you could implement a `NetworkDicomLoader` to stream bytes
/// directly from a PACS server.
///
/// Loading is bytes-only by design: there is no local file system on the
/// Web, so callers are expected to read a file's contents into memory
/// (e.g. via a file picker or `dart:io`) before handing it to the loader.
abstract class IDicomLoader {
  /// Loads a DICOM object from raw bytes.
  Future<DicomFrameResult> loadFromBytes(final Uint8List bytes,
      {final DicomConfig? config});
}

/// The default implementation for loading DICOM files via the Rust bridge.
class RustDicomLoader implements IDicomLoader {
  @override
  Future<DicomFrameResult> loadFromBytes(final Uint8List bytes,
      {final DicomConfig? config}) async {
    final finalConfig = config ?? await DicomConfig.default_();
    return loadDicomFromBytes(bytes: bytes.toList(), config: finalConfig);
  }
}

/// A domain service that orchestrates DICOM operations.
///
/// This class serves as a bridge between the [DicomController] (State Management)
/// and the [IDicomLoader] (Data Access).
class DicomService {
  /// Creates a [DicomService] with a specific loader.
  ///
  /// Defaults to [RustDicomLoader] if no loader is provided.
  DicomService({final IDicomLoader? loader})
      : _loader = loader ?? RustDicomLoader();
  final IDicomLoader _loader;

  /// Requests a processed DICOM frame from raw bytes.
  Future<DicomFrameResult> loadFrameFromBytes(final Uint8List bytes,
      {final DicomConfig? config}) {
    return _loader.loadFromBytes(bytes, config: config);
  }
}
