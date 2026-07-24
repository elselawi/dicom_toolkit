import 'package:dicom_toolkit/dicom_toolkit.dart';
import 'package:dicom_toolkit/src/rust/api/core/models/dicom_metadata.dart'
    as generated;
import 'package:flutter_test/flutter_test.dart';

/// Builds a generated [generated.DicomMetadata] with test-friendly defaults.
generated.DicomMetadata _buildInner({
  final String patientName = 'Test Patient',
  final String patientId = 'TEST-001',
  final String modality = 'CT',
  final int width = 512,
  final int height = 512,
  final double windowCenter = 40.0,
  final double windowWidth = 400.0,
  final double rescaleIntercept = -1024.0,
  final double rescaleSlope = 1.0,
  final int pixelRepresentation = 0,
  final int samplesPerPixel = 1,
  final String photometricInterpretation = 'MONOCHROME2',
  final int bitsAllocated = 16,
  final int bitsStored = 12,
}) =>
    generated.DicomMetadata(
      patientId: patientId,
      patientName: patientName,
      studyDate: '20240101',
      studyDescription: 'Test Study',
      modality: modality,
      manufacturer: 'TestCo',
      manufacturerModelName: 'TestModel',
      institutionName: 'Test Hospital',
      studyInstanceUid: '1.2.3.4.5',
      seriesInstanceUid: '1.2.3.4.5.1',
      sopInstanceUid: '1.2.3.4.5.1.1',
      seriesDescription: 'Test Series',
      bodyPartExamined: 'CHEST',
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
    );

void main() {
  group('DicomMetadata wrapper', () {
    test('delegates typed getters to inner', () {
      final inner = _buildInner(patientName: 'Jane Doe');
      final meta = DicomMetadata(inner: inner);

      expect(meta.patientName, 'Jane Doe');
      expect(meta.patientId, 'TEST-001');
      expect(meta.modality, 'CT');
      expect(meta.width, 512);
      expect(meta.height, 512);
      expect(meta.windowCenter, 40.0);
      expect(meta.windowWidth, 400.0);
      expect(meta.rescaleIntercept, -1024.0);
      expect(meta.rescaleSlope, 1.0);
      expect(meta.samplesPerPixel, 1);
      expect(meta.bitsAllocated, 16);
      expect(meta.bitsStored, 12);
      expect(meta.pixelRepresentation, 0);
      expect(meta.photometricInterpretation, 'MONOCHROME2');
    });

    test('all typed getters return non-null values', () {
      final inner = _buildInner();
      final meta = DicomMetadata(inner: inner);

      // String getters
      expect(meta.patientName, isNotEmpty);
      expect(meta.patientId, isNotEmpty);
      expect(meta.studyDate, isNotEmpty);
      expect(meta.studyDescription, isNotEmpty);
      expect(meta.modality, isNotEmpty);
      expect(meta.manufacturer, isNotEmpty);
      expect(meta.manufacturerModelName, isNotEmpty);
      expect(meta.institutionName, isNotEmpty);
      expect(meta.studyInstanceUid, isNotEmpty);
      expect(meta.seriesInstanceUid, isNotEmpty);
      expect(meta.sopInstanceUid, isNotEmpty);
      expect(meta.seriesDescription, isNotEmpty);
      expect(meta.bodyPartExamined, isNotEmpty);
      expect(meta.instanceNumber, isNotEmpty);
      expect(meta.photometricInterpretation, isNotEmpty);

      // Numeric getters
      expect(meta.sliceThickness, isA<double>());
      expect(meta.width, isA<int>());
      expect(meta.height, isA<int>());
      expect(meta.windowCenter, isA<double>());
      expect(meta.windowWidth, isA<double>());
      expect(meta.rescaleIntercept, isA<double>());
      expect(meta.rescaleSlope, isA<double>());
      expect(meta.samplesPerPixel, isA<int>());
      expect(meta.bitsAllocated, isA<int>());
      expect(meta.bitsStored, isA<int>());
      expect(meta.highBit, isA<int>());
      expect(meta.pixelRepresentation, isA<int>());
    });

    test('tag lookup returns null for missing tag', () {
      final inner = _buildInner();
      final meta = DicomMetadata(inner: inner);

      expect(meta.tag(DicomTagId.pixelSpacing), isNull);
    });

    test('tag lookup returns value when present', () {
      final inner = _buildInner();
      final tags = {DicomTagId.pixelSpacing: '0.5\\0.5'};
      final meta = DicomMetadata(inner: inner, tags: tags);

      expect(meta.tag(DicomTagId.pixelSpacing), '0.5\\0.5');
    });

    test('allTags returns unmodifiable map', () {
      final tags = {DicomTagId.pixelSpacing: '0.5\\0.5'};
      final meta = DicomMetadata(inner: _buildInner(), tags: tags);

      final all = meta.allTags;
      expect(all.length, 1);
      expect(all[DicomTagId.pixelSpacing], '0.5\\0.5');
      expect(() => all[DicomTagId.pixelSpacing] = 'bad', throwsA(anything));
    });

    test('pixelSpacing getter reads from tags', () {
      final tags = {DicomTagId.pixelSpacing: '0.3\\0.3'};
      final meta = DicomMetadata(inner: _buildInner(), tags: tags);

      expect(meta.pixelSpacing, '0.3\\0.3');
    });

    test('pixelSpacing returns null when tag missing', () {
      final meta = DicomMetadata(inner: _buildInner());

      expect(meta.pixelSpacing, isNull);
    });

    test('allTags is empty when no tags provided', () {
      final meta = DicomMetadata(inner: _buildInner());
      expect(meta.allTags, isEmpty);
    });

    test('MONOCHROME1 is preserved', () {
      final inner = _buildInner(
        photometricInterpretation: 'MONOCHROME1',
      );
      final meta = DicomMetadata(inner: inner);
      expect(meta.photometricInterpretation, 'MONOCHROME1');
    });

    test('signed pixels (pixelRepresentation=1)', () {
      final inner = _buildInner(pixelRepresentation: 1);
      final meta = DicomMetadata(inner: inner);
      expect(meta.pixelRepresentation, 1);
    });
  });
}
