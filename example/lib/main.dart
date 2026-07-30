import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:dicom_toolkit/dicom_toolkit.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart' show rootBundle;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DicomToolkit.init();
  runApp(const DicomExampleApp());
}

// ════════════════════════════════════════════════════════════
// App entry
// ════════════════════════════════════════════════════════════

class DicomExampleApp extends StatelessWidget {
  const DicomExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DICOM Toolkit',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.indigo,
      ),
      home: const ToolkitScreen(),
    );
  }
}

// ════════════════════════════════════════════════════════════
// Measurement state
// ════════════════════════════════════════════════════════════

enum MeasureMode { none, ruler, roi }

class _MeasureState {
  final MeasureMode mode;
  final Offset? start;
  final Offset? end;
  final RoiStatistics? stats;
  final double? rulerMm;

  const _MeasureState({
    this.mode = MeasureMode.none,
    this.start,
    this.end,
    this.stats,
    this.rulerMm,
  });

  _MeasureState copyWith({
    MeasureMode? mode,
    Offset? start,
    Offset? end,
    RoiStatistics? stats,
    double? rulerMm,
    bool clearStart = false,
    bool clearEnd = false,
    bool clearStats = false,
    bool clearRuler = false,
  }) =>
      _MeasureState(
        mode: mode ?? this.mode,
        start: clearStart ? null : (start ?? this.start),
        end: clearEnd ? null : (end ?? this.end),
        stats: clearStats ? null : (stats ?? this.stats),
        rulerMm: clearRuler ? null : (rulerMm ?? this.rulerMm),
      );
}

// ════════════════════════════════════════════════════════════
// Main screen
// ════════════════════════════════════════════════════════════

class ToolkitScreen extends StatefulWidget {
  const ToolkitScreen({super.key});

  @override
  State<ToolkitScreen> createState() => _ToolkitScreenState();
}

class _ToolkitScreenState extends State<ToolkitScreen> {
  final _controller = DicomViewerController();
  final _viewerKey = GlobalKey();
  String? _currentFileName;
  _MeasureState _measure = const _MeasureState();
  final _ruler = const DicomRuler();

