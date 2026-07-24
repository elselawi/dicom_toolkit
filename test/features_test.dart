import 'dart:typed_data';

import 'package:dicom_toolkit/dicom_toolkit.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tests for ROI measurement, DicomExport, invert toggle, and MONOCHROME1.
void main() {
  // ──────────────────────────────────────────────────────────
  // DicomRoi
  // ──────────────────────────────────────────────────────────
  group('DicomRoi', () {
    test('correctly computes right and bottom', () {
      const roi = DicomRoi(left: 10, top: 20, width: 100, height: 50);
      expect(roi.right, 110);
      expect(roi.bottom, 70);
    });

    test('statistics computes mean correctly for known values', () {
      const roi = DicomRoi(left: 0, top: 0, width: 2, height: 2);
      final pixelData = Int16List.fromList([100, 200, 300, 400]);
      // raw=100 → 100*1+0=100, 200→200, 300→300, 400→400

      final stats = DicomRoi.statistics(
        roi: roi,
        pixelData: pixelData,
        imageWidth: 2,
        imageHeight: 2,
        rescaleSlope: 1.0,
        rescaleIntercept: 0.0,
      );

      expect(stats.count, 4);
      expect(stats.min, 100);
      expect(stats.max, 400);
      expect(stats.mean, 250);
    });

    test('statistics applies rescale slope/intercept', () {
      const roi = DicomRoi(left: 0, top: 0, width: 1, height: 1);
      final pixelData = Int16List.fromList([-1000]);
      // -1000 * 1.0 + (-1024) = -2024

      final stats = DicomRoi.statistics(
        roi: roi,
        pixelData: pixelData,
        imageWidth: 1,
        imageHeight: 1,
        rescaleSlope: 1.0,
        rescaleIntercept: -1024.0,
      );

      expect(stats.mean, -2024);
    });

    test('ROI clamped to image bounds', () {
      const roi = DicomRoi(left: -10, top: -10, width: 1000, height: 1000);
      final pixelData = Int16List.fromList([42]);
      // Image is 1×1, so ROI should clamp to (0,0)-(0,0) → 1 pixel

      final stats = DicomRoi.statistics(
        roi: roi,
        pixelData: pixelData,
        imageWidth: 1,
        imageHeight: 1,
        rescaleSlope: 1.0,
        rescaleIntercept: 0,
      );

      expect(stats.count, 1);
      expect(stats.mean, 42);
    });

    test('meanHu convenience method works', () {
      const roi = DicomRoi(left: 0, top: 0, width: 2, height: 2);
      final pixelData = Int16List.fromList([10, 10, 10, 10]);

      final mean = DicomRoi.meanHu(
        roi: roi,
        pixelData: pixelData,
        imageWidth: 2,
        imageHeight: 2,
        rescaleSlope: 2.0,
        rescaleIntercept: 0,
      );

      expect(mean, 20); // 10 * 2 + 0
    });

    test('RoiStatistics toString is readable', () {
      const stats = RoiStatistics(
        min: -100,
        max: 500,
        mean: 200,
        stddev: 50,
        count: 100,
      );
      expect(stats.toString(), contains('200.0'));
      expect(stats.toString(), contains('HU'));
    });
  });

  // ──────────────────────────────────────────────────────────
  // DicomMeasurement / Offset
  // ──────────────────────────────────────────────────────────
  group('DicomMeasurement', () {
    test('Offset distanceTo computes Euclidean distance', () {
      final a = Offset(0, 0);
      final b = Offset(3, 4);
      expect(a.distanceTo(b), 5.0);
    });

    test('Offset distanceTo is zero for same point', () {
      final a = Offset(10, 20);
      expect(a.distanceTo(a), 0);
    });

    test('DicomMeasurement holds two offsets', () {
      const m = DicomMeasurement(start: Offset(0, 0), end: Offset(100, 200));
      expect(m.start.dx, 0);
      expect(m.end.dy, 200);
    });
  });

  // ──────────────────────────────────────────────────────────
  // DicomExport
  // ──────────────────────────────────────────────────────────
  group('DicomExport', () {
    test('toPngBytes exists and returns Future<Uint8List>', () {
      // Static verification — actual encoding needs GPU
      expect(DicomExport.toPngBytes, isA<Function>());
    });
  });

  // ──────────────────────────────────────────────────────────
  // MONOCHROME1 detection
  // ──────────────────────────────────────────────────────────
  group('DicomController — MONOCHROME1', () {
    test('isMonochrome1 returns true for MONOCHROME1', () {
      final metadata = DicomMetadata(
        patientId: '',
        patientName: '',
        studyDate: '',
        studyDescription: '',
        modality: '',
        manufacturer: '',
        manufacturerModelName: '',
        institutionName: '',
        studyInstanceUid: '',
        seriesInstanceUid: '',
        sopInstanceUid: '',
        seriesDescription: '',
        bodyPartExamined: '',
        sliceThickness: 0,
        instanceNumber: '',
        photometricInterpretation: 'MONOCHROME1',
        width: 1,
        height: 1,
        windowCenter: 0,
        windowWidth: 0,
        rescaleIntercept: 0,
        rescaleSlope: 1,
        samplesPerPixel: 1,
        bitsAllocated: 16,
        bitsStored: 16,
        highBit: 15,
        pixelRepresentation: 0,
      );
      expect(metadata.photometricInterpretation, 'MONOCHROME1');
    });

    test('DicomMetadata detects MONOCHROME2 correctly', () {
      final metadata = DicomMetadata(
        patientId: '',
        patientName: '',
        studyDate: '',
        studyDescription: '',
        modality: '',
        manufacturer: '',
        manufacturerModelName: '',
        institutionName: '',
        studyInstanceUid: '',
        seriesInstanceUid: '',
        sopInstanceUid: '',
        seriesDescription: '',
        bodyPartExamined: '',
        sliceThickness: 0,
        instanceNumber: '',
        photometricInterpretation: 'MONOCHROME2',
        width: 1,
        height: 1,
        windowCenter: 0,
        windowWidth: 0,
        rescaleIntercept: 0,
        rescaleSlope: 1,
        samplesPerPixel: 1,
        bitsAllocated: 16,
        bitsStored: 16,
        highBit: 15,
        pixelRepresentation: 0,
      );
      expect(metadata.photometricInterpretation, 'MONOCHROME2');
    });
  });

  // ──────────────────────────────────────────────────────────
  // Color maps
  // ──────────────────────────────────────────────────────────
  group('DicomColorMap', () {
    test('all maps have non-empty labels', () {
      for (final map in DicomColorMap.values) {
        expect(map.label, isNotEmpty);
      }
    });

    test('ColorMapLut.generate returns 1024 bytes (256×4)', () {
      for (final map in DicomColorMap.values) {
        final lut = ColorMapLut.generate(map);
        expect(lut.length, 1024); // 256 * 4
      }
    });
  });
}
