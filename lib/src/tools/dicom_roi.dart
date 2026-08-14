import 'dart:math';

import '../core/dicom_parse_result.dart';
import '../core/dicom_pixel_data.dart';

/// Computed statistics for a rectangular region of interest.
class RoiStatistics {

  const RoiStatistics._({
    required this.pixelCount,
    required this.min,
    required this.max,
    required this.mean,
    required this.stdDev,
    required this.median,
  });
  /// The number of pixels inside the ROI.
  final int pixelCount;

  /// Minimum raw pixel value within the ROI.
  final double min;

  /// Maximum raw pixel value within the ROI.
  final double max;

  /// Arithmetic mean of pixel values within the ROI.
  final double mean;

  /// Standard deviation of pixel values within the ROI.
  final double stdDev;

  /// Median pixel value within the ROI.
  final double median;

  @override
  String toString() =>
      'RoiStatistics(min=$min, max=$max, mean=${mean.toStringAsFixed(2)}, '
      'stdDev=${stdDev.toStringAsFixed(2)}, median=$median, n=$pixelCount)';
}

/// A rectangular region of interest with statistical computation.
class DicomRoi {

  /// Creates a rectangular ROI.
  ///
  /// Negative [x] or [y] are treated as 0. [width] and [height] are
  /// automatically clamped to the image dimensions during [compute].
  const DicomRoi({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });
  /// Left edge (inclusive), in pixel coordinates.
  final int x;

  /// Top edge (inclusive), in pixel coordinates.
  final int y;

  /// Width in pixels (clamped to image bounds).
  final int width;

  /// Height in pixels (clamped to image bounds).
  final int height;

  /// Computes [RoiStatistics] over the pixel region defined by this ROI
  /// within [result].
  RoiStatistics compute(final DicomParseResult result) {
    final pixels = result.pixelData;
    if (pixels is! DicomInt16PixelData) {
      throw ArgumentError(
          'Only 16-bit signed pixel data is currently supported');
    }

    final imgWidth = pixels.width;
    final imgHeight = pixels.height;

    // Clamp ROI bounds to image dimensions.
    final x0 = max(x, 0);
    final y0 = max(y, 0);
    final x1 = min(x + width, imgWidth);
    final y1 = min(y + height, imgHeight);

    if (x0 >= x1 || y0 >= y1) {
      return const RoiStatistics._(
        pixelCount: 0,
        min: 0,
        max: 0,
        mean: 0,
        stdDev: 0,
        median: 0,
      );
    }

    final buffer = pixels.buffer;
    final values = <double>[];
    final isMonochrome = result.isMonochrome;
    for (var row = y0; row < y1; row++) {
      for (var col = x0; col < x1; col++) {
        if (isMonochrome) {
          final idx = row * imgWidth + col;
          if (idx < buffer.length) {
            values.add(buffer[idx].toDouble());
          }
        } else {
          final idx = (row * imgWidth + col) * 3;
          if (idx + 2 < buffer.length) {
            final r = buffer[idx + 0];
            final g = buffer[idx + 1];
            final b = buffer[idx + 2];
            final lum = 0.299 * r + 0.587 * g + 0.114 * b;
            values.add(lum);
          }
        }
      }
    }

    final n = values.length;
    values.sort();
    final sum = values.fold<double>(0, (final a, final b) => a + b);
    final mean = sum / n;

    final variance =
        values.fold<double>(0, (final a, final b) => a + (b - mean) * (b - mean)) / (n - 1);

    return RoiStatistics._(
      pixelCount: n,
      min: values.first,
      max: values.last,
      mean: mean,
      stdDev: sqrt(variance),
      median:
          n.isOdd ? values[n ~/ 2] : (values[n ~/ 2 - 1] + values[n ~/ 2]) / 2,
    );
  }

  /// Creates a copy with the given fields replaced.
  DicomRoi copyWith(
          {final int? x, final int? y, final int? width, final int? height}) =>
      DicomRoi(
        x: x ?? this.x,
        y: y ?? this.y,
        width: width ?? this.width,
        height: height ?? this.height,
      );

  @override
  String toString() => 'DicomRoi(x=$x, y=$y, width=$width, height=$height)';
}
