import 'dart:io';
import 'dart:typed_data';

import '../backend/dicom_decoder.dart';
import '../core/dicom_metadata.dart';
import '../core/dicom_parse_result.dart';
import '../rust/api/core/config/dicom_config.dart';

/// The primary entry point for reading DICOM files.
///
/// Injects a [DicomDecoder] (defaults to [RustDecoder]) and provides both
/// bytes-based and file-based convenience methods.  Use [parse] when you
/// already have bytes (web, in-memory) and [parseFile] for local paths.
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

  /// Reads [file] from disk, then parses it.
  Future<DicomParseResult> parseFile(final File file) =>
      file.readAsBytes().then(_decoder.decode);

  /// Parses raw DICOM [bytes] and returns only the [DicomMetadata].
  ///
  /// Unlike [parse], this uses `skipPixels: true` so the Rust engine skips
  /// pixel extraction — fast and GPU-free.
  Future<DicomMetadata> parseMetadata(final Uint8List bytes) async {
    const config = DicomConfig(autoNormalize: false, skipPixels: true);
    final result = await _decoder.decode(bytes, config: config);
    return result.metadata;
  }

  /// Reads [file] from disk, then returns only the [DicomMetadata].
  ///
  /// Uses `skipPixels: true` — fast, no pixel extraction.
  Future<DicomMetadata> parseMetadataFile(final File file) async {
    final bytes = await file.readAsBytes();
    return parseMetadata(bytes);
  }
}
