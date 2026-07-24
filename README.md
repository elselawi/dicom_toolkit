# dicom_toolkit

**Workstation-grade DICOM imaging for Flutter.** A Rust-powered GPU rendering pipeline that delivers real-time windowing, 16-bit precision, and zero-UI-thread blocking — across mobile, desktop, and web.

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](LICENSE)
[![pub](https://img.shields.io/badge/pub-dicom__toolkit-blue)](https://pub.dev/packages/dicom_toolkit)

---

## The problem

Flutter's image pipeline stops at 8-bit RGBA. That's fine for JPEGs and PNGs. It's not fine when a radiologist is reading a CT scan and needs to distinguish 3,071 shades of gray.

Pure-Dart DICOM parsers exist, but they choke on volume — pushing 512×512×16-bit frames through a single-threaded Dart isolate while the UI freezes is not a clinical workflow. You need real-time contrast adjustment (windowing), you need Hounsfield Unit accuracy, and you need the GPU to do the math — not the Dart event loop.

**dicom_toolkit** moves the heavy lifting to where it belongs: a Rust native core for parsing and a GLSL fragment shader for rendering. Dart never touches the 16-bit data. The UI thread never blocks. The result is a viewer that feels like a native workstation, not a web app.

---

## Getting started

### Prerequisites

You need the Rust toolchain — install it once, and the build system handles everything else:

```bash
# macOS / Linux
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# Windows — download and run https://rustup.rs
```

For web builds, you'll also want the nightly toolchain and `wasm-pack`:

```bash
rustup toolchain install nightly
rustup +nightly target add wasm32-unknown-unknown
cargo install wasm-pack
```

### Install

```yaml
dependencies:
  dicom_toolkit: ^0.2.0
```

### Initialize

```dart
import 'package:dicom_toolkit/dicom_toolkit.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RustLib.init();   // loads the native Rust library
  runApp(const MyApp());
}
```

### Load and display

Loading is bytes-only across all platforms — read the file yourself (via `dart:io`, a file picker, or a PACS client), then hand the bytes to the controller:

```dart
final controller = DicomController();
await controller.initialize();
await controller.loadFromBytes(bytes: fileBytes);

// Drop this anywhere in your widget tree:
DicomViewer(controller: controller)
```

Don't forget to dispose:

```dart
@override
void dispose() {
  controller.dispose();   // frees GPU textures
  super.dispose();
}
```

### Windowing presets

```dart
controller.updateWindowing(center: 40, width: 400);   // soft tissue
controller.updateWindowing(center: -500, width: 1500); // lung
controller.resetWindowing();                           // back to DICOM defaults
```

### Metadata-only reads (no GPU required)

When you just need header information — file explorers, PACS indexers, batch processing — skip the controller entirely:

```dart
final info = await readDicomInfo('/path/to/scan.dcm');
print(info.metadata.patientName);  // "John Doe"
print(info.metadata.modality);     // "CT"
print(info.metadata.studyDate);    // "20240115"
```

No shader compilation. No texture allocation. Just one FFI round-trip.

---

## What you get

### 27 extracted DICOM tags

Every tag comes with automatic fallback defaults when the field is absent from the source file:

| Category | Tags | Examples |
|---|---|---|
| Patient & Study | `patientId`, `patientName`, `studyDate`, `studyDescription` | name, DOB, accession |
| Equipment | `modality`, `manufacturer`, `manufacturerModelName`, `institutionName` | "CT", "SIEMENS" |
| Identifiers | `studyInstanceUid`, `seriesInstanceUid`, `sopInstanceUid` | globally unique UIDs |
| Acquisition | `seriesDescription`, `bodyPartExamined`, `sliceThickness`, `instanceNumber` | "CHEST", 1.25 mm |
| Image geometry | `width`, `height`, `samplesPerPixel`, `bitsAllocated`, `bitsStored`, `highBit`, `pixelRepresentation`, `photometricInterpretation` | 512×512, 16-bit signed |
| Windowing | `windowCenter`, `windowWidth`, `rescaleIntercept`, `rescaleSlope` | default contrast values |

### GPU color maps

Six color LUTs rendered entirely on the GPU — no Dart-side color math:

| Map | Use case |
|---|---|
| `grayscale` | Default monochrome |
| `hotIron` | Classic thermal |
| `petHeat` | PET/SPECT fusion |
| `rainbow` | Perfusion studies |
| `cool` | Vascular |
| `bone` | Orthopedic |

```dart
await controller.setColorMap(DicomColorMap.hotIron);
await controller.setColorMap(DicomColorMap.grayscale); // switch back
```

### ROI measurement

Draw a rectangle, get statistics in Hounsfield Units:

```dart
final roi = Rect.fromLTWH(100, 100, 50, 50);
final stats = computeRoiStatistics(
  roi: roi,
  pixelData: frame.pixelData,
  imageWidth: metadata.width,
  imageHeight: metadata.height,
  rescaleSlope: metadata.rescaleSlope,
  rescaleIntercept: metadata.rescaleIntercept,
);
print('mean: ${stats.mean} HU, range: ${stats.min}-${stats.max} HU');
```

### MONOCHROME1 support

CR/DX and some MR series use inverted grayscale (MONOCHROME1 photometric interpretation). The shader detects and inverts these automatically. A manual toggle is also available:

```dart
controller.toggleInvert();
print(controller.isMonochrome1); // true for CR/DX
```

### PNG export

Save the current viewport as an image:

```dart
final pngBytes = await DicomExport.toPngBytes(controller.rawTexture!);
await File('export.png').writeAsBytes(pngBytes);
```

---

## Web support

The web target compiles Rust to WASM instead of using native FFI. Two things to know:

### 1. Cross-origin isolation

Threaded WASM requires `SharedArrayBuffer`, which browsers gate behind cross-origin isolation. Serve your app with these headers:

```
Cross-Origin-Opener-Policy: same-origin
Cross-Origin-Embedder-Policy: require-corp
```

The simplest way during development is a VS Code launch config:

```json
{
  "name": "dicom_toolkit (web)",
  "type": "dart",
  "request": "launch",
  "program": "lib/main.dart",
  "deviceId": "chrome",
  "args": [
    "--web-header=Cross-Origin-Opener-Policy=same-origin",
    "--web-header=Cross-Origin-Embedder-Policy=require-corp"
  ]
}
```

### 2. Shared-memory linker flags

When rebuilding the WASM binary with `wasm-pack`, you must include the full linker flag set that marks the module's memory as shared. The repository's `rust/.cargo/config.toml` already contains these. Without them, the `WorkerPool` will crash with `DataCloneError: #<Memory> could not be cloned` — a non-shared `WebAssembly.Memory` cannot be transferred between threads via `postMessage`. The required flags are:

```
-C target-feature=+atomics,+bulk-memory,+mutable-globals
-C link-args=--shared-memory
-C link-args=--max-memory=1073741824
-C link-args=--import-memory
-C link-args=--export=__heap_base
-C link-args=--export=__wasm_init_tls
-C link-args=--export=__tls_size
-C link-args=--export=__tls_align
-C link-args=--export=__tls_base
```

---


## How the pipeline works

The 16-bit precision trick is worth understanding. Flutter only accepts 8-bit RGBA textures. To preserve full diagnostic precision through that constraint, we pack each 16-bit pixel into two 8-bit channels:

```
Dart:  pixel[i] + 32768  →  R = high byte, G = low byte  →  ui.Image (rgba8888)
GLSL:  R×255, G×255  →  (R×256 + G) - 32768  →  HU = pixel × slope + intercept
```

The Dart side never decodes medical values — it just packs bytes. The fragment shader unpacks them on the GPU, applies the Hounsfield transform, and runs the windowing math. All in a single draw call.

---

## Contributing

Bug reports, feature ideas, and pull requests are welcome. Before diving into a large change, please open an issue first.

- Read [CONTRIBUTING.md](CONTRIBUTING.md) for the full process
- Read [CLA.md](CLA.md) — all contributors must accept the Contributor License Agreement
- The project is GPL v3. Commercial users who cannot comply with GPL terms may contact the author about a separate license

---

## License

**GNU General Public License v3.0** — see [LICENSE](LICENSE).