# dicom_toolkit

**A composable DICOM imaging toolkit for Flutter.** GPU-accelerated rendering, interactive measurement, and clinical precision — across mobile, desktop, and web.

[![pub](https://img.shields.io/badge/pub-dicom__toolkit-blue)](https://pub.dev/packages/dicom_toolkit)
[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](LICENSE)

> **Forked from [MostafaSensei106/Flutter-Dicom](https://github.com/MostafaSensei106/Flutter-Dicom)** — the original Rust+DICOM FFI bridge, GPU shader, and 16-bit precision pipeline. This project extends it with a composable toolkit API, web support, measurement tools, rotation, pixel-spacing-aware rulers, and modality-agnostic windowing presets. Licensed under GPL v3 in compliance with the original.

> **[Live example → dicomtoolkit.pages.dev](https://dicomtoolkit.pages.dev/)** — try the toolkit in your browser.

> **[pub.dev → dicom_toolkit](https://pub.dev/packages/dicom_toolkit)**


> **What's next?** See [NEXT.md](NEXT.md) for the roadmap.


---

## The kit

| Tool | What it does |
|------|-------------|
| `DicomToolkit` | Entry point — `init()` loads the native engine, `render()` is a one-liner |
| `DicomParser` | Parses DICOM bytes (or files) into `DicomParseResult` (metadata + pixels) |
| `DicomDecoder` | Pluggable decoder interface — default `RustDecoder` hits the Rust FFI |
| `DicomRenderer` | GPU pipeline: compile shader → pack 16-bit texture → apply windowing + color LUT |
| `DicomRoi` | Draw a rectangle, get `RoiStatistics` (min, max, mean, stdDev, median) |
| `DicomRuler` | Measure distance in mm using pixel spacing (with Imager Pixel Spacing fallback for X-ray) |
| `DicomExport` | Render + encode to PNG bytes — works on web (no `dart:io`) |
| `DicomWindowPreset` | Named presets: CT Hounsfield + modality-agnostic `forImage()` from pixel range |
| `DicomViewerController` | Reactive state manager — loading, windowing, color, invert, rotation |
| `DicomViewer` | Interactive widget: GPU rendering, pinch-zoom, windowing drag, rotation |

### Data types

| Type | Description |
|------|------------|
| `DicomTagId` | Immutable DICOM tag (group, element) — 31 predefined constants |
| `DicomMetadata` | 35 typed getters + generic `tag()` lookup + `bestDate` resolution |
| `DicomPixelData` | Sealed class — `DicomInt16PixelData` for 16-bit monochrome |
| `DicomParseResult` | Parsed frame: `metadata` + `pixelData` + `frame()` + `computeRoi()` |
| `DicomColorMap` | Enum: `grayscale`, `hotIron`, `pet`, `rainbow`, `cool`, `bone` |
| `RoiStatistics` | `pixelCount`, `min`, `max`, `mean`, `stdDev`, `median` |

---

## Quick start

```dart
import 'package:dicom_toolkit/dicom_toolkit.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DicomToolkit.init();
  runApp(const MyApp());
}
```

### One-liner render

```dart
final parser = const DicomParser();
final result = await parser.parse(fileBytes);
final image  = await DicomToolkit.render(result,
  windowCenter: 40, windowWidth: 400,
);
```

### Full viewer

```dart
final controller = DicomViewerController();
await controller.loadFromBytes(bytes: fileBytes);
// In your widget tree:
DicomViewer(controller: controller)

// Don't forget:
@override void dispose() { controller.dispose(); super.dispose(); }
```

### Metadata-only (no GPU)

```dart
final info = await readDicomInfo('/path/to/scan.dcm');
print(info.metadata.patientName);   // "John Doe"
print(info.metadata.modality);      // "CT"
```

---

## Every tool, with examples

### `DicomParser` — parse DICOM bytes

```dart
const parser = DicomParser();                         // default: RustDecoder
// const parser = DicomParser(decoder: myDecoder);    // inject custom backend

final result = await parser.parse(bytes);             // DicomParseResult (metadata + pixels)
final meta   = await parser.parseMetadata(bytes);     // DicomMetadata only — skipPixels: true, no GPU needed
```

### `DicomRenderer` — GPU rendering pipeline

```dart
final renderer = DicomRenderer(
  colorMap: DicomColorMap.grayscale,
  invert: false,
);

final texture = await renderer.createTexture(result);      // pack 16-bit → RGBA
final image   = await renderer.render(result,              // full pipeline
  windowCenter: 40, windowWidth: 400,
  colorMap: DicomColorMap.hotIron,
  rotationSteps: 1,                                        // 90° CW
);
```

### `DicomWindowPreset` — modality-agnostic presets

```dart
// Image-adaptive presets (works on CT, MR, X-ray, US):
final presets = DicomWindowPreset.forImage(result);
// → [Full Range, DICOM Default, Mid 50%, Narrow 25%, High, Low]

// Or use CT-specific Hounsfield presets:
const bone = DicomWindowPreset.bone();                   // W:2000, C:500
const lung = DicomWindowPreset.lung();                   // W:1500, C:-500

// All built-in CT presets:
DicomWindowPreset.all;  // bone, lung, softTissue, brain, liver, mediastinum, spine
```

### `DicomRoi` — region of interest statistics

```dart
const roi = DicomRoi(x: 100, y: 100, width: 50, height: 50);
final stats = roi.compute(result);
// or: final stats = result.computeRoi(roi);

print(stats.mean);     // 342.5
print(stats.stdDev);   // 87.3
print(stats.min);      // 102
print(stats.max);      // 1892
print(stats.median);   // 298
print(stats.pixelCount); // 2500
```

### `DicomRuler` — real-world distance

```dart
const ruler = DicomRuler();

// Measure between two pixel points:
final mm = ruler.measure(result.metadata,
  (x: 100, y: 200),    // DicomPoint = ({double x, double y})
  (x: 350, y: 200),
);
print('${mm.toStringAsFixed(1)} mm');  // e.g. "125.3 mm"

// Uses Pixel Spacing (0028,0030) — falls back to Imager Pixel Spacing
// (0018,1164) for CR/DX X-ray files.  Falls back to pixel units if neither
// tag is present.
```

### `DicomExport` — PNG output (web-safe)

```dart
const exporter = DicomExport();

final pngBytes = await exporter.toPngBytes(result,
  windowCenter: 40,
  windowWidth: 400,
  colorMap: DicomColorMap.grayscale,
  invert: false,
  rotationSteps: controller.rotationSteps,  // matches display
);
// Write to disk, share, or trigger a browser download — your choice.
```

### `DicomViewerController` — reactive state

```dart
final controller = DicomViewerController();

// Windowing
controller.updateWindowing(center: 40, width: 400);
controller.adjustWindowing(deltaX: 10, deltaY: -5);  // drag gesture
controller.resetWindowing();                           // back to DICOM defaults
controller.applyPreset(center: preset.center, width: preset.width);

// Rotation
controller.rotateClockwise();         // 0° → 90° → 180° → 270° → 0°
controller.rotateCounterClockwise();  // reverse
controller.rotationSteps;             // 0–3

// Display
await controller.setColorMap(DicomColorMap.hotIron);
controller.toggleInvert();
controller.isMonochrome1;              // true for CR/DX

// Lifecycle
controller.clear();                   // frees current image
controller.dispose();                 // frees GPU resources
```

### `DicomViewer` — interactive widget

```dart
DicomViewer(
  controller: controller,
  interactive: true,                   // enables drag-windowing + pinch-zoom
  fit: BoxFit.contain,
)

// Set interactive: false when an outer widget needs to capture
// taps/pans for measurement tools.
```

### `DicomTagId` — tag constants for generic lookup

```dart
// 31 predefined constants:
DicomTagId.patientName               // (0010,0010)
DicomTagId.modality                  // (0008,0060)
DicomTagId.pixelSpacing              // (0028,0030)
DicomTagId.imagerPixelSpacing        // (0018,1164)
DicomTagId.toothNumber               // (0018,6032) — ISO 3950 FDI

// Create custom tags:
const tag = DicomTagId.fromParts(0x0020, 0x0032);   // ImagePositionPatient
final tag = DicomTagId.fromHex('00100010');          // PatientName

// Generic lookup:
meta.tag(DicomTagId.patientName);    // "John Doe"
meta.allTags;                        // Map<DicomTagId, String>
```

### `bestDate` — resolve the most relevant date

```dart
// DICOM files can carry up to four date tags: Study Date (0008,0020),
// Series Date (0008,0021), Acquisition Date (0008,0022), and
// Content Date (0008,0023).  `bestDate` returns the most recent valid
// one that is not in the future:

final date = result.metadata.bestDate;  // DateTime? — null if none valid
if (date != null) {
  print('${date.year}-${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}');
}

// All four raw date strings are also available as typed getters:
print(result.metadata.studyDate);        // "20240315" or "Unknown"
print(result.metadata.seriesDate);       // "20240314" or "Unknown"
print(result.metadata.acquisitionDate);  // "20240314" or "Unknown"
print(result.metadata.contentDate);      // "20240315" or "Unknown"
```

---

## 37 extracted DICOM tags

| Category | Tags |
|---|---|
| Patient | `patientId`, `patientName`, `studyDescription` |
| Dates | `studyDate`, `seriesDate`, `acquisitionDate`, `contentDate` |
| Dental | `toothInfo` (tries standard Tooth Number, Tooth Region, then 6 vendor private tags) |
| Equipment | `modality`, `manufacturer`, `manufacturerModelName`, `institutionName` |
| UIDs | `studyInstanceUid`, `seriesInstanceUid`, `sopInstanceUid` |
| Acquisition | `seriesDescription`, `bodyPartExamined`, `sliceThickness`, `instanceNumber` |
| Image | `width`, `height`, `samplesPerPixel`, `bitsAllocated`, `bitsStored`, `highBit`, `pixelRepresentation`, `photometricInterpretation`, `pixelSpacing` |
| Spatial | `imagePositionPatient`, `imageOrientationPatient`, `sliceLocation`, `spacingBetweenSlices` |
| Volume | `numberOfFrames` |
| Windowing | `windowCenter`, `windowWidth`, `rescaleIntercept`, `rescaleSlope` |

### Computed properties

| Property | Returns | Logic |
|---|---|---|
| `isMultiFrame` | `bool` | `numberOfFrames > 1` |
| `hasSpatialInfo` | `bool` | `imagePositionPatient` non-empty AND (`spacingBetweenSlices > 0` OR `sliceThickness > 0`) |
| `isVolumetric` | `bool` | `isMultiFrame OR hasSpatialInfo` — true for multi-frame cine/MFSC, enhanced CT/MR, or single slices with 3D placement |

---

## Web support

The web target compiles Rust to WASM with threading (`SharedArrayBuffer`). This requires three things:

### 1. Prerequisites

Nightly Rust (for `build-std` with atomics) and `wasm-pack`:

```bash
rustup toolchain install nightly
rustup +nightly target add wasm32-unknown-unknown
cargo install wasm-pack
```

### 2. Build WASM

After any change to `rust/src/api/**`, rebuild the WASM binary:

```bash
.\tool\rebuild_wasm.ps1          # debug (fast compile)
.\tool\rebuild_wasm.ps1 -Release  # release (smaller .wasm, ~1.3 MB)
```

The script compiles the Rust crate to WASM, copies the artifacts to `web/pkg/` and `rust/pkg/`, and strips the `.gitignore` that `wasm-pack` creates.

WASM artifacts are **committed to git** — consumers get them automatically via Flutter's asset system. No manual copy step, no Rust toolchain required on the consumer side.

### 3. Build + serve the Flutter app

```bash
cd example
flutter build web
python serve_debug.py    # starts http://localhost:8080
```

The `serve_debug.py` script injects the required **cross-origin isolation headers**:
- `Cross-Origin-Opener-Policy: same-origin`
- `Cross-Origin-Embedder-Policy: require-corp`

Without these, `SharedArrayBuffer` is disabled by the browser and the WASM worker pool crashes with `DataCloneError`.

> **Web performance note:** The SSE bridge copies every `List<int>` argument from JS→WASM. For large multi-frame DICOMs (150+ MB), this adds seconds of latency and ~2 GB peak RAM. On native platforms, DCO passes a pointer with zero copy. flutter_rust_bridge 2.12 does not auto-select DCO on web even when `crossOriginIsolated: true` — see the [upstream issue tracker](https://github.com/fzyzcjy/flutter_rust_bridge/issues). As a mitigation, the Rust decoder only extracts the first frame's pixel data (raw-byte fast path for uncompressed DICOM, decoder fallback for compressed).

> **Shader fallback:** `FragmentProgram.fromAsset()` is unsupported on CanvasKit (web). The renderer catches the compile failure and applies windowing in pure Dart, displaying the result via `RawImage` instead of the GPU shader.

### VS Code launch config

Alternatively, use this launch configuration to serve from VS Code:

```json
{
  "name": "dicom_toolkit (web)",
  "type": "dart",
  "request": "launch",
  "program": "example/lib/main.dart",
  "deviceId": "chrome",
  "args": [
    "--web-header=Cross-Origin-Opener-Policy=same-origin",
    "--web-header=Cross-Origin-Embedder-Policy=require-corp"
  ]
}
```

---

## License

**GPL v3** — see [LICENSE](LICENSE).

Original work copyright (c) 2024 MostafaSensei106 ([Flutter-Dicom](https://github.com/MostafaSensei106/Flutter-Dicom)). Modifications and extensions copyright (c) 2026 dicom_toolkit contributors.
