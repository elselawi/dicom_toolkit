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
  /// On web (CanvasKit), FragmentProgram is unsupported — returns null silently.
  Future<ui.FragmentShader?> get shader async {
    if (_shader != null) {
      print('[DART] renderer.shader: already cached');
      return _shader;
    }
    print('[DART] renderer.shader: attempting _compileShader...');
    try {
      _shader = await _compileShader();
      print('[DART] renderer.shader: compiled OK');
    } catch (e) {
      print('[DART] renderer.shader: compile FAILED — $e');
      _shader = null;
    }
    return _shader;
  }

  /// Compiles the GLSL windowing shader from assets.
  Future<ui.FragmentShader> _compileShader() async {
    print(
        '[DART] renderer._compileShader: loading asset ${LibShaders.dicomWindow}...');
    final program = await ui.FragmentProgram.fromAsset(LibShaders.dicomWindow);
    print('[DART] renderer._compileShader: FragmentProgram loaded');
    final fs = program.fragmentShader();
    print('[DART] renderer._compileShader: fragmentShader OK');
    return fs;
  }

  /// Packs 16-bit DICOM pixel data into an 8-bit RGBA [ui.Image] texture.
  ///
  /// When [applyWindowing] is true (CPU fallback for web), applies
  /// window-center/window-width/HU in Dart instead of the GPU shader.
  Future<ui.Image> createTexture(
    final DicomParseResult result, {
    final double? windowCenter,
    final double? windowWidth,
    final bool applyWindowing = false,
  }) async {
    final pixelData = result.pixelData;
    if (pixelData is! DicomInt16PixelData) {
      throw ArgumentError(
          'Only 16-bit signed pixel data is currently supported');
    }

    final data = pixelData.buffer;
    final width = pixelData.width;
    final height = pixelData.height;
    final pixelCount = width * height;
    final meta = result.metadata;
    print('[DART] createTexture: applyWindowing=$applyWindowing '
        'buffer.len=${data.length} w=$width h=$height pixelCount=$pixelCount');

    if (applyWindowing) {
      // ── CPU fallback (web): apply windowing in pure Dart ──
      final wc = windowCenter ?? meta.windowCenter;
      final ww = (windowWidth ?? meta.windowWidth).clamp(1.0, 65536.0);
      final slope = meta.rescaleSlope;
      final intercept = meta.rescaleIntercept;
      final low = wc - ww / 2.0;
      print(
          '[DART] createTexture CPU: wc=$wc ww=$ww slope=$slope intercept=$intercept');
      final rgbaData = Uint8List(pixelCount * 4);
      for (var i = 0; i < pixelCount && i < data.length; i++) {
        final hu = data[i].toDouble() * slope + intercept;
        final norm = ((hu - low) / ww).clamp(0.0, 1.0);
        final v = (norm * 255.0).round();
        rgbaData[i * 4 + 0] = v;
        rgbaData[i * 4 + 1] = v;
        rgbaData[i * 4 + 2] = v;
        rgbaData[i * 4 + 3] = 255;
      }
      print(
          '[DART] createTexture CPU: packing done, calling decodeImageFromPixels...');
      final completer = Completer<ui.Image>();
      ui.decodeImageFromPixels(
        rgbaData,
        width,
        height,
        ui.PixelFormat.rgba8888,
        (final ui.Image img) {
          print(
              '[DART] createTexture CPU: decodeImageFromPixels callback, img=${img.width}x${img.height}');
          completer.complete(img);
        },
      );
      print('[DART] createTexture CPU: awaiting completer...');
      return completer.future;
    }

    // ── GPU path: pack 16-bit into R/G channels for shader ──
    print(
        '[DART] createTexture GPU: packing ${pixelCount} pixels into RGBA...');
    final rgbaData = Uint8List(pixelCount * 4);

    for (var i = 0; i < pixelCount && i < data.length; i++) {
      final val = data[i] + 32768; // Offset to unsigned u16 range
      rgbaData[i * 4 + 0] = (val >> 8) & 0xFF; // R = high byte
      rgbaData[i * 4 + 1] = val & 0xFF; // G = low byte
      rgbaData[i * 4 + 2] = 0; // B = unused
      rgbaData[i * 4 + 3] = 255; // A = opaque
    }

    print(
        '[DART] createTexture GPU: packing done, calling decodeImageFromPixels...');
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      rgbaData,
      width,
      height,
      ui.PixelFormat.rgba8888,
      (final ui.Image img) {
        print(
            '[DART] createTexture GPU: decodeImageFromPixels callback, img=${img.width}x${img.height}');
        completer.complete(img);
      },
    );
    print('[DART] createTexture GPU: awaiting completer...');
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
  /// On platforms with shader support, applies windowing + HU + color LUT on GPU.
  /// On web (no shader), falls back to CPU windowing via [createTexture].
  Future<ui.Image> render(
    final DicomParseResult result, {
    final double? windowCenter,
    final double? windowWidth,
    final DicomColorMap? colorMap,
    final bool? invert,
    final int rotationSteps = 0,
  }) async {
    print('[DART] renderer.render: entry, awaiting shader...');
    final s = await shader;
    print('[DART] renderer.render: shader=${s == null ? "NULL" : "OK"}');
    if (s == null) {
      print('[DART] renderer.render: taking CPU fallback path');
      return createTexture(
        result,
        windowCenter: windowCenter,
        windowWidth: windowWidth,
        applyWindowing: true,
      );
    }
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
    if (s == null) {
      // Web fallback: CPU windowing
      return createTexture(
        result,
        windowCenter: wc,
        windowWidth: ww,
        applyWindowing: true,
      );
    }

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
