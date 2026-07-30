import '../rust/api/core/models/dicom_metadata.dart' as generated;
import 'dicom_tag_id.dart';

/// Wraps the generated [generated.DicomMetadata] with generic tag access.
///
/// The 37 typed getters delegate to the underlying generated metadata.
/// [tag] and [allTags] provide escape-hatch access to any DICOM tag,
/// including fields not covered by the typed getters.
///
/// [bestDate] resolves the most recent valid date among the four
/// DICOM date tags (Study, Series, Acquisition, Content).
class DicomMetadata {
  /// Creates from the generated metadata with an optional tag map.
  factory DicomMetadata({
    required final generated.DicomMetadata inner,
    final Map<DicomTagId, String>? tags,
  }) {
    return DicomMetadata._(inner, tags ?? {});
  }
  DicomMetadata._(this._inner, this._tags);

  final generated.DicomMetadata _inner;
  final Map<DicomTagId, String> _tags;

  // ── Generic tag access ──

  /// Returns the string value for [id], or null if not present.
  String? tag(final DicomTagId id) => _tags[id];

  /// All extracted tags as a map.
  Map<DicomTagId, String> get allTags => Map.unmodifiable(_tags);

  // ── Typed getters ──

  /// The hospital-assigned patient identifier (MRN). Tag (0010,0020).
  String get patientId => _inner.patientId;

  /// The patient's full name. Tag (0010,0010).
  String get patientName => _inner.patientName;

  /// Study date in DICOM format (YYYYMMDD). Tag (0008,0020).
  String get studyDate => _inner.studyDate;

  /// Series date in DICOM format (YYYYMMDD). Tag (0008,0021).
  String get seriesDate => _inner.seriesDate;

  /// Acquisition date in DICOM format (YYYYMMDD). Tag (0008,0022).
  String get acquisitionDate => _inner.acquisitionDate;

  /// Content date in DICOM format (YYYYMMDD). Tag (0008,0023).
  String get contentDate => _inner.contentDate;

  /// Description of the study. Tag (0008,1030).
  String get studyDescription => _inner.studyDescription;

  /// Imaging modality (CT, MR, US, XA, etc.). Tag (0008,0060).
  String get modality => _inner.modality;

  /// Equipment manufacturer. Tag (0008,0070).
  String get manufacturer => _inner.manufacturer;

  /// Manufacturer's model name. Tag (0008,1090).
  String get manufacturerModelName => _inner.manufacturerModelName;

  /// Institution where the study was performed. Tag (0008,0080).
  String get institutionName => _inner.institutionName;

  /// Unique identifier for the study. Tag (0020,000D).
  String get studyInstanceUid => _inner.studyInstanceUid;

  /// Unique identifier for the series. Tag (0020,000E).
  String get seriesInstanceUid => _inner.seriesInstanceUid;

  /// Unique identifier for this SOP instance. Tag (0008,0018).
  String get sopInstanceUid => _inner.sopInstanceUid;

  /// Description of the series. Tag (0008,103E).
  String get seriesDescription => _inner.seriesDescription;

  /// Body part examined. Tag (0018,0015).
  String get bodyPartExamined => _inner.bodyPartExamined;

  /// Tooth identification string. Tries standard Tooth Number (0018,6032),
  /// Tooth Region (0018,6033), then vendor private tags (Planmeca,
  /// Carestream, VATECH, Sirona, Dexis, KaVo). Returns `"Unknown"` if
  /// no tooth tag is present.
  String get toothInfo => _inner.toothInfo;

  /// Slice thickness in mm. Tag (0018,0050).
  double get sliceThickness => _inner.sliceThickness;

  /// Instance number within the series. Tag (0020,0013).
  String get instanceNumber => _inner.instanceNumber;

  /// Photometric interpretation (MONOCHROME1, MONOCHROME2, RGB). Tag (0028,0004).
  String get photometricInterpretation => _inner.photometricInterpretation;

  /// Number of pixel columns. Tag (0028,0011).
  int get width => _inner.width;

  /// Number of pixel rows. Tag (0028,0010).
  int get height => _inner.height;

  /// Default window center (level) from the DICOM header. Tag (0028,1050).
  double get windowCenter => _inner.windowCenter;

  /// Default window width from the DICOM header. Tag (0028,1051).
  double get windowWidth => _inner.windowWidth;

  /// Rescale intercept for Hounsfield / modality transform. Tag (0028,1052).
  double get rescaleIntercept => _inner.rescaleIntercept;

  /// Rescale slope for Hounsfield / modality transform. Tag (0028,1053).
  double get rescaleSlope => _inner.rescaleSlope;

  /// Number of colour components (1 = monochrome, 3 = RGB). Tag (0028,0002).
  int get samplesPerPixel => _inner.samplesPerPixel;

  /// Bits allocated per pixel. Tag (0028,0100).
  int get bitsAllocated => _inner.bitsAllocated;

  /// Bits actually used for pixel data. Tag (0028,0101).
  int get bitsStored => _inner.bitsStored;

  /// Most significant bit of pixel data. Tag (0028,0102).
  int get highBit => _inner.highBit;

  /// Pixel representation (0 = unsigned, 1 = signed). Tag (0028,0103).
  int get pixelRepresentation => _inner.pixelRepresentation;