  @override
  void initState() {
    super.initState();
    _loadSample();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // ── File ──────────────────────────────────────────────────

  Future<void> _loadSample() async {
    try {
      final bytes = await rootBundle.load('dicom_samples/sample.dcm');
      await _loadBytes(bytes.buffer.asUint8List(), name: 'sample.dcm');
    } catch (_) {
      // Sample not available — user can still pick a file.
    }
  }

  Future<void> _pickFile() async {
    final result =
        await FilePicker.pickFiles(type: FileType.any, withData: true);
    final file = result?.files.single;
    final bytes = file?.bytes;
    if (file == null || bytes == null) return;
    await _loadBytes(bytes, name: file.name);
  }

  Future<void> _loadBytes(Uint8List bytes, {required String name}) async {
    _currentFileName = name;
    _measure = const _MeasureState();
    try {
      await _controller.loadFromBytes(bytes: bytes);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load DICOM: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  // ── Export ─────────────────────────────────────────────────

  Future<void> _exportPng(BuildContext context) async {
    final res = _controller.result;
    if (res == null || !mounted) return;

    final exporter = const DicomExport();
    final bytes = await exporter.toPngBytes(
      res,
      windowCenter: _controller.windowCenter,
      windowWidth: _controller.windowWidth,
      colorMap: _controller.colorMap,
      invert: _controller.invert,
      rotationSteps: _controller.rotationSteps,
    );
    final name = _currentFileName?.split(RegExp(r'[/\\]')).last ?? 'dicom';

    await FilePicker.saveFile(
      bytes: bytes,
      dialogTitle: 'Save DICOM as PNG',
      fileName: '$name.png',
      type: FileType.custom,
      allowedExtensions: ['png'],
    );
  }

  // ── Measurement helpers ────────────────────────────────────

  /// Map a point in the viewer widget's local coordinates to DICOM pixel
  /// coordinates, accounting for FittedBox(BoxFit.contain) layout.
  Offset _toImagePixel(Offset widgetLocal, Size widgetSize, Size imageSize) {
    if (imageSize.isEmpty || widgetSize.isEmpty) return Offset.zero;

    final imgAspect = imageSize.width / imageSize.height;
    final widgetAspect = widgetSize.width / widgetSize.height;

    double displayW, displayH, offsetX, offsetY;
    if (imgAspect > widgetAspect) {
      // Image is wider than widget — constrained by width, letterboxed top/bottom
      displayW = widgetSize.width;
      displayH = widgetSize.width / imgAspect;
      offsetX = 0;
      offsetY = (widgetSize.height - displayH) / 2;
    } else {
      // Image is taller or equal — constrained by height, letterboxed left/right
      displayH = widgetSize.height;
      displayW = widgetSize.height * imgAspect;
      offsetX = (widgetSize.width - displayW) / 2;
      offsetY = 0;
    }

    return Offset(
      ((widgetLocal.dx - offsetX) / displayW * imageSize.width)
          .clamp(0, imageSize.width - 1),
      ((widgetLocal.dy - offsetY) / displayH * imageSize.height)
          .clamp(0, imageSize.height - 1),
    );
  }

  void _onViewerTapDown(TapDownDetails details, Size imageSize) {
    if (_measure.mode == MeasureMode.none) return;

    final box = _viewerKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final local = box.globalToLocal(details.globalPosition);
    final viewerSize = box.size;

    if (_measure.mode == MeasureMode.ruler) {
      if (_measure.start == null) {
        setState(() {
          _measure = _measure.copyWith(
            start: _toImagePixel(local, viewerSize, imageSize),
            clearEnd: true,
            clearRuler: true,
          );
        });
      } else {
        final end = _toImagePixel(local, viewerSize, imageSize);
        final result = _controller.result;
        if (result != null) {
          final mm = _ruler.measure(
            result.metadata,
            (x: _measure.start!.dx, y: _measure.start!.dy),
            (x: end.dx, y: end.dy),
          );
          setState(() {
            _measure = _measure.copyWith(end: end, rulerMm: mm);
          });
        }
      }
    }
  }

  void _onViewerPanStart(DragStartDetails details, Size imageSize) {
    if (_measure.mode != MeasureMode.roi) return;
    final box = _viewerKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final local = box.globalToLocal(details.globalPosition);
    final viewerSize = box.size;
    setState(() {
      _measure = _measure.copyWith(
        start: _toImagePixel(local, viewerSize, imageSize),
        clearEnd: true,
        clearStats: true,
      );
    });
  }

  void _onViewerPanUpdate(DragUpdateDetails details, Size imageSize) {
    if (_measure.mode != MeasureMode.roi || _measure.start == null) return;
    final box = _viewerKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final local = box.globalToLocal(details.globalPosition);
    final viewerSize = box.size;
    setState(() {
      _measure = _measure.copyWith(
        end: _toImagePixel(local, viewerSize, imageSize),
      );
    });
  }

  void _onViewerPanEnd(DragEndDetails details, Size imageSize) {
    if (_measure.mode != MeasureMode.roi ||
        _measure.start == null ||
        _measure.end == null) {
      return;
    }
    final result = _controller.result;
    if (result == null) {
      return;
    }

    final s = _measure.start!;
    final e = _measure.end!;
    final roi = DicomRoi(
      x: s.dx < e.dx ? s.dx.toInt() : e.dx.toInt(),
      y: s.dy < e.dy ? s.dy.toInt() : e.dy.toInt(),
      width: (s.dx - e.dx).abs().toInt(),
      height: (s.dy - e.dy).abs().toInt(),
    );

    if (roi.width > 0 && roi.height > 0) {
      final stats = roi.compute(result);
      setState(() {
        _measure = _measure.copyWith(stats: stats);
      });
    }
  }

  void _clearMeasurement() {
    setState(() => _measure = const _MeasureState());
  }

  // ── Build ──────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          if (_controller.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!_controller.hasData) {
            return _buildEmptyState();
          }
          return _buildViewer();
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    final error = _controller.hasError ? _controller.errorMessage : null;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.biotech,
              size: 72,
              color:
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.4)),
          const SizedBox(height: 16),
          Text('DICOM Toolkit',
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text('Open a .dcm file to begin',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
          if (error != null) ...[
            const SizedBox(height: 16),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(error,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onErrorContainer,
                      fontSize: 13)),
            ),
          ],
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FilledButton.icon(
                onPressed: _loadSample,
                icon: const Icon(Icons.science),
                label: const Text('Load Sample'),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: _pickFile,
                icon: const Icon(Icons.folder_open),
                label: const Text('Open DICOM File'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildViewer() {
    final fileName =
        _currentFileName?.split(RegExp(r'[/\\]')).last ?? 'Unknown';
    final meta = _controller.result!.metadata;
    final imageSize = Size(meta.width.toDouble(), meta.height.toDouble());
    print(
        '[EXAMPLE] _buildViewer: hasData=${_controller.hasData} hasError=${_controller.hasError} '
        'isLoading=${_controller.isLoading} rawTexture=${_controller.rawTexture != null} '
        'shader=${_controller.shader != null}');

    return LayoutBuilder(builder: (context, constraints) {
      final isWide = constraints.maxWidth > 600;
      final viewerPane = _buildViewerPane(imageSize);

      if (isWide) {
        return Row(children: [
          Expanded(flex: 3, child: viewerPane),
          SizedBox(
            width: 340,
            child: _ToolPanel(
              controller: _controller,
              fileName: fileName,
              measure: _measure,
              onPickFile: _pickFile,
              onExport: _exportPng,
              onMeasureMode: (m) => setState(() {
                _measure = _measure.copyWith(
                    mode: m,
                    clearStart: true,
                    clearEnd: true,
                    clearStats: true,
                    clearRuler: true);
              }),
              onClearMeasure: _clearMeasurement,
            ),
          ),
        ]);
      }

      return Column(children: [
        Expanded(flex: 5, child: viewerPane),
        Expanded(
          flex: 4,
          child: _ToolPanel(
            controller: _controller,
            fileName: fileName,
            measure: _measure,
            onPickFile: _pickFile,
            onExport: _exportPng,
            onMeasureMode: (m) => setState(() {
              _measure = _measure.copyWith(
                  mode: m,
                  clearStart: true,
                  clearEnd: true,
                  clearStats: true,
                  clearRuler: true);
            }),
            onClearMeasure: _clearMeasurement,
          ),
        ),
      ]);
    });
  }

  Widget _buildViewerPane(Size imageSize) {
    final meta = _controller.result!.metadata;
    final measuring = _measure.mode != MeasureMode.none;

    Widget viewerStack = Stack(
      key: _viewerKey,
      fit: StackFit.expand,
      children: [
        DicomViewer(
          controller: _controller,
          interactive: !measuring,
        ),

        // Measurement overlay
        if (measuring) _MeasureOverlay(measure: _measure, imageSize: imageSize),

        // Patient info overlay
        Positioned(
          bottom: 16,
          left: 16,
          right: 16,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        meta.modality == 'Unknown' ? 'DICOM' : meta.modality,
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(meta.patientName,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 15)),
                    Text(
                      '${_formatDateOrUnknown(meta.bestDate)}  ·  '
                      '${meta.width}×${meta.height}',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 12),
                    ),
                  ],
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _OverlayIconButton(
                      icon: Icons.folder_open,
                      onTap: _pickFile,
                      tooltip: 'Open file'),
                  const SizedBox(height: 6),
                  _OverlayIconButton(
                      icon: Icons.refresh,
                      onTap: _controller.resetWindowing,
                      tooltip: 'Reset windowing'),
                ],
              ),
            ],
          ),
        ),
      ],
    );

    if (!measuring) return viewerStack;

    // When measuring, wrap in a GestureDetector that captures taps/pans
    // before they reach the (now non-interactive) DicomViewer.
    return GestureDetector(
      onTapDown: (d) => _onViewerTapDown(d, imageSize),
      onPanStart: (d) => _onViewerPanStart(d, imageSize),
      onPanUpdate: (d) => _onViewerPanUpdate(d, imageSize),
      onPanEnd: (d) => _onViewerPanEnd(d, imageSize),
      child: viewerStack,
    );
  }
}

