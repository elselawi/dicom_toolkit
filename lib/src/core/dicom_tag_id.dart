/// An immutable identifier for a DICOM data element (group, element).
///
/// Used with [DicomMetadata.tag] for generic tag lookup beyond the 32
/// typed getters.
///
/// ```dart
/// final tag = DicomTagId.fromHex('00100010');        // PatientName
/// final tag = DicomTagId.fromParts(0x0020, 0x0032);  // ImagePositionPatient
/// ```
class DicomTagId {
  /// Creates a [DicomTagId] from an 8-character hex string (e.g. "00100010").
  /// This constructor cannot be used in const contexts; use [fromParts] for
  /// compile-time constants.
  DicomTagId.fromHex(final String hex)
      : group = int.parse(hex.substring(0, 4), radix: 16),
        element = int.parse(hex.substring(4, 8), radix: 16);

  /// Creates a [DicomTagId] from separate group and element values.
  /// This is the const-safe constructor.
  const DicomTagId.fromParts(this.group, this.element);

  /// The DICOM group number (high 4 hex digits).
  final int group;

  /// The DICOM element number (low 4 hex digits).
  final int element;

  /// The canonical 8-character hex representation, e.g. "00100010".
  String get hex {
    final g = group.toRadixString(16).padLeft(4, '0');
    final e = element.toRadixString(16).padLeft(4, '0');
    return '$g$e';
  }

  @override
  bool operator ==(final Object other) =>
      other is DicomTagId && other.group == group && other.element == element;

  @override
  int get hashCode => group.hashCode ^ element.hashCode;

  @override
  String toString() => 'DicomTagId($hex)';

  // ── Predefined constants (34 common DICOM tags) ──

  // Patient & Study
  /// Patient's Name (0010,0010).
  static const patientName = DicomTagId.fromParts(0x0010, 0x0010);

  /// Patient ID (0010,0020).
  static const patientId = DicomTagId.fromParts(0x0010, 0x0020);

  /// Study Date (0008,0020).
  static const studyDate = DicomTagId.fromParts(0x0008, 0x0020);

  /// Series Date (0008,0021).
  static const seriesDate = DicomTagId.fromParts(0x0008, 0x0021);

  /// Acquisition Date (0008,0022).
  static const acquisitionDate = DicomTagId.fromParts(0x0008, 0x0022);

  /// Content Date (0008,0023).
  static const contentDate = DicomTagId.fromParts(0x0008, 0x0023);

  /// Study Description (0008,1030).
  static const studyDescription = DicomTagId.fromParts(0x0008, 0x1030);

  // Equipment
  /// Modality (0008,0060).
  static const modality = DicomTagId.fromParts(0x0008, 0x0060);

  /// Manufacturer (0008,0070).
  static const manufacturer = DicomTagId.fromParts(0x0008, 0x0070);

  /// Manufacturer Model Name (0008,1090).
  static const manufacturerModelName = DicomTagId.fromParts(0x0008, 0x1090);

  /// Institution Name (0008,0080).
  static const institutionName = DicomTagId.fromParts(0x0008, 0x0080);

  // UIDs
  /// Study Instance UID (0020,000D).
  static const studyInstanceUid = DicomTagId.fromParts(0x0020, 0x000D);

  /// Series Instance UID (0020,000E).
  static const seriesInstanceUid = DicomTagId.fromParts(0x0020, 0x000E);

  /// SOP Instance UID (0008,0018).
  static const sopInstanceUid = DicomTagId.fromParts(0x0008, 0x0018);

  // Acquisition
  /// Series Description (0008,103E).
  static const seriesDescription = DicomTagId.fromParts(0x0008, 0x103E);

  /// Body Part Examined (0018,0015).
  static const bodyPartExamined = DicomTagId.fromParts(0x0018, 0x0015);

  // Dental
  /// Tooth Number (0018,6032) — ISO 3950 FDI notation.
  static const toothNumber = DicomTagId.fromParts(0x0018, 0x6032);

  /// Tooth Region (0018,6033).
  static const toothRegion = DicomTagId.fromParts(0x0018, 0x6033);

  /// Slice Thickness (0018,0050).
  static const sliceThickness = DicomTagId.fromParts(0x0018, 0x0050);

  /// Instance Number (0020,0013).
  static const instanceNumber = DicomTagId.fromParts(0x0020, 0x0013);

  // Image
  /// Columns / width (0028,0011).
  static const width = DicomTagId.fromParts(0x0028, 0x0011);

  /// Rows / height (0028,0010).
  static const height = DicomTagId.fromParts(0x0028, 0x0010);

  /// Samples per Pixel (0028,0002).
  static const samplesPerPixel = DicomTagId.fromParts(0x0028, 0x0002);

  /// Bits Allocated (0028,0100).
  static const bitsAllocated = DicomTagId.fromParts(0x0028, 0x0100);

  /// Bits Stored (0028,0101).
  static const bitsStored = DicomTagId.fromParts(0x0028, 0x0101);

  /// High Bit (0028,0102).
  static const highBit = DicomTagId.fromParts(0x0028, 0x0102);

  /// Pixel Representation (0028,0103).
  static const pixelRepresentation = DicomTagId.fromParts(0x0028, 0x0103);

  /// Photometric Interpretation (0028,0004).
  static const photometricInterpretation = DicomTagId.fromParts(0x0028, 0x0004);

  /// Pixel Spacing (0028,0030).
  static const pixelSpacing = DicomTagId.fromParts(0x0028, 0x0030);

  /// Imager Pixel Spacing (0018,1164) — alternative to Pixel Spacing,
  /// commonly found in CR/DX (computed/digital radiography) X-ray files.
  static const imagerPixelSpacing = DicomTagId.fromParts(0x0018, 0x1164);

  // Spatial Positioning (multi-slice / CBCT)
  /// Image Position Patient (0020,0032) — x, y, z coordinates of the
  /// top-left pixel in mm.
  static const imagePositionPatient = DicomTagId.fromParts(0x0020, 0x0032);

  /// Slice Location (0020,1041) — relative position of the slice in mm.
  static const sliceLocation = DicomTagId.fromParts(0x0020, 0x1041);

  /// Spacing Between Slices (0018,0088) — center-to-center distance
  /// between adjacent slices in mm.
  static const spacingBetweenSlices = DicomTagId.fromParts(0x0018, 0x0088);

  // Windowing
  /// Window Center (0028,1050).
  static const windowCenter = DicomTagId.fromParts(0x0028, 0x1050);

  /// Window Width (0028,1051).
  static const windowWidth = DicomTagId.fromParts(0x0028, 0x1051);

  /// Rescale Intercept (0028,1052).
  static const rescaleIntercept = DicomTagId.fromParts(0x0028, 0x1052);

  /// Rescale Slope (0028,1053).
  static const rescaleSlope = DicomTagId.fromParts(0x0028, 0x1053);
}
