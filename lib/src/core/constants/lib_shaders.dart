/// A centralized registry for shader asset paths used within the library.
///
/// This class provides static constants pointing to the GLSL fragment shaders
/// bundled with the `dicom_toolkit` package. These shaders are used for
/// high-performance image processing on the GPU, such as:
/// * Window Leveling (Contrast/Brightness)
/// * 16-bit to 8-bit pixel mapping
/// * Photometric Interpretation handling
///
/// Using constants ensures that asset paths remain consistent across the
/// [DicomController] and internal rendering components.
///
/// {@category Constants}
final class LibShaders {
  /// The path to the primary DICOM windowing fragment shader.
  static const String dicomWindow =
      'packages/dicom_toolkit/assets/shaders/dicom_window.frag';
}
