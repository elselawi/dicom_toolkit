import 'dart:typed_data';

import 'package:dicom_toolkit/dicom_toolkit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockDicomParser extends Mock implements DicomParser {}

void main() {
  late DicomViewerController controller;
  late MockDicomParser mockParser;

  setUpAll(() {
    registerFallbackValue(Uint8List(0));
  });

  setUp(() {
    mockParser = MockDicomParser();
    controller = DicomViewerController(parser: mockParser);
  });

  group('DicomViewerController', () {
    test('initial state is correct', () {
      expect(controller.isLoading, isFalse);
      expect(controller.hasError, isFalse);
      expect(controller.hasData, isFalse);
      expect(controller.result, isNull);
    });

    test('loadFromBytes sets loading state', () async {
      when(() => mockParser.parse(any())).thenAnswer(
        (final _) async => throw Exception('test error'),
      );

      final future = controller.loadFromBytes(bytes: Uint8List(1));
      expect(controller.isLoading, isTrue);
      await future;
      expect(controller.hasError, isTrue);
      expect(controller.errorMessage, contains('Failed to load DICOM'));
    });

    test('clear resets all state', () {
      controller.clear();
      expect(controller.result, isNull);
      expect(controller.windowCenter, isNull);
      expect(controller.windowWidth, isNull);
      expect(controller.hasError, isFalse);
      expect(controller.invert, isFalse);
    });

    test('toggleInvert toggles the invert flag', () {
      expect(controller.invert, isFalse);
      controller.toggleInvert();
      expect(controller.invert, isTrue);
      controller.toggleInvert();
      expect(controller.invert, isFalse);
    });
  });
}
