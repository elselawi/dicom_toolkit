import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../rust/api/core/models/dicom_frame_result.dart';

/// A performance-critical [CustomPainter] that offloads medical rendering to the GPU.
///
/// `DicomShaderPainter` acts as the bridge between Flutter's Canvas and the
/// custom GLSL Fragment Shader. It handles:
/// 1. Passing current Window Center/Width to the shader.
/// 2. Binding the 16-bit packed texture.
/// 3. Passing Hounsfield Unit (HU) transformation constants.
/// 4. Binding an optional 256×1 color LUT for image colorization.
///
/// By performing these calculations on the GPU, we ensure clinical precision
/// and smooth 60fps interactivity even on mobile devices.
class DicomShaderPainter extends CustomPainter {
  /// Creates a [DicomShaderPainter].
  DicomShaderPainter({
    required this.frameResult,
    required this.windowCenter,
    required this.windowWidth,
    required this.shader,
    required this.rawTexture,
    this.colorLutTexture,
    this.colorize = false,
    this.invert = false,
    this.monochrome1 = false,
  });

  /// The processing result containing metadata and pixel data pointers.
  final DicomFrameResult frameResult;

  /// The user-defined or default Window Center for contrast mapping.
  final double windowCenter;

  /// The user-defined or default Window Width for contrast mapping.
  final double windowWidth;

  /// The compiled GLSL shader program instance.
  final ui.FragmentShader shader;

  /// The raw 16-bit pixel data packed into an RGBA [ui.Image] sampler.
  final ui.Image rawTexture;

  /// An optional 256×1 RGBA color lookup table for image colorization.
  final ui.Image? colorLutTexture;

  /// Whether to apply the color LUT (true) or render grayscale (false).
  final bool colorize;

  /// Whether to invert grayscale (true) or render normally (false).
  final bool invert;

  /// Whether the image uses MONOCHROME1 photometric interpretation.
  final bool monochrome1;

  /// Performs the actual drawing operation using the fragment shader.
  @override
  void paint(final Canvas canvas, final Size size) {
    // 1. Pass the canvas resolution to the shader
    shader.setFloat(0, size.width);
    shader.setFloat(1, size.height);

    // 2. Pass the interactive Windowing parameters
    shader.setFloat(2, windowCenter);
    shader.setFloat(3, windowWidth);

    // 3. Pass the hardware-specific metadata for Hounsfield Units calculation
    shader.setFloat(4, frameResult.metadata.rescaleIntercept);
    shader.setFloat(5, frameResult.metadata.rescaleSlope);

    // 4. Pass the colorize toggle
    shader.setFloat(6, colorize ? 1.0 : 0.0);

    // 5. Pass invert + MONOCHROME1 flags
    shader.setFloat(7, invert ? 1.0 : 0.0);
    shader.setFloat(8, monochrome1 ? 1.0 : 0.0);

    // 6. Pass the actual image texture
    shader.setImageSampler(0, rawTexture);

    // 7. Pass the color LUT (or a dummy if grayscale — shader won't use it)
    if (colorLutTexture != null) {
      shader.setImageSampler(1, colorLutTexture!);
    } else {
      shader.setImageSampler(1, rawTexture);
    }

    // 8. Tell the GPU to paint a rectangle covering the canvas using our shader
    final paint = Paint()..shader = shader;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
  }

  /// Determines if the painter needs to rebuild.
  @override
  bool shouldRepaint(covariant final DicomShaderPainter oldDelegate) {
    return oldDelegate.windowCenter != windowCenter ||
        oldDelegate.windowWidth != windowWidth ||
        oldDelegate.frameResult != frameResult ||
        oldDelegate.colorize != colorize ||
        oldDelegate.invert != invert ||
        oldDelegate.monochrome1 != monochrome1 ||
        oldDelegate.colorLutTexture != colorLutTexture;
  }
}
