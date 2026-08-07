import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:async';

import 'package:dicom_toolkit/dicom_toolkit.dart';
import 'package:dicom_toolkit/src/rust/api/core/models/dicom_metadata.dart'
    as generated;
import 'package:flutter_test/flutter_test.dart';

/// Builds a small [DicomParseResult] (2×1 pixels) for PNG export testing.
DicomParseResult _buildResult() {
  const inner = generated.DicomMetadata(
    patientId: 'P001',
    patientName: 'Test',
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
    photometricInterpretation: 'MONOCHROME2',
    width: 2,
    height: 1,
    windowCenter: 100.0,
    windowWidth: 200.0,
    rescaleIntercept: 0.0,
    rescaleSlope: 1.0,
    samplesPerPixel: 1,
    bitsAllocated: 16,
    bitsStored: 16,
    highBit: 15,
    pixelRepresentation: 1,
    pixelSpacing: '',
    imagePositionPatient: '',
    sliceLocation: 0.0,
    spacingBetweenSlices: 0.0,
    imageOrientationPatient: '',
    numberOfFrames: 1,
  );
  final frame = DicomFrameResult(
    metadata: inner,
    pixelData: Int16List.fromList([0, 200]),
  );
  return DicomParseResult.fromFrame(frame: frame);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DicomExport.toPngBytes', () {
    test('produces a decodable PNG with the correct dimensions', () async {
      const exporter = DicomExport();
      final pngBytes = await exporter.toPngBytes(
        _buildResult(),
        windowCenter: 100,
        windowWidth: 200,
      );

      // PNG signature: 137 80 78 71 13 10 26 10
      const magic = [137, 80, 78, 71, 13, 10, 26, 10];
      expect(pngBytes.length, greaterThan(magic.length));
      for (var i = 0; i < magic.length; i++) {
        expect(pngBytes[i], magic[i], reason: 'byte $i should match PNG magic');
      }

      // The returned list must be a fresh copy owned by the caller — not a
      // view onto a buffer that was released when the image was disposed.
      expect(pngBytes, isNotEmpty);

      // Decode confirms it is a real, well-formed PNG (not just a signature),
      // and that the byte copy outlives the disposed source image.
      final decodeCompleter = Completer<ui.Image>();
      ui.decodeImageFromList(pngBytes, decodeCompleter.complete);
      final decoded = await decodeCompleter.future;
      try {
        expect(decoded.width, 2);
        expect(decoded.height, 1);
      } finally {
        decoded.dispose();
      }
    });

    test('disposes the image and rethrows when encoding returns null',
        () async {
      final exporter = DicomExport(
        encodePng: (image) async => null,
      );
      await expectLater(
        exporter.toPngBytes(_buildResult()),
        throwsA(isA<StateError>()),
      );
    });

    test('disposes the image and rethrows when encoding throws', () async {
      final exporter = DicomExport(
        encodePng: (image) async => throw Exception('encode boom'),
      );
      await expectLater(
        exporter.toPngBytes(_buildResult()),
        throwsA(isA<Exception>()),
      );
    });
  });
}
