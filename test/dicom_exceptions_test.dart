import 'package:dicom_toolkit/dicom_toolkit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DicomException', () {
    test('with message only', () {
      const ex = DicomProcessingException('Something went wrong');

      expect(ex.message, 'Something went wrong');
      expect(ex.originalError, isNull);
    });

    test('with original error', () {
      final original = Exception('root cause');
      final ex = DicomProcessingException('Parse failed', original);

      expect(ex.message, 'Parse failed');
      expect(ex.originalError, original);
    });

    test('toString includes message', () {
      const ex = DicomProcessingException('Parse failed');

      expect(ex.toString(), contains('Parse failed'));
      expect(ex.toString(), contains('DicomProcessingException'));
    });

    test('toString includes original error', () {
      const ex = DicomProcessingException('Parse failed', 'Rust panic');

      expect(ex.toString(), contains('Parse failed'));
      expect(ex.toString(), contains('Rust panic'));
    });

    test('is an Exception', () {
      const ex = DicomProcessingException('test');
      expect(ex, isA<Exception>());
    });

    test('DicomException is abstract', () {
      // DicomException is abstract; DicomProcessingException is the concrete one
      const ex = DicomProcessingException('test');
      expect(ex, isA<DicomException>());
    });
  });
}
