import 'dart:typed_data';

import 'package:flutter/material.dart';
import '../controller/dicom_controller.dart';
import 'dicom_viewer.dart';

/// A template screen demonstrating the implementation of a medical viewer.
///
/// This screen provides:
/// * An [AppBar] with a reset button.
/// * Automatic initialization and disposal of the [DicomController].
/// * Integration of the [DicomViewer] for interactive medical scans.
class MedicalScreen extends StatefulWidget {
  /// Creates a [MedicalScreen] for the given [dicomBytes].
  const MedicalScreen({required this.dicomBytes, this.title, super.key});

  /// The raw contents of the .dcm file to display.
  final Uint8List dicomBytes;

  /// The title of the screen.
  final String? title;

  @override
  State<MedicalScreen> createState() => _MedicalScreenState();
}

class _MedicalScreenState extends State<MedicalScreen> {
  late final DicomController _dicomController;

  @override
  Future<void> initState() async {
    super.initState();
    _dicomController = DicomController();

    await _dicomController.loadFromBytes(bytes: widget.dicomBytes);
  }

  @override
  void dispose() {
    _dicomController.dispose();
    super.dispose();
  }

  @override
  Widget build(final BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title ?? 'DICOM Native Viewer'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _dicomController.resetWindowing,
          ),
        ],
      ),
      body: DicomViewer(controller: _dicomController),
    );
  }
}