// ════════════════════════════════════════════════════════════
// Measurement overlay
// ════════════════════════════════════════════════════════════

class _MeasureOverlay extends StatelessWidget {
  const _MeasureOverlay({required this.measure, required this.imageSize});
  final _MeasureState measure;
  final Size imageSize;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final widgetSize = Size(constraints.maxWidth, constraints.maxHeight);
      final imgAspect = imageSize.width / imageSize.height;
      final widgetAspect = widgetSize.width / widgetSize.height;

      double displayW, displayH, offsetX, offsetY;
      if (imgAspect > widgetAspect) {
        displayW = widgetSize.width;
        displayH = widgetSize.width / imgAspect;
        offsetX = 0;
        offsetY = (widgetSize.height - displayH) / 2;
      } else {
        displayH = widgetSize.height;
        displayW = widgetSize.height * imgAspect;
        offsetX = (widgetSize.width - displayW) / 2;
        offsetY = 0;
      }

      return IgnorePointer(
        child: CustomPaint(
          size: Size.infinite,
          painter: _MeasurePainter(
            measure: measure,
            displayW: displayW,
            displayH: displayH,
            offsetX: offsetX,
            offsetY: offsetY,
            imageW: imageSize.width,
            imageH: imageSize.height,
            color: Theme.of(context).colorScheme.tertiary,
          ),
        ),
      );
    });
  }
}

