## 0.2.0

- (BREAKING): package renamed from `flutter_dicom` to `dicom_toolkit`
  - Update your `pubspec.yaml` dependency and all `import 'package:dicom_toolkit/dicom_toolkit.dart';` statements
  - Rust crate renamed from `flutter_dicom` to `dicom_toolkit` (affects the native library filename on all platforms)
  - `FlutterDicomWeb` → `DicomToolkitWeb`; `lib/flutter_dicom_web.dart` → `lib/dicom_toolkit_web.dart`
  - `FileDicomLoader` → `RustDicomLoader`
  - Shader asset path updated to `packages/dicom_toolkit/assets/shaders/dicom_window.frag`
- (BREAKING): removed `DicomController.loadFromFile()`, `IDicomLoader.load()`, `DicomService.loadFrame()`, and `WebDicomLoader` — loading is now bytes-only via `loadFromBytes()` on every platform
- (chore): project ownership and repository moved to [@elselawi](https://github.com/elselawi)

## 0.1.0+3

- (docs): refine performance benchmarks in README

## 0.1.0+4

- (feat): add `readDicomInfo()` — lightweight metadata-only API (no controller, no shaders, no pixels)
- (feat): add `DicomFileInfo` class wrapping `filePath`, `fileName`, and `DicomMetadata`
- (feat): expand metadata extraction from 13 to 27 DICOM tags
  - Added patient demographics: `studyDescription`
  - Added equipment info: `modality`, `manufacturer`, `manufacturerModelName`, `institutionName`
  - Added identifiers: `studyInstanceUid`, `seriesInstanceUid`, `sopInstanceUid`
  - Added acquisition details: `seriesDescription`, `bodyPartExamined`, `sliceThickness`, `instanceNumber`
- (refactor): introduce `get_str_tag`, `get_float_tag`, `get_int_tag` helpers for cleaner tag extraction
- (feat): add 8-bit pixel data support with signedness-aware conversion
- (perf): reorder pixel extraction to try fast byte-chunking first, with transfer-syntax-aware fallback
- (docs): update README with 27-field metadata table, `readDicomInfo()` guide, and usage examples

## 0.1.0+3

- (docs): refine performance benchmarks in README

## 0.1.0+2

- (feat): add comprehensive performance benchmarks and metadata defaults
- (feat) add `DicomMetadata` defaults and refactor DICOM processing
- (feat): implement `DicomMetadata` defaults and a `new` constructor in Rust; refactor `process_dicom_file` to use them.
- Added `Default` implementation and a `new` constructor for `DicomMetadata` in Rust.
- Refactored `process_dicom_file` to use `DicomMetadata` defaults when tags are missing.
- (feat): add `newInstance` and `default_` static methods to `DicomMetadata` and `DicomFrameResult` Dart classes.
- Added `newInstance` and `default_` static methods to `DicomMetadata` and `DicomFrameResult` Dart classes.
- (feat): introduce `LibShaders` constant for centralized shader asset path management.
- Introduced `LibShaders` constant for centralized shader asset path management.
- (refactor): integrate `LibShaders` into `DicomController`.
- Integrated `LibShaders` into `DicomController` for shader loading.
- (fix): update `MedicalScreen` to support an optional `title` parameter.
- Updated `MedicalScreen` to support an optional `title` parameter.
- (feat): add `series_performance_test.dart` covering throughput, latency, windowing stress, and lifecycle tests.
- (docs): add detailed performance benchmarks and workstation-grade metrics to README.
- (chore): add test series data to `.gitignore`.

## 0.1.0+1

- (fix): README images src

## 0.1.0

 - Initial release of Flutter-Dicom.
 - High-performance Rust core for DICOM parsing and pixel extraction.
 - GPU Fragment Shaders for real-time Windowing (Level/Width).
 - Support for 16-bit precision and Hounsfield Unit (HU) mapping.
 - Built-in `DicomViewer` widget with interactive pan, zoom, and contrast adjustments.
 - Comprehensive metadata extraction (Patient Name, Modality, Rescale Slope/Intercept, etc.).
 - Cross-platform support (Android, iOS, macOS, Windows, Linux).
