// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:typed_data';

import 'package:dicom_toolkit/dicom_toolkit.dart';
import 'package:dicom_toolkit/src/rust/frb_generated.dart';
import 'package:flutter_test/flutter_test.dart';

/// Integration tests for DicomController using real DICOM files.
///
/// Requires valid DICOM files in the `test/` directory. Since loading is
/// bytes-only, files are read from disk here to simulate what a real file
/// picker would hand to [DicomController.loadFromBytes].
Uint8List _bytesOf(final String path) => File(path).readAsBytesSync();

/// Deliberately invalid DICOM data, used to exercise the error-handling paths.
final _corruptBytes = Uint8List.fromList(List.filled(16, 0));

void main() {
  // ─── Setup ────────────────────────────────────────────────

  setUpAll(() async {
    await RustLib.init();
  });

  // ──────────────────────────────────────────────────────────
  // GROUP 1 ▸ Load pipeline (metadata — works without GPU)
  // ──────────────────────────────────────────────────────────
  group('DicomController — Load pipeline (metadata)', () {
    late DicomController controller;

    setUp(() {
      controller = DicomController();
    });

    tearDown(() {
      controller.dispose();
    });

    test('loadFromBytes populates metadata with real DICOM data', () async {
      await controller.loadFromBytes(bytes: _bytesOf('test/test-1.dcm'));

      expect(controller.metadata, isNotNull);
      expect(controller.metadata!.width, greaterThan(0));
      expect(controller.metadata!.height, greaterThan(0));
      expect(controller.currentFrame, isNotNull);
      expect(controller.metadata!.patientName, isNotEmpty);
      expect(controller.metadata!.modality, isNotEmpty);
    });

    test('loadFromBytes stores windowing defaults from DICOM headers',
        () async {
      await controller.loadFromBytes(bytes: _bytesOf('test/test-1.dcm'));

      // Even without GPU, _currentWindowCenter/Width are set from metadata
      expect(controller.windowCenter, isNotNull);
      expect(controller.windowWidth, isNotNull);
      expect(controller.windowCenter, controller.metadata!.windowCenter);
      expect(controller.windowWidth, controller.metadata!.windowWidth);
    });

    test('loadFromBytes sets isLoading=false after completion', () async {
      expect(controller.isLoading, isFalse);

      await controller.loadFromBytes(bytes: _bytesOf('test/test-1.dcm'));

      expect(controller.isLoading, isFalse);
    });

    test('loadFromBytes clears previous error on success', () async {
      // Trigger an error first
      try {
        await controller.loadFromBytes(bytes: _corruptBytes);
      } catch (_) {}

      expect(controller.hasError, isTrue);

      // Now load a valid file — error should be cleared
      await controller.loadFromBytes(bytes: _bytesOf('test/test-1.dcm'));

      expect(controller.hasError, isFalse);
      expect(controller.errorMessage, isNull);
      expect(controller.metadata, isNotNull);
    });
  });

  // ──────────────────────────────────────────────────────────
  // GROUP 2 ▸ State lifecycle
  // ──────────────────────────────────────────────────────────
  group('DicomController — State lifecycle', () {
    late DicomController controller;

    setUp(() {
      controller = DicomController();
    });

    tearDown(() {
      controller.dispose();
    });

    test('initial state is correct', () {
      expect(controller.isLoading, isFalse);
      expect(controller.hasError, isFalse);
      expect(controller.hasData, isFalse);
      expect(controller.metadata, isNull);
      expect(controller.currentFrame, isNull);
      expect(controller.rawTexture, isNull);
      expect(controller.shader, isNull);
      expect(controller.windowCenter, isNull);
      expect(controller.windowWidth, isNull);
      expect(controller.errorMessage, isNull);
    });

    test('clear resets metadata and frame state after load', () async {
      await controller.loadFromBytes(bytes: _bytesOf('test/test-1.dcm'));
      expect(controller.metadata, isNotNull);
      expect(controller.currentFrame, isNotNull);

      controller.clear();

      expect(controller.metadata, isNull);
      expect(controller.currentFrame, isNull);
      expect(controller.hasError, isFalse);
      expect(controller.windowCenter, isNull);
      expect(controller.windowWidth, isNull);
    });

    test('reloading after clear works for metadata', () async {
      await controller.loadFromBytes(bytes: _bytesOf('test/test-1.dcm'));
      controller.clear();

      await controller.loadFromBytes(bytes: _bytesOf('test/test-2.dcm'));

      expect(controller.metadata, isNotNull);
      expect(controller.metadata!.width, greaterThan(0));
    });
  });

  // ──────────────────────────────────────────────────────────
  // GROUP 3 ▸ Multi-file sequential loading
  // ──────────────────────────────────────────────────────────
  group('DicomController — Multi-file loading', () {
    late DicomController controller;

    setUp(() {
      controller = DicomController();
    });

    tearDown(() {
      controller.dispose();
    });

    final testFiles = [
      'test/test-1.dcm',
      'test/test-2.dcm',
      'test/test-non-latin.dcm',
      'test/test-non-latin-2.dcm',
    ];

    test('loads all 4 test files sequentially without errors', () async {
      for (final path in testFiles) {
        await controller.loadFromBytes(bytes: _bytesOf(path));
        expect(controller.hasError, isFalse, reason: 'Failed on $path');
        expect(controller.metadata, isNotNull, reason: 'No metadata for $path');
        expect(controller.metadata!.width, greaterThan(0),
            reason: 'Zero width for $path');
      }
    });

    test('validates metadata fields across all 4 files', () async {
      for (final path in testFiles) {
        await controller.loadFromBytes(bytes: _bytesOf(path));

        final meta = controller.metadata!;
        expect(meta.width, greaterThan(0));
        expect(meta.height, greaterThan(0));
        expect(meta.patientName, isNotEmpty);
        expect(meta.sopInstanceUid, isNotEmpty);
        expect(meta.modality, isNotEmpty);
      }
    });

    test('all 4 files have distinct SOP Instance UIDs', () async {
      final uids = <String>{};
      for (final path in testFiles) {
        await controller.loadFromBytes(bytes: _bytesOf(path));
        uids.add(controller.metadata!.sopInstanceUid);
      }
      // All 4 should be unique
      expect(uids.length, 4);
    });
  });

  // ──────────────────────────────────────────────────────────
  // GROUP 4 ▸ Error handling
  // ──────────────────────────────────────────────────────────
  group('DicomController — Error handling', () {
    late DicomController controller;

    setUp(() {
      controller = DicomController();
    });

    tearDown(() {
      controller.dispose();
    });

    test('throws DicomProcessingException on invalid DICOM bytes', () async {
      expect(
        () => controller.loadFromBytes(bytes: _corruptBytes),
        throwsA(isA<DicomProcessingException>()),
      );
    });

    test('sets hasError=true and errorMessage after failed load', () async {
      try {
        await controller.loadFromBytes(bytes: _corruptBytes);
      } catch (_) {}

      expect(controller.hasError, isTrue);
      expect(controller.errorMessage, isNotNull);
      expect(controller.errorMessage, contains('Failed'));
    });

    test('isLoading is false after a failed load', () async {
      try {
        await controller.loadFromBytes(bytes: _corruptBytes);
      } catch (_) {}

      expect(controller.isLoading, isFalse);
    });
  });

  // ──────────────────────────────────────────────────────────
  // GROUP 5 ▸ DicomConfig options
  // ──────────────────────────────────────────────────────────
  group('DicomController — DicomConfig', () {
    late DicomController controller;

    setUp(() {
      controller = DicomController();
    });

    tearDown(() {
      controller.dispose();
    });

    test('skipPixels: true loads metadata without pixel data', () async {
      final config = DicomConfig(autoNormalize: false, skipPixels: true);
      await controller.loadFromBytes(
          bytes: _bytesOf('test/test-1.dcm'), config: config);

      expect(controller.metadata, isNotNull);
      expect(controller.metadata!.width, greaterThan(0));
      // With skipPixels, the frame still has metadata but pixelData is empty
      expect(controller.currentFrame!.pixelData, isEmpty);
    });

    test('skipPixels: false includes pixel data', () async {
      final config = DicomConfig(autoNormalize: false, skipPixels: false);
      await controller.loadFromBytes(
          bytes: _bytesOf('test/test-1.dcm'), config: config);

      expect(controller.currentFrame!.pixelData, isNotEmpty);
    });

    test('autoNormalize option does not cause errors', () async {
      final config = DicomConfig(autoNormalize: true, skipPixels: false);
      await controller.loadFromBytes(
          bytes: _bytesOf('test/test-1.dcm'), config: config);

      expect(controller.hasError, isFalse);
      expect(controller.metadata, isNotNull);
    });
  });

  // ──────────────────────────────────────────────────────────
  // GROUP 6 ▸ Non-Latin patient names
  // ──────────────────────────────────────────────────────────
  group('DicomController — Non-Latin support', () {
    late DicomController controller;

    setUp(() {
      controller = DicomController();
    });

    tearDown(() {
      controller.dispose();
    });

    test('loads test-non-latin.dcm successfully', () async {
      await controller.loadFromBytes(
          bytes: _bytesOf('test/test-non-latin.dcm'));

      expect(controller.hasError, isFalse);
      expect(controller.metadata, isNotNull);
      expect(controller.metadata!.patientName, isNotEmpty);
    });

    test('loads test-non-latin-2.dcm successfully', () async {
      await controller.loadFromBytes(
          bytes: _bytesOf('test/test-non-latin-2.dcm'));

      expect(controller.hasError, isFalse);
      expect(controller.metadata, isNotNull);
      expect(controller.metadata!.patientName, isNotEmpty);
    });
  });

  // ──────────────────────────────────────────────────────────
  // GROUP 7 ▸ ChangeNotifier behavior
  // ──────────────────────────────────────────────────────────
  group('DicomController — ChangeNotifier', () {
    test('notifies listeners during loadFromBytes', () async {
      final controller = DicomController();
      addTearDown(() => controller.dispose());

      var notifyCount = 0;
      controller.addListener(() => notifyCount++);

      await controller.loadFromBytes(bytes: _bytesOf('test/test-1.dcm'));

      // Loading sets isLoading=true then false, plus final data — at least 2 notifications
      expect(notifyCount, greaterThanOrEqualTo(2),
          reason: 'Controller should notify at least twice during load');
    });

    test('notifies listeners on clear', () async {
      final controller = DicomController();
      addTearDown(() => controller.dispose());

      await controller.loadFromBytes(bytes: _bytesOf('test/test-1.dcm'));

      var notifyCount = 0;
      controller.addListener(() => notifyCount++);

      controller.clear();

      expect(notifyCount, greaterThan(0));
    });
  });
}
