use crate::api::core::{
    config::dicom_config::DicomConfig,
    models::{dicom_frame_result::DicomFrameResult, dicom_metadata::DicomMetadata},
};
use anyhow::{Context, Result};
use dicom::core::Tag;
use dicom::dictionary_std::tags;
use dicom::object::{open_file, DefaultDicomObject};
use dicom::core::value::Value as DicomValue;
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
    #[cfg(debug_assertions)]
    eprintln!("[RUST] process_dicom_from_bytes ENTRY: bytes.len={}", bytes.len());
    let cursor = std::io::Cursor::new(bytes);
    let obj = dicom::object::from_reader(cursor).context("Failed to read DICOM from bytes")?;
    #[cfg(debug_assertions)]
    eprintln!("[RUST] process_dicom_from_bytes: from_reader OK");
    process_dicom_object(obj, config)
}

fn process_dicom_object(obj: DefaultDicomObject, config: &DicomConfig) -> Result<DicomFrameResult> {
    #[cfg(debug_assertions)]
    eprintln!("[RUST] process_dicom_object START, skip_pixels={}", config.skip_pixels);
    let default_meta = DicomMetadata::default();

    // --- Mandatory Dimensions ---
    let width = obj.element(tags::COLUMNS)?.to_int::<u32>()?;
    let height = obj.element(tags::ROWS)?.to_int::<u32>()?;
    #[cfg(debug_assertions)]
    eprintln!("[RUST] dimensions: {}x{}", width, height);

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

    // --- Spatial Positioning (multi-slice / CBCT) ---
    let image_position_patient = get_str_tag(&obj, tags::IMAGE_POSITION_PATIENT)
        .unwrap_or_default();
    let image_orientation_patient = get_str_tag(&obj, tags::IMAGE_ORIENTATION_PATIENT)
        .unwrap_or_default();
    let slice_location = get_float_tag(&obj, tags::SLICE_LOCATION, 0.0);
    let spacing_between_slices =
        get_float_tag(&obj, tags::SPACING_BETWEEN_SLICES, 0.0);
    let number_of_frames =
        get_int_tag(&obj, tags::NUMBER_OF_FRAMES, 1u32);

    #[cfg(debug_assertions)]
    eprintln!("[RUST] all metadata extracted, building struct...");
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
        image_position_patient,
        image_orientation_patient,
        slice_location,
        spacing_between_slices,
        number_of_frames,
    });

    #[cfg(debug_assertions)]
    eprintln!("[RUST] metadata built, starting pixel extraction...");

    // --- Pixel Data Extraction ---
    //
    // Two-path strategy to avoid WASM OOM on large multi-frame DICOMs:
    //
    //   PATH 1 (fast): Read the raw PixelData element bytes directly.
    //     Works for all uncompressed/native transfer syntaxes — the bytes
    //     are the literal pixel values.  We slice to the first frame only.
    //
    //   PATH 2 (fallback): Use dicom-pixeldata's decoder.  Needed for
    //     compressed transfer syntaxes (JPEG, JPEG-LS, JPEG 2000, RLE).
    //     This decodes ALL frames and may panic in WASM on huge files.
    //
    let mut pixel_data: Vec<i16> = Vec::new();

    if !config.skip_pixels {
        let bytes_per_sample = (bits_allocated as usize).div_ceil(8);
        let samples_per_frame =
            (width as usize) * (height as usize) * (samples_per_pixel as usize);
        let frame_bytes = samples_per_frame * bytes_per_sample;

        // Try PATH 1: raw element read (works for native/uncompressed data).
        #[cfg(debug_assertions)]
        eprintln!("[RUST] bytes_per_sample={} samples_per_frame={} frame_bytes={}",
            bytes_per_sample, samples_per_frame, frame_bytes);
        let raw_element = obj.element(tags::PIXEL_DATA).ok();
        let is_encapsulated = raw_element
            .as_ref()
            .map(|e| matches!(e.value(), DicomValue::PixelSequence(_)))
            .unwrap_or(false);

        if !is_encapsulated {
            // ── PATH 1: uncompressed — read raw bytes, slice first frame ──
            if let Some(ref elem) = raw_element {
                if let Ok(raw_bytes) = elem.to_bytes() {
                    let raw_slice = raw_bytes.as_ref();
                    #[cfg(debug_assertions)]
                    eprintln!("[RUST] PATH1 uncompressed: raw_bytes={} frame_bytes={} n_frames={}",
                        raw_slice.len(), frame_bytes, number_of_frames);
                    if !raw_slice.is_empty() && frame_bytes > 0 {
                        let first_frame = if raw_slice.len() > frame_bytes {
                            #[cfg(debug_assertions)]
                            eprintln!("[RUST] PATH1 slicing first {frame_bytes} of {} bytes",
                                raw_slice.len());
                            &raw_slice[..frame_bytes]
                        } else {
                            raw_slice
                        };
                        pixel_data = convert_pixels(
                            first_frame, bits_allocated, pixel_representation);
                    }
                }
            }
        }

        // ── PATH 2: compressed — use full decoder (may be slow/large) ──
        if pixel_data.is_empty() && !is_encapsulated {
            // raw read failed; try decoder as fallback
        }
        if pixel_data.is_empty() {
            #[cfg(debug_assertions)]
            eprintln!("[RUST] PATH1 empty (is_encapsulated={}), falling back to PATH2...", is_encapsulated);
            if let Ok(decoded) = obj.decode_pixel_data() {
                let raw_bytes = decoded.data();
                #[cfg(debug_assertions)]
                eprintln!("[RUST] PATH2 decoded {} bytes, keeping first {} frame_bytes",
                    raw_bytes.len(), frame_bytes);
                if !raw_bytes.is_empty() && frame_bytes > 0 {
                    let first_frame = if raw_bytes.len() > frame_bytes {
                        &raw_bytes[..frame_bytes]
                    } else {
                        raw_bytes
                    };
                    pixel_data = convert_pixels(
                        first_frame, bits_allocated, pixel_representation);
                }
            } else {
                #[cfg(debug_assertions)]
                eprintln!("[RUST] PATH2 decode_pixel_data FAILED");
            }
        }
    }

    #[cfg(debug_assertions)]
    eprintln!("[RUST] pixel_data.len={} (i16 elements) window_center={} window_width={}",
        pixel_data.len(), window_center, window_width);

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

    #[cfg(debug_assertions)]
    eprintln!("[RUST] DONE — returning DicomFrameResult");
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

/// Converts raw pixel bytes into i16 values, applying offset for unsigned data.
///
/// [bytes] should be the raw pixel data (1 or 2 bytes per sample).
/// [bits_allocated] determines byte width (≤8 = 1 byte, >8 = 2 bytes).
/// [pixel_representation] = 0 for unsigned, 1 for signed.
fn convert_pixels(bytes: &[u8], bits_allocated: u16, pixel_representation: u16) -> Vec<i16> {
    if bits_allocated <= 8 {
        if pixel_representation == 1 {
            bytes.iter().map(|&b| b as i8 as i16).collect()
        } else {
            bytes.iter().map(|&b| b as i16).collect()
        }
    } else if bytes.len() % 2 == 0 {
        if pixel_representation == 0 {
            // Unsigned 16-bit → offset to signed range for shader
            bytes
                .chunks_exact(2)
                .map(|chunk| {
                    let raw = u16::from_le_bytes([chunk[0], chunk[1]]);
                    (raw as i32 - 32768) as i16
                })
                .collect()
        } else {
            bytes
                .chunks_exact(2)
                .map(|chunk| i16::from_le_bytes([chunk[0], chunk[1]]))
                .collect()
        }
    } else {
        Vec::new()
    }
}
