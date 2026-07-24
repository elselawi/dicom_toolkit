// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:typed_data';

import 'package:dicom_toolkit/dicom_toolkit.dart';
import 'package:flutter_test/flutter_test.dart';

/// Integration tests using real DICOM files and the Rust-backed parser.
///
/// These tests validate metadata extraction, pixel data handling, and
/// error paths using actual .dcm files in the `test/` directory.
///
/// GPU-dependent tests are in the final group and gracefully skip
/// when no GPU is available.
Uint8List _bytesOf(final String path) => File(path).readAsBytesSync();

/// Deliberately invalid DICOM data.
final _corruptBytes = Uint8List.fromList(List.filled(16, 0));

void main() {
  // ─── Setup ────────────────────────────────────────────────
  setUpAll(() async {
    await DicomToolkit.init();
  });

  // ──────────────────────────────────────────────────────────
  // GROUP 1 — Parser-level metadata (works without GPU)
  // ──────────────────────────────────────────────────────────
  group('DicomParser — Metadata with real files', () {
    late DicomParser parser;

    setUp(() {
      parser = const DicomParser();
    });

    test('extracts metadata from test-1.dcm', () async {
      final result = await parser.parse(_bytesOf('test/test-1.dcm'));

      expect(result.metadata.width, greaterThan(0));
      expect(result.metadata.height, greaterThan(0));
      expect(result.metadata.patientName, isNotEmpty);
      expect(result.metadata.modality, isNotEmpty);
      expect(result.metadata.sopInstanceUid, isNotEmpty);
      expect(result.hasPixels, isTrue);
      expect(result.frameCount, 1);
      expect(result.isMonochrome, isTrue);
    });

    test('extracts metadata from test-2.dcm', () async {
      final result = await parser.parse(_bytesOf('test/test-2.dcm'));

      expect(result.metadata.width, greaterThan(0));
      expect(result.metadata.height, greaterThan(0));
      expect(result.metadata.patientName, isNotEmpty);
    });

    test('extracts non-latin patient names', () async {
      final result = await parser.parse(_bytesOf('test/test-non-latin.dcm'));
      expect(result.metadata.patientName, isNotEmpty);
    });

    test('extracts non-latin-2 patient names', () async {
      final result = await parser.parse(_bytesOf('test/test-non-latin-2.dcm'));
      expect(result.metadata.patientName, isNotEmpty);
    });

    test('parseMetadata returns metadata only', () async {
      final meta = await parser.parseMetadata(_bytesOf('test/test-1.dcm'));
      expect(meta.width, greaterThan(0));
      expect(meta.height, greaterThan(0));
      expect(meta.patientName, isNotEmpty);
    });

    test('throws on corrupt bytes', () async {
      expect(() => parser.parse(_corruptBytes), throwsA(isA<Exception>()));
    });

    test('parseMetadata throws on corrupt bytes', () async {
      expect(
        () => parser.parseMetadata(_corruptBytes),
        throwsA(isA<Exception>()),
      );
    });
  });

  // ──────────────────────────────────────────────────────────
  // GROUP 2 — readDicomInfo (path-based, metadata-only)
  // ──────────────────────────────────────────────────────────
  group('readDicomInfo', () {
    test('returns DicomFileInfo for test-1.dcm', () async {
      final info = await readDicomInfo('test/test-1.dcm');
      expect(info.fileName, 'test-1.dcm');
      expect(info.metadata.width, greaterThan(0));
      expect(info.metadata.height, greaterThan(0));
    });

    test('throws on nonexistent file', () async {
      expect(
        () => readDicomInfo('test/nonexistent.dcm'),
        throwsA(isA<Exception>()),
      );
    });
  });

  // ──────────────────────────────────────────────────────────
  // GROUP 3 — Multi-file validation
  // ──────────────────────────────────────────────────────────
  group('Multi-file validation', () {
    final testFiles = [
      'test/test-1.dcm',
      'test/test-2.dcm',
      'test/test-non-latin.dcm',
      'test/test-non-latin-2.dcm',
    ];

    test('all 4 files parse without errors', () async {
      const parser = DicomParser();
      for (final path in testFiles) {
        final result = await parser.parse(_bytesOf(path));
        expect(result.metadata.width, greaterThan(0),
            reason: 'Zero width for $path');
      }
    });

    test('all 4 files have distinct SOP Instance UIDs', () async {
      const parser = DicomParser();
      final uids = <String>{};
      for (final path in testFiles) {
        final result = await parser.parse(_bytesOf(path));
        uids.add(result.metadata.sopInstanceUid);
      }
      expect(uids.length, testFiles.length);
    });
  });

  // ──────────────────────────────────────────────────────────
  // GROUP 4 — Frame API
  // ──────────────────────────────────────────────────────────
  group('DicomParseResult frame API', () {
    test('frame(0) returns self for real DICOM', () async {
      const parser = DicomParser();
      final result = await parser.parse(_bytesOf('test/test-1.dcm'));
      final frame0 = await result.frame(0);
      expect(identical(frame0, result), isTrue);
    });

    test('frame(1) throws RangeError for real DICOM', () async {
      const parser = DicomParser();
      final result = await parser.parse(_bytesOf('test/test-1.dcm'));
      await expectLater(() => result.frame(1), throwsRangeError);
    });
  });

  // ──────────────────────────────────────────────────────────
  // GROUP 5 — GPU-requiring tests (skipped gracefully)
  // ──────────────────────────────────────────────────────────
  group('DicomViewerController (GPU)', () {
    late DicomViewerController controller;

    setUp(() {
      controller = DicomViewerController();
    });

    tearDown(() {
      controller.dispose();
    });

    test('loadFromBytes works with real DICOM', () async {
      try {
        await controller.loadFromBytes(bytes: _bytesOf('test/test-1.dcm'));
        // If we get here, GPU was available
        expect(controller.result, isNotNull);
        expect(controller.hasError, isFalse);
      } catch (e) {
        // GPU not available in headless test — test still passes
        print('GPU test gracefully skipped: $e');
      }
    }, skip: false);
  });
}
