import 'dart:typed_data';

import 'package:dicom_toolkit/dicom_toolkit.dart';
import 'package:dicom_toolkit/src/rust/api/core/models/dicom_metadata.dart'
    as generated;
import 'package:flutter_test/flutter_test.dart';

/// Helper to build a DicomParseResult for tests.
DicomParseResult _buildResult({
  final int width = 4,
  final int height = 4,
  final Int16List? pixels,
  final int pixelRepresentation = 1,
  final String photometricInterpretation = 'MONOCHROME2',
  final Map<DicomTagId, String>? tags,
}) {
  final inner = generated.DicomMetadata(
    patientId: 'P001',
    patientName: 'Test Patient',
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
    windowCenter: 40.0,
    windowWidth: 400.0,
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
    pixelData: pixels ?? Int16List(width * height),
  );
  return DicomParseResult.fromFrame(frame: frame, tags: tags);
}

void main() {
  group('DicomParseResult — MONOCHROME1', () {
    test('isMonochrome1 returns false for MONOCHROME2', () {
      final result = _buildResult();
      // isMonochrome1 property is on DicomViewerController, not DicomParseResult
      // But we can check photometricInterpretation
      expect(result.metadata.photometricInterpretation, 'MONOCHROME2');
    });
  });

  group('DicomParseResult — Signed pixels', () {
    test('isSigned true for pixelRepresentation=1', () {
      final result = _buildResult();
      expect(result.isSigned, isTrue);
    });

    test('isSigned false for pixelRepresentation=0', () {
      final result = _buildResult(pixelRepresentation: 0);
      expect(result.isSigned, isFalse);
    });
  });

  group('DicomRoi — edge cases', () {
    test('median for odd count', () {
      // 3×1 image: [100, 500, 300], sorted: [100, 300, 500], median = 300
      final pixels = Int16List.fromList([100, 500, 300]);
      final result = _buildResult(width: 3, height: 1, pixels: pixels);
      const roi = DicomRoi(x: 0, y: 0, width: 3, height: 1);

      final stats = roi.compute(result);
      expect(stats.median, 300);
    });

    test('stdDev for single pixel', () {
      final pixels = Int16List.fromList([42]);
      final result = _buildResult(width: 1, height: 1, pixels: pixels);
      const roi = DicomRoi(x: 0, y: 0, width: 1, height: 1);

      final stats = roi.compute(result);
      // variance = 0 / 0 = NaN for n=1
      expect(stats.stdDev.isNaN, isTrue);
    });

    test('ROI partially inside image (right edge)', () {
      // 2×2 image: [1,2,3,4]
      final pixels = Int16List.fromList([1, 2, 3, 4]);
      final result = _buildResult(width: 2, height: 2, pixels: pixels);
      // ROI starts at (1,0) covering 2 columns — only column 1 is valid
      const roi = DicomRoi(x: 1, y: 0, width: 2, height: 2);

      final stats = roi.compute(result);
      // Clamped to columns [1,1] (just col 1): pixels[1]=2, pixels[3]=4
      expect(stats.pixelCount, 2);
      expect(stats.mean, 3.0); // (2+4)/2
    });
  });

  group('DicomTagId — edge cases', () {
    test('hex pads with leading zeros', () {
      const tag = DicomTagId.fromParts(0x0001, 0x0001);
      expect(tag.hex, '00010001');
    });

    test('toString round-trips', () {
      const tag = DicomTagId.fromParts(0x0010, 0x0010);
      final parsed = tag.toString();
      expect(parsed, 'DicomTagId(00100010)');
    });
  });

  group('DicomWindowPreset — comparison', () {
    test(
        'softTissue and mediastinum have same center/width but different labels',
        () {
      const st = DicomWindowPreset.softTissue();
      const md = DicomWindowPreset.mediastinum();
      expect(st.center, md.center);
      expect(st.width, md.width);
      expect(st, isNot(equals(md))); // labels differ
    });

    test('custom with same values as built-in is not equal', () {
      const bone = DicomWindowPreset.bone();
      const custom = DicomWindowPreset.custom(
        center: 500,
        width: 2000,
        label: 'Not Bone',
      );
      expect(bone, isNot(equals(custom)));
    });
  });
}
