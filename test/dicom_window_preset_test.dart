import 'package:dicom_toolkit/dicom_toolkit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DicomWindowPreset constructors', () {
    test('bone preset has correct values', () {
      const preset = DicomWindowPreset.bone();
      expect(preset.center, 500);
      expect(preset.width, 2000);
      expect(preset.label, 'Bone');
    });

    test('lung preset has correct values', () {
      const preset = DicomWindowPreset.lung();
      expect(preset.center, -500);
      expect(preset.width, 1500);
      expect(preset.label, 'Lung');
    });

    test('softTissue preset has correct values', () {
      const preset = DicomWindowPreset.softTissue();
      expect(preset.center, 50);
      expect(preset.width, 400);
      expect(preset.label, 'Soft Tissue');
    });

    test('brain preset has correct values', () {
      const preset = DicomWindowPreset.brain();
      expect(preset.center, 40);
      expect(preset.width, 80);
      expect(preset.label, 'Brain');
    });

    test('liver preset has correct values', () {
      const preset = DicomWindowPreset.liver();
      expect(preset.center, 30);
      expect(preset.width, 150);
      expect(preset.label, 'Liver');
    });

    test('mediastinum preset has correct values', () {
      const preset = DicomWindowPreset.mediastinum();
      expect(preset.center, 50);
      expect(preset.width, 400);
      expect(preset.label, 'Mediastinum');
    });

    test('spine preset has correct values', () {
      const preset = DicomWindowPreset.spine();
      expect(preset.center, 300);
      expect(preset.width, 2000);
      expect(preset.label, 'Spine');
    });

    test('custom preset with label', () {
      const preset = DicomWindowPreset.custom(
        center: 100,
        width: 200,
        label: 'Custom Window',
      );
      expect(preset.center, 100);
      expect(preset.width, 200);
      expect(preset.label, 'Custom Window');
    });

    test('custom preset with default label', () {
      const preset = DicomWindowPreset.custom(center: 100, width: 200);
      expect(preset.label, 'Custom');
    });

    test('unnamed constructor works', () {
      const preset = DicomWindowPreset(
        center: 50,
        width: 400,
        label: 'Test',
      );
      expect(preset.center, 50);
      expect(preset.width, 400);
      expect(preset.label, 'Test');
    });
  });

  group('DicomWindowPreset.all', () {
    test('contains 7 presets', () {
      expect(DicomWindowPreset.all.length, 7);
    });

    test('all preset labels are unique', () {
      final labels = DicomWindowPreset.all.map((final p) => p.label).toSet();
      expect(labels.length, 7);
    });

    test('all presets have positive width', () {
      for (final preset in DicomWindowPreset.all) {
        expect(preset.width, greaterThan(0));
      }
    });

    test('all presets have non-empty label', () {
      for (final preset in DicomWindowPreset.all) {
        expect(preset.label, isNotEmpty);
      }
    });
  });

  group('DicomWindowPreset equality', () {
    test('same values are equal', () {
      const a = DicomWindowPreset.bone();
      const b = DicomWindowPreset.bone();
      expect(a, equals(b));
    });

    test('different center is not equal', () {
      const a = DicomWindowPreset.bone();
      const b = DicomWindowPreset.spine();
      expect(a, isNot(equals(b)));
    });

    test('different label is not equal', () {
      const a = DicomWindowPreset.bone();
      const b =
          DicomWindowPreset.custom(center: 500, width: 2000, label: 'Not Bone');
      expect(a, isNot(equals(b)));
    });

    test('hashCode consistent with equality', () {
      const a = DicomWindowPreset.bone();
      const b = DicomWindowPreset.bone();
      expect(a.hashCode, equals(b.hashCode));
    });

    test('hashCode differs for different presets', () {
      const a = DicomWindowPreset.bone();
      const b = DicomWindowPreset.lung();
      expect(a.hashCode, isNot(equals(b.hashCode)));
    });
  });

  group('DicomWindowPreset.toString', () {
    test('includes label, center, and width', () {
      const preset = DicomWindowPreset.bone();
      final str = preset.toString();
      expect(str, contains('Bone'));
      expect(str, contains('500'));
      expect(str, contains('2000'));
    });
  });
}
