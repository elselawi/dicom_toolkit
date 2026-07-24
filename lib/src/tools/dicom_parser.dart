import 'dart:typed_data';

import '../backend/dicom_decoder.dart';
import '../core/dicom_metadata.dart';
import '../core/dicom_parse_result.dart';
import '../rust/api/core/config/dicom_config.dart';

/// The primary entry point for reading DICOM files.
///
/// Injects a [DicomDecoder] (defaults to [RustDecoder]) and provides both
/// bytes-based and file-based convenience methods.
///
/// For metadata-only reads without loading pixel data, use [parseMetadata] —
/// it passes `skipPixels: true` to the Rust engine for a fast header-only
/// parse.
class DicomParser {
  /// Creates a parser backed by [decoder]. Defaults to [RustDecoder] if omitted.
  const DicomParser({final DicomDecoder decoder = const RustDecoder()})
      : _decoder = decoder;
  final DicomDecoder _decoder;

  /// Parses raw DICOM [bytes] and returns the complete result (metadata + pixels).
  Future<DicomParseResult> parse(final Uint8List bytes) =>
      _decoder.decode(bytes);

  /// Parses raw DICOM [bytes] and returns only the [DicomMetadata].
  ///
  /// Unlike [parse], this uses `skipPixels: true` so the Rust engine skips
  /// pixel extraction — fast and GPU-free.
  Future<DicomMetadata> parseMetadata(final Uint8List bytes) async {
    const config = DicomConfig(autoNormalize: false, skipPixels: true);
    final result = await _decoder.decode(bytes, config: config);
    return result.metadata;
  }
}