class _MeasurePainter extends CustomPainter {
  _MeasurePainter({
    required this.measure,
    required this.displayW,
    required this.displayH,
    required this.offsetX,
    required this.offsetY,
    required this.imageW,
    required this.imageH,
    required this.color,
  });
  final _MeasureState measure;
  final double displayW, displayH, offsetX, offsetY;
  final double imageW, imageH;
  final Color color;

  /// Convert a DICOM pixel coordinate to a widget-local canvas coordinate.
  Offset _toCanvas(Offset pixel) => Offset(
        pixel.dx / imageW * displayW + offsetX,
        pixel.dy / imageH * displayH + offsetY,
      );

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    final start = measure.start;
    if (start == null) return;
    final s = _toCanvas(start);

    if (measure.mode == MeasureMode.ruler) {
      _crosshair(canvas, s, paint);
      if (measure.end != null) {
        final e = _toCanvas(measure.end!);
        _crosshair(canvas, e, paint);
        canvas.drawLine(s, e, paint..strokeWidth = 1.5);
        if (measure.rulerMm != null) {
          _label(canvas, e, '${measure.rulerMm!.toStringAsFixed(1)} mm', color);
        }
      }
    }

    if (measure.mode == MeasureMode.roi && measure.end != null) {
      final e = _toCanvas(measure.end!);
      final rect = Rect.fromPoints(s, e);
      canvas.drawRect(
          rect,
          paint
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5);
      canvas.drawRect(
          rect,
          paint
            ..color = color.withValues(alpha: 0.15)
            ..style = PaintingStyle.fill);
      if (measure.stats != null) {
        final st = measure.stats!;
        _label(
            canvas,
            Offset(rect.left + 4, rect.top + 14),
            'μ=${st.mean.toStringAsFixed(0)}  σ=${st.stdDev.isNaN ? "—" : st.stdDev.toStringAsFixed(0)}',
            color);
        _label(
            canvas,
            Offset(rect.left + 4, rect.top + 30),
            'min=${st.min.toStringAsFixed(0)}  max=${st.max.toStringAsFixed(0)}  n=${st.pixelCount}',
            color);
      }
    }
  }

  void _crosshair(Canvas canvas, Offset c, Paint paint) {
    const r = 6.0;
    canvas.drawCircle(c, r, paint);
    canvas.drawLine(Offset(c.dx - r - 3, c.dy), Offset(c.dx + r + 3, c.dy),
        paint..strokeWidth = 1);
    canvas.drawLine(
        Offset(c.dx, c.dy - r - 3), Offset(c.dx, c.dy + r + 3), paint);
  }

  void _label(Canvas canvas, Offset pos, String text, Color bg) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontFamily: 'monospace',
            fontWeight: FontWeight.w600,
            shadows: const [Shadow(blurRadius: 4, color: Colors.black)]),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(pos.dx - 3, pos.dy - tp.height - 2, tp.width + 6,
                tp.height + 4),
            const Radius.circular(3)),
        Paint()..color = bg.withValues(alpha: 0.7));
    tp.paint(canvas, Offset(pos.dx, pos.dy - tp.height - 1));
  }

  @override
  bool shouldRepaint(covariant _MeasurePainter o) => measure != o.measure;
}

