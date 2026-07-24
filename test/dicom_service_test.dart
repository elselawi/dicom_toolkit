import 'dart:typed_data';

import 'package:dicom_toolkit/dicom_toolkit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockDicomLoader extends Mock implements IDicomLoader {}

void main() {
  late DicomService service;
  late MockDicomLoader mockLoader;

  setUp(() {
    mockLoader = MockDicomLoader();
    service = DicomService(loader: mockLoader);
  });

  group('DicomService', () {
    final testBytes = Uint8List.fromList([1, 2, 3]);
    const testMetadata = DicomMetadata(
      patientId: 'PAT-001',
      patientName: 'John Doe',
      studyDate: '20240115',
      studyDescription: 'Routine Chest',
      modality: 'CT',
      manufacturer: 'SIEMENS',
      manufacturerModelName: 'SOMATOM Force',
      institutionName: 'General Hospital',
      studyInstanceUid: '1.2.840.10008.1.1',
      seriesInstanceUid: '1.2.840.10008.1.1.1',
      sopInstanceUid: '1.2.840.10008.1.1.1.1',
      seriesDescription: 'Axial C+',
      bodyPartExamined: 'CHEST',
      sliceThickness: 1.25,
      instanceNumber: '42',
      width: 512,
      height: 512,
      windowCenter: 40.0,
      windowWidth: 400.0,
      rescaleIntercept: -1024.0,
      rescaleSlope: 1.0,
      photometricInterpretation: 'MONOCHROME2',
      samplesPerPixel: 1,
      bitsAllocated: 16,
      bitsStored: 12,
      highBit: 11,
      pixelRepresentation: 0,
    );

    test('loadFrameFromBytes calls loader with correct parameters', () async {
      final mockResult = DicomFrameResult(
        metadata: testMetadata,
        pixelData: Int16List(0),
      );

      when(() =>
              mockLoader.loadFromBytes(testBytes, config: any(named: 'config')))
          .thenAnswer((final _) async => mockResult);

      final result = await service.loadFrameFromBytes(testBytes);

      expect(result, mockResult);
      verify(() =>
              mockLoader.loadFromBytes(testBytes, config: any(named: 'config')))
          .called(1);
    });

    test('loadFrameFromBytes propagates errors from loader', () async {
      when(() =>
              mockLoader.loadFromBytes(testBytes, config: any(named: 'config')))
          .thenThrow(Exception('Load failed'));

      expect(() => service.loadFrameFromBytes(testBytes), throwsException);
    });
  });
}
