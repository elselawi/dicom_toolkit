use crate::api::core::{
    config::dicom_config::DicomConfig, models::dicom_frame_result::DicomFrameResult,
    utils::process_dicom_file::{process_dicom_file, process_dicom_from_bytes},
};

/// Initializes the high-performance Rust backend.
///
/// This function sets up the default logging and utility handlers
/// required for the Flutter-Rust communication bridge.
/// It should be called once at the start of the application.
#[flutter_rust_bridge::frb(init)]
pub fn init_app() {
    flutter_rust_bridge::setup_default_user_utils();
}

/// The primary entry point for loading and parsing a DICOM file from the local file system.
///
/// This function performs the following:
/// 1. Opens and validates the DICOM file at the provided [path].
/// 2. Extracts critical medical metadata (Patient Name, Windowing, Pixel Precision).
/// 3. Processes the raw Pixel Data into a memory-efficient buffer for Flutter consumption.
///
/// # Arguments
/// * `path` - The absolute path to the .dcm file.
/// * `config` - A [DicomConfig] object used to tune performance (e.g., skip pixel processing).
///
/// # Returns
/// * A [DicomFrameResult] containing both the metadata and the 16-bit pixel buffer.
/// * An error if the file is corrupted, missing, or has an unsupported transfer syntax.
pub fn load_dicom(path: String, config: DicomConfig) -> anyhow::Result<DicomFrameResult> {
    process_dicom_file(&path, &config)
}

/// Parses a DICOM file directly from an in-memory byte array.
/// Useful for Web or environments where a local file system is unavailable.
pub fn load_dicom_from_bytes(bytes: Vec<u8>, config: DicomConfig) -> anyhow::Result<DicomFrameResult> {
    process_dicom_from_bytes(&bytes, &config)
}