  /// Pixel spacing in mm, e.g. "0.5\\0.5" (row\\column).
  /// Checks Pixel Spacing (0028,0030) first, then Imager Pixel Spacing
  /// (0018,1164) — the latter is common in CR/DX X-ray files.
  /// Returns the raw generated value if present, otherwise falls back to
  /// the tag map.
  String? get pixelSpacing {
    final generated = _inner.pixelSpacing;
    if (generated.isNotEmpty) return generated;
    return _tags[DicomTagId.pixelSpacing] ??
        _tags[DicomTagId.imagerPixelSpacing];
  }

  /// Parsed pixel spacing X (column) in mm, from [pixelSpacing].
  /// Returns `null` if [pixelSpacing] is absent or unparseable.
  double? get pixelSpacingX => _parseSpacingComponent(pixelSpacing, 0);

  /// Parsed pixel spacing Y (row) in mm, from [pixelSpacing].
  /// Returns `null` if [pixelSpacing] is absent or unparseable.
  double? get pixelSpacingY => _parseSpacingComponent(pixelSpacing, 1);

  /// Instance number as an integer, parsed from [instanceNumber].
  /// Returns `null` if unparseable.
  int? get instanceNumberInt => int.tryParse(instanceNumber);

  // ── Spatial positioning (multi-slice / CBCT volumes) ──

  /// The x, y, z coordinates of the top-left pixel in mm.
  /// DICOM format: "x\\y\\z". Tag (0020,0032).
  String get imagePositionPatient => _inner.imagePositionPatient;

  /// Parsed X coordinate from [imagePositionPatient], or `null`.
  double? get imagePositionX => _parseSpacingComponent(imagePositionPatient, 0);

  /// Parsed Y coordinate from [imagePositionPatient], or `null`.
  double? get imagePositionY => _parseSpacingComponent(imagePositionPatient, 1);

  /// Parsed Z coordinate from [imagePositionPatient], or `null`.
  double? get imagePositionZ => _parseSpacingComponent(imagePositionPatient, 2);

  /// Direction cosines of the first row and first column of the image.
  /// DICOM format: "x1\\y1\\z1\\x2\\y2\\z2". Tag (0020,0037).
  String get imageOrientationPatient => _inner.imageOrientationPatient;

  /// Relative position of the slice in mm. Tag (0020,1041).
  double get sliceLocation => _inner.sliceLocation;

  /// Center-to-center spacing between adjacent slices in mm.
  /// Tag (0018,0088).
  double get spacingBetweenSlices => _inner.spacingBetweenSlices;

  /// Number of frames in a multi-frame image. Tag (0028,0008).
  /// 1 = single-frame; >1 = cine / multi-frame secondary capture / volumetric.
  int get numberOfFrames => _inner.numberOfFrames;

  /// Parses a DICOM backslash-separated string (e.g. "0.5\\0.5\\1.0")
  /// and returns the component at [index], or `null`.
  static double? _parseSpacingComponent(final String? raw, final int index) {
    if (raw == null || raw.isEmpty) return null;
    final parts = raw.split('\\');
    if (index >= parts.length) return null;
    return double.tryParse(parts[index]);
  }

  // ── Date resolution ──

  /// Returns the most recent valid date among the four DICOM date tags:
  /// [studyDate] (0008,0020), [seriesDate] (0008,0021),
  /// [acquisitionDate] (0008,0022), and [contentDate] (0008,0023).
  ///
  /// Dates are parsed from DICOM YYYYMMDD format. Values of "Unknown",
  /// malformed strings, and dates in the future are excluded. If multiple
  /// dates are valid, the most recent one is returned.
  ///
  /// Returns `null` if none of the four dates are valid and not in the future.
  DateTime? get bestDate {
    final candidates = <DateTime>[];

    for (final raw in [studyDate, seriesDate, acquisitionDate, contentDate]) {
      final parsed = _tryParseDicomDate(raw);
      if (parsed != null && !parsed.isAfter(DateTime.now())) {
        candidates.add(parsed);
      }
    }

    if (candidates.isEmpty) return null;
    candidates.sort();
    return candidates.last;
  }

  /// Attempts to parse a DICOM date string (YYYYMMDD) into a [DateTime].
  ///
  /// Handles DICOM date ranges (e.g. "20240101-20240105") by taking the
  /// earliest date. Returns `null` for "Unknown", empty strings, or
  /// malformed values.
  static DateTime? _tryParseDicomDate(final String raw) {
    if (raw.isEmpty || raw == 'Unknown') return null;

    // Handle DICOM date range: take the first date before the dash
    final datePart = raw.split('-').first;
    if (datePart.length != 8) return null;

    final y = int.tryParse(datePart.substring(0, 4));
    final m = int.tryParse(datePart.substring(4, 6));
    final d = int.tryParse(datePart.substring(6, 8));

    if (y == null || m == null || d == null) return null;
    if (m < 1 || m > 12 || d < 1 || d > 31) return null;

    // Validate the day against the actual month (DateTime.utc normalizes
    // out-of-range days, e.g. Feb 30 → Mar 1, so we must check explicitly).
    final daysInMonth = _daysInMonth(y, m);
    if (d > daysInMonth) return null;

    return DateTime.utc(y, m, d);
  }

  /// Returns the number of days in the given month, accounting for leap years.
  static int _daysInMonth(final int year, final int month) {
    const days = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    if (month == 2 && _isLeapYear(year)) return 29;
    return days[month - 1];
  }

  /// Returns `true` if [year] is a leap year.
  static bool _isLeapYear(final int year) =>
      (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0);
}
