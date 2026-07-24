use crate::api::core::{
    config::dicom_config::DicomConfig,
    models::{dicom_frame_result::DicomFrameResult, dicom_metadata::DicomMetadata},
};
use anyhow::{Context, Result};
use dicom::core::Tag;
use dicom::dictionary_std::tags;
use dicom::object::{open_file, DefaultDicomObject};

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
    let slice_thickness =
        get_float_tag(&obj, tags::SLICE_THICKNESS, default_meta.slice_thickness);
    let instance_number =
        get_str_tag(&obj, tags::INSTANCE_NUMBER).unwrap_or_else(|| default_meta.instance_number.clone());

    // --- Technical & Display Metadata ---
    let window_center = get_float_tag(&obj, tags::WINDOW_CENTER, default_meta.window_center);
    let window_width = get_float_tag(&obj, tags::WINDOW_WIDTH, default_meta.window_width);
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

    let metadata = DicomMetadata::new(DicomMetadata {
        patient_id,
        patient_name,
        study_date,
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
    });

    // --- Pixel Data Extraction ---
    let mut pixel_data: Vec<i16> = Vec::new();

    if !config.skip_pixels {
        if let Ok(element) = obj.element(tags::PIXEL_DATA) {
            let raw_bytes = element
                .to_bytes()
                .context("Failed to get raw pixel bytes")?;

            if !raw_bytes.is_empty() {
                if bits_allocated <= 8 {
                    // 8-bit pixel data (e.g., ultrasound, secondary captures)
                    // Preserve sign for pixel_representation=1 (signed)
                    if pixel_representation == 1 {
                        pixel_data = raw_bytes.iter().map(|&b| b as i8 as i16).collect();
                    } else {
                        pixel_data = raw_bytes.iter().map(|&b| b as i16).collect();
                    }
                } else {
                    // 16-bit pixel data — fast path: direct byte-chunking
                    if raw_bytes.len() % 2 == 0 {
                        pixel_data = if pixel_representation == 0 {
                            // Unsigned 16-bit (0..65535) → offset to signed range (-32768..32767)
                            // so the Dart +32768 offset and shader -32768 offset correctly
                            // reconstruct the original unsigned value.
                            raw_bytes
                                .chunks_exact(2)
                                .map(|chunk| {
                                    let raw = u16::from_le_bytes([chunk[0], chunk[1]]);
                                    (raw as i32 - 32768) as i16
                                })
                                .collect()
                        } else {
                            // Signed 16-bit (-32768..32767) — native byte representation
                            raw_bytes
                                .chunks_exact(2)
                                .map(|chunk| i16::from_le_bytes([chunk[0], chunk[1]]))
                                .collect()
                        };
                    }

                    // If direct chunking produced no data (unlikely but defensive),
                    // fall back to the dicom crate's transfer-syntax-aware decoding.
                    if pixel_data.is_empty() || pixel_data.len() != (width * height) as usize {
                        pixel_data = element
                            .to_multi_float64()
                            .map(|v| v.into_iter().map(|f| f as i16).collect())
                            .unwrap_or_else(|_| element.to_multi_int::<i16>().unwrap_or_default());

                        // Final fallback: if still empty after dicom crate decoding,
                        // retry raw bytes with pixel-representation-aware conversion
                        if pixel_data.is_empty() && !raw_bytes.is_empty() {
                            pixel_data = if pixel_representation == 0 {
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
        }
    }

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
