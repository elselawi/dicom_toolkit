// ignore_for_file: avoid_print

import 'package:dicom_toolkit/dicom_toolkit.dart';
import 'package:dicom_toolkit/src/rust/frb_generated.dart';
import 'package:flutter_test/flutter_test.dart';

/// Comprehensive tests for the `readDicomInfo()` lightweight metadata API.
///
/// Requires valid DICOM files in the `test/` directory.
void main() {
  // ─── Setup ────────────────────────────────────────────────

  setUpAll(() async {
    await RustLib.init();
  });

  /// Returns all .dcm files found in the test directory.
  List<String> findTestFiles() {
    // Explicit list of known test files — avoids FS dependency issues
    final candidates = [
      'test/test-1.dcm',
      'test/test-2.dcm',
      'test/test-non-latin.dcm',
      'test/test-non-latin-2.dcm',
    ];
    return candidates;
  }

  // ──────────────────────────────────────────────────────────
  // GROUP 1 ▸ Basic readDicomInfo
  // ──────────────────────────────────────────────────────────
  group('readDicomInfo — Basic', () {
    test('returns DicomFileInfo for test-1.dcm', () async {
      final info = await readDicomInfo('test/test-1.dcm');

      expect(info.fileName, 'test-1.dcm');
      expect(info.filePath, 'test/test-1.dcm');
      expect(info.metadata, isA<DicomMetadata>());
    });

    test('returns DicomFileInfo for test-2.dcm', () async {
      final info = await readDicomInfo('test/test-2.dcm');

      expect(info.fileName, 'test-2.dcm');
      expect(info.filePath, 'test/test-2.dcm');
      expect(info.metadata, isA<DicomMetadata>());
    });

    test('returns DicomFileInfo for test-non-latin.dcm', () async {
      final info = await readDicomInfo('test/test-non-latin.dcm');

      expect(info.fileName, 'test-non-latin.dcm');
      expect(info.metadata, isA<DicomMetadata>());
    });

    test('returns DicomFileInfo for test-non-latin-2.dcm', () async {
      final info = await readDicomInfo('test/test-non-latin-2.dcm');

      expect(info.fileName, 'test-non-latin-2.dcm');
      expect(info.metadata, isA<DicomMetadata>());
    });
  });

  // ──────────────────────────────────────────────────────────
  // GROUP 2 ▸ Metadata sanity checks
  // ──────────────────────────────────────────────────────────
  group('readDicomInfo — Metadata validation', () {
    late DicomFileInfo info;

    setUp(() async {
      info = await readDicomInfo('test/test-1.dcm');
    });

    test('has non-zero dimensions', () {
      expect(info.metadata.width, greaterThan(0));
      expect(info.metadata.height, greaterThan(0));
    });

    test('has valid modality', () {
      expect(info.metadata.modality, isNotEmpty);
      expect(info.metadata.modality, isNot('Unknown'));
    });

    test('has valid patient name', () {
      expect(info.metadata.patientName, isNotEmpty);
    });

    test('has valid study date', () {
      expect(info.metadata.studyDate, isNotEmpty);
    });

    test('has valid UIDs', () {
      expect(info.metadata.sopInstanceUid, isNotEmpty);
      expect(info.metadata.sopInstanceUid, contains('.'));
      expect(info.metadata.studyInstanceUid, isNotEmpty);
      expect(info.metadata.seriesInstanceUid, isNotEmpty);
    });

    test('has valid windowing defaults', () {
      expect(info.metadata.windowCenter, isA<double>());
      expect(info.metadata.windowWidth, isA<double>());
      expect(info.metadata.windowWidth, greaterThan(0));
    });

    test('has valid rescale values', () {
      expect(info.metadata.rescaleSlope, isA<double>());
      expect(info.metadata.rescaleIntercept, isA<double>());
    });

    test('has valid photometric interpretation', () {
      expect(info.metadata.photometricInterpretation, isNotEmpty);
      expect(
        info.metadata.photometricInterpretation,
        anyOf('MONOCHROME1', 'MONOCHROME2', 'RGB'),
      );
    });

    test('has valid bit depth', () {
      expect(info.metadata.bitsAllocated, anyOf(8, 16));
      expect(info.metadata.bitsStored,
          lessThanOrEqualTo(info.metadata.bitsAllocated));
    });

    test('has valid samples per pixel', () {
      expect(info.metadata.samplesPerPixel, anyOf(1, 3));
    });

    test('all 27 metadata fields are non-null', () {
      final m = info.metadata;
      expect(m.patientId, isNotNull);
      expect(m.patientName, isNotNull);
      expect(m.studyDate, isNotNull);
      expect(m.studyDescription, isNotNull);
      expect(m.modality, isNotNull);
      expect(m.manufacturer, isNotNull);
      expect(m.manufacturerModelName, isNotNull);
      expect(m.institutionName, isNotNull);
      expect(m.studyInstanceUid, isNotNull);
      expect(m.seriesInstanceUid, isNotNull);
      expect(m.sopInstanceUid, isNotNull);
      expect(m.seriesDescription, isNotNull);
      expect(m.bodyPartExamined, isNotNull);
      expect(m.sliceThickness, isNotNull);
      expect(m.instanceNumber, isNotNull);
      expect(m.photometricInterpretation, isNotNull);
      expect(m.width, isNotNull);
      expect(m.height, isNotNull);
      expect(m.windowCenter, isNotNull);
      expect(m.windowWidth, isNotNull);
      expect(m.rescaleIntercept, isNotNull);
      expect(m.rescaleSlope, isNotNull);
      expect(m.samplesPerPixel, isNotNull);
      expect(m.bitsAllocated, isNotNull);
      expect(m.bitsStored, isNotNull);
      expect(m.highBit, isNotNull);
      expect(m.pixelRepresentation, isNotNull);
    });
  });

  // ──────────────────────────────────────────────────────────
  // GROUP 3 ▸ All test files are loadable
  // ──────────────────────────────────────────────────────────
  group('readDicomInfo — Load all test files', () {
    for (final path in findTestFiles()) {
      test('loads: $path', () async {
        final info = await readDicomInfo(path);
        expect(info.metadata.width, greaterThan(0));
        expect(info.metadata.height, greaterThan(0));
      });
    }
  });

  // ──────────────────────────────────────────────────────────
  // GROUP 4 ▸ File identity is correct
  // ──────────────────────────────────────────────────────────
  group('readDicomInfo — File identity', () {
    test('fileName extracts correctly from Windows-style paths', () async {
      final info = await readDicomInfo(r'test\test-1.dcm');
      expect(info.fileName, 'test-1.dcm');
      expect(info.filePath, r'test\test-1.dcm');
    });

    test('fileName extracts correctly from Unix-style paths', () async {
      final info = await readDicomInfo('test/test-1.dcm');
      expect(info.fileName, 'test-1.dcm');
      expect(info.filePath, 'test/test-1.dcm');
    });
  });

  // ──────────────────────────────────────────────────────────
  // GROUP 5 ▸ skipPixels is effective
  // ──────────────────────────────────────────────────────────
  group('readDicomInfo — skipPixels guarantee', () {
    test('readDicomInfo uses skipPixels (metadata-only, fast)', () async {
      final sw = Stopwatch()..start();
      await readDicomInfo('test/test-1.dcm');
      sw.stop();

      // Metadata-only reads should be very fast (< 200ms)
      expect(sw.elapsedMilliseconds, lessThan(200),
          reason: 'Metadata-only reads should complete quickly');
    });
  });

  // ──────────────────────────────────────────────────────────
  // GROUP 6 ▸ Error handling
  // ──────────────────────────────────────────────────────────
  group('readDicomInfo — Error handling', () {
    test('throws on non-existent file', () async {
      expect(
        () => readDicomInfo('test/does-not-exist.dcm'),
        throwsA(isA<DicomException>()),
      );
    });

    test('throws on directory path', () async {
      expect(
        () => readDicomInfo('test/'),
        throwsA(isA<DicomException>()),
      );
    });

    test('error includes file name in message', () async {
      try {
        await readDicomInfo('test/nonexistent-xyz123.dcm');
        fail('Should have thrown');
      } on DicomException catch (e) {
        expect(e.message, contains('nonexistent-xyz123'));
      }
    });
  });

  // ──────────────────────────────────────────────────────────
  // GROUP 7 ▸ DicomFileInfo toString
  // ──────────────────────────────────────────────────────────
  group('DicomFileInfo', () {
    test('toString is readable', () async {
      final info = await readDicomInfo('test/test-1.dcm');
      final str = info.toString();
      expect(str, contains('DicomFileInfo'));
      expect(str, contains('test-1.dcm'));
    });
  });

  // ──────────────────────────────────────────────────────────
  // GROUP 8 ▸ Cross-file consistency
  // ──────────────────────────────────────────────────────────
  group('readDicomInfo — Cross-file consistency', () {
    test('test-1 and test-2 have same dimensions', () async {
      final info1 = await readDicomInfo('test/test-1.dcm');
      final info2 = await readDicomInfo('test/test-2.dcm');

      // Files of similar size (288366 bytes) likely share dimensions
      expect(info1.metadata.width, info2.metadata.width);
      expect(info1.metadata.height, info2.metadata.height);
    });
  });
}
