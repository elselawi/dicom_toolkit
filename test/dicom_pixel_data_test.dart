import 'dart:typed_data';

import 'package:dicom_toolkit/dicom_toolkit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DicomInt16PixelData', () {
    test('constructs with all required fields', () {
      final buffer = Int16List.fromList([100, 200, 300]);
      final pixelData = DicomInt16PixelData(
        buffer: buffer,
        width: 3,
        height: 1,
        bitsAllocated: 16,
        bitsStored: 12,
        isSigned: true,
      );

      expect(pixelData.length, 3);
      expect(pixelData.width, 3);
      expect(pixelData.height, 1);
      expect(pixelData.bitsAllocated, 16);
      expect(pixelData.bitsStored, 12);
      expect(pixelData.isSigned, isTrue);
    });

    test('is a DicomPixelData', () {
      final pixelData = DicomInt16PixelData(
        buffer: Int16List(0),
        width: 0,
        height: 0,
        bitsAllocated: 16,
        bitsStored: 16,
        isSigned: false,
      );

      expect(pixelData, isA<DicomPixelData>());
    });

    test('length matches buffer length', () {
      final buffer = Int16List.fromList([1, 2, 3, 4, 5]);
      final pixelData = DicomInt16PixelData(
        buffer: buffer,
        width: 5,
        height: 1,
        bitsAllocated: 16,
        bitsStored: 16,
        isSigned: false,
      );

      expect(pixelData.length, 5);
    });

    test('handles empty buffer', () {
      final pixelData = DicomInt16PixelData(
        buffer: Int16List(0),
        width: 0,
        height: 0,
        bitsAllocated: 16,
        bitsStored: 16,
        isSigned: false,
      );

      expect(pixelData.length, 0);
    });

    test('handles unsigned pixels', () {
      final pixelData = DicomInt16PixelData(
        buffer: Int16List(0),
        width: 0,
        height: 0,
        bitsAllocated: 16,
        bitsStored: 12,
        isSigned: false,
      );

      expect(pixelData.isSigned, isFalse);
    });

    test('buffer preserves negative values', () {
      final buffer = Int16List.fromList([-1000, -500, 0, 500, 1000]);
      final pixelData = DicomInt16PixelData(
        buffer: buffer,
        width: 5,
        height: 1,
        bitsAllocated: 16,
        bitsStored: 16,
        isSigned: true,
      );

      expect(pixelData.buffer[0], -1000);
      expect(pixelData.buffer[1], -500);
      expect(pixelData.buffer[4], 1000);
    });

    test('pattern matching via is works', () {
      final pixelData = DicomInt16PixelData(
        buffer: Int16List(0),
        width: 0,
        height: 0,
        bitsAllocated: 16,
        bitsStored: 16,
        isSigned: false,
      );

      if (pixelData case DicomInt16PixelData(:final buffer)) {
        expect(buffer, isEmpty);
      }
    });
  });

  group('DicomPixelData sealed hierarchy', () {
    test('DicomInt16PixelData is the only subtype', () {
      final pixelData = DicomInt16PixelData(
        buffer: Int16List(0),
        width: 0,
        height: 0,
        bitsAllocated: 16,
        bitsStored: 16,
        isSigned: false,
      );

      // Verify exhaustive check would work
      final result = switch (pixelData) {
        DicomInt16PixelData() => 'int16',
      };
      expect(result, 'int16');
    });
  });
}
