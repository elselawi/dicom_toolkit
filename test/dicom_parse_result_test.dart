import 'dart:typed_data';

import 'package:dicom_toolkit/dicom_toolkit.dart';
import 'package:dicom_toolkit/src/rust/api/core/models/dicom_metadata.dart'
    as generated;
import 'package:flutter_test/flutter_test.dart';

/// Helper to build test metadata.
generated.DicomMetadata _buildInner({
  final int width = 256,
  final int height = 256,
  final int pixelRepresentation = 0,
  final int samplesPerPixel = 1,
  final int bitsAllocated = 16,
  final int bitsStored = 16,
  final double windowCenter = 40.0,
  final double windowWidth = 400.0,
  final double rescaleIntercept = 0.0,
  final double rescaleSlope = 1.0,
  final String photometricInterpretation = 'MONOCHROME2',
}) =>
    generated.DicomMetadata(
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
      rescaleIntercept: rescaleIntercept,
      rescaleSlope: rescaleSlope,
      samplesPerPixel: samplesPerPixel,
      bitsAllocated: bitsAllocated,
      bitsStored: bitsStored,
      highBit: bitsStored - 1,
      pixelRepresentation: pixelRepresentation,
      pixelSpacing: '',
      imagePositionPatient: '',
      sliceLocation: 0.0,
      spacingBetweenSlices: 0.0,
    );

DicomParseResult _buildResult({
  final int width = 256,
  final int height = 256,
  final Int16List? pixels,
  final int pixelRepresentation = 0,
  final int samplesPerPixel = 1,
  final String photometricInterpretation = 'MONOCHROME2',
  final Map<DicomTagId, String>? tags,
}) {
  final inner = _buildInner(
    width: width,
    height: height,
    pixelRepresentation: pixelRepresentation,
    samplesPerPixel: samplesPerPixel,
    photometricInterpretation: photometricInterpretation,
  );
  final frame = DicomFrameResult(
    metadata: inner,
    pixelData: pixels ?? Int16List(width * height),
  );
  return DicomParseResult.fromFrame(frame: frame, tags: tags);
}

void main() {
  group('DicomParseResult.fromFrame', () {
    test('creates result with correct dimensions', () {
      final result = _buildResult(width: 128);

      expect(result.metadata.width, 128);
      expect(result.metadata.height, 256);
    });

    test('packs pixel data correctly', () {
      final pixels = Int16List.fromList([100, 200, 300, 400]);
      final result = _buildResult(width: 2, height: 2, pixels: pixels);

      expect(result.pixelData.length, 4);
      expect(result.pixelData, isA<DicomInt16PixelData>());
      final data = result.pixelData as DicomInt16PixelData;
      expect(data.buffer[0], 100);
      expect(data.buffer[3], 400);
    });

    test('detects signed pixels', () {
      final result = _buildResult(pixelRepresentation: 1);

      expect(result.isSigned, isTrue);
    });

    test('detects unsigned pixels', () {
      final result = _buildResult();

      expect(result.isSigned, isFalse);
    });

    test('detects MONOCHROME2 as monochrome', () {
      final result = _buildResult();

      expect(result.isMonochrome, isTrue);
    });

    test('detects RGB as not monochrome', () {
      final result = _buildResult(
        samplesPerPixel: 3,
        photometricInterpretation: 'RGB',
      );

      expect(result.isMonochrome, isFalse);
    });

    test('passes tags through to metadata', () {
      final tags = {DicomTagId.pixelSpacing: '0.5\\0.5'};
      final result = _buildResult(tags: tags);

      expect(result.metadata.pixelSpacing, '0.5\\0.5');
    });
  });

  group('DicomParseResult properties', () {
    test('frameCount is always 1', () {
      final result = _buildResult();
      expect(result.frameCount, 1);
    });

    test('hasPixels returns true when pixel data present', () {
      final result = _buildResult(
        pixels: Int16List.fromList([1, 2, 3, 4]),
        width: 2,
        height: 2,
      );
      expect(result.hasPixels, isTrue);
    });

    test('hasPixels returns false when pixel data empty', () {
      final result = _buildResult(
        pixels: Int16List(0),
        width: 0,
        height: 0,
      );
      expect(result.hasPixels, isFalse);
    });
  });

  group('DicomParseResult.frame', () {
    test('frame(0) returns self', () async {
      final result = _buildResult();
      final frame0 = await result.frame(0);
      expect(identical(frame0, result), isTrue);
    });

    test('frame(1) throws RangeError', () async {
      final result = _buildResult();
      expect(() => result.frame(1), throwsRangeError);
    });

    test('frame(-1) throws RangeError', () async {
      final result = _buildResult();
      expect(() => result.frame(-1), throwsRangeError);
    });
  });
}