// ════════════════════════════════════════════════════════════
// Overlay icon button
// ════════════════════════════════════════════════════════════

class _OverlayIconButton extends StatelessWidget {
  const _OverlayIconButton(
      {required this.icon, required this.onTap, this.tooltip});
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? '',
      child: Material(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(icon, size: 18, color: Colors.white70),
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
// Side panel: Controls · Measure · Metadata
// ════════════════════════════════════════════════════════════

class _ToolPanel extends StatefulWidget {
  const _ToolPanel({
    required this.controller,
    required this.fileName,
    required this.measure,
    required this.onPickFile,
    required this.onExport,
    required this.onMeasureMode,
    required this.onClearMeasure,
  });
  final DicomViewerController controller;
  final String fileName;
  final _MeasureState measure;
  final VoidCallback onPickFile;
  final void Function(BuildContext) onExport;
  final void Function(MeasureMode) onMeasureMode;
  final VoidCallback onClearMeasure;

  @override
  State<_ToolPanel> createState() => _ToolPanelState();
}

class _ToolPanelState extends State<_ToolPanel>
    with SingleTickerProviderStateMixin {
  late final _tabController = TabController(length: 3, vsync: this);

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      TabBar(controller: _tabController, tabs: const [
        Tab(icon: Icon(Icons.tune), text: 'Controls'),
        Tab(icon: Icon(Icons.straighten), text: 'Measure'),
        Tab(icon: Icon(Icons.info_outline), text: 'Metadata'),
      ]),
      Expanded(
        child: TabBarView(controller: _tabController, children: [
          _ControlsTab(
              controller: widget.controller,
              onPickFile: widget.onPickFile,
              onExport: widget.onExport),
          _MeasureTab(
              measure: widget.measure,
              onMode: widget.onMeasureMode,
              onClear: widget.onClearMeasure),
          _MetadataTab(
              controller: widget.controller, fileName: widget.fileName),
        ]),
      ),
    ]);
  }
}

// ════════════════════════════════════════════════════════════
// Controls tab
// ════════════════════════════════════════════════════════════

class _ControlsTab extends StatelessWidget {
  const _ControlsTab({
    required this.controller,
    required this.onPickFile,
    required this.onExport,
  });
  final DicomViewerController controller;
  final VoidCallback onPickFile;
  final void Function(BuildContext) onExport;

