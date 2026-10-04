# AGENTS.md — dicom_toolkit

## Project Identity

**dicom_toolkit** is a Flutter plugin for workstation-grade DICOM medical imaging. It pairs a **Rust native core** (`dicom` crate v0.9) with **GPU fragment shaders** (GLSL) to deliver 16-bit precision, real-time windowing, and zero-UI-thread-blocking rendering. The Dart↔Rust bridge is powered by `flutter_rust_bridge` v2.12.0.

- **License**: GPL v3 — forked from [MostafaSensei106/Flutter-Dicom](https://github.com/MostafaSensei106/Flutter-Dicom)
- **Platforms**: Android, iOS, Linux, macOS, Windows, Web (WASM)
- **Version**: `0.3.0`

---

## Architecture

```
lib/
  dicom_toolkit.dart                 ← barrel: exports + DicomToolkit class
  dicom_toolkit_web.dart             ← no-op web plugin registration (WASM is loaded by FRB)
  src/
    platform/
      rust_library_web.dart          ← web init: loads WASM from the Flutter asset path
      rust_library_io.dart           ← native init; iOS/macOS resolve statically linked symbols
    backend/
      dicom_decoder.dart             ← DicomDecoder (abstract) + RustDecoder (FFI impl)
    core/
      dicom_tag_id.dart              ← DicomTagId (group, element) + 39 constants
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
    debug_log.dart                   ← conditional debug-only logger (kDebugMode)
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
        models/dicom_metadata.rs    ← 37-field struct + Default impl
        models/dicom_frame_result.rs← metadata + Vec<i16>
        constants/lib_constants.rs  ← DefaultConfigs consts
        utils/process_dicom_file.rs ← THE CORE: parses .dcm, extracts tags+pixels

assets/shaders/dicom_window.frag    ← GLSL: 16-bit unpack + HU + windowing + LUT

web/pkg/                            ← WASM + JS bindings (wasm-pack output, committed to git)

ios/
  dicom_toolkit.podspec             ← CocoaPods integration (cargokit script phase)
  dicom_toolkit/Package.swift       ← Swift Package Manager integration
  dicom_toolkit/dicom_toolkit.xcframework/  ← prebuilt *dynamic* Rust core (committed)

macos/                              ← same three pieces as ios/

test/
  dicom_tag_id_test.dart            ← 31 constants, equality, hex
  dicom_pixel_data_test.dart        ← sealed hierarchy, buffer
  dicom_window_preset_test.dart     ← 7 presets, forImage(), equality
  dicom_window_preset_for_image_test.dart ← forImage() edge cases
  dicom_metadata_test.dart          ← typed getters, tag(), pixelSpacing
  dicom_parse_result_test.dart      ← fromFrame, frame(), hasPixels
  dicom_roi_test.dart               ← compute(), copyWith, clamping
  dicom_ruler_test.dart             ← measure(), spacing fallback
  dicom_parser_test.dart            ← mocked decoder delegation
  dicom_renderer_test.dart          ← pack16Bit + applyWindowingRgba helpers
  dicom_color_map_lut_test.dart     ← ColorMapLut.generate for every map
  dicom_export_test.dart            ← PNG export + failure-path disposal
  dicom_viewer_controller_test.dart ← state lifecycle, error paths, CPU fallback
  dicom_controller_test.dart        ← controller lifecycle + windowing defaults
  dicom_viewer_test.dart            ← widget states (loading, error, empty)
  dicom_exceptions_test.dart        ← DicomException hierarchy
  features_test.dart                ← cross-tool integration
  dicom_integration_test.dart       ← real .dcm files via parser (dcms/ corpus
                                       groups self-skip when dcms/ is absent)
  dicom_reader_test.dart            ← readDicomInfo() with real files
```

---

## Data Flow

1. `DicomToolkit.init()` — loads the native library / WASM via `src/platform/rust_library_io.dart`
   or `rust_library_web.dart`:
   - Android/Windows/Linux: `RustLib.init()` → packaged shared library.
   - **iOS/macOS: the FFI symbols are resolved from the process image** — see
     `_initializeApple`. They are looked up by name at runtime, so there is nothing to
     `dlopen` by path, and the same code works whether the Rust core lives in the app
     binary or in an embedded framework. Under **CocoaPods** the podspecs inject the Rust
     archive into the *app* target with `-force_load` plus `DEAD_CODE_STRIPPING = NO` (in
     `user_target_xcconfig`, because `pod_target_xcconfig` never reaches the app link);
     without both, Release builds silently drop the whole Rust core. Under **Swift Package
     Manager** the symbols come from the committed dynamic `dicom_toolkit.xcframework`
     instead, so no codegen or force-linking happens at all (see *Apple integration*).
     The `cargo build --release` dylib is used when running from source. If nothing can be
     loaded, `DicomInitializationException` is thrown.
   - Web: WASM from the Flutter asset path.
2. `DicomParser.parse(bytes)` → `DicomDecoder.decode()` → `loadDicomFromBytes()` FFI
3. Rust `process_dicom_file.rs`: opens DICOM, extracts 37 tags + pixel spacing (with Imager Pixel Spacing fallback for X-ray), extracts `Vec<i16>` pixels (first frame only via dual-path: raw bytes for uncompressed, decoder for compressed)
4. `DicomParseResult.fromFrame()`: wraps generated metadata → `DicomMetadata` wrapper, packs pixels → `DicomInt16PixelData`
5. `DicomRenderer`: compiles GLSL shader, packs 16-bit → RGBA (+32768 offset), renders via `PictureRecorder` → `ui.Image`. Without a shader it falls back to `_renderCpu` (windowing + color map + invert + MONOCHROME1 + rotation in Dart).
6. `DicomViewer`: `CustomPaint` → `DicomShaderPainter` → shader (windowing + HU + color LUT), wrapped in `Transform.rotate`. With no shader it renders `controller.rawTexture` (the CPU-windowed image) via `RawImage`.

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
| 9 | `u_is_rgb` (flag — 1.0 = direct RGB, 0.0 = packed 16-bit monochrome) |
| sampler 0 | `u_texture` (RGBA-packed image) |
| sampler 1 | `u_color_lut` (256×1 LUT or dummy) |

---

## Build Commands

```bash
# Generate bridge (after any Rust struct change)
flutter_rust_bridge_codegen generate

# Build Rust (native)
cargo build && cargo build --release

# Build WASM (web) — use the convenience script:
.\tool\rebuild_wasm.ps1        # debug (fast compile)
.\tool\rebuild_wasm.ps1 -Release  # release (smaller .wasm)

# Build the Apple XCFrameworks (Swift Package Manager) — commit the result:
tool/rebuild_xcframework.sh          # both
tool/rebuild_xcframework.sh ios      # iOS only
tool/rebuild_xcframework.sh macos    # macOS only

# Tests
flutter test

# Lint
dart analyze lib

# Android: exercise android.newDsl=true (AGP 10 readiness) against android/ in place
dart run tool/agp_newdsl_probe.dart
```

**CRITICAL**: After changing any `rust/src/api/**/*.rs` struct:
1. `flutter_rust_bridge_codegen generate`
2. `cargo build && cargo build --release`
3. If web: `.\tool\rebuild_wasm.ps1`
4. If Apple (iOS/macOS): `tool/rebuild_xcframework.sh` and commit the updated folders
5. `flutter clean` in example if running there

### Web WASM artifacts

WASM binaries (`web/pkg/dicom_toolkit.js`, `web/pkg/dicom_toolkit_bg.wasm`) are
**committed to git**. Consumers get them automatically — no Rust toolchain needed.

`pubspec.yaml` declares `web/pkg/` as a Flutter asset. When a consuming app runs
`flutter build web`, the WASM files are bundled into
`assets/packages/dicom_toolkit/web/pkg/`. At runtime, `DicomToolkit.init()`
detects the web platform and loads the WASM from this asset path automatically.

When you modify `rust/src/`, rebuild with `.\tool\rebuild_wasm.ps1` and commit
the updated `web/pkg/` and `rust/pkg/` files. The script also strips the
`.gitignore` that `wasm-pack` creates (which would otherwise block the files) and
copies artifacts to all required locations.

### Apple integration (iOS + macOS)

Both platforms are supported through **two independent paths**, and both are
tested:

| Path | Trigger | Rust core comes from |
|------|---------|----------------------|
| Swift Package Manager | `ios/dicom_toolkit/Package.swift` exists (SPM is on by default in recent Flutter) | `dicom_toolkit.xcframework` |
| CocoaPods | app has a `Podfile` and SPM cannot be used | cargokit builds/links the Rust staticlib |

`Package.swift` is enough for Flutter to detect SPM support — it declares
`swift-tools-version: 5.9` (Flutter's minimum) and a single
`.binaryTarget(name: "dicom_toolkit", path: "dicom_toolkit.xcframework")`.
SPM cannot compile Rust, so the core ships as a **prebuilt dynamic
XCFramework** committed to git (`tool/rebuild_xcframework.sh` produces it for
`aarch64-apple-ios`, an `aarch64-apple-ios-sim` + `x86_64-apple-ios` simulator
slice, and a universal `arm64`+`x86_64` macOS slice). It must be *dynamic*,
not static: Flutter links the generated plugin package statically, and a static
Rust archive gets dead-stripped because the FFI symbols are only looked up by
name at runtime.

> Building the **example app** prints
> `Plugin dicom_toolkit has a Package.swift for ios but is missing a dependency on
> FlutterFramework`. That check looks for the literal string `FlutterFramework` in
> the manifest, and is only run for a plugin's own example app — consumers never
> see it. It does not apply here: the plugin has no Swift/ObjC target that
> `import Flutter`, and `binaryTarget` cannot declare dependencies. Do **not**
> add `.package(path: "../FlutterFramework")` just to silence it: that path only
> exists for a plugin built from its own checkout, so it would break consumers
> resolving this plugin from the pub cache. Flutter's own first-party plugins
> with `Package.swift` (e.g. `url_launcher_ios`) omit it too.

Because the Rust core can end up either inside the app binary (CocoaPods
static linkage) or inside an embedded framework (SPM), the Dart side resolves
symbols in this order — see `lib/src/platform/rust_library_io.dart`:

1. `DynamicLibrary.process()` — searches every loaded image, so it works in
   both layouts. Guarded by a probe for `frb_get_rust_content_hash` so a
   partially-loaded library isn't mistaken for a valid one.
2. `flutter_rust_bridge`'s own loader (dev-only `rust/target/release/*.dylib`).
3. Throw `DicomInitializationException` with a remediation hint.

`DEAD_CODE_STRIPPING = NO` is set in `user_target_xcconfig` by both podspecs,
but only matters on the CocoaPods path when the Rust code lands in the app
binary. Note this is applied app-wide, not to a single pod.

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

## Supported Android build matrix

Last verified 2026-09-20 against Flutter 3.47.0 (template defaults: Gradle 9.3.1, AGP 9.1.0,
Kotlin 2.4.0).

| Component | Supported | Verification |
|-----------|-----------|--------------|
| AGP | 8.13.1 – 9.1.x | Built a stock Flutter app + this plugin at path dependency with AGP 8.13.1 and 9.1.0 |
| AGP `android.newDsl=true` | 9.1.0 | `dart run tool/agp_newdsl_probe.dart` |
| Gradle | 8.14 – 9.3.1 | Same builds as above; Gradle 9 removed `Project.buildDir` **and** `Project.exec` |
| JDK (Gradle) | 17 – 21 | Gradle 8.14 refuses to run on JDK 25 |
| NDK | app's `flutter.ndkVersion` | AGP 9's default is r28c / 28.2.13676358 |
| module `compileSdk` | 36 | AAR `minCompileSdk` == 36, so no consumer override is needed |
| module `minSdk` | 24 | Flutter 3.47 hard-errors on app minSdk < 23 |

`android.build.gradle` uses property-assignment syntax (`compileSdk = 36`) throughout so it
parses under both DSL implementations. Do not reintroduce `compileSdkVersion 33`,
`minSdkVersion`, `applicationVariants`/`libraryVariants`, `android.sdkDirectory`,
`android.compileSdkVersion` or `sourceSets.*.jniLibs` — all of them break AGP 9's new DSL
(and therefore AGP 10).

---

## cargokit is a locally-patched vendored copy

`cargokit/` is a copy of [fzyzcjy/cargokit](https://github.com/fzyzcjy/cargokit) (the
maintained fork of the archived `irondash/cargokit`) as vendored by flutter_rust_bridge's
`integrate` backend. **`cargokit/gradle/plugin.gradle` is patched locally and must not be
re-synced blindly** — its header comment lists every deviation with a Tier A / Tier B label:

- **Tier A** (Gradle 9): `project.buildDir` → `project.layout.buildDirectory`, `project.exec`
  → injected `ExecOperations`.
- **Tier B** (AGP 10 readiness): `androidComponents.onVariants` instead of the legacy variant
  API, `androidComponents.sdkComponents.sdkDirectory`, `CommonExtension.compileSdk`,
  `variant.minSdk.apiLevel`, and `variant.sources.jniLibs.addGeneratedSourceDirectory(...)`
  instead of `AndroidSourceSet.jniLibs` + the `merge<BuildType>NativeLibs` hook.

Upstream main already contains the `ExecOperations` fix, so when upstream lands Tier B a sync
only needs to re-apply the Tier B block. Known remaining upstream-inherited warning:
`Invocation of Task.project at execution time` (the task action reads `project.cargokit`); it
is a Gradle-10 error, not an AGP deprecation.

---

## Common Pitfalls

1. **Editing generated code** — changes to `lib/src/rust/` will be overwritten by codegen
2. **Stale WASM** — after Rust struct changes, run `.\tool\rebuild_wasm.ps1` and commit updated `web/pkg/` + `rust/pkg/`
3. **Stale DLL** — after codegen, both `cargo build` (debug) and `cargo build --release` must run
4. **Shader asset path** — use `LibShaders.dicomWindow` constant, not a raw string
5. **SSE vs DCO codec** — `flutter test` uses DCO (VM FFI), `flutter run` uses SSE (serialized). Both need matching DLLs
6. **SSE large-data bottleneck** — on web, SSE copies every `List<int>` arg JS→WASM (150+ MB = seconds + ~2 GB RAM). DCO (zero-copy) is available when `crossOriginIsolated: true` but flutter_rust_bridge 2.12 codegen doesn't emit it — see [upstream issue]
7. **Web shader fallback** — `FragmentProgram.fromAsset()` unsupported on CanvasKit; renderer catches compile failure and falls back to CPU windowing via `RawImage`
8. **Stale XCFramework** — after any `rust/src/` change, run `tool/rebuild_xcframework.sh` and commit `ios/dicom_toolkit/dicom_toolkit.xcframework/` + `macos/dicom_toolkit/dicom_toolkit.xcframework/`; SPM builds run no codegen and will silently keep the old binary otherwise
9. **iOS FFI symbols dead-stripped** — the Rust symbols must survive linking; never let `-dead_strip` remove them (see *Apple integration* above)
