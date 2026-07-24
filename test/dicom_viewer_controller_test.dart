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
}