  @override
  Widget build(BuildContext context) {
    // Use actual pixel data range for slider bounds — not the DICOM header
    // values which are often useless (e.g. C:32768/W:65536 for 16-bit unsigned).
    final presets = DicomWindowPreset.forImage(controller.result!);
    final fullRange = presets.firstWhere(
      (p) => p.label == 'Full Range',
      orElse: () => presets.first,
    );
    final pixelMid = fullRange.center;
    final pixelRange = fullRange.width;
    // Level slider: cover the full pixel range ±50% margin
    final centerRange = (pixelRange * 1.5).clamp(100.0, 65536.0);
    final levelMin = (pixelMid - centerRange).floorToDouble();
    final levelMax = (pixelMid + centerRange).ceilToDouble();
    // Width slider: from 1 to 2× the pixel range
    final widthMax = (pixelRange * 2.0).clamp(4.0, 65536.0);

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // File actions
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onPickFile,
                    icon: const Icon(Icons.folder_open, size: 16),
                    label: const Text('Open', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => onExport(context),
                    icon: const Icon(Icons.save_alt, size: 16),
                    label: const Text('Export PNG',
                        style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact),
                  ),
                ),
              ]),
              const SizedBox(height: 16),

              // Presets from DicomWindowPreset toolkit
              Text('Quick Presets',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: presets.map((preset) {
                  final selected = controller.windowCenter == preset.center &&
                      controller.windowWidth == preset.width;
                  return ChoiceChip(
                    label: Text(preset.label,
                        style: const TextStyle(fontSize: 11)),
                    selected: selected,
                    onSelected: (_) => controller.applyPreset(
                        center: preset.center, width: preset.width),
                    visualDensity: VisualDensity.compact,
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              _LabeledSlider(
                label: 'Level',
                value: controller.windowCenter ?? pixelMid,
                min: levelMin,
                max: levelMax,
                onChanged: (v) => controller.updateWindowing(center: v),
              ),
              const SizedBox(height: 4),
              _LabeledSlider(
                label: 'Width',
                value: controller.windowWidth ?? pixelRange,
                min: 1,
                max: widthMax.ceilToDouble(),
                onChanged: (v) => controller.updateWindowing(width: v),
              ),
              const SizedBox(height: 12),

              Row(children: [
                OutlinedButton.icon(
                  onPressed: controller.resetWindowing,
                  icon: const Icon(Icons.restore, size: 16),
                  label: const Text('Reset', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact),
                ),
                const Spacer(),
                Text(
                  'L/W: ${controller.windowCenter?.toStringAsFixed(0) ?? '—'}/${controller.windowWidth?.toStringAsFixed(0) ?? '—'}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ]),
              const SizedBox(height: 12),

              // Rotation
              Row(children: [
                OutlinedButton.icon(
                  onPressed: controller.rotateCounterClockwise,
                  icon: const Icon(Icons.rotate_left, size: 16),
                  label: const Text('Rotate', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: controller.rotateClockwise,
                  icon: const Icon(Icons.rotate_right, size: 16),
                  label: const Text('Rotate', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact),
                ),
                const SizedBox(width: 8),
                Text(
                  '${controller.rotationSteps * 90}°',
                  style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ]),
              const SizedBox(height: 16),

              Text('Color Map',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: DicomColorMap.values.map((map) {
                  final isSelected = controller.colorMap == map;
                  return ChoiceChip(
                    label:
                        Text(map.label, style: const TextStyle(fontSize: 11)),
                    selected: isSelected,
                    onSelected: (_) => controller.setColorMap(map),
                    visualDensity: VisualDensity.compact,
                    selectedColor: isSelected
                        ? Theme.of(context).colorScheme.primaryContainer
                        : null,
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),

              ChoiceChip(
                label: const Text('Invert Grayscale',
                    style: TextStyle(fontSize: 11)),
                selected: controller.invert,
                onSelected: (_) => controller.toggleInvert(),
                visualDensity: VisualDensity.compact,
                avatar: Icon(
                  controller.invert
                      ? Icons.invert_colors
                      : Icons.invert_colors_off,
                  size: 16,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ════════════════════════════════════════════════════════════
// Measure tab
// ════════════════════════════════════════════════════════════

class _MeasureTab extends StatelessWidget {
  const _MeasureTab(
      {required this.measure, required this.onMode, required this.onClear});
  final _MeasureState measure;
  final void Function(MeasureMode) onMode;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Select Tool',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: ChoiceChip(
              label: const Text('None', style: TextStyle(fontSize: 12)),
              selected: measure.mode == MeasureMode.none,
              onSelected: (_) => onMode(MeasureMode.none),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ChoiceChip(
              label: const Text('📏 Ruler', style: TextStyle(fontSize: 12)),
              selected: measure.mode == MeasureMode.ruler,
              onSelected: (_) => onMode(MeasureMode.ruler),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ChoiceChip(
              label: const Text('⬜ ROI', style: TextStyle(fontSize: 12)),
              selected: measure.mode == MeasureMode.roi,
              onSelected: (_) => onMode(MeasureMode.roi),
            ),
          ),
        ]),
        const SizedBox(height: 16),
        if (measure.mode == MeasureMode.ruler) ...[
          _InfoCard(
            icon: Icons.touch_app,
            text: measure.start == null
                ? 'Tap two points on the image to measure distance.'
                : 'Tap the second point to complete measurement.',
          ),
        ],
        if (measure.mode == MeasureMode.roi)
          _InfoCard(
            icon: Icons.drag_indicator,
            text:
                'Drag to draw a rectangular ROI. Statistics appear on release.',
          ),
        if (measure.rulerMm != null) ...[
          const SizedBox(height: 12),
          _ResultCard(
            title: 'Distance',
            value: '${measure.rulerMm!.toStringAsFixed(1)} mm',
          ),
        ],
        if (measure.stats != null) ...[
          const SizedBox(height: 12),
          _ResultCard(
            title: 'ROI Statistics',
            value: [
              'Mean:  ${measure.stats!.mean.toStringAsFixed(0)}',
              'StdDev: ${measure.stats!.stdDev.isNaN ? "—" : measure.stats!.stdDev.toStringAsFixed(0)}',
              'Min:   ${measure.stats!.min.toStringAsFixed(0)}',
              'Max:   ${measure.stats!.max.toStringAsFixed(0)}',
              'Median:${measure.stats!.median.toStringAsFixed(0)}',
              'Count: ${measure.stats!.pixelCount} px',
            ].join('\n'),
          ),
        ],
        if (measure.mode != MeasureMode.none &&
            (measure.start != null || measure.rulerMm != null)) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onClear,
              icon: const Icon(Icons.clear, size: 16),
              label: const Text('Clear measurement',
                  style: TextStyle(fontSize: 12)),
              style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact),
            ),
          ),
        ],
      ]),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(children: [
        Icon(icon,
            size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text,
              style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ),
      ]),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.title, required this.value});
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .tertiaryContainer
            .withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color:
                Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: Theme.of(context).colorScheme.tertiary)),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════
// Labeled slider
// ════════════════════════════════════════════════════════════

class _LabeledSlider extends StatelessWidget {
  const _LabeledSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });
  final String label;
  final double value, min, max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final clamped = value.clamp(min, max);
    return Row(children: [
      SizedBox(
        width: 48,
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ),
      Expanded(
          child:
              Slider(value: clamped, min: min, max: max, onChanged: onChanged)),
      SizedBox(
        width: 52,
        child: Text(value.toStringAsFixed(0),
            textAlign: TextAlign.end,
            style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                fontWeight: FontWeight.w600)),
      ),
    ]);
  }
}

