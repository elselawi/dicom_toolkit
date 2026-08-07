import 'package:dicom_toolkit/src/tools/dicom_renderer.dart';
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
}
