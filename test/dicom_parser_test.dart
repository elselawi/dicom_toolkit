import 'dart:typed_data';

import 'package:dicom_toolkit/dicom_toolkit.dart';
import 'package:dicom_toolkit/src/rust/api/core/models/dicom_metadata.dart'
    as generated;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockDecoder extends Mock implements DicomDecoder {}

/// Builds a minimal DicomParseResult.
DicomParseResult _buildResult({
  final int width = 512,
  final int height = 512,
  final double windowCenter = 40.0,
  final double windowWidth = 400.0,
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
    photometricInterpretation: 'MONOCHROME2',
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
    pixelRepresentation: 1,
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
  group('DicomDecoder (abstract)', () {
    test('RustDecoder is const-constructible', () {
      const decoder = RustDecoder();
      expect(decoder, isA<DicomDecoder>());
    });
  });

  group('DicomParser', () {
    late MockDecoder mockDecoder;
    late DicomParser parser;

    setUp(() {
      mockDecoder = MockDecoder();
      parser = DicomParser(decoder: mockDecoder);
    });

    test('is const-constructible with default decoder', () {
      const parser = DicomParser();
      expect(parser, isA<DicomParser>());
    });

    test('parse delegates to decoder.decode', () async {
      final bytes = Uint8List.fromList([1, 2, 3]);
      final expected = _buildResult();
      when(() => mockDecoder.decode(bytes))
          .thenAnswer((final _) async => expected);

      final result = await parser.parse(bytes);

      expect(identical(result, expected), isTrue);
      verify(() => mockDecoder.decode(bytes)).called(1);
    });

    test('parse propagates decoder errors', () async {
      final bytes = Uint8List.fromList([1, 2, 3]);
      when(() => mockDecoder.decode(bytes))
          .thenThrow(Exception('decoder error'));

      expect(() => parser.parse(bytes), throwsA(isA<Exception>()));
    });

    test('parseMetadata returns only metadata', () async {
      final bytes = Uint8List.fromList([1, 2, 3]);
      final result = _buildResult();
      when(() => mockDecoder.decode(bytes, config: any(named: 'config')))
          .thenAnswer((final _) async => result);

      final meta = await parser.parseMetadata(bytes);

      expect(meta.patientName, result.metadata.patientName);
      expect(meta.width, result.metadata.width);
    });

    test('parseMetadata propagates errors', () async {
      final bytes = Uint8List.fromList([1, 2, 3]);
      when(() => mockDecoder.decode(bytes, config: any(named: 'config')))
          .thenThrow(Exception('fail'));

      expect(() => parser.parseMetadata(bytes), throwsA(isA<Exception>()));
    });
  });
}
