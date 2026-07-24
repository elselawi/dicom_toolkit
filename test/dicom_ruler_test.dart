import 'package:dicom_toolkit/dicom_toolkit.dart';
import 'package:dicom_toolkit/src/rust/api/core/models/dicom_metadata.dart'
    as generated;
import 'package:flutter_test/flutter_test.dart';

/// Builds metadata with pixel spacing tag.
DicomMetadata _buildMeta({final String? pixelSpacing}) {
  const inner = generated.DicomMetadata(
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
    photometricInterpretation: 'MONOCHROME2',
    width: 512,
    height: 512,
    windowCenter: 40.0,
    windowWidth: 400.0,
    rescaleIntercept: 0.0,
    rescaleSlope: 1.0,
    samplesPerPixel: 1,
    bitsAllocated: 16,
    bitsStored: 16,
    highBit: 15,
    pixelRepresentation: 1,
    pixelSpacing: '',
  );
  final tags = pixelSpacing != null
      ? {DicomTagId.pixelSpacing: pixelSpacing}
      : <DicomTagId, String>{};
  return DicomMetadata(inner: inner, tags: tags);
}

void main() {
  group('DicomRuler', () {
    test('is const-constructible', () {
      const ruler = DicomRuler();
      expect(ruler, isA<DicomRuler>());
    });

    test('measures distance in mm with spacing 0.5\\0.5', () {
      const ruler = DicomRuler();
      final meta = _buildMeta(pixelSpacing: '0.5\\0.5');

      // Points 10 pixels apart: sqrt((10*0.5)^2 + (0)^2) = 5.0
      final distance = ruler.measure(
        meta,
        (x: 0, y: 0),
        (x: 10, y: 0),
      );

      expect(distance, closeTo(5.0, 0.01));
    });

    test('measures diagonal distance correctly', () {
      const ruler = DicomRuler();
      final meta = _buildMeta(pixelSpacing: '1.0\\1.0');

      // 3-4-5 triangle: dx=3, dy=4 → 5
      final distance = ruler.measure(
        meta,
        (x: 0, y: 0),
        (x: 3, y: 4),
      );

      expect(distance, closeTo(5.0, 0.01));
    });

    test('handles anisotropic spacing', () {
      const ruler = DicomRuler();
      final meta = _buildMeta(pixelSpacing: '2.0\\0.5');

      // dx=5*2.0=10, dy=4*0.5=2 → sqrt(100+4)=sqrt(104)≈10.198
      final distance = ruler.measure(
        meta,
        (x: 0, y: 0),
        (x: 5, y: 4),
      );

      expect(distance, closeTo(10.198, 0.01));
    });

    test('falls back to pixel distance when no spacing tag', () {
      const ruler = DicomRuler();
      final meta = _buildMeta();

      // dx=3, dy=4 → 5 pixels (spacing defaults to 1,1)
      final distance = ruler.measure(
        meta,
        (x: 0, y: 0),
        (x: 3, y: 4),
      );

      expect(distance, closeTo(5.0, 0.01));
    });

    test('handles malformed spacing string', () {
      const ruler = DicomRuler();
      final meta = _buildMeta(pixelSpacing: 'not-a-number');

      // Falls back to 1,1 spacing
      final distance = ruler.measure(
        meta,
        (x: 0, y: 0),
        (x: 10, y: 0),
      );

      expect(distance, closeTo(10.0, 0.01));
    });

    test('handles zero spacing gracefully', () {
      const ruler = DicomRuler();
      final meta = _buildMeta(pixelSpacing: '0\\0');

      // Falls back to 1,1 spacing
      final distance = ruler.measure(
        meta,
        (x: 0, y: 0),
        (x: 10, y: 0),
      );

      expect(distance, closeTo(10.0, 0.01));
    });

    test('returns zero for same point', () {
      const ruler = DicomRuler();
      final meta = _buildMeta(pixelSpacing: '0.5\\0.5');

      final distance = ruler.measure(
        meta,
        (x: 100, y: 200),
        (x: 100, y: 200),
      );

      expect(distance, closeTo(0.0, 0.001));
    });
  });
}
