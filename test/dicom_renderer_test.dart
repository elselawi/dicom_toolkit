import 'dart:typed_data';

import 'package:dicom_toolkit/dicom_toolkit.dart';
import 'package:dicom_toolkit/src/rust/api/core/models/dicom_metadata.dart'
    as generated;
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('pack16Bit', () {
    test('offsets signed value by +32768 and splits high/low bytes', () {
      // 0 → +32768 → R=0x80 G=0x00
      final out = pack16Bit([0], 1);
      expect(out[0], 0x80);
      expect(out[1], 0x00);
      expect(out[2], 0); // B unused
      expect(out[3], 255); // A opaque
    });

    test('negative value encodes correctly', () {
      // -32768 → +0 → R=0x00 G=0x00
      final out = pack16Bit([-32768], 1);
      expect(out[0], 0x00);
      expect(out[1], 0x00);
      expect(out[3], 255);
    });

    test('max signed value encodes high byte last', () {
      // 32767 → +32768 = 65535 → R=0xFF G=0xFF
      final out = pack16Bit([32767], 1);
      expect(out[0], 0xFF);
      expect(out[1], 0xFF);
    });

    test('multiple pixels produce 4 bytes each', () {
      final out = pack16Bit([0, 1, 2], 3);
      expect(out.length, 12);
      // Value 1 → 32769 → R=0x80 G=0x01
      expect(out[4], 0x80);
      expect(out[5], 0x01);
    });

    test('does not over-read a shorter buffer (pixelCount cap)', () {
      // Only 2 pixels in buffer but pixelCount says 4.
      final out = pack16Bit([0, 1], 4);
      expect(out.length, 16);
      // All pixels are zero-initialized (padding beyond buffer stays 0).
      expect(out[8], 0);
      expect(out[9], 0);
      expect(out[10], 0);
      // Only the alpha channel of written pixels is 255.
      expect(out[3], 255);
      // Unwritten pixel alpha is not forced — stays 0.
      expect(out[11], 0);
    });
  });

  group('applyWindowingRgba', () {
    test('maps value at window center to 128 (mid-gray)', () {
      // wc=100, ww=100, slope=1, intercept=0 → low=50.
      // value 100 → (100-50)/100 = 0.5 → 127.5 → round 128.
      final out = applyWindowingRgba(
        [100],
        1,
        windowCenter: 100,
        windowWidth: 100,
        slope: 1,
        intercept: 0,
      );
      expect(out[0], 128);
      expect(out[1], 128);
      expect(out[2], 128);
      expect(out[3], 255);
    });

    test('clamps values below window low to black (0)', () {
      // low = 50, value 0 → below → 0.
      final out = applyWindowingRgba(
        [0],
        1,
        windowCenter: 100,
        windowWidth: 100,
        slope: 1,
        intercept: 0,
      );
      expect(out[0], 0);
      expect(out[3], 255);
    });

    test('clamps values above window high to white (255)', () {
      // high = 150, value 200 → above → 255.
      final out = applyWindowingRgba(
        [200],
        1,
        windowCenter: 100,
        windowWidth: 100,
        slope: 1,
        intercept: 0,
      );
      expect(out[0], 255);
    });

    test('applies Hounsfield slope + intercept transform', () {
      // pixel 100, slope 2, intercept -50 → hu = 200 - 50 = 150.
      // wc=100 ww=100 low=50 → (150-50)/100 = 1.0 → 255.
      final out = applyWindowingRgba(
        [100],
        1,
        windowCenter: 100,
        windowWidth: 100,
        slope: 2,
        intercept: -50,
      );
      expect(out[0], 255);
    });

    test('produces grayscale (r == g == b) output', () {
      final out = applyWindowingRgba(
        [150, 120, 90],
        3,
        windowCenter: 100,
        windowWidth: 200,
        slope: 1,
        intercept: 0,
      );
      for (var i = 0; i < 3; i++) {
        expect(out[i * 4 + 0], out[i * 4 + 1]);
        expect(out[i * 4 + 1], out[i * 4 + 2]);
        expect(out[i * 4 + 3], 255);
      }
    });

    test('clamps windowWidth to minimum of 1', () {
      // ww clamped to 1.0; low = 100 - 0.5 = 99.5.
      // value 100 → (100-99.5)/1 = 0.5 → 128.
      final out = applyWindowingRgba(
        [100],
        1,
        windowCenter: 100,
        windowWidth: 0, // would cause division-by-zero if not clamped
        slope: 1,
        intercept: 0,
      );
      expect(out[0], 128);
      expect(out[3], 255);
    });

    test('handles constant-value buffer (min == max) without NaN', () {
      final out = applyWindowingRgba(
        [42, 42, 42],
        3,
        windowCenter: 42,
        windowWidth: 100,
        slope: 1,
        intercept: 0,
      );
      expect(out[0], 128);
      expect(out[4], 128);
      expect(out[8], 128);
    });
  });

  group('packRgb', () {
    test('packs RGB triplets into RGBA bytes with opaque alpha', () {
      // 2 RGB pixels: (255, 0, 128), (10, 20, 30)
      final out = packRgb([255, 0, 128, 10, 20, 30], 2);
      expect(out.length, 8);
      expect(out[0], 255); // R0
      expect(out[1], 0);   // G0
      expect(out[2], 128); // B0
      expect(out[3], 255); // A0
      expect(out[4], 10);  // R1
      expect(out[5], 20);  // G1
      expect(out[6], 30);  // B1
      expect(out[7], 255); // A1
    });

    test('supports invert option', () {
      final out = packRgb([255, 0, 100], 1, invert: true);
      expect(out[0], 0);   // 255 - 255
      expect(out[1], 255); // 255 - 0
      expect(out[2], 155); // 255 - 100
      expect(out[3], 255); // Alpha stays 255
    });

    test('supports 16-bit to 8-bit downscaling', () {
      final out = packRgb([65535, 32768, 0], 1, bitsStored: 16);
      expect(out[0], 255); // 65535 >> 8
      expect(out[1], 128); // 32768 >> 8
      expect(out[2], 0);
      expect(out[3], 255);
    });

    test('does not over-read shorter pixel buffer', () {
      final out = packRgb([255, 128, 0], 4);
      expect(out.length, 16);
      expect(out[0], 255);
      expect(out[1], 128);
      expect(out[2], 0);
      expect(out[3], 255);
      // Unwritten pixels stay 0
      expect(out[4], 0);
      expect(out[7], 0);
    });
  });

  group('DicomRenderer.createTexture with RGB data', () {
    test('creates texture from RGB pixel data', () async {
      const inner = generated.DicomMetadata(
        patientId: 'P001',
        patientName: 'Test',
        studyDate: '20240101',
        seriesDate: 'Unknown',
        acquisitionDate: 'Unknown',
        contentDate: 'Unknown',
        studyDescription: 'Study',
        modality: 'OPT',
        manufacturer: 'Mfr',
        manufacturerModelName: 'Model',
        institutionName: 'Hosp',
        studyInstanceUid: '1.2.3',
        seriesInstanceUid: '1.2.3.1',
        sopInstanceUid: '1.2.3.1.1',
        seriesDescription: 'Series',
        bodyPartExamined: 'EYE',
        toothInfo: 'Unknown',
        sliceThickness: 1.0,
        instanceNumber: '1',
        photometricInterpretation: 'RGB',
        width: 2,
        height: 2,
        windowCenter: 127.5,
        windowWidth: 255.0,
        rescaleIntercept: 0.0,
        rescaleSlope: 1.0,
        samplesPerPixel: 3,
        bitsAllocated: 8,
        bitsStored: 8,
        highBit: 7,
        pixelRepresentation: 0,
        pixelSpacing: '',
        imagePositionPatient: '',
        sliceLocation: 0.0,
        spacingBetweenSlices: 0.0,
        imageOrientationPatient: '',
        numberOfFrames: 1,
      );
      final pixels = Int16List.fromList([
        255, 0, 0,    // (0,0) Red
        0, 255, 0,    // (1,0) Green
        0, 0, 255,    // (0,1) Blue
        255, 255, 255 // (1,1) White
      ]);
      final frame = DicomFrameResult(metadata: inner, pixelData: pixels);
      final result = DicomParseResult.fromFrame(frame: frame);

      final renderer = DicomRenderer();
      final texture = await renderer.createTexture(result);

      expect(texture.width, 2);
      expect(texture.height, 2);
    });
  });
}
