use crate::api::core::{
    config::dicom_config::DicomConfig,
    models::{dicom_frame_result::DicomFrameResult, dicom_metadata::DicomMetadata},
};
use anyhow::{Context, Result};
use dicom::core::Tag;
use dicom::dictionary_std::tags;
use dicom::object::{open_file, DefaultDicomObject};
use dicom_pixeldata::PixelDecoder;

/// Internal utility function for parsing a DICOM file and extracting its metadata and pixels.
///
/// This function uses the `dicom-rs` ecosystem to handle the complex structure of DICOM objects.
///
/// # Implementation Details:
/// - **Metadata Extraction**: Uses clean helper functions to extract all critical tags with
///   sensible fallback defaults for missing or malformed headers.
/// - **Resilience**: Provides sane defaults for missing tags often encountered in non-standard DICOM files.
/// - **Pixel Extraction**: Attempts direct byte-chunking first (fast path for uncompressed data),
///   falling back to the `dicom` crate's transfer-syntax-aware decoding for compressed formats.
///
/// # Returns
/// - `Ok(DicomFrameResult)` on successful processing.
/// - `Err` if the file could not be opened or is missing critical metadata.
pub fn process_dicom_file(path: &str, config: &DicomConfig) -> Result<DicomFrameResult> {
    let obj = open_file(path).context("Failed to open DICOM file")?;
    process_dicom_object(obj, config)
}

pub fn process_dicom_from_bytes(bytes: &[u8], config: &DicomConfig) -> Result<DicomFrameResult> {
    let cursor = std::io::Cursor::new(bytes);
    let obj = dicom::object::from_reader(cursor).context("Failed to read DICOM from bytes")?;
    process_dicom_object(obj, config)
}

