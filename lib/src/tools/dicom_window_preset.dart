/// A named windowing preset (center + width) and a collection of common
/// radiological presets.
///
/// Use [DicomWindowPreset.bone], [DicomWindowPreset.lung], etc. to get
/// CT-specific Hounsfield presets.  For modality-agnostic presets that adapt
/// to the image's actual pixel range, use [DicomWindowPreset.forImage].
///
/// Create a custom one with [DicomWindowPreset.custom].
library;

import '../core/dicom_parse_result.dart';
import '../core/dicom_pixel_data.dart';

/// A named windowing preset (center + width) and a collection of common
/// radiological presets.
///
/// Use [DicomWindowPreset.bone], [DicomWindowPreset.lung], etc. to get
/// CT-specific Hounsfield presets.  For modality-agnostic presets that adapt
/// to the image's actual pixel range, use [DicomWindowPreset.forImage].
///
/// Create a custom one with [DicomWindowPreset.custom].
class DicomWindowPreset {
  /// Creates a preset.
  const DicomWindowPreset({
    required this.center,
    required this.width,
    required this.label,
  });

  /// Creates a custom preset with the given label.
  const DicomWindowPreset.custom({
    required this.center,
    required this.width,
    this.label = 'Custom',
  });

  // --- Common CT presets (Hounsfield Units) ---

  /// Bone window: W:2000, C:500
  const DicomWindowPreset.bone()
      : center = 500,
        width = 2000,
        label = 'Bone';

  /// Lung window: W:1500, C:-500
  const DicomWindowPreset.lung()
      : center = -500,
        width = 1500,
        label = 'Lung';

  /// Soft-tissue / abdomen: W:400, C:50
  const DicomWindowPreset.softTissue()
      : center = 50,
        width = 400,
        label = 'Soft Tissue';

  /// Brain / stroke window: W:80, C:40
  const DicomWindowPreset.brain()
      : center = 40,
        width = 80,
        label = 'Brain';

  /// Liver window: W:150, C:30
  const DicomWindowPreset.liver()
      : center = 30,
        width = 150,
        label = 'Liver';

  /// Mediastinum window: W:400, C:50
  const DicomWindowPreset.mediastinum()
      : center = 50,
        width = 400,
        label = 'Mediastinum';

  /// Spine window: W:2000, C:300
  const DicomWindowPreset.spine()
      : center = 300,
        width = 2000,
        label = 'Spine';

  /// The window center (level).
  final double center;

  /// The window width.
  final double width;

  /// A human-readable label for this preset.
  final String label;

  /// List of all built-in CT presets (Hounsfield scale).
  static const List<DicomWindowPreset> all = [
    DicomWindowPreset.bone(),
    DicomWindowPreset.lung(),
    DicomWindowPreset.softTissue(),
    DicomWindowPreset.brain(),
    DicomWindowPreset.liver(),
    DicomWindowPreset.mediastinum(),
    DicomWindowPreset.spine(),
  ];

  /// Generates modality-agnostic presets from the pixel value range of
  /// [result].  These adapt to any modality (CT, MR, X-ray, US, etc.).
  ///
  /// Returns a list of presets that are meaningful regardless of the
  /// underlying value scale — they use the image's actual min/max rather
  /// than hardcoded Hounsfield units.
  static List<DicomWindowPreset> forImage(final DicomParseResult result) {
    final pixels = result.pixelData;
    if (pixels is! DicomInt16PixelData || pixels.length == 0) {
      return all;
    }

    final buf = pixels.buffer;
    var minVal = buf[0];
    var maxVal = buf[0];
    for (var i = 1; i < buf.length; i++) {
      final v = buf[i];
      if (v < minVal) minVal = v;
      if (v > maxVal) maxVal = v;
    }

    if (maxVal == minVal) return all;

    final range = (maxVal - minVal).toDouble();
    final mid = (minVal + maxVal) / 2.0;
    final defaultCenter = result.metadata.windowCenter;
    final defaultWidth = result.metadata.windowWidth;

    return [
      DicomWindowPreset(
        center: mid,
        width: range,
        label: 'Full Range',
      ),
      DicomWindowPreset(
        center: defaultCenter,
        width: defaultWidth,
        label: 'DICOM Default',
      ),
      DicomWindowPreset(
        center: mid,
        width: range * 0.50,
        label: 'Mid 50%',
      ),
      DicomWindowPreset(
        center: mid,
        width: range * 0.25,
        label: 'Narrow 25%',
      ),
      DicomWindowPreset(
        center: mid + range * 0.25,
        width: range * 0.50,
        label: 'High',
      ),
      DicomWindowPreset(
        center: mid - range * 0.25,
        width: range * 0.50,
        label: 'Low',
      ),
    ];
  }

  @override
  bool operator ==(final Object other) =>
      other is DicomWindowPreset &&
      center == other.center &&
      width == other.width &&
      label == other.label;

  @override
  int get hashCode => Object.hash(center, width, label);

  @override
  String toString() => 'DicomWindowPreset($label, C:$center W:$width)';
}
