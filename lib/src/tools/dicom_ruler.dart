import 'dart:math';

import '../core/dicom_metadata.dart';

/// A pixel-space point within a DICOM image.
///
/// [x] is the column (horizontal), [y] is the row (vertical).
typedef DicomPoint = ({double x, double y});

/// Computes real-world distances from pixel coordinates using DICOM physical
/// spacing metadata.
///
/// Checks Pixel Spacing (0028,0030) first, then Imager Pixel Spacing
/// (0018,1164) — the latter is common in CR/DX X-ray files.
/// Falls back to pixel-unit distance when neither tag is available.
class DicomRuler {
  /// Creates a [DicomRuler] for measuring real-world distances from
  /// pixel coordinates.
  const DicomRuler();

  /// Returns the Euclidean distance between [a] and [b] in millimetres.
  ///
  /// Falls back to pixel-unit distance when [metadata] lacks pixel spacing.
  double measure(
    final DicomMetadata metadata,
    final DicomPoint a,
    final DicomPoint b,
  ) {
    final spacing = _tryGetSpacing(metadata);
    final dx = (b.x - a.x) * spacing.x;
    final dy = (b.y - a.y) * spacing.y;
    return sqrt(dx * dx + dy * dy);
  }

  /// Returns the pixel spacing row/col as a (x: row, y: col) pair.
  /// Checks Pixel Spacing (0028,0030) first, then Imager Pixel Spacing
  /// (0018,1164). Falls back to (1, 1) when neither is present.
  ({double x, double y}) _tryGetSpacing(final DicomMetadata metadata) {
    final raw = metadata.pixelSpacing;
    if (raw == null || !raw.contains('\\')) return (x: 1, y: 1);

    final parts = raw.split('\\');
    if (parts.length < 2) return (x: 1, y: 1);

    final row = double.tryParse(parts[0]);
    final col = double.tryParse(parts[1]);
    if (row == null || col == null || row <= 0 || col <= 0) {
      return (x: 1, y: 1);
    }

    return (x: row, y: col);
  }
}