fn process_dicom_object(obj: DefaultDicomObject, config: &DicomConfig) -> Result<DicomFrameResult> {
    let default_meta = DicomMetadata::default();

    // --- Mandatory Dimensions ---
    let width = obj.element(tags::COLUMNS)?.to_int::<u32>()?;
    let height = obj.element(tags::ROWS)?.to_int::<u32>()?;

    // --- Patient & Study Demographics ---
    let patient_id =
        get_str_tag(&obj, tags::PATIENT_ID).unwrap_or_else(|| default_meta.patient_id.clone());
    let patient_name =
        get_str_tag(&obj, tags::PATIENT_NAME).unwrap_or_else(|| default_meta.patient_name.clone());
    let study_date =
        get_str_tag(&obj, tags::STUDY_DATE).unwrap_or_else(|| default_meta.study_date.clone());
    let series_date =
        get_str_tag(&obj, tags::SERIES_DATE).unwrap_or_else(|| default_meta.series_date.clone());
    let acquisition_date = get_str_tag(&obj, tags::ACQUISITION_DATE)
        .unwrap_or_else(|| default_meta.acquisition_date.clone());
    let content_date =
        get_str_tag(&obj, tags::CONTENT_DATE).unwrap_or_else(|| default_meta.content_date.clone());
    let study_description = get_str_tag(&obj, tags::STUDY_DESCRIPTION)
        .unwrap_or_else(|| default_meta.study_description.clone());

    // --- Equipment & Institution ---
    let modality =
        get_str_tag(&obj, tags::MODALITY).unwrap_or_else(|| default_meta.modality.clone());
    let manufacturer =
        get_str_tag(&obj, tags::MANUFACTURER).unwrap_or_else(|| default_meta.manufacturer.clone());
    let manufacturer_model_name = get_str_tag(&obj, tags::MANUFACTURER_MODEL_NAME)
        .unwrap_or_else(|| default_meta.manufacturer_model_name.clone());
    let institution_name = get_str_tag(&obj, tags::INSTITUTION_NAME)
        .unwrap_or_else(|| default_meta.institution_name.clone());

    // --- Study / Series / Instance UIDs ---
    let study_instance_uid = get_str_tag(&obj, tags::STUDY_INSTANCE_UID)
        .unwrap_or_else(|| default_meta.study_instance_uid.clone());
    let series_instance_uid = get_str_tag(&obj, tags::SERIES_INSTANCE_UID)
        .unwrap_or_else(|| default_meta.series_instance_uid.clone());
    let sop_instance_uid = get_str_tag(&obj, tags::SOP_INSTANCE_UID)
        .unwrap_or_else(|| default_meta.sop_instance_uid.clone());

    // --- Acquisition Details ---
    let series_description = get_str_tag(&obj, tags::SERIES_DESCRIPTION)
        .unwrap_or_else(|| default_meta.series_description.clone());
    let body_part_examined = get_str_tag(&obj, tags::BODY_PART_EXAMINED)
        .unwrap_or_else(|| default_meta.body_part_examined.clone());

    // --- Tooth Identification (dental DICOM) ---
    // Tries standard tags first, then vendor-specific private tags,
    // then generic description fields that may contain tooth/location info.
    let tooth_info = get_str_tag(&obj, Tag(0x0018, 0x6032)) // Tooth Number
        .or_else(|| get_str_tag(&obj, Tag(0x0018, 0x6033))) // Tooth Region
        .or_else(|| get_str_tag(&obj, Tag(0x0021, 0x1000))) // Planmeca
        .or_else(|| get_str_tag(&obj, Tag(0x0029, 0x1010))) // Carestream
        .or_else(|| get_str_tag(&obj, Tag(0x7053, 0x1003))) // VATECH
        .or_else(|| get_str_tag(&obj, Tag(0x0021, 0x1005))) // Sirona
        .or_else(|| get_str_tag(&obj, Tag(0x0029, 0x1060))) // Dexis
        .or_else(|| get_str_tag(&obj, Tag(0x0021, 0x1030))) // KaVo
        .or_else(|| get_str_tag(&obj, tags::IMAGE_COMMENTS))
        .or_else(|| get_str_tag(&obj, tags::ACQUISITION_PROTOCOL_NAME))
        .or_else(|| get_str_tag(&obj, tags::ACQUISITION_CONTEXT_DESCRIPTION))
        .unwrap_or_default();

    let slice_thickness =
        get_float_tag(&obj, tags::SLICE_THICKNESS, default_meta.slice_thickness);
    let instance_number =
        get_str_tag(&obj, tags::INSTANCE_NUMBER).unwrap_or_else(|| default_meta.instance_number.clone());

    // --- Technical & Display Metadata ---
    let window_center_opt = obj
        .element(tags::WINDOW_CENTER)
        .ok()
        .and_then(|e| e.to_float32().ok());
    let window_width_opt = obj
        .element(tags::WINDOW_WIDTH)
        .ok()
        .and_then(|e| e.to_float32().ok());

    let mut window_center = window_center_opt.unwrap_or(0.0);
    let mut window_width = window_width_opt.unwrap_or(0.0);

    let rescale_intercept = get_float_tag(
        &obj,
        tags::RESCALE_INTERCEPT,
        default_meta.rescale_intercept,
    );
    let rescale_slope = get_float_tag(&obj, tags::RESCALE_SLOPE, default_meta.rescale_slope);

    let photometric_interpretation = get_str_tag(&obj, tags::PHOTOMETRIC_INTERPRETATION)
        .unwrap_or_else(|| default_meta.photometric_interpretation.clone());

    let samples_per_pixel = get_int_tag(
        &obj,
        tags::SAMPLES_PER_PIXEL,
        default_meta.samples_per_pixel,
    );
    let bits_allocated = get_int_tag(&obj, tags::BITS_ALLOCATED, default_meta.bits_allocated);
    let bits_stored = get_int_tag(&obj, tags::BITS_STORED, default_meta.bits_stored);
    let high_bit = get_int_tag(&obj, tags::HIGH_BIT, default_meta.high_bit);
    let pixel_representation = get_int_tag(
        &obj,
        tags::PIXEL_REPRESENTATION,
        default_meta.pixel_representation,
    );

    // --- Align DICOM window center with our offset pixel storage ---
    // DICOM Window Center/Width are defined in the original pixel value space.
    // For unsigned data, our pipeline offsets raw pixel values by -32768 to
    // fit in i16 (and the shader reverses this). The window center must be
    // offset identically so it aligns with the shader's coordinate space.
    if pixel_representation == 0 && window_width > 0.0 {
        window_center -= 32768.0;
    }

    // --- Pixel Spacing (try standard tag first, then Imager Pixel Spacing) ---
    let pixel_spacing = get_str_tag(&obj, tags::PIXEL_SPACING)
        .or_else(|| get_str_tag(&obj, tags::IMAGER_PIXEL_SPACING))
        .unwrap_or_default();

    let mut metadata = DicomMetadata::new(DicomMetadata {
        patient_id,
        patient_name,
        study_date,
        series_date,
        acquisition_date,
        content_date,
        study_description,
        modality,
        manufacturer,
        manufacturer_model_name,
        institution_name,
        study_instance_uid,
        series_instance_uid,
        sop_instance_uid,
        series_description,
        body_part_examined,
        tooth_info,
        slice_thickness,
        instance_number,
        photometric_interpretation,
        width,
        height,
        window_center,
        window_width,
        rescale_intercept,
        rescale_slope,
        samples_per_pixel,
        bits_allocated,
        bits_stored,
        high_bit,
        pixel_representation,
        pixel_spacing,
    });

    // --- Pixel Data Extraction ---
    // Uses dicom-pixeldata's PixelDecoder trait which handles ALL transfer
    // syntaxes: uncompressed, JPEG lossless/lossy, JPEG-LS, JPEG 2000, RLE, etc.
    let mut pixel_data: Vec<i16> = Vec::new();

    if !config.skip_pixels {
        if let Ok(decoded) = obj.decode_pixel_data() {
            let raw_bytes = decoded.data().to_vec();

            if !raw_bytes.is_empty() {
                if bits_allocated <= 8 {
                    if pixel_representation == 1 {
                        pixel_data = raw_bytes.iter().map(|&b| b as i8 as i16).collect();
                    } else {
                        pixel_data = raw_bytes.iter().map(|&b| b as i16).collect();
                    }
                } else if raw_bytes.len() % 2 == 0 {
                    pixel_data = if pixel_representation == 0 {
                        // Unsigned 16-bit → offset to signed range for shader
                        raw_bytes
                            .chunks_exact(2)
                            .map(|chunk| {
                                let raw = u16::from_le_bytes([chunk[0], chunk[1]]);
                                (raw as i32 - 32768) as i16
                            })
                            .collect()
                    } else {
                        raw_bytes
                            .chunks_exact(2)
                            .map(|chunk| i16::from_le_bytes([chunk[0], chunk[1]]))
                            .collect()
                    };
                }
            }
        }
    }

    // If the DICOM header did not provide window center/width, compute sensible
    // defaults from the actual pixel data range so the image is immediately visible.
    // This prevents the "all white" problem with modalities like CR/DR that lack
    // window tags while using hardcoded CT-brain defaults (C:40/W:400).
    if window_width == 0.0 && !pixel_data.is_empty() {
        if let (Some(&min), Some(&max)) = (pixel_data.iter().min(), pixel_data.iter().max()) {
            window_width = (max as f32 - min as f32).max(1.0);
            window_center = (min as f32 + max as f32) / 2.0;
        }
    }

    // Reflect the (possibly auto-computed) window in the metadata.
    metadata.window_center = window_center;
    metadata.window_width = window_width;

    Ok(DicomFrameResult::new(DicomFrameResult {
        metadata,
        pixel_data,
    }))
}

// --- Helper Functions ---

/// Extracts a string value from a DICOM tag, trimming whitespace.
/// Returns `None` if the tag is missing or cannot be read as a string.
fn get_str_tag(obj: &DefaultDicomObject, tag: Tag) -> Option<String> {
    obj.element(tag)
        .ok()
        .and_then(|e| e.to_str().ok().map(|s| s.trim().to_string()))
}

/// Extracts a float value from a DICOM tag, falling back to the provided default.
fn get_float_tag(obj: &DefaultDicomObject, tag: Tag, default: f32) -> f32 {
    obj.element(tag)
        .ok()
        .and_then(|e| e.to_float32().ok())
        .unwrap_or(default)
}

/// Extracts an integer value from a DICOM tag, falling back to the provided default.
/// Generic over the integer type — works for `u16`, `u32`, etc.
fn get_int_tag<T>(obj: &DefaultDicomObject, tag: Tag, default: T) -> T
where
    T: TryFrom<i64> + Copy,
{
    obj.element(tag)
        .ok()
        .and_then(|e| e.to_int::<i64>().ok())
        .and_then(|v| T::try_from(v).ok())
        .unwrap_or(default)
}
