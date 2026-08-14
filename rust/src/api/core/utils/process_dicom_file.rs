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
    let planar_configuration = get_int_tag(
        &obj,
        tags::PLANAR_CONFIGURATION,
        0u16,
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
    // The centre is offset identically to the stored samples (see
    // `convert_pixels`), so that metadata and pixels share a coordinate space.
    window_center = align_window_center(
        pixel_representation,
        bits_allocated,
        window_width,
        window_center,
    );

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
        photometric_interpretation: photometric_interpretation.clone(),
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

                        if photometric_interpretation == "PALETTE COLOR" {
                            if let Some(palette_pixels) = try_expand_palette_color(&obj, first_frame) {
                                pixel_data = palette_pixels;
                                metadata.samples_per_pixel = 3;
                                metadata.photometric_interpretation = "RGB".to_string();
                            }
                        }

                        if pixel_data.is_empty() {
                            if samples_per_pixel == 3 {
                                let mut color_bytes = if planar_configuration == 1 {
                                    if bits_allocated <= 8 {
                                        interleave_planes_u8(first_frame)
                                    } else {
                                        interleave_planes_u16(first_frame)
                                    }
                                } else {
                                    first_frame.to_vec()
                                };

                                match photometric_interpretation.as_str() {
                                    "YBR_FULL" => {
                                        convert_ybr_full_to_rgb_u8(&mut color_bytes);
                                        metadata.photometric_interpretation = "RGB".to_string();
                                    }
                                    "YBR_FULL_422" => {
                                        color_bytes = convert_ybr_full_422_to_rgb_u8(&color_bytes);
                                        metadata.photometric_interpretation = "RGB".to_string();
                                    }
                                    "YBR_PARTIAL_422" => {
                                        color_bytes = convert_ybr_partial_422_to_rgb_u8(&color_bytes);
                                        metadata.photometric_interpretation = "RGB".to_string();
                                    }
                                    _ => {}
                                }

                                pixel_data = convert_pixels(
                                    &color_bytes, bits_allocated, pixel_representation);
                            } else {
                                pixel_data = convert_pixels(
                                    first_frame, bits_allocated, pixel_representation);
                            }
                        }
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
                let decoded_spp = decoded.samples_per_pixel();
                let decoded_bits = decoded.bits_allocated();
                let decoded_bytes_per_sample = (decoded_bits as usize).div_ceil(8);
                let decoded_frame_samples = (width as usize) * (height as usize) * (decoded_spp as usize);
                let decoded_frame_bytes = decoded_frame_samples * decoded_bytes_per_sample;

                let raw_bytes = decoded.data();
                #[cfg(debug_assertions)]
                eprintln!("[RUST] PATH2 decoded {} bytes, keeping first {} frame_bytes, decoded_spp={}, decoded_bits={}",
                    raw_bytes.len(), decoded_frame_bytes, decoded_spp, decoded_bits);
                if !raw_bytes.is_empty() && decoded_frame_bytes > 0 {
                    let first_frame = if raw_bytes.len() > decoded_frame_bytes {
                        &raw_bytes[..decoded_frame_bytes]
                    } else {
                        raw_bytes
                    };

                    if decoded_spp == 3 {
                        let is_planar = (decoded.planar_configuration() as u16) == 1;
                        let mut color_bytes = if is_planar {
                            if decoded_bits <= 8 {
                                interleave_planes_u8(first_frame)
                            } else {
                                interleave_planes_u16(first_frame)
                            }
                        } else {
                            first_frame.to_vec()
                        };

                        let pi_str = decoded.photometric_interpretation().as_ref();
                        match pi_str {
                            "YBR_FULL" => {
                                convert_ybr_full_to_rgb_u8(&mut color_bytes);
                            }
                            "YBR_FULL_422" => {
                                color_bytes = convert_ybr_full_422_to_rgb_u8(&color_bytes);
                            }
                            "YBR_PARTIAL_422" => {
                                color_bytes = convert_ybr_partial_422_to_rgb_u8(&color_bytes);
                            }
                            _ => {}
                        }

                        metadata.samples_per_pixel = 3;
                        metadata.photometric_interpretation = "RGB".to_string();
                        pixel_data = convert_pixels(
                            &color_bytes, decoded_bits, pixel_representation);
                    } else {
                        metadata.samples_per_pixel = decoded_spp;
                        pixel_data = convert_pixels(
                            first_frame, decoded_bits, pixel_representation);
                    }
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

/// Aligns a DICOM window centre with the stored-pixel coordinate space.
///
/// DICOM Window Center/Width are defined in the original pixel value space.
/// For unsigned data, our pipeline offsets raw pixel values by `-32768` to
/// fit in `i16` (and the shader reverses this) — but ONLY for sample widths
/// greater than 8 bits (`convert_pixels` keeps unsigned 8-bit samples in their
/// native `0..255` range). The window centre is offset identically to the
/// stored samples so that metadata and pixels share a coordinate space.
///
/// Offsetting an unsigned 8-bit centre (e.g. 128 → −32640) would put pixels
/// and window in incompatible coordinate systems and clip the whole image.
fn align_window_center(
    pixel_representation: u16,
    bits_allocated: u16,
    window_width: f32,
    window_center: f32,
) -> f32 {
    if pixel_representation == 0 && bits_allocated > 8 && window_width > 0.0 {
        window_center - 32768.0
    } else {
        window_center
    }
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

/// Interleaves color-by-plane (planar configuration 1) 8-bit data into color-by-pixel RGB.
fn interleave_planes_u8(data: &[u8]) -> Vec<u8> {
    if data.len() % 3 != 0 {
        return data.to_vec();
    }
    let plane_len = data.len() / 3;
    let r = &data[..plane_len];
    let g = &data[plane_len..2 * plane_len];
    let b = &data[2 * plane_len..];
    let mut out = Vec::with_capacity(data.len());
    for i in 0..plane_len {
        out.push(r[i]);
        out.push(g[i]);
        out.push(b[i]);
    }
    out
}

/// Interleaves color-by-plane (planar configuration 1) 16-bit data into color-by-pixel RGB.
fn interleave_planes_u16(data: &[u8]) -> Vec<u8> {
    if data.len() % 6 != 0 {
        return data.to_vec();
    }
    let samples_per_plane = data.len() / 6;
    let bytes_per_plane = samples_per_plane * 2;
    let r = &data[..bytes_per_plane];
    let g = &data[bytes_per_plane..2 * bytes_per_plane];
    let b = &data[2 * bytes_per_plane..];
    let mut out = Vec::with_capacity(data.len());
    for i in 0..samples_per_plane {
        out.push(r[2 * i]);
        out.push(r[2 * i + 1]);
        out.push(g[2 * i]);
        out.push(g[2 * i + 1]);
        out.push(b[2 * i]);
        out.push(b[2 * i + 1]);
    }
    out
}

/// Converts YBR_FULL 8-bit triplets into RGB 8-bit triplets in-place.
fn convert_ybr_full_to_rgb_u8(data: &mut [u8]) {
    for chunk in data.chunks_exact_mut(3) {
        let y = chunk[0] as f32;
        let cb = chunk[1] as f32 - 128.0;
        let cr = chunk[2] as f32 - 128.0;

        let r = (y + 1.402 * cr).clamp(0.0, 255.0);
        let g = (y - 0.344136 * cb - 0.714136 * cr).clamp(0.0, 255.0);
        let b = (y + 1.772 * cb).clamp(0.0, 255.0);

        chunk[0] = r.round() as u8;
        chunk[1] = g.round() as u8;
        chunk[2] = b.round() as u8;
    }
}

/// Converts YBR_FULL_422 8-bit data (Y1, Y2, Cb, Cr) into RGB 8-bit triplets.
fn convert_ybr_full_422_to_rgb_u8(data: &[u8]) -> Vec<u8> {
    let mut out = Vec::with_capacity((data.len() / 4) * 6);
    for chunk in data.chunks_exact(4) {
        let y1 = chunk[0] as f32;
        let y2 = chunk[1] as f32;
        let cb = chunk[2] as f32 - 128.0;
        let cr = chunk[3] as f32 - 128.0;

        let r1 = (y1 + 1.402 * cr).clamp(0.0, 255.0).round() as u8;
        let g1 = (y1 - 0.344136 * cb - 0.714136 * cr).clamp(0.0, 255.0).round() as u8;
        let b1 = (y1 + 1.772 * cb).clamp(0.0, 255.0).round() as u8;

        let r2 = (y2 + 1.402 * cr).clamp(0.0, 255.0).round() as u8;
        let g2 = (y2 - 0.344136 * cb - 0.714136 * cr).clamp(0.0, 255.0).round() as u8;
        let b2 = (y2 + 1.772 * cb).clamp(0.0, 255.0).round() as u8;

        out.extend_from_slice(&[r1, g1, b1, r2, g2, b2]);
    }
    out
}

/// Converts YBR_PARTIAL_422 8-bit data into RGB 8-bit triplets.
fn convert_ybr_partial_422_to_rgb_u8(data: &[u8]) -> Vec<u8> {
    let mut out = Vec::with_capacity((data.len() / 4) * 6);
    for chunk in data.chunks_exact(4) {
        let y1 = (chunk[0] as f32 - 16.0) * (255.0 / 219.0);
        let y2 = (chunk[1] as f32 - 16.0) * (255.0 / 219.0);
        let cb = (chunk[2] as f32 - 128.0) * (255.0 / 224.0);
        let cr = (chunk[3] as f32 - 128.0) * (255.0 / 224.0);

        let r1 = (y1 + 1.402 * cr).clamp(0.0, 255.0).round() as u8;
        let g1 = (y1 - 0.344136 * cb - 0.714136 * cr).clamp(0.0, 255.0).round() as u8;
        let b1 = (y1 + 1.772 * cb).clamp(0.0, 255.0).round() as u8;

        let r2 = (y2 + 1.402 * cr).clamp(0.0, 255.0).round() as u8;
        let g2 = (y2 - 0.344136 * cb - 0.714136 * cr).clamp(0.0, 255.0).round() as u8;
        let b2 = (y2 + 1.772 * cb).clamp(0.0, 255.0).round() as u8;

        out.extend_from_slice(&[r1, g1, b1, r2, g2, b2]);
    }
    out
}

/// Checks and applies PALETTE COLOR LUT expansion if present.
fn try_expand_palette_color(
    obj: &DefaultDicomObject,
    indices: &[u8],
) -> Option<Vec<i16>> {
    let red_data = obj.element(tags::RED_PALETTE_COLOR_LOOKUP_TABLE_DATA).ok()?.to_bytes().ok()?;
    let green_data = obj.element(tags::GREEN_PALETTE_COLOR_LOOKUP_TABLE_DATA).ok()?.to_bytes().ok()?;
    let blue_data = obj.element(tags::BLUE_PALETTE_COLOR_LOOKUP_TABLE_DATA).ok()?.to_bytes().ok()?;

    let red_desc_elem = obj.element(tags::RED_PALETTE_COLOR_LOOKUP_TABLE_DESCRIPTOR).ok()?;
    let num_entries = red_desc_elem.to_int::<u32>().ok().unwrap_or(256);
    let num_entries = if num_entries == 0 { 65536 } else { num_entries as usize };

    let r_slice = red_data.as_ref();
    let g_slice = green_data.as_ref();
    let b_slice = blue_data.as_ref();

    let is_16bit_lut = r_slice.len() >= num_entries * 2;

    let mut out = Vec::with_capacity(indices.len() * 3);
    for &idx_byte in indices {
        let idx = idx_byte as usize;
        let (r, g, b) = if is_16bit_lut {
            let r_val = if idx * 2 + 1 < r_slice.len() { u16::from_le_bytes([r_slice[idx * 2], r_slice[idx * 2 + 1]]) >> 8 } else { 0 };
            let g_val = if idx * 2 + 1 < g_slice.len() { u16::from_le_bytes([g_slice[idx * 2], g_slice[idx * 2 + 1]]) >> 8 } else { 0 };
            let b_val = if idx * 2 + 1 < b_slice.len() { u16::from_le_bytes([b_slice[idx * 2], b_slice[idx * 2 + 1]]) >> 8 } else { 0 };
            (r_val as i16, g_val as i16, b_val as i16)
        } else {
            let r_val = if idx < r_slice.len() { r_slice[idx] } else { 0 };
            let g_val = if idx < g_slice.len() { g_slice[idx] } else { 0 };
            let b_val = if idx < b_slice.len() { b_slice[idx] } else { 0 };
            (r_val as i16, g_val as i16, b_val as i16)
        };
        out.push(r);
        out.push(g);
        out.push(b);
    }
    Some(out)
}

#[cfg(test)]
mod tests {
    use super::*;

    // ── convert_pixels: 8-bit paths ─────────────────────────────

    #[test]
    fn converts_unsigned_8bit_passthrough() {
        // bits <= 8, pixel_representation == 0 → byte as positive i16.
        assert_eq!(convert_pixels(&[0, 1, 127, 128, 255], 8, 0), vec![0, 1, 127, 128, 255]);
    }

    #[test]
    fn converts_signed_8bit_two_complement() {
        // bits <= 8, pixel_representation == 1 → i8 sign extension.
        assert_eq!(convert_pixels(&[0, 1, 127, 128, 255], 8, 1), vec![0, 1, 127, -128, -1]);
    }

    // ── convert_pixels: 16-bit paths ────────────────────────────

    #[test]
    fn converts_signed_16bit_little_endian() {
        let bytes = [0x34, 0x12, 0xFC, 0xFF]; // 0x1234 = 4660; 0xFFFC = -4
        assert_eq!(convert_pixels(&bytes, 16, 1), vec![4660, -4]);
    }

    #[test]
    fn offsets_unsigned_16bit_into_signed_range() {
        // Unsigned raw 0 → 0 - 32768 = -32768
        assert_eq!(convert_pixels(&[0x00, 0x00], 16, 0), vec![-32768]);
        // Unsigned raw 0x8000 (32768) → 32768 - 32768 = 0
        assert_eq!(convert_pixels(&[0x00, 0x80], 16, 0), vec![0]);
        // Unsigned raw 0xFFFF (65535) → 65535 - 32768 = 32767
        assert_eq!(convert_pixels(&[0xFF, 0xFF], 16, 0), vec![32767]);
    }

    #[test]
    fn handles_16bit_little_endian_byte_order() {
        // 0x1234 little-endian is bytes [0x34, 0x12].
        let bytes = [0x34, 0x12];
        assert_eq!(convert_pixels(&bytes, 16, 1), vec![0x1234]);
        // Wrong order [0x12, 0x34] gives 0x3412.
        assert_eq!(convert_pixels(&[0x12, 0x34], 16, 1), vec![0x3412]);
    }

    #[test]
    fn returns_empty_for_odd_length_16bit() {
        // Buffers with a trailing byte cannot be chunked → empty.
        assert_eq!(convert_pixels(&[0x01, 0x02, 0x03], 16, 0), Vec::<i16>::new());
        assert_eq!(convert_pixels(&[0x01, 0x02, 0x03], 16, 1), Vec::<i16>::new());
    }

    #[test]
    fn returns_empty_for_empty_input() {
        assert_eq!(convert_pixels(&[], 16, 0), Vec::<i16>::new());
        assert_eq!(convert_pixels(&[], 16, 1), Vec::<i16>::new());
        assert_eq!(convert_pixels(&[], 8, 0), Vec::<i16>::new());
    }

    #[test]
    fn boundary_bits_allocated_switches_width() {
        // bits_allocated == 8 → 1-byte path.
        assert_eq!(convert_pixels(&[255], 8, 0), vec![255]);
        // bits_allocated == 9 → 2-byte path.
        assert_eq!(convert_pixels(&[0xFF, 0xFF], 9, 0), vec![32767]);
        // bits_allocated == 0 ≤ 8 → treated as 1-byte.
        assert_eq!(convert_pixels(&[7], 0, 0), vec![7]);
    }

    #[test]
    fn signed_16bit_full_range_roundtrip() {
        // -32768 (0x8000) and 32767 (0x7FFF) round-trip exactly.
        assert_eq!(convert_pixels(&[0x00, 0x80], 16, 1), vec![-32768]);
        assert_eq!(convert_pixels(&[0xFF, 0x7F], 16, 1), vec![32767]);
    }

    // ── align_window_center: unsigned 8-bit vs 16-bit ──────────

    #[test]
    fn offset_unsigned_16bit_window_center_into_signed_range() {
        // Unsigned 16-bit samples are shifted -32768; the centre must be too.
        // DICOM centre 32768 → 0 in stored-pixel space.
        assert_eq!(align_window_center(0, 16, 256.0, 32768.0), 0.0);
        assert_eq!(align_window_center(0, 16, 256.0, 128.0), 128.0 - 32768.0);
    }

    #[test]
    fn does_not_offset_unsigned_8bit_window_center() {
        // Unsigned 8-bit samples stay in 0..255, so the centre must stay too:
        // centre 128 → mid-gray, NOT −32640.
        assert_eq!(align_window_center(0, 8, 256.0, 128.0), 128.0);
        assert_eq!(align_window_center(0, 8, 256.0, 128.0), 128.0);
    }

    #[test]
    fn does_not_offset_signed_window_center() {
        // Signed samples need no offset regardless of bit width.
        assert_eq!(align_window_center(1, 16, 256.0, 128.0), 128.0);
        assert_eq!(align_window_center(1, 8, 256.0, 128.0), 128.0);
    }

    #[test]
    fn does_not_offset_when_window_width_is_zero() {
        // Zero/absent window width means no windowing metadata to align.
        assert_eq!(align_window_center(0, 16, 0.0, 32768.0), 32768.0);
        assert_eq!(align_window_center(0, 16, -1.0, 32768.0), 32768.0);
    }

    // ── Color processing: interleaving & YBR->RGB conversions ────

    #[test]
    fn interleaves_planar_u8_correctly() {
        // 2 pixels: P0 = (R0=10, G0=20, B0=30), P1 = (R1=40, G1=50, B1=60)
        // Planar format: [10, 40, 20, 50, 30, 60]
        let planar = vec![10, 40, 20, 50, 30, 60];
        let interleaved = interleave_planes_u8(&planar);
        assert_eq!(interleaved, vec![10, 20, 30, 40, 50, 60]);
    }

    #[test]
    fn converts_ybr_full_to_rgb_correctly() {
        // Pure gray: Y=128, Cb=128, Cr=128 -> RGB should be ~ (128, 128, 128)
        let mut data = vec![128, 128, 128];
        convert_ybr_full_to_rgb_u8(&mut data);
        assert_eq!(data, vec![128, 128, 128]);

        // Pure white: Y=255, Cb=128, Cr=128 -> RGB should be ~ (255, 255, 255)
        let mut white = vec![255, 128, 128];
        convert_ybr_full_to_rgb_u8(&mut white);
        assert_eq!(white, vec![255, 255, 255]);

        // Pure black: Y=0, Cb=128, Cr=128 -> RGB should be (0, 0, 0)
        let mut black = vec![0, 128, 128];
        convert_ybr_full_to_rgb_u8(&mut black);
        assert_eq!(black, vec![0, 0, 0]);
    }

    #[test]
    fn converts_ybr_full_422_to_rgb_correctly() {
        // 2 pixels in 4:2:2: Y1=128, Y2=255, Cb=128, Cr=128
        let data = vec![128, 255, 128, 128];
        let rgb = convert_ybr_full_422_to_rgb_u8(&data);
        assert_eq!(rgb, vec![128, 128, 128, 255, 255, 255]);
    }
}
