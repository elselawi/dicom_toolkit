# NEXT.md — dicom_toolkit roadmap

Suggestions for the next features, sorted by estimated effort.

---

### Pixel probe

**What:** Hover or tap any pixel to see its Hounsfield Unit (or modality-specific value) in an overlay tooltip.

**Why:** Surgeons and radiologists constantly probe images during reading. This is the single most-requested viewer feature.

**Implementation:** The `DicomInt16PixelData.buffer` already holds the full 16-bit array. Map a `GestureDetector` tap/pan position → image pixel coordinates (the same `_toImagePixel` helper already exists in the example app) → index into the buffer. Display as `HU: 42 (raw: -962)` in a small positioned overlay. Account for rotation and zoom. Use the `DicomRuler` pixel-spacing logic to optionally show the mm coordinates.

---

### Frame navigation

**What:** Next/previous frame buttons plus a slider to scrub through multi-frame DICOMs (cine, MFSC, enhanced CT).

**Why:** The 400-frame CT your example app loaded shows only frame 1. Users need to view all frames. This is the natural next step after `frameCount` and `numberOfFrames` extraction.

**Implementation:** Add `currentFrame: int` to `DicomViewerController`. The Rust decoder currently only extracts frame 1 — to support navigation, either:
- **(A) Single-pass:** decode only the requested frame (modify the Rust `process_dicom_file.rs` to accept a `frameIndex` parameter and slice `raw_bytes[frameIndex*frameBytes .. (frameIndex+1)*frameBytes]`).
- **(B) All-frames:** decode all frames and cache them on the Dart side (memory-heavy for large datasets).
- **(C) Lazy:** decode on-demand per frame index.

Approach (A) is preferred — one FFI call per frame change. Add a `ThumbnailSlider` widget that shows a mini preview strip when available.

---

### Cine playback

**What:** Play/pause/stop controls for multi-frame datasets. Configurable frame rate (1–60 fps). Loop mode.

**Why:** Cine loops are standard for cardiac, angiography, and dynamic studies. Builds directly on frame navigation.

**Implementation:** Add a `play()` / `pause()` / `stop()` API to `DicomViewerController`. Use a `Timer.periodic` or `Ticker` to advance `currentFrame`. Add FPS selector. Auto-detect reasonable frame rate from DICOM tags (`CineRate`, `FrameTime`, `FrameTimeVector`). Add a transport bar widget with play/pause/stop icons, frame counter (`42 / 400`), and a scrubber.

---

### Scale bar overlay

**What:** A calibrated line drawn on the image showing real-world distance (e.g. `├── 5 cm ──┤`).

**Why:** Every medical image viewer has one. Builds trust that measurements are calibrated.

**Implementation:** Read `pixelSpacingX`/`pixelSpacingY` from metadata. Choose a "nice" physical length (1, 2, 5, 10, 20, 50, 100 mm). Draw a line + label in the bottom corner of the viewport. Update on zoom. A 30-minute feature.

---

### Orientation markers

**What:** Display `L`/`R`, `A`/`P`, `H`/`F` (or `S`/`I`) labels in the image corners based on `imageOrientationPatient` direction cosines.

**Why:** Standard DICOM viewer convention. Prevents left/right confusion — a critical patient safety feature.

**Implementation:** Parse the 6 direction cosines from `imageOrientationPatient` (tag 0020,0037). Map the row and column vectors to anatomical directions using a lookup table (e.g., `[1,0,0,0,1,0]` = axial, row→right, col→anterior). Render text labels at the four corners of the image. Auto-hide when `imageOrientationPatient` is absent.

---

### Window preset save/load

**What:** Users can save custom window presets (name + center + width) and reload them. Presets persist across sessions.

**Why:** Radiologists tune windowing per study type, per preference. Built-in presets (`bone`, `lung`, etc.) are CT-only — users need custom presets for MR, US, XA, and their own reading style.

**Implementation:** Add `savePreset(name, center, width)` and `deletePreset(name)` to the controller. Serialize to JSON via `shared_preferences`. Add a "Save current" button in the controls panel. Show user presets in the quick-preset chips alongside built-in ones. Distinguish with a different chip color or icon.

---

### JPEG/TIFF export

**What:** Export rendered frames as JPEG or TIFF in addition to the existing PNG export.

**Why:** JPEG is smaller for sharing; TIFF preserves 16-bit precision for secondary processing.

