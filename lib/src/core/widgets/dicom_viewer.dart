import 'package:flutter/material.dart';
import '../constants/color_maps.dart';
import '../controller/dicom_controller.dart';
import '../shader/dicom_shader_painter.dart';

/// A production-ready, interactive widget for high-performance DICOM rendering.
///
/// `DicomViewer` provides a seamless user experience by integrating:
/// * **GPU-Accelerated Rendering**: Uses the [DicomShaderPainter] for clinical precision.
/// * **Interactive Gestures**: Built-in support for Panning, Zooming, and dragging
///   to adjust Windowing (Contrast/Brightness).
/// * **State Management**: Listens to a [DicomController] to automatically update
///   itself when metadata or pixel data changes.
///
/// **Default Interactions:**
/// * **Two-Finger Pinch**: Zoom in/out.
/// * **Single-Finger Drag**: Adjust Window Level/Width.
/// * **Double-Tap**: Reset contrast/brightness to DICOM defaults.
class DicomViewer extends StatelessWidget {
  /// Creates a [DicomViewer].
  const DicomViewer({
    required this.controller,
    super.key,
    this.fit = BoxFit.contain,
  });

  /// The state controller that provides metadata and GPU shaders.
  final DicomController controller;

  /// How the image should be inscribed into the allocated space.
  final BoxFit fit;

  @override
  Widget build(final BuildContext context) {
    // ListenableBuilder ensures only this widget rebuilds when state changes
    return ListenableBuilder(
      listenable: controller,
      builder: (final context, final _) {
        if (controller.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (controller.hasError) {
          return Center(
            child: Text(
              controller.errorMessage ?? 'Unknown error',
              style: const TextStyle(color: Colors.red),
            ),
          );
        }

        if (!controller.hasData) {
          return const Center(child: Text('No DICOM data loaded.'));
        }

        // The core interactive area
        return ClipRect(
          child: GestureDetector(
            // Handle Windowing adjustments (Drag up/down, left/right)
            onPanUpdate: (final details) {
              controller.adjustWindowing(
                deltaX: details.delta.dx,
                deltaY: details.delta.dy,
              );
            },
            onDoubleTap: controller.resetWindowing, // Reset on double tap
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 10.0,
              child: FittedBox(
                fit: fit,
                child: SizedBox(
                  width: controller.currentFrame!.metadata.width.toDouble(),
                  height: controller.currentFrame!.metadata.height.toDouble(),
                  // The actual Native Renderer using Fragment Shaders
                  child: CustomPaint(
                    painter: DicomShaderPainter(
                      frameResult: controller.currentFrame!,
                      windowCenter: controller.windowCenter!,
                      windowWidth: controller.windowWidth!,
                      shader: controller.shader!,
                      rawTexture: controller.rawTexture!,
                      colorLutTexture: controller.colorLutTexture,
                      colorize: controller.colorMap != DicomColorMap.grayscale,
                      invert: controller.invert,
                      monochrome1: controller.isMonochrome1,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
