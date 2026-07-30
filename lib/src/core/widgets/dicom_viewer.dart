import 'package:flutter/material.dart';

import '../../viewer/dicom_viewer_controller.dart';
import '../constants/color_maps.dart';
import '../shader/dicom_shader_painter.dart';

/// A production-ready, interactive widget for high-performance DICOM rendering.
///
/// `DicomViewer` provides a seamless user experience by integrating:
/// * **GPU-Accelerated Rendering**: Uses the [DicomShaderPainter] for clinical precision.
/// * **Interactive Gestures**: Built-in support for Panning, Zooming, and dragging
///   to adjust Windowing (Contrast/Brightness).
/// * **State Management**: Listens to a [DicomViewerController] to automatically update
///   itself when metadata or pixel data changes.
///
/// **Default Interactions:**
/// * **Two-Finger Pinch**: Zoom in/out.
/// * **Single-Finger Drag**: Adjust Window Level/Width.
/// * **Double-Tap**: Reset contrast/brightness to DICOM defaults.
///
/// Set [interactive] to `false` to disable all built-in gestures (useful when
/// an outer widget needs to handle taps/pans for measurement tools).
class DicomViewer extends StatelessWidget {
  /// Creates a [DicomViewer].
  const DicomViewer({
    required this.controller,
    super.key,
    this.fit = BoxFit.contain,
    this.interactive = true,
  });

  /// The state controller that provides metadata and GPU shaders.
  final DicomViewerController controller;

  /// How the image should be inscribed into the allocated space.
  final BoxFit fit;

  /// When false, disables windowing drag, pinch-to-zoom, and double-tap reset.
  final bool interactive;

  @override
  Widget build(final BuildContext context) {
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

        final result = controller.result!;
        final rot = controller.rotationSteps;
        final isRotated = rot.isOdd; // 90° or 270° swap w/h
        final hasGpuShader = controller.shader != null;
        final hasTexture = controller.rawTexture != null;
        print(
            '[DART] viewer build: hasGpuShader=$hasGpuShader hasTexture=$hasTexture '
            'texSize=${controller.rawTexture?.width}x${controller.rawTexture?.height} '
            'wc=${controller.windowCenter} ww=${controller.windowWidth}');

        // The core image widget — always present.
        print(
            '[DART] viewer build: using ${hasGpuShader ? "GPU CustomPaint" : "CPU RawImage"}');
        final image = Transform.rotate(
          angle: rot * 1.57079632679, // π/2 per step
          child: SizedBox(
            width:
                (isRotated ? result.pixelData.height : result.pixelData.width)
                    .toDouble(),
            height:
                (isRotated ? result.pixelData.width : result.pixelData.height)
                    .toDouble(),
            child: hasGpuShader
                ? CustomPaint(
                    painter: DicomShaderPainter(
                      result: result,
                      windowCenter: controller.windowCenter!,
                      windowWidth: controller.windowWidth!,
                      shader: controller.shader!,
                      rawTexture: controller.rawTexture!,
                      colorLutTexture: controller.colorLutTexture,
                      colorize: controller.colorMap != DicomColorMap.grayscale,
                      invert: controller.invert,
                    ),
                  )
                : RawImage(
                    image: controller.rawTexture,
                    fit: BoxFit.fill,
                  ),
          ),
        );

        if (!interactive) {
          return ClipRect(child: FittedBox(fit: fit, child: image));
        }

        return ClipRect(
          child: GestureDetector(
            onPanUpdate: (final details) {
              controller.adjustWindowing(
                deltaX: details.delta.dx,
                deltaY: details.delta.dy,
              );
            },
            onDoubleTap: controller.resetWindowing,
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 10.0,
              child: FittedBox(fit: fit, child: image),
            ),
          ),
        );
      },
    );
  }
}
