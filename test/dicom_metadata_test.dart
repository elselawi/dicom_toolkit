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
  final String studyDate = '20240101',
  final String seriesDate = 'Unknown',
  final String acquisitionDate = 'Unknown',
  final String contentDate = 'Unknown',
  final String toothInfo = 'Unknown',
}) =>
    generated.DicomMetadata(
      patientId: patientId,
      patientName: patientName,
      studyDate: studyDate,
      seriesDate: seriesDate,
      acquisitionDate: acquisitionDate,
      contentDate: contentDate,
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
      toothInfo: toothInfo,
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
      expect(meta.seriesDate, isNotEmpty);
      expect(meta.acquisitionDate, isNotEmpty);
      expect(meta.contentDate, isNotEmpty);
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
      expect(meta.toothInfo, isNotEmpty);
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

  group('Date fields', () {
    test('studyDate delegates to inner', () {
      final inner = _buildInner(studyDate: '20240315');
      final meta = DicomMetadata(inner: inner);
      expect(meta.studyDate, '20240315');
    });

    test('seriesDate delegates to inner', () {
      final inner = _buildInner(seriesDate: '20240314');
      final meta = DicomMetadata(inner: inner);
      expect(meta.seriesDate, '20240314');
    });

    test('acquisitionDate delegates to inner', () {
      final inner = _buildInner(acquisitionDate: '20240313');
      final meta = DicomMetadata(inner: inner);
      expect(meta.acquisitionDate, '20240313');
    });

    test('contentDate delegates to inner', () {
      final inner = _buildInner(contentDate: '20240312');
      final meta = DicomMetadata(inner: inner);
      expect(meta.contentDate, '20240312');
    });

    test('all date getters default to "Unknown"', () {
      final inner = _buildInner(
        studyDate: 'Unknown',
        seriesDate: 'Unknown',
        acquisitionDate: 'Unknown',
        contentDate: 'Unknown',
      );
      final meta = DicomMetadata(inner: inner);
      expect(meta.studyDate, 'Unknown');
      expect(meta.seriesDate, 'Unknown');
      expect(meta.acquisitionDate, 'Unknown');
      expect(meta.contentDate, 'Unknown');
    });
  });

  group('bestDate', () {
    test('returns studyDate when it is the only valid date', () {
      final inner = _buildInner(studyDate: '20240115');
      final meta = DicomMetadata(inner: inner);
      expect(meta.bestDate, DateTime.utc(2024, 1, 15));
    });

    test('returns the most recent valid date among all four', () {
      final inner = _buildInner(
        studyDate: '20240110',
        seriesDate: '20240112',
        acquisitionDate: '20240111',
        contentDate: '20240109',
      );
      final meta = DicomMetadata(inner: inner);
      expect(meta.bestDate, DateTime.utc(2024, 1, 12));
    });

    test('ignores "Unknown" values', () {
      final inner = _buildInner(
        studyDate: 'Unknown',
        seriesDate: 'Unknown',
        acquisitionDate: '20240201',
        contentDate: 'Unknown',
      );
      final meta = DicomMetadata(inner: inner);
      expect(meta.bestDate, DateTime.utc(2024, 2, 1));
    });

    test('returns null when all dates are "Unknown"', () {
      final inner = _buildInner(
        studyDate: 'Unknown',
        seriesDate: 'Unknown',
        acquisitionDate: 'Unknown',
        contentDate: 'Unknown',
      );
      final meta = DicomMetadata(inner: inner);
      expect(meta.bestDate, isNull);
    });

    test('returns null when all dates are empty', () {
      final inner = _buildInner(
        studyDate: '',
        seriesDate: '',
        acquisitionDate: '',
        contentDate: '',
      );
      final meta = DicomMetadata(inner: inner);
      expect(meta.bestDate, isNull);
    });

    test('excludes future dates', () {
      final futureYear = (DateTime.now().year + 10).toString();
      final inner = _buildInner(
        studyDate: '20240101',
        seriesDate: '${futureYear}0101',
        acquisitionDate: 'Unknown',
        contentDate: 'Unknown',
      );
      final meta = DicomMetadata(inner: inner);
      expect(meta.bestDate, DateTime.utc(2024, 1, 1));
    });

    test('returns null when all dates are in the future', () {
      final futureYear = (DateTime.now().year + 5).toString();
      final inner = _buildInner(
        studyDate: '${futureYear}0101',
        seriesDate: '${futureYear}0201',
        acquisitionDate: '${futureYear}0301',
        contentDate: '${futureYear}0401',
      );
      final meta = DicomMetadata(inner: inner);
      expect(meta.bestDate, isNull);
    });

    test('handles DICOM date range (takes start date)', () {
      final inner = _buildInner(
        studyDate: '20240101-20240105',
        seriesDate: 'Unknown',
        acquisitionDate: 'Unknown',
        contentDate: 'Unknown',
      );
      final meta = DicomMetadata(inner: inner);
      expect(meta.bestDate, DateTime.utc(2024, 1, 1));
    });

    test('handles DICOM date range across months', () {
      final inner = _buildInner(
        studyDate: '20240328-20240402',
        seriesDate: 'Unknown',
        acquisitionDate: 'Unknown',
        contentDate: 'Unknown',
      );
      final meta = DicomMetadata(inner: inner);
      expect(meta.bestDate, DateTime.utc(2024, 3, 28));
    });

    test('ignores malformed date strings', () {
      final inner = _buildInner(
        studyDate: 'not-a-date',
        seriesDate: '2024',
        acquisitionDate: '202401',
        contentDate: '2024011',
      );
      final meta = DicomMetadata(inner: inner);
      expect(meta.bestDate, isNull);
    });

    test('ignores mixed valid and malformed dates', () {
      final inner = _buildInner(
        studyDate: 'bad-date',
        seriesDate: 'Unknown',
        acquisitionDate: '20240615',
        contentDate: 'also-bad',
      );
      final meta = DicomMetadata(inner: inner);
      expect(meta.bestDate, DateTime.utc(2024, 6, 15));
    });

    test('rejects impossible month/day', () {
      final inner = _buildInner(
        studyDate: '20241301', // month 13
        seriesDate: '20240132', // day 32
        acquisitionDate: '20240230', // Feb 30
        contentDate: '20240001', // month 0
      );
      final meta = DicomMetadata(inner: inner);
      expect(meta.bestDate, isNull);
    });

    test('contentDate wins when it is most recent', () {
      final inner = _buildInner(
        studyDate: '20240101',
        seriesDate: '20240102',
        acquisitionDate: '20240103',
        contentDate: '20240104',
      );
      final meta = DicomMetadata(inner: inner);
      expect(meta.bestDate, DateTime.utc(2024, 1, 4));
    });

    test('mixed unknowns and valid dates picks most recent', () {
      final inner = _buildInner(
        studyDate: 'Unknown',
        seriesDate: '20240301',
        acquisitionDate: '',
        contentDate: '20240315',
      );
      final meta = DicomMetadata(inner: inner);
      expect(meta.bestDate, DateTime.utc(2024, 3, 15));
    });

    test('accepts Feb 29 on leap year', () {
      // 2024 is a leap year
      final inner = _buildInner(
        studyDate: '20240229',
        seriesDate: 'Unknown',
        acquisitionDate: 'Unknown',
        contentDate: 'Unknown',
      );
      final meta = DicomMetadata(inner: inner);
      expect(meta.bestDate, DateTime.utc(2024, 2, 29));
    });

    test('rejects Feb 29 on non-leap year', () {
      // 2023 is not a leap year
      final inner = _buildInner(
        studyDate: '20230229',
        seriesDate: 'Unknown',
        acquisitionDate: 'Unknown',
        contentDate: 'Unknown',
      );
      final meta = DicomMetadata(inner: inner);
      expect(meta.bestDate, isNull);
    });
  });

  group('Tooth info', () {
    test('toothInfo delegates to inner', () {
      final inner = _buildInner(toothInfo: '36');
      final meta = DicomMetadata(inner: inner);
      expect(meta.toothInfo, '36');
    });

    test('toothInfo defaults to "Unknown"', () {
      final inner = _buildInner();
      final meta = DicomMetadata(inner: inner);
      expect(meta.toothInfo, 'Unknown');
    });

    test('toothInfo with FDI notation', () {
      final inner = _buildInner(toothInfo: '11');
      final meta = DicomMetadata(inner: inner);
      expect(meta.toothInfo, '11');
    });

    test('toothInfo with region string', () {
      final inner = _buildInner(toothInfo: 'Maxillary Right');
      final meta = DicomMetadata(inner: inner);
      expect(meta.toothInfo, 'Maxillary Right');
    });

    test('toothInfo empty string still present', () {
      final inner = _buildInner(toothInfo: '');
      final meta = DicomMetadata(inner: inner);
      expect(meta.toothInfo, '');
    });
  });
}
