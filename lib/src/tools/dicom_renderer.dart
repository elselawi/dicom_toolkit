import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../core/constants/color_maps.dart';
import '../core/constants/lib_shaders.dart';
import '../core/dicom_parse_result.dart';
import '../core/dicom_pixel_data.dart';

/// GPU-accelerated DICOM image renderer.
///
/// This tool handles the complete rendering pipeline:
/// 1. Compiles the GLSL fragment shader on first use.
/// 2. Packs 16-bit pixel data into an 8-bit RGBA texture.
/// 3. Applies windowing, Hounsfield transform, colorization, and inversion
///    on the GPU.
///
/// Use [render] for a one-call render-to-[ui.Image], or use [createTexture]
/// and [renderToImage] separately when you need to reuse the texture across
/// many windowing settings.
class DicomRenderer {

  /// Creates a renderer.
  ///
  /// [colorMap] defaults to [DicomColorMap.grayscale]. Pass a different map
  /// for pseudocolor (hot-iron, PET, etc.).
  DicomRenderer({
    final DicomColorMap colorMap = DicomColorMap.grayscale,
    final bool invert = false,
  })  : _colorMap = colorMap,
        _invert = invert;
  ui.FragmentShader? _shader;
  final DicomColorMap _colorMap;
  final bool _invert;

  /// Ensures the fragment shader has been compiled.
  Future<ui.FragmentShader> get shader async {
    _shader ??= await _compileShader();
    return _shader!;
  }

  /// Compiles the GLSL windowing shader from assets.
  Future<ui.FragmentShader> _compileShader() async {
    final program = await ui.FragmentProgram.fromAsset(LibShaders.dicomWindow);
    return program.fragmentShader();
  }

  /// Packs 16-bit DICOM pixel data into an 8-bit RGBA [ui.Image] texture.
  ///
  /// The high byte goes into R, the low byte into G. The shader reverses this
  /// to reconstruct full 16-bit precision.
  Future<ui.Image> createTexture(final DicomParseResult result) async {
    final pixelData = result.pixelData;
    if (pixelData is! DicomInt16PixelData) {
      throw ArgumentError(
          'Only 16-bit signed pixel data is currently supported');
    }

    final data = pixelData.buffer;
    final width = pixelData.width;
    final height = pixelData.height;
    final rgbaData = Uint8List(width * height * 4);

    for (var i = 0; i < data.length; i++) {
      final val = data[i] + 32768; // Offset to unsigned u16 range
      rgbaData[i * 4 + 0] = (val >> 8) & 0xFF; // R = high byte
      rgbaData[i * 4 + 1] = val & 0xFF; // G = low byte
      rgbaData[i * 4 + 2] = 0; // B = unused
      rgbaData[i * 4 + 3] = 255; // A = opaque
    }

    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      rgbaData,
      width,
      height,
      ui.PixelFormat.rgba8888,
      (final ui.Image img) => completer.complete(img),
    );
    return completer.future;
  }

  /// Builds a color LUT texture for [map], or null for grayscale.
  Future<ui.Image?> _buildColorLutFor(final DicomColorMap map) async {
    if (map == DicomColorMap.grayscale) return null;

    final lutBytes = ColorMapLut.generate(map);
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      lutBytes,
      256,
      1,
      ui.PixelFormat.rgba8888,
      (final ui.Image img) => completer.complete(img),
    );
    return completer.future;
  }

  /// Renders a DICOM frame to a [ui.Image] in a single call.
  ///
  /// This is the main entry point. It creates the texture, applies windowing
  /// and HU scaling, and outputs the final rendered image.
  ///
  /// [windowCenter] and [windowWidth] override the DICOM header defaults.
  /// If omitted, the values from [result.metadata] are used.
  ///
  /// [colorMap] overrides the renderer's default color map for this call.
  /// [invert] overrides the renderer's default invert flag for this call.
  /// [rotationSteps] rotates the output 0–3 steps of 90° clockwise.
  Future<ui.Image> render(
    final DicomParseResult result, {
    final double? windowCenter,
    final double? windowWidth,
    final DicomColorMap? colorMap,
    final bool? invert,
    final int rotationSteps = 0,
  }) async {
    final texture = await createTexture(result);
    return renderToImage(
      result,
      texture,
      windowCenter: windowCenter,
      windowWidth: windowWidth,
      colorMap: colorMap,
      invert: invert,
      rotationSteps: rotationSteps,
    );
  }

  /// Renders an already-created [texture] to a new [ui.Image].
  ///
  /// Use this when you need to re-render with different windowing without
  /// re-packing the pixel data.
  Future<ui.Image> renderToImage(
    final DicomParseResult result,
    final ui.Image texture, {
    final double? windowCenter,
    final double? windowWidth,
    final DicomColorMap? colorMap,
    final bool? invert,
    final int rotationSteps = 0,
  }) async {
    final meta = result.metadata;
    final wc = windowCenter ?? meta.windowCenter;
    final ww = windowWidth ?? meta.windowWidth;
    final isMonochrome1 = meta.photometricInterpretation == 'MONOCHROME1';
    final effectiveColorMap = colorMap ?? _colorMap;
    final effectiveInvert = invert ?? _invert;
    final rot = rotationSteps % 4;

    final colorLut = effectiveColorMap == DicomColorMap.grayscale
        ? null
        : await _buildColorLutFor(effectiveColorMap);

    final s = await shader;

    // Bind uniforms (order must match shader expectations).
    final width = texture.width.toDouble();
    final height = texture.height.toDouble();
    s.setFloat(0, width);
    s.setFloat(1, height);
    s.setFloat(2, wc);
    s.setFloat(3, ww);
    s.setFloat(4, meta.rescaleIntercept);
    s.setFloat(5, meta.rescaleSlope);
    s.setFloat(6, colorLut != null ? 1.0 : 0.0);
    s.setFloat(7, effectiveInvert ? 1.0 : 0.0);
    s.setFloat(8, isMonochrome1 ? 1.0 : 0.0);
    s.setImageSampler(0, texture);
    s.setImageSampler(1, colorLut ?? texture);

    // Render via a PictureRecorder → ui.Image.
    final recorder = ui.PictureRecorder();

    // Apply rotation: render into a canvas that's rotated around its center.
    final canvasW = rot.isOdd ? height : width;
    final canvasH = rot.isOdd ? width : height;
    final canvas = Canvas(recorder);
    canvas.translate(canvasW / 2, canvasH / 2);
    canvas.rotate(rot * 1.57079632679); // π/2 × steps
    canvas.translate(-width / 2, -height / 2);

    final paint = Paint()..shader = s;
    canvas.drawRect(Rect.fromLTWH(0, 0, width, height), paint);

    final picture = recorder.endRecording();
    final rendered = await picture.toImage(canvasW.toInt(), canvasH.toInt());
    return rendered;
  }

  /// Releases the compiled shader. Call when the renderer is no longer needed.
  void dispose() {
    _shader = null;
  }
}