// ════════════════════════════════════════════════════════════
// Metadata tab
// ════════════════════════════════════════════════════════════

class _MetadataTab extends StatelessWidget {
  const _MetadataTab({required this.controller, required this.fileName});
  final DicomViewerController controller;
  final String fileName;

  @override
  Widget build(BuildContext context) {
    final meta = controller.result?.metadata;
    if (meta == null) return const SizedBox.shrink();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(title: 'File'),
          const SizedBox(height: 6),
          _MetaGrid(children: [
            _MetaTile(label: 'Name', value: fileName),
            _MetaTile(label: 'Modality', value: meta.modality),
            _MetaTile(
                label: 'Resolution', value: '${meta.width} × ${meta.height}'),
            _MetaTile(
                label: 'Photometric', value: meta.photometricInterpretation),
            _MetaTile(
                label: 'Frames',
                value: '${controller.result?.frameCount ?? 1}'),
            _MetaTile(
              label: 'Volumetric',
              value: meta.isVolumetric
                  ? (meta.isMultiFrame ? '✓ (multi-frame)' : '✓ (spatial)')
                  : 'No',
            ),
          ]),
          const SizedBox(height: 16),
          _SectionHeader(title: 'Patient'),
          const SizedBox(height: 6),
          _MetaGrid(children: [
            _MetaTile(label: 'Name', value: meta.patientName),
            _MetaTile(label: 'ID', value: meta.patientId),
            _MetaTile(label: 'Study date', value: meta.studyDate),
            _MetaTile(label: 'Study', value: meta.studyDescription),
          ]),
          const SizedBox(height: 16),
          _SectionHeader(title: 'Dates'),
          const SizedBox(height: 6),
          _MetaGrid(children: [
            _MetaTile(
                label: 'Best date',
                value: meta.bestDate != null
                    ? '${meta.bestDate!.year}-'
                        '${meta.bestDate!.month.toString().padLeft(2, '0')}-'
                        '${meta.bestDate!.day.toString().padLeft(2, '0')}'
                    : 'N/A'),
            _MetaTile(label: 'Study', value: meta.studyDate),
            _MetaTile(label: 'Series', value: meta.seriesDate),
            _MetaTile(label: 'Acquisition', value: meta.acquisitionDate),
            _MetaTile(label: 'Content', value: meta.contentDate),
          ]),
          const SizedBox(height: 16),
          _SectionHeader(title: 'Equipment'),
          const SizedBox(height: 6),
          _MetaGrid(children: [
            _MetaTile(label: 'Manufacturer', value: meta.manufacturer),
            _MetaTile(label: 'Model', value: meta.manufacturerModelName),
            _MetaTile(label: 'Institution', value: meta.institutionName),
            _MetaTile(label: 'Body part', value: meta.bodyPartExamined),
          ]),
          const SizedBox(height: 16),
          _SectionHeader(title: 'Acquisition'),
          const SizedBox(height: 6),
          _MetaGrid(children: [
            _MetaTile(label: 'Series', value: meta.seriesDescription),
            _MetaTile(label: 'Instance #', value: meta.instanceNumber),
            _MetaTile(
                label: 'Slice thickness',
                value: meta.sliceThickness > 0
                    ? '${meta.sliceThickness} mm'
                    : 'N/A'),
            _MetaTile(label: 'Tooth', value: meta.toothInfo),
            _MetaTile(label: 'Samples/px', value: '${meta.samplesPerPixel}'),
          ]),
          const SizedBox(height: 16),
          _SectionHeader(title: 'Spatial'),
          const SizedBox(height: 6),
          _MetaGrid(children: [
            _MetaTile(
                label: 'Pixel spacing',
                value: meta.pixelSpacingX != null && meta.pixelSpacingY != null
                    ? '${meta.pixelSpacingX!.toStringAsFixed(4)} × '
                        '${meta.pixelSpacingY!.toStringAsFixed(4)} mm'
                    : meta.pixelSpacing ?? 'N/A'),
            _MetaTile(
                label: 'Image position',
                value: meta.imagePositionPatient.isNotEmpty
                    ? meta.imagePositionPatient
                    : 'N/A'),
            _MetaTile(
                label: 'Slice location',
                value: meta.sliceLocation != 0
                    ? '${meta.sliceLocation.toStringAsFixed(2)} mm'
                    : 'N/A'),
            _MetaTile(
                label: 'Slice spacing',
                value: meta.spacingBetweenSlices > 0
                    ? '${meta.spacingBetweenSlices.toStringAsFixed(2)} mm'
                    : 'N/A'),
            _MetaTile(
                label: 'Orientation',
                value: meta.imageOrientationPatient.isNotEmpty
                    ? meta.imageOrientationPatient
                    : 'N/A',
                mono: true),
          ]),
          const SizedBox(height: 16),
          _SectionHeader(title: 'Technical'),
          const SizedBox(height: 6),
          _MetaGrid(children: [
            _MetaTile(
                label: 'Bits (alloc/stored/high)',
                value:
                    '${meta.bitsAllocated}/${meta.bitsStored}/${meta.highBit}'),
            _MetaTile(
                label: 'Pixel repr.',
                value: meta.pixelRepresentation == 0 ? 'unsigned' : 'signed'),
            _MetaTile(
                label: 'Rescale (slope/int)',
                value: '${meta.rescaleSlope} / ${meta.rescaleIntercept}'),
            _MetaTile(
                label: 'Window (L/W)',
                value:
                    '${meta.windowCenter.toStringAsFixed(0)} / ${meta.windowWidth.toStringAsFixed(0)}'),
          ]),
          const SizedBox(height: 16),
          _SectionHeader(title: 'UIDs'),
          const SizedBox(height: 6),
          _MetaTile(
              label: 'SOP Instance', value: meta.sopInstanceUid, mono: true),
          const SizedBox(height: 6),
          _MetaTile(label: 'Series', value: meta.seriesInstanceUid, mono: true),
          const SizedBox(height: 6),
          _MetaTile(label: 'Study', value: meta.studyInstanceUid, mono: true),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;
  @override
  Widget build(BuildContext context) {
    return Text(title,
        style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: Theme.of(context).colorScheme.primary));
  }
}

/// Formats a [DateTime] as YYYYMMDD, or returns "Unknown" if null.
String _formatDateOrUnknown(DateTime? dt) {
  if (dt == null) return 'Unknown';
  return '${dt.year}'
      '${dt.month.toString().padLeft(2, '0')}'
      '${dt.day.toString().padLeft(2, '0')}';
}

class _MetaGrid extends StatelessWidget {
  const _MetaGrid({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: children.map((child) {
          return SizedBox(width: (constraints.maxWidth - 8) / 2, child: child);
        }).toList(),
      );
    });
  }
}

class _MetaTile extends StatelessWidget {
  const _MetaTile(
      {required this.label, required this.value, this.mono = false});
  final String label, value;
  final bool mono;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 2),
          Text(value == 'Unknown' ? '—' : value,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  fontFamily: mono ? 'monospace' : null),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}
