import 'dart:typed_data';

import 'package:dicom_toolkit/dicom_toolkit.dart';
import 'package:dicom_toolkit/src/rust/api/core/models/dicom_metadata.dart'
    as generated;
import 'package:flutter_test/flutter_test.dart';

/// Builds a [DicomInt16PixelData] result with the given [pixels].
DicomParseResult _buildResult(
  final Int16List pixels, {
  final int width = 4,
  final int height = 2,
  final double windowCenter = 32768.0,
  final double windowWidth = 65536.0,
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
    imageOrientationPatient: '',
    numberOfFrames: 1,
  );
  final frame = DicomFrameResult(metadata: inner, pixelData: pixels);
  return DicomParseResult.fromFrame(frame: frame);
}

void main() {
  group('DicomWindowPreset.forImage edge cases', () {
    test('returns default presets (all) when pixel data is empty', () {
      final result = _buildResult(Int16List(0));
      final presets = DicomWindowPreset.forImage(result);
      expect(presets, DicomWindowPreset.all);
      expect(presets.length, 7);
    });

    test('returns default presets (all) for a single constant value', () {
      final result = _buildResult(Int16List.fromList([42, 42, 42, 42, 42]));
      final presets = DicomWindowPreset.forImage(result);
      // maxVal == minVal → returns all (no meaningful Full Range)
      expect(presets, DicomWindowPreset.all);
      expect(presets.length, 7);
    });

    test('Full Range covers min..max with midpoint center', () {
      // Pixel range -1000..2000 → mid = 500, range = 3000.
      final result = _buildResult(
        Int16List.fromList([-1000, 0, 500, 1000, 2000]),
      );
      final presets = DicomWindowPreset.forImage(result);
      final full = presets.firstWhere((final p) => p.label == 'Full Range');
      expect(full.center, closeTo(500.0, 0.001));
      expect(full.width, closeTo(3000.0, 0.001));
    });

    test('Mid 50% keeps center, quarter width', () {
      final result = _buildResult(
        Int16List.fromList([-1000, 0, 500, 1000, 2000]),
      );
      final presets = DicomWindowPreset.forImage(result);
      final mid = presets.firstWhere((final p) => p.label == 'Mid 50%');
      expect(mid.center, closeTo(500.0, 0.001));
      expect(mid.width, closeTo(1500.0, 0.001)); // 3000 * 0.5
    });

    test('Narrow 25% keeps center, quarter width', () {
      final result = _buildResult(
        Int16List.fromList([-1000, 0, 500, 1000, 2000]),
      );
      final presets = DicomWindowPreset.forImage(result);
      final narrow = presets.firstWhere((final p) => p.label == 'Narrow 25%');
      expect(narrow.center, closeTo(500.0, 0.001));
      expect(narrow.width, closeTo(750.0, 0.001)); // 3000 * 0.25
    });

    test('High preset is centered above the midpoint', () {
      final result = _buildResult(
        Int16List.fromList([-1000, 0, 500, 1000, 2000]),
      );
      final presets = DicomWindowPreset.forImage(result);
      final high = presets.firstWhere((final p) => p.label == 'High');
      // mid + range*0.25 = 500 + 750 = 1250
      expect(high.center, closeTo(1250.0, 0.001));
      expect(high.width, closeTo(1500.0, 0.001)); // range * 0.5
    });

    test('Low preset is centered below the midpoint', () {
      final result = _buildResult(
        Int16List.fromList([-1000, 0, 500, 1000, 2000]),
      );
      final presets = DicomWindowPreset.forImage(result);
      final low = presets.firstWhere((final p) => p.label == 'Low');
      // mid - range*0.25 = 500 - 750 = -250
      expect(low.center, closeTo(-250.0, 0.001));
      expect(low.width, closeTo(1500.0, 0.001)); // range * 0.5
    });

    test('DICOM Default reports header values alongside data-driven presets',
        () {
      final result = _buildResult(
        Int16List.fromList([-1000, 0, 500, 1000, 2000]),
      );
      final presets = DicomWindowPreset.forImage(result);
      final dicomDefault =
          presets.firstWhere((final p) => p.label == 'DICOM Default');
      expect(dicomDefault.center, 32768.0);
      expect(dicomDefault.width, 65536.0);
    });
  });
}
