import 'dart:math';
import 'dart:ui' as ui;
import 'dart:typed_data';

/// An axis-aligned rectangular region of interest on the DICOM image.
class DicomRoi {
  const DicomRoi(
      {required this.left,
      required this.top,
      required this.width,
      required this.height});

  final double left;
  final double top;
  final double width;
  final double height;

  double get right => left + width;
  double get bottom => top + height;

  /// Returns the mean HU value within this ROI, given the raw pixel data and rescale parameters.
  static double meanHu({
    required DicomRoi roi,
    required Int16List pixelData,
    required int imageWidth,
    required int imageHeight,
    required double rescaleSlope,
    required double rescaleIntercept,
  }) {
    final stats = _computeStats(roi, pixelData, imageWidth, imageHeight,
        rescaleSlope, rescaleIntercept);
    return stats.mean;
  }

  /// Returns comprehensive statistics for the ROI: min, max, mean, stddev in HU.
  static RoiStatistics statistics({
    required DicomRoi roi,
    required Int16List pixelData,
    required int imageWidth,
    required int imageHeight,
    required double rescaleSlope,
    required double rescaleIntercept,
  }) {
    return _computeStats(roi, pixelData, imageWidth, imageHeight, rescaleSlope,
        rescaleIntercept);
  }

  static RoiStatistics _computeStats(
    DicomRoi roi,
    Int16List data,
    int imgW,
    int imgH,
    double slope,
    double intercept,
  ) {
    final x0 = roi.left.round().clamp(0, imgW - 1);
    final y0 = roi.top.round().clamp(0, imgH - 1);
    final x1 = roi.right.round().clamp(0, imgW - 1);
    final y1 = roi.bottom.round().clamp(0, imgH - 1);

    final values = <double>[];
    for (var y = y0; y <= y1; y++) {
      for (var x = x0; x <= x1; x++) {
        final raw = data[y * imgW + x];
        values.add(raw * slope + intercept);
      }
    }

    if (values.isEmpty)
      return const RoiStatistics(min: 0, max: 0, mean: 0, stddev: 0, count: 0);

    final count = values.length;
    final mean = values.reduce((a, b) => a + b) / count;
    final minVal = values.reduce(min);
    final maxVal = values.reduce(max);
    final variance =
        values.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b) /
            count;

    return RoiStatistics(
      min: minVal,
      max: maxVal,
      mean: mean,
      stddev: sqrt(variance),
      count: count,
    );
  }
}

/// Statistics for a region of interest.
class RoiStatistics {
  const RoiStatistics({
    required this.min,
    required this.max,
    required this.mean,
    required this.stddev,
    required this.count,
  });

  final double min;
  final double max;
  final double mean;
  final double stddev;
  final int count;

  @override
  String toString() => 'Mean: ${mean.toStringAsFixed(1)} HU, '
      'SD: ${stddev.toStringAsFixed(1)}, '
      'Min: ${min.toStringAsFixed(0)} Max: ${max.toStringAsFixed(0)}';
}

/// A 2D measurement between two points on the image.
class DicomMeasurement {
  const DicomMeasurement({required this.start, required this.end});

  final Offset start;
  final Offset end;
}

/// A 2D offset (dx, dy) in image pixel space.
class Offset {
  const Offset(this.dx, this.dy);

  final double dx;
  final double dy;

  /// Euclidean distance between two offsets in pixels.
  double distanceTo(Offset other) {
    return sqrt(
        (dx - other.dx) * (dx - other.dx) + (dy - other.dy) * (dy - other.dy));
  }

  @override
  String toString() => '(${dx.toStringAsFixed(1)}, ${dy.toStringAsFixed(1)})';
}
