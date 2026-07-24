import 'dart:typed_data';

/// Available color maps for DICOM image colorization.
enum DicomColorMap {
  /// Standard grayscale (no colorization).
  grayscale('Grayscale'),

  /// Hot iron: black → red → orange → yellow → white.
  /// Commonly used for CT/MR general purpose.
  hotIron('Hot Iron'),

  /// PET heat: black → purple → magenta → red → yellow → white.
  /// Commonly used in nuclear medicine and PET imaging.
  pet('PET Heat'),

  /// Rainbow: blue → cyan → green → yellow → red.
  /// Common for flow visualization and Doppler.
  rainbow('Rainbow'),

  /// Cool: cyan → blue → magenta.
  /// Common for ultrasound alternatives.
  cool('Cool'),

  /// Bone: cool blue-white gradient.
  /// Useful for orthopedic imaging.
  bone('Bone');

  const DicomColorMap(this.label);
  final String label;
}

/// Generates 256-element RGBA LUT bytes for each color map.
///
/// Each entry is 4 bytes (R, G, B, A=255). The LUT is uploaded as a 256×1
/// `ui.Image` texture and sampled by the shader.
abstract class ColorMapLut {
  ColorMapLut._();

  /// Returns a 256×4-byte (1024 bytes) Uint8List for the given [map].
  static Uint8List generate(DicomColorMap map) {
    return switch (map) {
      DicomColorMap.grayscale => _grayscale(),
      DicomColorMap.hotIron => _gradient(_hotIronStops),
      DicomColorMap.pet => _gradient(_petStops),
      DicomColorMap.rainbow => _gradient(_rainbowStops),
      DicomColorMap.cool => _gradient(_coolStops),
      DicomColorMap.bone => _gradient(_boneStops),
    };
  }

  /// Builds a 256-entry LUT from a list of (position, r, g, b) stops.
  /// Positions are in [0, 1]; colors are linearly interpolated.
  static Uint8List _gradient(List<_ColorStop> stops) {
    final data = Uint8List(256 * 4);
    for (var i = 0; i < 256; i++) {
      final t = i / 255.0;

      // Find the two stops surrounding t
      var lo = stops.first;
      var hi = stops.last;
      for (var s = 0; s < stops.length - 1; s++) {
        if (t >= stops[s].pos && t <= stops[s + 1].pos) {
          lo = stops[s];
          hi = stops[s + 1];
          break;
        }
      }

      final range = hi.pos - lo.pos;
      final frac = range == 0 ? 0.0 : (t - lo.pos) / range;

      data[i * 4 + 0] = (lo.r + (hi.r - lo.r) * frac).round().clamp(0, 255);
      data[i * 4 + 1] = (lo.g + (hi.g - lo.g) * frac).round().clamp(0, 255);
      data[i * 4 + 2] = (lo.b + (hi.b - lo.b) * frac).round().clamp(0, 255);
      data[i * 4 + 3] = 255;
    }
    return data;
  }

  static Uint8List _grayscale() {
    final data = Uint8List(256 * 4);
    for (var i = 0; i < 256; i++) {
      data[i * 4 + 0] = i;
      data[i * 4 + 1] = i;
      data[i * 4 + 2] = i;
      data[i * 4 + 3] = 255;
    }
    return data;
  }

  // ── Color stop definitions ──────────────────────────────────

  static const _hotIronStops = [
    _ColorStop(0.00, 0, 0, 0),
    _ColorStop(0.25, 128, 0, 0),
    _ColorStop(0.50, 255, 64, 0),
    _ColorStop(0.75, 255, 192, 0),
    _ColorStop(1.00, 255, 255, 255),
  ];

  static const _petStops = [
    _ColorStop(0.00, 0, 0, 0),
    _ColorStop(0.15, 64, 0, 64),
    _ColorStop(0.35, 192, 0, 128),
    _ColorStop(0.55, 255, 32, 32),
    _ColorStop(0.75, 255, 192, 0),
    _ColorStop(1.00, 255, 255, 255),
  ];

  static const _rainbowStops = [
    _ColorStop(0.00, 0, 0, 128),
    _ColorStop(0.25, 0, 128, 255),
    _ColorStop(0.50, 0, 255, 128),
    _ColorStop(0.75, 255, 255, 0),
    _ColorStop(1.00, 255, 0, 0),
  ];

  static const _coolStops = [
    _ColorStop(0.00, 0, 0, 0),
    _ColorStop(0.33, 0, 128, 255),
    _ColorStop(0.66, 0, 255, 255),
    _ColorStop(1.00, 192, 128, 255),
  ];

  static const _boneStops = [
    _ColorStop(0.00, 0, 0, 32),
    _ColorStop(0.35, 64, 128, 192),
    _ColorStop(0.65, 192, 192, 224),
    _ColorStop(0.85, 224, 224, 240),
    _ColorStop(1.00, 255, 255, 255),
  ];
}

class _ColorStop {
  const _ColorStop(this.pos, this.r, this.g, this.b);
  final double pos;
  final int r;
  final int g;
  final int b;
}
