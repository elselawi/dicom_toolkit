/// Base exception for all DICOM-related errors in the SDK.
///
/// All specialized exceptions in the Flutter-Dicom package inherit from this class,
/// allowing you to catch all medical imaging errors in a single block.
abstract class DicomException implements Exception {
  /// Creates a [DicomException].
  const DicomException(this.message, [this.originalError]);

  /// A human-readable message explaining what went wrong.
  final String message;

  /// The underlying error (e.g., a FileSystemException or Rust panic) if available.
  final dynamic originalError;

  @override
  String toString() {
    if (originalError != null) {
      return '$runtimeType: $message (Details: $originalError)';
    }
    return '$runtimeType: $message';
  }
}

/// Thrown when the high-performance Rust engine fails to parse or process the file.
///
/// Common causes include:
/// * Corrupted .dcm file.
/// * Unsupported DICOM transfer syntax.
/// * Memory allocation failures during large volume parsing.
class DicomProcessingException extends DicomException {
  /// Thrown when the high-performance Rust engine fails to parse or process the file.
  ///
  /// Common causes include:
  /// * Corrupted .dcm file.
  /// * Unsupported DICOM transfer syntax.
  /// * Memory allocation failures during large volume parsing.
  const DicomProcessingException(super.message, [super.originalError]);
}

/// Thrown when the GPU Fragment Shader fails to load or compile.
///
/// This usually indicates an issue with the Flutter assets configuration
/// or an incompatible graphics driver on the target device.
class DicomShaderException extends DicomException {
  /// Thrown when the GPU Fragment Shader fails to load or compile.
  ///
  /// This usually indicates an issue with the Flutter assets configuration
  /// or an incompatible graphics driver on the target device.
  const DicomShaderException(super.message);
}

/// Thrown when an invalid configuration is passed to the SDK.
class DicomConfigurationException extends DicomException {
  /// Thrown when an invalid configuration is passed to the SDK.
  const DicomConfigurationException(super.message);
}

/// Thrown when the native Rust engine cannot be loaded into the current process.
///
/// On iOS and macOS the Rust core is linked into the app target by the podspec
/// (`-force_load`, with `DEAD_CODE_STRIPPING = NO` to keep it). If it is missing
/// — for example because those podspec settings were removed, or the pod was
/// compiled with different linker settings — `DicomToolkit.init()` throws this
/// instead of surfacing a raw dynamic-library error. See the "iOS and macOS"
/// section of the package README.
class DicomInitializationException extends DicomException {
  /// Thrown when the native Rust engine cannot be loaded into the current process.
  const DicomInitializationException(super.message, [super.originalError]);
}
