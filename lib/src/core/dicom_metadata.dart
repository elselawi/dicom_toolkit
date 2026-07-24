import '../rust/api/core/models/dicom_metadata.dart' as generated;
import 'dicom_tag_id.dart';

/// Wraps the generated [generated.DicomMetadata] with generic tag access.
///
/// The 28 typed getters delegate to the underlying generated metadata.
/// [tag] and [allTags] provide escape-hatch access to any DICOM tag,
/// including fields not covered by the typed getters.
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
}
