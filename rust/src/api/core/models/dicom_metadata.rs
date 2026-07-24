/// Represents the extracted medical metadata from a DICOM file header.
///
/// This struct contains critical parameters for clinical rendering,
/// including spatial dimensions, windowing defaults, and patient identity.
#[derive(Debug, Clone)]
pub struct DicomMetadata {
    // -- Patient & Study Demographics --
    /// The hospital-assigned patient identifier (e.g., MRN). Tag (0010,0020).
    pub patient_id: String,
    /// The name of the patient as recorded in the file header. Tag (0010,0010).
    pub patient_name: String,
    /// The date the study was performed, in DICOM format (YYYYMMDD). Tag (0008,0020).
    pub study_date: String,
    /// A description of the study (e.g., "R/O pneumonia"). Tag (0008,1030).
    pub study_description: String,

    // -- Equipment & Institution --
    /// The imaging modality (e.g., "CT", "MR", "US", "XA"). Tag (0008,0060).
    pub modality: String,
    /// The manufacturer of the imaging device (e.g., "SIEMENS"). Tag (0008,0070).
    pub manufacturer: String,
    /// The manufacturer's model name (e.g., "SOMATOM Force"). Tag (0008,1090).
    pub manufacturer_model_name: String,
    /// The institution where the study was performed. Tag (0008,0080).
    pub institution_name: String,

    // -- Study / Series / Instance UIDs --
    /// Globally unique identifier for the study. Tag (0020,000D).
    pub study_instance_uid: String,
    /// Globally unique identifier for the series within the study. Tag (0020,000E).
    pub series_instance_uid: String,
    /// Globally unique identifier for this specific SOP Instance. Tag (0008,0018).
    pub sop_instance_uid: String,

    // -- Acquisition Details --
    /// A description of the series (e.g., "Axial T2 FLAIR"). Tag (0008,103E).
    pub series_description: String,
    /// The body part examined (e.g., "CHEST", "ABDOMEN"). Tag (0018,0015).
    pub body_part_examined: String,
    /// The slice thickness in mm. Tag (0018,0050).
    pub slice_thickness: f32,
    /// The instance (frame) number within the series. Tag (0020,0013).
    pub instance_number: String,

    // -- Image Characteristics --
    /// The Photometric Interpretation (e.g., "MONOCHROME1", "MONOCHROME2").
    /// Informs the renderer how to map pixel values to grayscale intensities.
    pub photometric_interpretation: String,

    /// The number of pixel columns in the image.
    pub width: u32,
    /// The number of pixel rows in the image.
    pub height: u32,

    /// The default Window Center (Level) provided in the DICOM metadata.
    pub window_center: f32,
    /// The default Window Width provided in the DICOM metadata.
    pub window_width: f32,

    /// The Rescale Intercept (Tag 0028,1052).
    pub rescale_intercept: f32,
    /// The Rescale Slope (Tag 0028,1053).
    pub rescale_slope: f32,

    /// The number of color components in this image (e.g., 1 for Grayscale).
    pub samples_per_pixel: u16,

    /// The number of bits allocated per pixel (typically 16).
    pub bits_allocated: u16,
    /// The number of bits actually used to store the pixel data (typically 12 or 16).
    pub bits_stored: u16,
    /// The most significant bit of the pixel data (typically bits_stored - 1).
    pub high_bit: u16,

    /// Specifies whether the pixel data is signed (1) or unsigned (0).
    pub pixel_representation: u16,
}

impl DicomMetadata {
    /// Creates a new [DicomMetadata] instance by copying values from another.
    /// Useful for ensuring a clean ownership transfer when constructing results.
    pub fn new(data: DicomMetadata) -> Self {
        return Self {
            patient_id: data.patient_id,
            patient_name: data.patient_name,
            study_date: data.study_date,
            study_description: data.study_description,
            modality: data.modality,
            manufacturer: data.manufacturer,
            manufacturer_model_name: data.manufacturer_model_name,
            institution_name: data.institution_name,
            study_instance_uid: data.study_instance_uid,
            series_instance_uid: data.series_instance_uid,
            sop_instance_uid: data.sop_instance_uid,
            series_description: data.series_description,
            body_part_examined: data.body_part_examined,
            slice_thickness: data.slice_thickness,
            instance_number: data.instance_number,
            photometric_interpretation: data.photometric_interpretation,
            width: data.width,
            height: data.height,
            window_center: data.window_center,
            window_width: data.window_width,
            rescale_intercept: data.rescale_intercept,
            rescale_slope: data.rescale_slope,
            samples_per_pixel: data.samples_per_pixel,
            bits_allocated: data.bits_allocated,
            bits_stored: data.bits_stored,
            high_bit: data.high_bit,
            pixel_representation: data.pixel_representation,
        };
    }
}
impl Default for DicomMetadata {
    /// Provides sensible default values for DICOM metadata.
    /// These defaults are used when specific tags are missing from the file header.
    fn default() -> Self {
        return Self {
            patient_id: "Unknown".to_string(),
            patient_name: "Unknown".to_string(),
            study_date: "Unknown".to_string(),
            study_description: "Unknown".to_string(),
            modality: "Unknown".to_string(),
            manufacturer: "Unknown".to_string(),
            manufacturer_model_name: "Unknown".to_string(),
            institution_name: "Unknown".to_string(),
            study_instance_uid: "Unknown".to_string(),
            series_instance_uid: "Unknown".to_string(),
            sop_instance_uid: "Unknown".to_string(),
            series_description: "Unknown".to_string(),
            body_part_examined: "Unknown".to_string(),
            slice_thickness: 0.0,
            instance_number: "0".to_string(),
            photometric_interpretation: "MONOCHROME2".to_string(),
            width: 0,
            height: 0,
            window_center: 40.0,
            window_width: 400.0,
            rescale_intercept: 0.0,
            rescale_slope: 1.0,
            samples_per_pixel: 1,
            bits_allocated: 16,
            bits_stored: 16,
            high_bit: 15,
            pixel_representation: 0,
        };
    }
}
