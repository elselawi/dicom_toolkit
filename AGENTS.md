# AGENTS.md — dicom_toolkit

## Project Identity

**dicom_toolkit** is a Flutter plugin for workstation-grade DICOM medical imaging. It pairs a **Rust native core** (`dicom` crate v0.9) with **GPU fragment shaders** (GLSL) to deliver 16-bit precision, real-time windowing, and zero-UI-thread-blocking rendering. The Dart↔Rust bridge is powered by `flutter_rust_bridge` v2.12.0.

- **License**: GPL v3 — forked from [MostafaSensei106/Flutter-Dicom](https://github.com/MostafaSensei106/Flutter-Dicom)
- **Platforms**: Android, iOS, Linux, macOS, Windows, Web (WASM)
- **Version**: `0.2.0`

---

## Architecture

```
lib/
  dicom_toolkit.dart                 ← barrel: exports + DicomToolkit class
  src/
    backend/
      dicom_decoder.dart             ← DicomDecoder (abstract) + RustDecoder (FFI impl)
    core/
      dicom_tag_id.dart              ← DicomTagId (group, element) + 28 constants
      dicom_metadata.dart            ← DicomMetadata wrapper (typed getters + tag lookup)
      dicom_pixel_data.dart          ← sealed DicomPixelData + DicomInt16PixelData
      dicom_parse_result.dart        ← DicomParseResult (metadata + pixels + frame API)
      constants/
        color_maps.dart              ← DicomColorMap enum + ColorMapLut generator
        lib_shaders.dart             ← shader asset path constant
      exceptions/
        dicom_exceptions.dart        ← DicomException + DicomProcessingException
      services/
        dicom_reader.dart            ← readDicomInfo() + DicomFileInfo (metadata-only)
      shader/
        dicom_shader_painter.dart    ← CustomPainter binding shader + texture
      widgets/
        dicom_viewer.dart            ← interactive viewer widget (GPU + gestures)
    tools/
      dicom_export.dart              ← PNG export (web-compatible, no dart:io)
      dicom_parser.dart              ← parsing entry point (DI DicomDecoder)
      dicom_renderer.dart            ← GPU rendering (shader compile, texture pack, render)
      dicom_roi.dart                 ← rectangular ROI + RoiStatistics
      dicom_ruler.dart               ← mm distance from pixel spacing
      dicom_window_preset.dart       ← presets (CT constants + forImage() factory)
    viewer/
      dicom_viewer_controller.dart   ← ChangeNotifier state manager
    rust/                            ← AUTO-GENERATED — never hand-edit
      frb_generated.dart
      frb_generated.io.dart / .web.dart
      api/init.dart, api/core/...

rust/
  Cargo.toml                        ← deps: dicom=0.9, flutter_rust_bridge=2.12.0
  src/
    lib.rs                          ← pub mod api; mod frb_generated;
    frb_generated.rs                ← AUTO-GENERATED
    api/
      init.rs                       ← load_dicom / load_dicom_from_bytes FFI entry
      core/
        config/dicom_config.rs      ← auto_normalize, skip_pixels
        models/dicom_metadata.rs    ← 28-field struct + Default impl
        models/dicom_frame_result.rs← metadata + Vec<i16>
        constants/lib_constants.rs  ← DefaultConfigs consts
        utils/process_dicom_file.rs ← THE CORE: parses .dcm, extracts tags+pixels

assets/shaders/dicom_window.frag    ← GLSL: 16-bit unpack + HU + windowing + LUT

web/pkg/                            ← WASM + JS bindings (wasm-pack output)
example/web/pkg/                    ← copy for example app

test/
  dicom_tag_id_test.dart            ← 28 constants, equality, hex
  dicom_pixel_data_test.dart        ← sealed hierarchy, buffer
  dicom_window_preset_test.dart     ← 7 presets, forImage(), equality
  dicom_metadata_test.dart          ← typed getters, tag(), pixelSpacing
  dicom_parse_result_test.dart      ← fromFrame, frame(), hasPixels
  dicom_roi_test.dart               ← compute(), copyWith, clamping
  dicom_ruler_test.dart             ← measure(), spacing fallback
  dicom_parser_test.dart            ← mocked decoder delegation
  dicom_viewer_controller_test.dart ← state lifecycle, error paths
  dicom_viewer_test.dart            ← widget states (loading, error, empty)
  dicom_exceptions_test.dart        ← DicomException hierarchy
  features_test.dart                ← cross-tool integration
  dicom_integration_test.dart       ← real .dcm files via parser
  dicom_reader_test.dart            ← readDicomInfo() with real files
```

---

## Data Flow

1. `DicomToolkit.init()` — loads native library / WASM
2. `DicomParser.parse(bytes)` → `DicomDecoder.decode()` → `loadDicomFromBytes()` FFI
3. Rust `process_dicom_file.rs`: opens DICOM, extracts 28 tags + pixel spacing (with Imager Pixel Spacing fallback for X-ray), extracts `Vec<i16>` pixels
4. `DicomParseResult.fromFrame()`: wraps generated metadata → `DicomMetadata` wrapper, packs pixels → `DicomInt16PixelData`
5. `DicomRenderer`: compiles GLSL shader, packs 16-bit → RGBA (+32768 offset), renders via `PictureRecorder` → `ui.Image`
6. `DicomViewer`: `CustomPaint` → `DicomShaderPainter` → shader (windowing + HU + color LUT), wrapped in `Transform.rotate`

---

## Key Patterns

### 16-bit Precision Through 8-bit Textures

R=high byte, G=low byte, +32768 offset → shader reverses to full 16-bit signed.

### Dependency Injection

`DicomParser` accepts a `DicomDecoder` (defaults to `RustDecoder`). Implement `DicomDecoder` for PACS, S3, or mock backends.

### Tag Extraction Helpers (Rust)

`get_str_tag`, `get_float_tag`, `get_int_tag` in `process_dicom_file.rs` — always use these when adding new tags. They handle missing elements, type conversion, and defaults automatically.

### Shader Uniform Binding Order

| Index | Uniform |
|-------|---------|
| 0 | `u_resolution` (width) |
| 1 | (height) |
| 2 | `u_window_center` |
| 3 | `u_window_width` |
| 4 | `u_rescale_intercept` |
| 5 | `u_rescale_slope` |
| 6 | `u_colorize` (flag) |
| 7 | `u_invert` (flag) |
| 8 | `u_monochrome1` (flag) |
| sampler 0 | `u_texture` (RGBA-packed image) |
| sampler 1 | `u_color_lut` (256×1 LUT or dummy) |

---

## Build Commands

```bash
# Generate bridge (after any Rust struct change)
flutter_rust_bridge_codegen generate

# Build Rust (native)
cargo build && cargo build --release

# Build WASM (web)
$env:RUSTUP_TOOLCHAIN='nightly'
wasm-pack build --dev --target no-modules --out-name dicom_toolkit
Copy-Item rust/pkg/* web/pkg/ -Force
Copy-Item rust/pkg/* example/web/pkg/ -Force

# Tests
flutter test

# Lint
dart analyze lib
```

**CRITICAL**: After changing any `rust/src/api/**/*.rs` struct:
1. `flutter_rust_bridge_codegen generate`
2. `cargo build && cargo build --release`
3. If web: rebuild WASM with wasm-pack
4. `flutter clean` in example if running there

---

## Coding Conventions

### Dart
- Relative imports inside `lib/src/`; package imports only in barrel
- `lint`: `package:lints/recommended.yaml` + `analysis_options.yaml` strict rules
- `final` everywhere; `const` for compile-time constants
- Always `dispose()` controllers
- `unawaited()` for fire-and-forget futures in `initState`

### Rust
- Edition 2021; `anyhow::Result` for public functions
- Tag extraction: always use helper functions from `process_dicom_file.rs`
- Structs: `derive(Debug, Clone)`; `#[frb]` for bridge exposure

### Generated code
- `lib/src/rust/**` and `rust/src/frb_generated.rs` are auto-generated
- `lib/src/rust/**` excluded from analysis in `analysis_options.yaml`
- `cargokit/**` excluded from analysis

---

## Common Pitfalls

1. **Editing generated code** — changes to `lib/src/rust/` will be overwritten by codegen
2. **Stale WASM** — after Rust struct changes, WASM binary must be rebuilt separately (`wasm-pack`)
3. **Stale DLL** — after codegen, both `cargo build` (debug) and `cargo build --release` must run
4. **Shader asset path** — use `LibShaders.dicomWindow` constant, not a raw string
5. **SSE vs DCO codec** — `flutter test` uses DCO (VM FFI), `flutter run` uses SSE (serialized). Both need matching DLLs