**Implementation:** For JPEG: `ui.Image.toByteData(format: ImageByteFormat.rawRgba)` → encode with `dart:ui` (limited) or the `image` package. For TIFF: the `image` package supports 16-bit grayscale TIFF encoding. Expose format as an enum parameter on `DicomExport.toBytes()`. TIFF export could bypass the renderer entirely — write the raw `Int16List` buffer directly for true 16-bit preservation.

---

### Volumetric stack navigation

**What:** Load an entire DICOM series (directory of `.dcm` files), sort by spatial position, and scroll through slices with the mouse wheel or a slider.

**Why:** Conventional CT/MR studies are stored as one file per slice. Loading a single file shows only one slice — useless for diagnosis. A stack navigator turns the toolkit into an actual viewer.

**Implementation:** New `DicomSeriesLoader` class that accepts a directory path (native) or a list of file bytes (web). Sorts files by `imagePositionPatient.z`, `sliceLocation`, or `instanceNumber`. Loads metadata for all slices on init (fast, `skipPixels: true`), then lazily loads pixel data for the visible slice ± a few neighbors. Scroll-wheel changes the active slice. Display `Slice 17 / 256` with position info. Consider caching the previous/next 3 slices for smooth scrolling.

---

### Annotation overlay

**What:** Draw measurement lines, rectangles, ellipses, angles, and free-text labels on the image. Measurements displayed in mm or HU.

**Why:** Every diagnostic workstation has annotation tools. ROI statistics are already supported — this extends to graphical overlays.

**Implementation:** New `AnnotationPainter` layer above the `DicomViewer`. Store annotations as a list of `Annotation` objects (sealed class hierarchy: `LineAnnotation`, `RectAnnotation`, `EllipseAnnotation`, `AngleAnnotation`, `TextAnnotation`). Each holds pixel coordinates and metadata. Add an `AnnotationToolbar` with mode buttons. Serialize annotations to JSON for save/load. Use `DicomRuler` for mm-based measurements on line annotations. Undo/redo via a simple command stack.

---

### DICOM writing

**What:** Write a valid DICOM file from pixel data + metadata. Primary use case: saving annotated images as DICOM Secondary Capture.

**Why:** Annotations are useless if they can't be saved back into the clinical workflow. DICOM SC is the standard way to persist marked-up images.

**Implementation:** The `dicom` crate v0.9 supports encoding via `dicom_object::mem::InMemDicomObject` + `dicom_object::to_writer`. Build an object with the original metadata + new SOP Instance UID + burned-in annotation indicator. Write pixel data from the rendered `ui.Image` (or from the raw `Int16List` for 16-bit preservation). Add `DicomWriter.writeSecondaryCapture(result, annotations, outputPath)`. Note: GPL licensing must be considered for downstream use.

---

### MPR — Multi-Planar Reconstruction

**What:** Given a loaded volumetric stack, reconstruct axial, sagittal, and coronal slices at arbitrary positions.

**Why:** Standard on all CT workstations. A volume isn't useful without orthogonal views.

**Implementation:** Requires volumetric stack navigation (above). For each orthogonal plane, sample the volume along the intersection line using trilinear interpolation. This is a pixel-by-pixel operation in pure Dart — expect ~100ms per reformat for a 512³ volume. Cache reformatted slices. Add a `MprViewer` widget with three linked panels (axial/sagittal/coronal) and cross-reference lines showing the other planes' positions. Pre-compute lookup tables for the major axes.

---

### 3D MIP/MinIP

**What:** Maximum (or minimum) intensity projection through the volume along the viewing direction. Rotatable.

**Why:** MIP is the standard 3D-like view for CT angiography and chest studies. Much simpler than full volume rendering.

**Implementation:** For each pixel in the output image, cast a ray through the volume and take the max (or min) value encountered. Rotate the volume by adjusting the ray direction. Pure Dart implementation is feasible for volumes up to 512³ at interactive rates (~200ms per frame). Add a `MipViewer` widget with rotation controls. Use nearest-neighbor sampling initially; add trilinear later.

---

### DICOMweb client

**What:** Query (`QIDO-RS`) and retrieve (`WADO-RS`) studies/series/images from a PACS server over HTTP.

**Why:** Enables the toolkit to work in a zero-install web environment pulling directly from hospital PACS. No file picker needed.

**Implementation:** HTTP client (`package:http` or `dart:io` `HttpClient`). Build QIDO-RS query URLs with DICOM tag filters. Parse JSON response into study/series/instance lists. WADO-RS retrieval downloads DICOM byte streams. Add `DicomWebSource` implementing `DicomDecoder` so the parser API is unchanged. Handle authentication (OAuth2, API keys). Test against Orthanc or DCM4CHEE.

