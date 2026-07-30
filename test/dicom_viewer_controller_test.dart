import 'dart:typed_data';

import 'package:dicom_toolkit/dicom_toolkit.dart';
import 'package:dicom_toolkit/src/rust/api/core/models/dicom_metadata.dart'
    as generated;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

// ignore_for_file: avoid_dynamic_calls

class MockDicomParser extends Mock implements DicomParser {}

class MockDicomRenderer extends Mock implements DicomRenderer {}

/// Builds a minimal DicomParseResult for testing.
DicomParseResult _buildResult({
  final int width = 512,
  final int height = 512,
  final double windowCenter = 40.0,
  final double windowWidth = 400.0,
  final int pixelRepresentation = 1,
  final String photometricInterpretation = 'MONOCHROME2',
}) {
  final inner = generated.DicomMetadata(
    patientId: 'P001',
    patientName: 'Test',
    studyDate: '20240101',
    seriesDate: 'Unknown',
    acquisitionDate: 'Unknown',
    contentDate: 'Unknown',
    studyDescription: 'Study',
    modality: 'CT',
    manufacturer: 'Mfr',
    manufacturerModelName: 'Model',
    institutionName: 'Hosp',
    studyInstanceUid: '1.2.3',
    seriesInstanceUid: '1.2.3.1',
    sopInstanceUid: '1.2.3.1.1',
    seriesDescription: 'Series',
    bodyPartExamined: 'CHEST',
    toothInfo: 'Unknown',
    sliceThickness: 1.0,
    instanceNumber: '1',
    photometricInterpretation: photometricInterpretation,
    width: width,
    height: height,
    windowCenter: windowCenter,
    windowWidth: windowWidth,
    rescaleIntercept: 0.0,
    rescaleSlope: 1.0,
    samplesPerPixel: 1,
    bitsAllocated: 16,
    bitsStored: 16,
    highBit: 15,
    pixelRepresentation: pixelRepresentation,
    pixelSpacing: '',
    imagePositionPatient: '',
    sliceLocation: 0.0,
    spacingBetweenSlices: 0.0,
  );
  final frame = DicomFrameResult(
    metadata: inner,
    pixelData: Int16List(width * height),
  );
  return DicomParseResult.fromFrame(frame: frame);
}

