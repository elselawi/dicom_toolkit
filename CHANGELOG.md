## 0.2.3

- **(fix)** JPEG-compressed DICOM decoding via `dicom-pixeldata` `PixelDecoder` trait — handles Carestream and other vendors using encapsulated transfer syntaxes (JPEG lossless, JPEG-LS, JPEG 2000, RLE)
- **(fix)** window center alignment for unsigned pixel data — DICOM window values are now offset by -32768 to match the shader's signed coordinate space, eliminating all-white/all-black images across Generic, Sirona, and Carestream files
- **(fix)** initial window defaults to pixel data range ("Full Range") instead of DICOM header values, which are often useless (e.g. C:32768/W:65536 spanning the full 16-bit range)
- **(fix)** window now resets on each `loadFromBytes` call; previously kept the previous file's window values
- **(fix)** level/width slider ranges computed from actual pixel data range instead of DICOM header values, eliminating ±40K dead zones
- **(deps)** added `dicom-pixeldata = "0.9"` to Rust dependencies for transfer-syntax-aware pixel decoding
- **(build)** WASM rebuilt with JPEG decoder support
- **(test)** 27 new tests: 23 integration tests against real Carestream/Generic/Sirona DICOM files validating JPEG decoding, window alignment, MONOCHROME1 detection, 12-bit-in-16-bit handling, and preset computation; 4 controller tests for auto-window and load-reset behavior

## 0.2.2

- **(feat)** expanded DICOM date extraction to 4 tags: `studyDate` (0008,0020), `seriesDate` (0008,0021), `acquisitionDate` (0008,0022), `contentDate` (0008,0023)
- **(feat)** `DicomMetadata.bestDate` — resolves the most recent valid non-future date among all four date tags; handles DICOM date ranges, leap years, and malformed values
- **(feat)** `DicomMetadata.toothInfo` — extracts tooth identification from dental DICOMs via cascade: standard Tooth Number (0018,6032), Tooth Region (0018,6033), then vendor private tags (Planmeca, Carestream, VATECH, Sirona, Dexis, KaVo), with generic fallbacks (`ImageComments`, `AcquisitionProtocolName`, `AcquisitionContextDescription`)
- **(feat)** new `DicomTagId` constants: `seriesDate`, `acquisitionDate`, `contentDate`, `toothNumber`, `toothRegion`
- **(refactor)** Rust `DicomMetadata` struct: 28→32 fields (added `series_date`, `acquisition_date`, `content_date`, `tooth_info`)
- **(refactor)** `dicom_decoder.dart` tag map updated with new date and tooth tag entries
- **(docs)** README: 28→32 extracted tags table, new Dates and Dental categories, `bestDate` usage section
- **(docs)** AGENTS.md: updated field count and tag counts throughout
- **(test)** 21 new tests: 11 `bestDate` edge cases, 5 tooth info tests, 5 date field delegation tests
- **(example)** metadata tab: new Dates section (best date + all 4 raw dates), Tooth tile in Acquisition section; viewer overlay uses `bestDate`


## 0.2.1

- Removed `dart:io` import completely. accepting only bytes as input.

## 0.2.0

- From here on, dicom_toolkit was born.
- **(BREAKING)** package renamed from `flutter_dicom` to `dicom_toolkit`
  - Update imports to `package:dicom_toolkit/dicom_toolkit.dart`
  - `DicomController` → `DicomViewerController`; `DicomService` removed
  - `FileDicomLoader` → `RustDecoder` (now implements `DicomDecoder`)
  - Loading is bytes-only on all platforms — `loadFromBytes()` only
- **(BREAKING)** composable toolkit API replaces monolithic controller
  - New: `DicomParser`, `DicomRenderer`, `DicomRoi`, `DicomRuler`, `DicomExport`, `DicomWindowPreset`
  - All tools accept dependency injection via abstract interfaces
- **(feat)** `DicomTagId` — 28 predefined DICOM tag constants + generic lookup via `DicomMetadata.tag()`
- **(feat)** `DicomPixelData` — sealed class hierarchy, `DicomInt16PixelData` for 16-bit monochrome
- **(feat)** `DicomViewer` widget — `interactive` flag to disable built-in gestures for measurement overlays
- **(feat)** rotation — 0°/90°/180°/270° via `rotateClockwise()`/`rotateCounterClockwise()`, included in PNG export
- **(feat)** pixel-spacing-aware `DicomRuler` — measures mm distance with fallback to Imager Pixel Spacing (0018,1164) for X-ray
- **(feat)** modality-agnostic `DicomWindowPreset.forImage()` — presets adapt to pixel value range, not hardcoded HU
- **(feat)** `DicomExport.toPngBytes()` — web-safe PNG export (no `dart:io`)
- **(feat)** `DicomParser.parseMetadata()` — metadata-only parse with `skipPixels: true`, no GPU needed
- **(feat)** web support — WASM build instructions, cross-origin isolation headers, `serve_debug.py`
- **(feat)** example app with measurement tools (ruler + ROI), rotation, presets, color maps, PNG export
- **(fix)** shader uniform index 8 bound for `u_monochrome1` flag
- **(fix)** `RangeError.range` used in `DicomParseResult.frame()` instead of `.index` (compatibility)
- **(refactor)** 28-field Rust `DicomMetadata` struct (added `pixel_spacing`)
- **(refactor)** `public_member_api_docs` enforced — all public API documented
- **(refactor)** `MedicalScreen` removed — use `DicomViewer` directly
- **(chore)** `analysis_options.yaml` strict lint rules; `cargokit` excluded from analysis
- **(docs)** rewritten `README.md` and `AGENTS.md` reflecting new architecture
- **(docs)** 175 unit + widget + integration tests, all passing

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
