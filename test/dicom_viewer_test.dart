import 'dart:ui' as ui;

import 'package:dicom_toolkit/dicom_toolkit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Manual mock for DicomViewerController — avoids mocktail issues with
/// ChangeNotifier concrete classes in widget tests.
class FakeController extends ChangeNotifier implements DicomViewerController {
  FakeController({
    this.isLoading = false,
    this.hasError = false,
    this.hasData = false,
    this.errorMessage,
    this.result,
    this.rawTexture,
    this.colorLutTexture,
    this.windowCenter,
    this.windowWidth,
    this.colorMap = DicomColorMap.grayscale,
    this.invert = false,
    this.isMonochrome1 = false,
    this.shader,
    this.hasShader = false,
    this.rotationSteps = 0,
  });

  @override
  bool isLoading;
  @override
  bool hasError;
  @override
  bool hasData;
  @override
  String? errorMessage;
  @override
  DicomParseResult? result;
  @override
  ui.Image? rawTexture;
  @override
  ui.Image? colorLutTexture;
  @override
  double? windowCenter;
  @override
  double? windowWidth;
  @override
  DicomColorMap colorMap;
  @override
  bool invert;
  @override
  bool isMonochrome1;
  @override
  ui.FragmentShader? shader;
  @override
  bool hasShader;
  @override
  int rotationSteps;

  @override
  Future<void> loadFromBytes({required final dynamic bytes}) async {}

  @override
  void adjustWindowing(
      {required final double deltaX, required final double deltaY}) {}

  @override
  void updateWindowing({final double? center, final double? width}) {}

  @override
  void resetWindowing() {}

  @override
  void applyPreset(
      {required final double center, required final double width}) {}

  @override
  Future<void> setColorMap(final DicomColorMap map) async {}

  @override
  void toggleInvert() {}

  @override
  void clear() {}

  @override
  void rotateClockwise() {}

  @override
  void rotateCounterClockwise() {}

  @override
  Future<void> ensureShader() async {}
}

Widget _buildApp(final FakeController controller) {
  return MaterialApp(
    home: Scaffold(
      body: DicomViewer(controller: controller),
    ),
  );
}

void main() {
  group('DicomViewer Widget', () {
    testWidgets('displays CircularProgressIndicator when loading',
        (final tester) async {
      final controller = FakeController(isLoading: true);
      await tester.pumpWidget(_buildApp(controller));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('displays error message when hasError', (final tester) async {
      final controller = FakeController(
        hasError: true,
        errorMessage: 'Test error message',
      );
      await tester.pumpWidget(_buildApp(controller));

      expect(find.text('Test error message'), findsOneWidget);
    });

    testWidgets('displays Unknown error when hasError with null message',
        (final tester) async {
      final controller = FakeController(hasError: true);
      await tester.pumpWidget(_buildApp(controller));

      expect(find.text('Unknown error'), findsOneWidget);
    });

    testWidgets('displays default text when no data', (final tester) async {
      final controller = FakeController();
      await tester.pumpWidget(_buildApp(controller));

      expect(find.text('No DICOM data loaded.'), findsOneWidget);
    });

    testWidgets('does not show error when hasError is false',
        (final tester) async {
      final controller = FakeController();
      await tester.pumpWidget(_buildApp(controller));

      expect(find.text('Unknown error'), findsNothing);
    });
  });
}