---

### Structured report rendering

**What:** Parse and display DICOM Structured Report (SR) documents — measurement tables, findings, and coded concepts.

**Why:** Many modalities (ultrasound, mammography, nuclear medicine) produce SR documents alongside images. Displaying them completes the reading experience.

**Implementation:** The `dicom` crate already parses SR content tree. Extract measurement groups, coded concepts, and text findings. Render as a scrollable tree or table in the metadata panel. Link measurements to image annotations where possible (e.g., a "3.2 cm" measurement in the report highlights the corresponding ROI).

---

### Full DICOM network — C-STORE SCP/SCU, C-FIND, C-MOVE

**What:** Full DIMSE protocol implementation: send images to PACS (C-STORE SCU), receive images (C-STORE SCP), query (C-FIND), retrieve (C-MOVE).

**Why:** This is what separates a viewer from a workstation. Required for clinical integration.

**Implementation:** The `dicom` crate v0.9 includes `dicom-ul` (upper layer) for association negotiation and DIMSE messaging. Implement `CStoreScu` (push), `CStoreScp` (listen), `CFindScu` (query), and `CMoveScu` (retrieve). Each is a state machine managing association → message → release. Handle multiple concurrent associations. Add a `network/` module in the Rust core. Expose via `flutter_rust_bridge` as async Dart APIs. Configuration: AE titles, host, port, timeout. Test against DVTk, Orthanc, or DCM4CHEE.

---

### 3D volume rendering

**What:** Full GPU ray-casting with a transfer function editor. Bone, soft tissue, and custom presets.

**Why:** The gold standard for surgical planning and patient communication. A strong differentiator.

**Implementation:** Requires a compute shader or a fragment shader that performs ray-marching through a 3D texture. Upload the full volume as a 3D texture to the GPU. The shader accumulates color and opacity along each ray using a 1D transfer function texture. Add a `TransferFunctionEditor` widget (ramp editor with control points). Implement rotation via arcball. This is a major feature — expect 2–3 weeks for a basic implementation, months for a clinical-grade one. Consider using `flutter_gl` or raw OpenGL ES via FFI if `ui.FragmentProgram` proves insufficient.

---

### Segmentation tools

**What:** Brush, flood fill, threshold-based, and optionally AI-assisted segmentation. 3D surface rendering of segmented structures.

**Why:** Segmentation is the foundation of surgical planning, volumetric measurement, and 3D printing.

**Implementation:** Store segmentation as a `Uint8List` mask (same dimensions as the image) per frame. Brush tool: paint on the mask with a circular kernel. Flood fill: 4- or 8-connected region growing from a seed point. Threshold: select all pixels in a HU range. Surface extraction: marching cubes algorithm on the 3D mask volume to generate a triangle mesh. Render the mesh with a simple 3D engine. Undo/redo via mask snapshots. Export as DICOM SEG or STL. AI-assisted: integrate an ONNX runtime for pre-trained models (e.g., nnU-Net).

---

### PET/CT fusion

**What:** Overlay a PET (or SPECT) volume on the corresponding CT with an adjustable alpha/blend slider. Color-map PET, grayscale CT.

**Why:** Standard in oncology and nuclear medicine. PET shows metabolic activity; CT shows anatomy. They must be viewed together.

**Implementation:** Load two volumes that share a `FrameOfReferenceUID`. Verify spatial alignment by comparing `imagePositionPatient` and `imageOrientationPatient`. Register if misaligned (rigid registration as a stretch goal). Render PET with a hot-iron or rainbow color LUT; render CT in grayscale. Blend with an opacity slider (0 = CT only, 1 = PET only). Requires volumetric stack loaded for both modalities. Add a `FusionViewer` widget with synchronized scroll/zoom/pan across both volumes.

---

### Real-time MPR with crosshairs

**What:** Three orthogonal views (axial, sagittal, coronal) updated at 60fps with synchronized cross-reference lines and linked scrolling.

**Why:** This is what commercial workstations look like. The 3-panel layout with crosshairs is the industry-standard reading paradigm.

**Implementation:** Extends MPR (medium difficulty) with GPU acceleration. Render each orthogonal plane via a fragment shader that samples the 3D texture. Cross-reference lines are drawn by the shader based on the other planes' positions. Link scroll positions across all three panels. Requires the full volume uploaded as a 3D texture (see 3D volume rendering). The shader samples along the appropriate plane based on uniform parameters. This is achievable with `ui.FragmentProgram` by uploading the volume as a stack of 2D textures or a custom 3D texture encoding.
