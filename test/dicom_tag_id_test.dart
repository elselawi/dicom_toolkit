import 'package:dicom_toolkit/dicom_toolkit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DicomTagId.fromParts', () {
    test('creates tag from group and element', () {
      const tag = DicomTagId.fromParts(0x0010, 0x0010);
      expect(tag.group, 0x0010);
      expect(tag.element, 0x0010);
    });

    test('handles zero values', () {
      const tag = DicomTagId.fromParts(0, 0);
      expect(tag.group, 0);
      expect(tag.element, 0);
      expect(tag.hex, '00000000');
    });

    test('handles max values', () {
      const tag = DicomTagId.fromParts(0xFFFF, 0xFFFF);
      expect(tag.group, 0xFFFF);
      expect(tag.element, 0xFFFF);
      expect(tag.hex, 'ffffffff');
    });

    test('is const-constructible', () {
      const tag = DicomTagId.fromParts(1, 2);
      expect(tag, isA<DicomTagId>());
    });
  });

  group('DicomTagId.fromHex', () {
    test('parses 8-char hex string', () {
      final tag = DicomTagId.fromHex('00100010');
      expect(tag.group, 0x0010);
      expect(tag.element, 0x0010);
    });

    test('parses uppercase hex', () {
      final tag = DicomTagId.fromHex('ABCDEF01');
      expect(tag.group, 0xABCD);
      expect(tag.element, 0xEF01);
    });

    test('parses lowercase hex', () {
      final tag = DicomTagId.fromHex('abcdef01');
      expect(tag.group, 0xABCD);
      expect(tag.element, 0xEF01);
    });

    test('throws on invalid hex', () {
      expect(() => DicomTagId.fromHex('GHIJKLMN'), throwsFormatException);
    });
  });

  group('DicomTagId.hex', () {
    test('pads to 8 characters', () {
      const tag = DicomTagId.fromParts(0x0001, 0x0002);
      expect(tag.hex, '00010002');
    });

    test('uses lowercase hex', () {
      const tag = DicomTagId.fromParts(0xABCD, 0xEF01);
      expect(tag.hex, 'abcdef01');
    });
  });

  group('DicomTagId equality', () {
    test('equal tags compare equal', () {
      const a = DicomTagId.fromParts(0x0010, 0x0010);
      const b = DicomTagId.fromParts(0x0010, 0x0010);
      expect(a, equals(b));
    });

    test('different groups are not equal', () {
      const a = DicomTagId.fromParts(0x0010, 0x0010);
      const b = DicomTagId.fromParts(0x0020, 0x0010);
      expect(a, isNot(equals(b)));
    });

    test('different elements are not equal', () {
      const a = DicomTagId.fromParts(0x0010, 0x0010);
      const b = DicomTagId.fromParts(0x0010, 0x0020);
      expect(a, isNot(equals(b)));
    });

    test('same values from different constructors are equal', () {
      const a = DicomTagId.fromParts(0x0010, 0x0010);
      final b = DicomTagId.fromHex('00100010');
      expect(a, equals(b));
    });

    test('hashCode is consistent with equality', () {
      const a = DicomTagId.fromParts(0x0010, 0x0010);
      const b = DicomTagId.fromParts(0x0010, 0x0010);
      expect(a.hashCode, equals(b.hashCode));
    });

    test('hashCode differs for different tags', () {
      const a = DicomTagId.fromParts(0x0010, 0x0010);
      const b = DicomTagId.fromParts(0x0010, 0x0020);
      expect(a.hashCode, isNot(equals(b.hashCode)));
    });
  });

  group('DicomTagId.toString', () {
    test('includes hex representation', () {
      const tag = DicomTagId.fromParts(0x0010, 0x0010);
      expect(tag.toString(), contains('00100010'));
    });
  });

  group('DicomTagId predefined constants', () {
    test('28 constants exist and have correct groups', () {
      expect(DicomTagId.patientName.group, 0x0010);
      expect(DicomTagId.patientId.group, 0x0010);
      expect(DicomTagId.studyDate.group, 0x0008);
      expect(DicomTagId.studyDescription.group, 0x0008);
      expect(DicomTagId.modality.group, 0x0008);
      expect(DicomTagId.manufacturer.group, 0x0008);
      expect(DicomTagId.manufacturerModelName.group, 0x0008);
      expect(DicomTagId.institutionName.group, 0x0008);
      expect(DicomTagId.studyInstanceUid.group, 0x0020);
      expect(DicomTagId.seriesInstanceUid.group, 0x0020);
      expect(DicomTagId.sopInstanceUid.group, 0x0008);
      expect(DicomTagId.seriesDescription.group, 0x0008);
      expect(DicomTagId.bodyPartExamined.group, 0x0018);
      expect(DicomTagId.sliceThickness.group, 0x0018);
      expect(DicomTagId.instanceNumber.group, 0x0020);
      expect(DicomTagId.width.group, 0x0028);
      expect(DicomTagId.height.group, 0x0028);
      expect(DicomTagId.samplesPerPixel.group, 0x0028);
      expect(DicomTagId.bitsAllocated.group, 0x0028);
      expect(DicomTagId.bitsStored.group, 0x0028);
      expect(DicomTagId.highBit.group, 0x0028);
      expect(DicomTagId.pixelRepresentation.group, 0x0028);
      expect(DicomTagId.photometricInterpretation.group, 0x0028);
      expect(DicomTagId.pixelSpacing.group, 0x0028);
      expect(DicomTagId.windowCenter.group, 0x0028);
      expect(DicomTagId.windowWidth.group, 0x0028);
      expect(DicomTagId.rescaleIntercept.group, 0x0028);
      expect(DicomTagId.rescaleSlope.group, 0x0028);
    });

    test('all 28 constants are distinct', () {
      const all = <DicomTagId>[
        DicomTagId.patientName,
        DicomTagId.patientId,
        DicomTagId.studyDate,
        DicomTagId.studyDescription,
        DicomTagId.modality,
        DicomTagId.manufacturer,
        DicomTagId.manufacturerModelName,
        DicomTagId.institutionName,
        DicomTagId.studyInstanceUid,
        DicomTagId.seriesInstanceUid,
        DicomTagId.sopInstanceUid,
        DicomTagId.seriesDescription,
        DicomTagId.bodyPartExamined,
        DicomTagId.sliceThickness,
        DicomTagId.instanceNumber,
        DicomTagId.width,
        DicomTagId.height,
        DicomTagId.samplesPerPixel,
        DicomTagId.bitsAllocated,
        DicomTagId.bitsStored,
        DicomTagId.highBit,
        DicomTagId.pixelRepresentation,
        DicomTagId.photometricInterpretation,
        DicomTagId.pixelSpacing,
        DicomTagId.windowCenter,
        DicomTagId.windowWidth,
        DicomTagId.rescaleIntercept,
        DicomTagId.rescaleSlope,
      ];
      final set = all.toSet();
      expect(set.length, 28);
    });
  });
}
