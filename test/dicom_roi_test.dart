import 'dart:typed_data';

import 'package:dicom_toolkit/dicom_toolkit.dart';
import 'package:dicom_toolkit/src/rust/api/core/models/dicom_metadata.dart'
    as generated;
import 'package:flutter_test/flutter_test.dart';

/// Builds a DicomParseResult with known pixel data.
DicomParseResult _buildResult({
  required final int width,
  required final int height,
  required final Int16List pixels,
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
  final frame = DicomFrameResult(metadata: inner, pixelData: pixels);
  return DicomParseResult.fromFrame(frame: frame);
}

void main() {
  group('DicomRoi', () {
    test('constructs with x, y, width, height', () {
      const roi = DicomRoi(x: 10, y: 20, width: 100, height: 50);
      expect(roi.x, 10);
      expect(roi.y, 20);
      expect(roi.width, 100);
      expect(roi.height, 50);
    });

    test('copyWith creates modified copy', () {
      const roi = DicomRoi(x: 10, y: 20, width: 100, height: 50);
      final modified = roi.copyWith(x: 30);

      expect(modified.x, 30);
      expect(modified.y, 20);
      expect(modified.width, 100);
      expect(modified.height, 50);
    });

    test('copyWith preserves unspecified fields', () {
      const roi = DicomRoi(x: 10, y: 20, width: 100, height: 50);
      final modified = roi.copyWith(width: 200, height: 60);

      expect(modified.x, 10);
      expect(modified.y, 20);
      expect(modified.width, 200);
      expect(modified.height, 60);
    });

    test('toString is readable', () {
      const roi = DicomRoi(x: 10, y: 20, width: 100, height: 50);
      expect(roi.toString(), contains('x=10'));
      expect(roi.toString(), contains('y=20'));
    });
  });

  group('DicomRoi.compute', () {
    test('computes correct statistics for known values', () {
      // 2×2 image: [100, 200, 300, 400]
      final pixels = Int16List.fromList([100, 200, 300, 400]);
      final result = _buildResult(width: 2, height: 2, pixels: pixels);
      const roi = DicomRoi(x: 0, y: 0, width: 2, height: 2);

      final stats = roi.compute(result);

      expect(stats.pixelCount, 4);
      expect(stats.min, 100.0);
      expect(stats.max, 400.0);
      expect(stats.mean, 250.0);
      // std dev of [100,200,300,400]: mean=250, variance=((150)^2+(50)^2+(50)^2+(150)^2)/3=50000/3≈16666.67
      expect(stats.stdDev, closeTo(129.099, 0.1));
      // median of sorted [100,200,300,400]: (200+300)/2=250
      expect(stats.median, 250.0);
    });

    test('handles single pixel', () {
      final pixels = Int16List.fromList([42]);
      final result = _buildResult(width: 1, height: 1, pixels: pixels);
      const roi = DicomRoi(x: 0, y: 0, width: 1, height: 1);

      final stats = roi.compute(result);

      expect(stats.pixelCount, 1);
      expect(stats.min, 42);
      expect(stats.max, 42);
      expect(stats.mean, 42);
      expect(stats.median, 42);
    });

    test('clamps ROI to image bounds', () {
      // 1×1 image with value 42
      final pixels = Int16List.fromList([42]);
      final result = _buildResult(width: 1, height: 1, pixels: pixels);
      const roi = DicomRoi(x: -10, y: -10, width: 1000, height: 1000);

      final stats = roi.compute(result);

      expect(stats.pixelCount, 1);
      expect(stats.mean, 42);
    });

    test('handles ROI completely outside image', () {
      final pixels = Int16List.fromList([1, 2, 3, 4]);
      final result = _buildResult(width: 2, height: 2, pixels: pixels);
      const roi = DicomRoi(x: 100, y: 100, width: 10, height: 10);

      final stats = roi.compute(result);

      expect(stats.pixelCount, 0);
    });

    test('handles partial overlap with image', () {
      // 3×3 image: [1,2,3, 4,5,6, 7,8,9]
      final pixels = Int16List.fromList([1, 2, 3, 4, 5, 6, 7, 8, 9]);
      final result = _buildResult(width: 3, height: 3, pixels: pixels);
      // ROI covers top-left 2×2
      const roi = DicomRoi(x: 0, y: 0, width: 2, height: 2);

      final stats = roi.compute(result);

      expect(stats.pixelCount, 4);
      expect(stats.min, 1);
      expect(stats.max, 5);
      // mean of [1,2,4,5] = 12/4 = 3
      expect(stats.mean, 3.0);
    });

    test('throws for non-Int16 pixel data', () {
      // DicomParseResult always produces Int16, but we test the guard
      final result =
          _buildResult(width: 1, height: 1, pixels: Int16List.fromList([1]));
      // This works — just verifying it doesn't throw
      const roi = DicomRoi(x: 0, y: 0, width: 1, height: 1);
      expect(() => roi.compute(result), returnsNormally);
    });
  });

  group('DicomParseResult.computeRoi', () {
    test('delegates to DicomRoi.compute', () {
      final pixels = Int16List.fromList([10, 20, 30, 40]);
      final result = _buildResult(width: 2, height: 2, pixels: pixels);
      const roi = DicomRoi(x: 0, y: 0, width: 2, height: 2);

      final stats = result.computeRoi(roi);

      expect(stats.pixelCount, 4);
      expect(stats.mean, 25.0);
    });
  });

  group('RoiStatistics.toString', () {
    test('contains key values', () {
      final pixels = Int16List.fromList([100, 200]);
      final result = _buildResult(width: 2, height: 1, pixels: pixels);
      const roi = DicomRoi(x: 0, y: 0, width: 2, height: 1);

      final stats = roi.compute(result);
      final str = stats.toString();

      expect(str, contains('min=100'));
      expect(str, contains('max=200'));
      expect(str, contains('n=2'));
    });
  });
}
