import 'package:dicom_toolkit/dicom_toolkit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ColorMapLut.generate', () {
    test('produces 256 entries × 4 bytes (RGBA) for every map', () {
      for (final map in DicomColorMap.values) {
        final lut = ColorMapLut.generate(map);
        expect(lut.length, 256 * 4,
            reason: '${map.label} LUT must be exactly 256×4 bytes');
      }
    });

    test('all LUT alpha channels are opaque (255)', () {
      for (final map in DicomColorMap.values) {
        final lut = ColorMapLut.generate(map);
        for (var i = 0; i < 256; i++) {
          expect(lut[i * 4 + 3], 255,
              reason: '${map.label} entry $i alpha must be 255');
        }
      }
    });

    test('grayscale LUT is exactly [i, i, i, 255]', () {
      final lut = ColorMapLut.generate(DicomColorMap.grayscale);
      for (var i = 0; i < 256; i++) {
        expect(lut[i * 4 + 0], i);
        expect(lut[i * 4 + 1], i);
        expect(lut[i * 4 + 2], i);
        expect(lut[i * 4 + 3], 255);
      }
    });

    test('grayscale starts black and ends white', () {
      final lut = ColorMapLut.generate(DicomColorMap.grayscale);
      expect(lut[0], 0); // R of entry 0
      expect(lut[255 * 4], 255); // R of entry 255
    });

    test('adjacent gradient samples never jump by more than a small delta', () {
      // Interpolation should produce smooth transitions — no single-step
      // cliff beyond a few intensity levels between neighbouring entries.
      for (final map in [
        DicomColorMap.hotIron,
        DicomColorMap.pet,
        DicomColorMap.rainbow,
        DicomColorMap.cool,
        DicomColorMap.bone,
      ]) {
        final lut = ColorMapLut.generate(map);
        for (var channel = 0; channel < 3; channel++) {
          for (var i = 1; i < 256; i++) {
            final delta =
                (lut[i * 4 + channel] - lut[(i - 1) * 4 + channel]).abs();
            expect(delta, lessThanOrEqualTo(8),
                reason: '${map.label} channel $channel high local delta at $i');
          }
        }
      }
    });

    test('color maps are not grayscale (produce chroma)', () {
      for (final map in [
        DicomColorMap.hotIron,
        DicomColorMap.pet,
        DicomColorMap.rainbow,
        DicomColorMap.cool,
        DicomColorMap.bone,
      ]) {
        final lut = ColorMapLut.generate(map);
        var hasChroma = false;
        for (var i = 0; i < 256; i++) {
          final r = lut[i * 4 + 0];
          final g = lut[i * 4 + 1];
          final b = lut[i * 4 + 2];
          if (r != g || g != b) {
            hasChroma = true;
            break;
          }
        }
        expect(hasChroma, isTrue,
            reason: '${map.label} should not be pure grayscale');
      }
    });

    test('hotIron ramp goes red before yellow before white', () {
      final lut = ColorMapLut.generate(DicomColorMap.hotIron);
      // Find first index where red is dominant early on, and verify green
      // increases as t increases (red+green → yellow → white).
      // Entry ~25% should be predominantly red (high R, low G).
      final quarter = lut[64 * 4];
      final quarterG = lut[64 * 4 + 1];
      expect(quarterG, lessThan(quarter),
          reason: 'hot iron early ramp should be red-dominant');
      // Entry ~75% should be yellow-ish (both R and G high).
      final threeQ = lut[192 * 4];
      final threeQG = lut[192 * 4 + 1];
      expect(threeQ, greaterThanOrEqualTo(190));
      expect(threeQG, greaterThanOrEqualTo(190));
      // Yellow (last stop before white) means R and G are both substantial.
      expect(threeQG, greaterThan(quarterG),
          reason: 'green should increase from red ramp to yellow ramp');
    });
  });
}
