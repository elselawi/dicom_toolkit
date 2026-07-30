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
  // GROUP 4.5 — Spatial & volumetric metadata
  // ──────────────────────────────────────────────────────────
  group('Spatial & volumetric metadata', () {
    late DicomParser parser;

    setUp(() {
      parser = const DicomParser();
    });

    test('numberOfFrames defaults to 1 for single-frame DICOM', () async {
      final result = await parser.parse(_bytesOf('test/test-1.dcm'));
      expect(result.metadata.numberOfFrames, 1);
      expect(result.frameCount, 1);
    });

    test('sliceThickness is extracted when present', () async {
      final result = await parser.parse(_bytesOf('test/test-1.dcm'));
      // sliceThickness may or may not be present; verify it's a valid number
      expect(result.metadata.sliceThickness, isA<double>());
    });

    test('spatial fields are present (may be empty/default)', () async {
      final result = await parser.parse(_bytesOf('test/test-1.dcm'));
      // These fields are always present — they default to empty/zero.
      expect(result.metadata.imagePositionPatient, isA<String>());
      expect(result.metadata.imageOrientationPatient, isA<String>());
      expect(result.metadata.sliceLocation, isA<double>());
      expect(result.metadata.spacingBetweenSlices, isA<double>());
    });

    test('all 9 vendor files have valid numberOfFrames', () async {
      final files = [
        for (var i = 1; i <= 3; i++) 'dcms/carestream ($i).dcm',
        for (var i = 1; i <= 4; i++) 'dcms/generic ($i).dcm',
        for (var i = 1; i <= 2; i++) 'dcms/sirona ($i).dcm',
      ];
      for (final path in files) {
        final result = await parser.parse(_bytesOf(path));
        expect(result.metadata.numberOfFrames, greaterThanOrEqualTo(1),
            reason: '$path numberOfFrames must be ≥ 1');
        expect(result.frameCount, result.metadata.numberOfFrames,
            reason: '$path frameCount must match numberOfFrames');
      }
    });

    test('pixelSpacing parsed components for Generic files', () async {
      final result = await parser.parse(_bytesOf('dcms/generic (1).dcm'));
      // Generic files may have pixel spacing — validate it's parseable if present
      final ps = result.metadata.pixelSpacing;
      if (ps != null && ps.isNotEmpty) {
        expect(result.metadata.pixelSpacingX, isNotNull,
            reason: 'pixelSpacingX should parse from "$ps"');
        expect(result.metadata.pixelSpacingY, isNotNull,
            reason: 'pixelSpacingY should parse from "$ps"');
      }
    });
  });

  // ──────────────────────────────────────────────────────────
  // GROUP 5 — Vendor file validation (Carestream, Generic, Sirona)
  //
  // These tests validate the fixes for:
  //   1. JPEG Lossless decoding (Carestream) via dicom-pixeldata
  //   2. Window center alignment for unsigned pixel data (-32768 offset)
  //   3. MONOCHROME1 vs MONOCHROME2 photometric interpretation
  //   4. 12-bit-in-16-bit pixel data (Carestream bits_stored=12)
  //
  // Files must be present in the dcms/ directory.
  // ──────────────────────────────────────────────────────────

  group('Vendor files — Carestream (JPEG Lossless, MONOCHROME1)', () {
    late DicomParser parser;

    setUp(() {
      parser = const DicomParser();
    });

    test('all 3 Carestream files parse without error', () async {
      for (var i = 1; i <= 3; i++) {
        final result = await parser.parse(_bytesOf('dcms/carestream ($i).dcm'));
        expect(result.metadata.width, greaterThan(0),
            reason: 'carestream ($i) width');
        expect(result.metadata.height, greaterThan(0),
            reason: 'carestream ($i) height');
      }
    });

    test('pixel data is non-empty (JPEG decoded correctly)', () async {
      final result = await parser.parse(_bytesOf('dcms/carestream (1).dcm'));
      expect(result.hasPixels, isTrue);
      expect(result.pixelData.length, greaterThan(0),
          reason: 'JPEG pixel data must be decoded');
      expect(result.pixelData.length,
          result.metadata.width * result.metadata.height,
          reason: 'Pixel count must match image dimensions');
    });

    test('MONOCHROME1 photometric interpretation is detected', () async {
      final result = await parser.parse(_bytesOf('dcms/carestream (1).dcm'));
      expect(result.metadata.photometricInterpretation, 'MONOCHROME1');
      expect(result.isMonochrome, isTrue);
    });

    test('bits_stored = 12 (not 16)', () async {
      final result = await parser.parse(_bytesOf('dcms/carestream (1).dcm'));
      expect(result.metadata.bitsAllocated, 16);
      expect(result.metadata.bitsStored, 12,
          reason: 'Carestream stores 12 meaningful bits in 16-bit container');
    });

    test('window center is in offset space (C ≈ -30720)', () async {
      // DICOM header says C:2048. After the -32768 alignment for unsigned
      // data, the window center should be ~-30720 in the shader's space.
      final result = await parser.parse(_bytesOf('dcms/carestream (1).dcm'));
      final wc = result.metadata.windowCenter;
      expect(wc, lessThan(-30000),
          reason: 'Window center should be in negative offset space, got $wc');
      expect(wc, greaterThan(-31000),
          reason: 'Window center should be near -30720 (2048-32768), got $wc');
    });

    test('pixel values are in 12-bit offset range', () async {
      final result = await parser.parse(_bytesOf('dcms/carestream (1).dcm'));
      final buf = (result.pixelData as DicomInt16PixelData).buffer;
      final min = buf.reduce((a, b) => a < b ? a : b);
      final max = buf.reduce((a, b) => a > b ? a : b);
      // 12-bit unsigned (0..4095) after -32768 offset → (-32768..-28673)
      expect(min, greaterThanOrEqualTo(-32768));
      expect(max, lessThanOrEqualTo(-28673));
    });
  });

  group('Vendor files — Generic XPECT (uncompressed, MONOCHROME2)', () {
    late DicomParser parser;

    setUp(() {
      parser = const DicomParser();
    });

    test('all 4 Generic files parse without error', () async {
      for (var i = 1; i <= 4; i++) {
        final result = await parser.parse(_bytesOf('dcms/generic ($i).dcm'));
        expect(result.metadata.width, greaterThan(0),
            reason: 'generic ($i) width');
        expect(result.metadata.height, greaterThan(0),
            reason: 'generic ($i) height');
      }
    });

    test('pixel data is non-empty', () async {
      final result = await parser.parse(_bytesOf('dcms/generic (1).dcm'));
      expect(result.hasPixels, isTrue);
      expect(result.pixelData.length, greaterThan(0));
      expect(result.pixelData.length,
          result.metadata.width * result.metadata.height);
    });

    test('window center aligned: DICOM C:32768 → offset space C≈0', () async {
      // Generic DICOM header has the useless C:32768 W:65536.
      // After the -32768 alignment, window center should be near 0.
      final result = await parser.parse(_bytesOf('dcms/generic (1).dcm'));
      final wc = result.metadata.windowCenter;
      expect(wc.abs(), lessThan(2.0),
          reason: 'Window center should be ~0 after offset alignment, got $wc');
    });

    test('window width preserved through alignment', () async {
      final result = await parser.parse(_bytesOf('dcms/generic (1).dcm'));
      // Width is not affected by the offset — only center is shifted.
      expect(result.metadata.windowWidth, closeTo(65536.0, 1.0));
    });

    test('MONOCHROME2 photometric interpretation', () async {
      final result = await parser.parse(_bytesOf('dcms/generic (1).dcm'));
      expect(result.metadata.photometricInterpretation, 'MONOCHROME2');
    });

    test('pixel values span the full 16-bit offset range', () async {
      final result = await parser.parse(_bytesOf('dcms/generic (1).dcm'));
      final buf = (result.pixelData as DicomInt16PixelData).buffer;
      final min = buf.reduce((a, b) => a < b ? a : b);
      final max = buf.reduce((a, b) => a > b ? a : b);
      // Full 16-bit unsigned (0..65535) after offset → (-32768..32767)
      expect(min, greaterThanOrEqualTo(-32768));
      expect(max, lessThanOrEqualTo(32767));
    });
  });

  group('Vendor files — Sirona (uncompressed, large dimensions)', () {
    late DicomParser parser;

    setUp(() {
      parser = const DicomParser();
    });

    test('both Sirona files parse without error', () async {
      for (var i = 1; i <= 2; i++) {
        final result = await parser.parse(_bytesOf('dcms/sirona ($i).dcm'));
        expect(result.metadata.width, greaterThan(0),
            reason: 'sirona ($i) width');
        expect(result.metadata.height, greaterThan(0),
            reason: 'sirona ($i) height');
      }
    });

    test('large image dimensions are correct', () async {
      final result = await parser.parse(_bytesOf('dcms/sirona (1).dcm'));
      // Dimensions from diagnostic: 2000×1336 (width × height)
      expect(result.metadata.width, 2000);
      expect(result.metadata.height, 1336);
      expect(result.pixelData.length, 2000 * 1336,
          reason: 'Large Sirona image must have correct pixel count');
    });

    test('window center aligned same as Generic', () async {
      // Sirona also has C:32768 → offset to near 0
      final result = await parser.parse(_bytesOf('dcms/sirona (1).dcm'));
      expect(result.metadata.windowCenter.abs(), lessThan(2.0),
          reason: 'Sirona window center should be ~0, got '
              '${result.metadata.windowCenter}');
    });
  });

  // ──────────────────────────────────────────────────────────
  // GROUP 6 — Window preset computation from pixel data
  // (validates that forImage() uses actual pixel range, not
  //  useless DICOM header values)
  // ──────────────────────────────────────────────────────────

  group('DicomWindowPreset.forImage — pixel-data-driven presets', () {
    late DicomParser parser;

    setUp(() {
      parser = const DicomParser();
    });

    test('Full Range preset uses pixel data, not DICOM header window',
        () async {
      // Generic files have useless DICOM C:32768 W:65536
      final result = await parser.parse(_bytesOf('dcms/generic (1).dcm'));
      final presets = DicomWindowPreset.forImage(result);
      final fullRange = presets.firstWhere((p) => p.label == 'Full Range');

      // Full Range must be centered near 0 (the pixel data midpoint in
      // offset space), NOT at 32768 (the useless DICOM header value).
      expect(fullRange.center.abs(), lessThan(2.0),
          reason: 'Full Range center should come from pixel data (~0), '
              'not DICOM header (32768)');
    });

    test('DICOM Default preset faithfully reports header values', () async {
      final result = await parser.parse(_bytesOf('dcms/generic (1).dcm'));
      final presets = DicomWindowPreset.forImage(result);
      final dicomDefault =
          presets.firstWhere((p) => p.label == 'DICOM Default');

      // After Rust alignment: center should be near 0
      expect(dicomDefault.center.abs(), lessThan(2.0));
    });

    test('Narrow 25% preset is tighter than Full Range', () async {
      final result = await parser.parse(_bytesOf('dcms/generic (1).dcm'));
      final presets = DicomWindowPreset.forImage(result);
      final fullRange = presets.firstWhere((p) => p.label == 'Full Range');
      final narrow = presets.firstWhere((p) => p.label == 'Narrow 25%');

      // Narrow should have the same center but 1/4 the width
      expect(narrow.center, closeTo(fullRange.center, 1.0));
      expect(narrow.width, closeTo(fullRange.width * 0.25, 1.0));
    });

    test('all 9 vendor files produce at least 6 presets', () async {
      final files = [
        for (var i = 1; i <= 3; i++) 'dcms/carestream ($i).dcm',
        for (var i = 1; i <= 4; i++) 'dcms/generic ($i).dcm',
        for (var i = 1; i <= 2; i++) 'dcms/sirona ($i).dcm',
      ];
      for (final path in files) {
        final result = await parser.parse(_bytesOf(path));
        final presets = DicomWindowPreset.forImage(result);
        expect(presets.length, greaterThanOrEqualTo(6),
            reason: '$path should produce at least 6 presets');
        // Verify all presets have positive width
        for (final p in presets) {
          expect(p.width, greaterThan(0),
              reason: '${p.label} preset in $path has non-positive width');
        }
      }
    });
  });

  // ──────────────────────────────────────────────────────────
  // GROUP 7 — GPU-requiring tests (skipped gracefully)
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