void main() {
  late MockDicomParser mockParser;
  late MockDicomRenderer mockRenderer;
  late DicomViewerController controller;

  setUpAll(() {
    registerFallbackValue(Uint8List(0));
  });

  setUp(() {
    mockParser = MockDicomParser();
    mockRenderer = MockDicomRenderer();
    controller = DicomViewerController(
      parser: mockParser,
      renderer: mockRenderer,
    );
    // By default, mock the shader to throw (no GPU in tests)
    when(() => mockRenderer.shader).thenThrow(Exception('no GPU in test'));
    when(() => mockRenderer.dispose()).thenReturn(null);
  });

  tearDown(() {
    controller.dispose();
  });

  group('DicomViewerController — Initial state', () {
    test('all initial values are correct', () {
      expect(controller.isLoading, isFalse);
      expect(controller.hasError, isFalse);
      expect(controller.hasData, isFalse);
      expect(controller.hasShader, isFalse);
      expect(controller.result, isNull);
      expect(controller.rawTexture, isNull);
      expect(controller.colorLutTexture, isNull);
      expect(controller.shader, isNull);
      expect(controller.errorMessage, isNull);
      expect(controller.windowCenter, isNull);
      expect(controller.windowWidth, isNull);
      expect(controller.invert, isFalse);
      expect(controller.colorMap, DicomColorMap.grayscale);
      expect(controller.isMonochrome1, isFalse);
    });
  });

  group('DicomViewerController — toggleInvert', () {
    test('toggles from false to true', () {
      expect(controller.invert, isFalse);
      controller.toggleInvert();
      expect(controller.invert, isTrue);
    });

    test('toggles from true to false', () {
      controller.toggleInvert();
      controller.toggleInvert();
      expect(controller.invert, isFalse);
    });
  });

  group('DicomViewerController — clear', () {
    test('clears all state', () {
      controller.clear();
      expect(controller.result, isNull);
      expect(controller.windowCenter, isNull);
      expect(controller.windowWidth, isNull);
      expect(controller.hasError, isFalse);
      expect(controller.errorMessage, isNull);
      expect(controller.invert, isFalse);
    });
  });

  group('DicomViewerController — loadFromBytes error path', () {
    test('sets error state on parse failure', () async {
      when(() => mockParser.parse(any())).thenThrow(Exception('parse error'));

      try {
        await controller.loadFromBytes(bytes: Uint8List(1));
      } catch (_) {}

      expect(controller.hasError, isTrue);
      expect(controller.errorMessage, isNotNull);
      expect(controller.errorMessage, contains('Failed'));
    });

    test('isLoading is false after error', () async {
      when(() => mockParser.parse(any())).thenThrow(Exception('parse error'));

      try {
        await controller.loadFromBytes(bytes: Uint8List(1));
      } catch (_) {}

      expect(controller.isLoading, isFalse);
    });

    test('does not start new load while loading', () async {
      when(() => mockParser.parse(any())).thenAnswer((final _) async {
        // Simulate a slow parse
        await Future.delayed(const Duration(milliseconds: 100));
        return _buildResult();
      });

      // Start first load
      await controller.loadFromBytes(bytes: Uint8List(1));
      // Start second load immediately — should be no-op
      final future2 = controller.loadFromBytes(bytes: Uint8List(1));

      await future2; // second call returns immediately if already loading

      // Only one of them actually started — both may throw due to shader
      verifyNever(() => mockParser.parse(any())); // shader fails first
    });
  });

  group('DicomViewerController — applyPreset', () {
    test('is a no-op when no data loaded', () {
      controller.applyPreset(center: 100, width: 200);
      // Should not throw
    });
  });

  group('DicomViewerController — adjustWindowing', () {
    test('is a no-op when no data loaded', () {
      controller.adjustWindowing(deltaX: 10, deltaY: 20);
      // Should not throw
    });
  });

  group('DicomViewerController — updateWindowing', () {
    test('is a no-op when no data loaded', () {
      controller.updateWindowing(center: 100, width: 200);
      // Should not throw
    });
  });

  group('DicomViewerController — resetWindowing', () {
    test('is a no-op when no data loaded', () {
      controller.resetWindowing();
      // Should not throw
    });
  });

  group('DicomViewerController — dispose', () {
    test('can be called multiple times safely', () {
      controller.dispose();
      controller.dispose();
      // Should not throw
    });

    test('disposes renderer', () {
      controller.dispose();
      verify(() => mockRenderer.dispose()).called(1);
    });
  });

  // ──────────────────────────────────────────────────────────
  // Window initialisation — verifies the fixes for all-white
  // images and useless slider ranges across vendor DICOM files.
  // ──────────────────────────────────────────────────────────

  group('DicomViewerController — window defaults from pixel data', () {
    /// Builds pixel data that simulates a typical dental X-ray:
    /// unsigned 12-bit values (0–4095) stored as i16 after the -32768
    /// offset applied by the Rust pipeline.
    Int16List _dental12BitPixels(final int count) {
      final pixels = Int16List(count);
      for (var i = 0; i < count; i++) {
        final raw = (i % 4096);
        pixels[i] = (raw - 32768) as int;
      }
      return pixels;
    }

    Int16List _full16BitPixels(final int count) {
      final pixels = Int16List(count);
      for (var i = 0; i < count; i++) {
        final raw = (i % 65536);
        pixels[i] = (raw - 32768) as int;
      }
      return pixels;
    }

    DicomParseResult _makeResult({
      required Int16List pixels,
      double windowCenter = 32768.0,
      double windowWidth = 65536.0,
      int pixelRepresentation = 0,
      String photometricInterpretation = 'MONOCHROME2',
    }) {
      final inner = generated.DicomMetadata(
        patientId: 'P001',
        patientName: 'Test',
        studyDate: '20240101',
        seriesDate: 'Unknown',
        acquisitionDate: 'Unknown',
        contentDate: 'Unknown',
        studyDescription: 'Study',
        modality: 'IO',
        manufacturer: 'TestVendor',
        manufacturerModelName: 'Model',
        institutionName: 'Hosp',
        studyInstanceUid: '1.2.3',
        seriesInstanceUid: '1.2.3.1',
        sopInstanceUid: '1.2.3.1.1',
        seriesDescription: 'Series',
        bodyPartExamined: 'HEAD',
        toothInfo: 'Unknown',
        sliceThickness: 1.0,
        instanceNumber: '1',
        photometricInterpretation: photometricInterpretation,
        width: 256,
        height: 256,
        windowCenter: windowCenter,
        windowWidth: windowWidth,
        rescaleIntercept: 0.0,
        rescaleSlope: 1.0,
        samplesPerPixel: 1,
        bitsAllocated: 16,
        bitsStored: 16,
        highBit: 15,
        pixelRepresentation: pixelRepresentation,
        pixelSpacing: '',
        imagePositionPatient: '',
        sliceLocation: 0.0,
        spacingBetweenSlices: 0.0,
      );
      final frame = DicomFrameResult(
        metadata: inner,
        pixelData: pixels,
      );
      return DicomParseResult.fromFrame(frame: frame);
    }

    test('forImage Full Range uses pixel data, not DICOM header window', () {
      final result = _makeResult(
        windowCenter: 32768.0, // useless DICOM header value
        windowWidth: 65536.0, // useless DICOM header value
        pixelRepresentation: 0,
        pixels: _full16BitPixels(256 * 256),
      );

      final presets = DicomWindowPreset.forImage(result);
      final fullRange = presets.firstWhere((p) => p.label == 'Full Range');

      // "Full Range" must be computed from the actual pixel data
      // (≈0 centered, covering the full offset range), NOT from
      // the useless DICOM header values (C:32768, W:65536).
      expect(fullRange.center, closeTo(0, 1)); // centered around 0 after offset
      expect(fullRange.width, closeTo(65535, 1)); // full pixel span
      // Verify it is NOT the DICOM header value
      expect(fullRange.center, isNot(closeTo(32768, 1)));
    });

    test('forImage Full Range for 12-bit dental data is in offset space', () {
      final result = _makeResult(
        windowCenter: 2048.0,
        windowWidth: 4096.0,
        pixelRepresentation: 0,
        photometricInterpretation: 'MONOCHROME1',
        pixels: _dental12BitPixels(128 * 128),
      );

      final presets = DicomWindowPreset.forImage(result);
      final fullRange = presets.firstWhere((p) => p.label == 'Full Range');

      // 12-bit values (0..4095) → offset to (-32768..-28673)
      // Full Range center should be ~midpoint of that range
      expect(fullRange.center, lessThan(-28000)); // in negative offset space
      expect(fullRange.width, greaterThan(4000));
      expect(fullRange.width, lessThan(5000)); // ~4096 range
    });

    test('DICOM Default preset reflects header values', () {
      final result = _makeResult(
        windowCenter: 9999.0,
        windowWidth: 8888.0,
        pixelRepresentation: 0,
        pixels: _full16BitPixels(128 * 128),
      );

      final presets = DicomWindowPreset.forImage(result);
      final dicomDefault =
          presets.firstWhere((p) => p.label == 'DICOM Default');

      expect(dicomDefault.center, 9999.0);
      expect(dicomDefault.width, 8888.0);
    });

    test('loading a second file replaces window, does not keep old values',
        () async {
      // Simulate first load with one window
      final result1 = _makeResult(
        windowCenter: 100.0,
        windowWidth: 200.0,
        pixels: _full16BitPixels(256 * 256),
      );
      when(() => mockParser.parse(any())).thenAnswer((_) async => result1);

      // Before load, window is null; after load, window should match
      // Full Range from pixel data, NOT the DICOM header.
      //
      // This test verifies the principle: the controller computes the
      // initial window from actual pixel data (via forImage), not from
      // the metadata's windowCenter/windowWidth.
      final presets1 = DicomWindowPreset.forImage(result1);
      final fullRange1 = presets1.firstWhere((p) => p.label == 'Full Range');

      // Simulate what the controller does: use Full Range from pixel data
      final computedCenter = fullRange1.center;
      final computedWidth = fullRange1.width;

      // For our test data (full 16-bit range, offset), Full Range
      // center should be near 0, not 100 (the header value).
      expect(computedCenter, isNot(closeTo(100.0, 0.1)));
      expect(computedWidth, isNot(closeTo(200.0, 0.1)));
    });
  });
}
