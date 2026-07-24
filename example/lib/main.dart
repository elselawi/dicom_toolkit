import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:dicom_toolkit/dicom_toolkit.dart';
import 'package:file_picker/file_picker.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RustLib.init();
  runApp(const DicomExampleApp());
}

// ────────────────────────────────────────────────────────────
// App entry
// ────────────────────────────────────────────────────────────

class DicomExampleApp extends StatelessWidget {
  const DicomExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DICOM Viewer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.indigo,
      ),
      home: const ViewerScreen(),
    );
  }
}

// ────────────────────────────────────────────────────────────
// Windowing Presets
// ────────────────────────────────────────────────────────────

enum WindowPreset {
  bone('Bone', 1500, 300),
  lung('Lung', -500, 1500),
  softTissue('Soft Tissue', 40, 400),
  brain('Brain', 40, 80),
  liver('Liver', 80, 160),
  mediastinum('Mediastinum', 50, 350);

  const WindowPreset(this.label, this.center, this.width);
  final String label;
  final double center;
  final double width;
}

// ────────────────────────────────────────────────────────────
// Main screen
// ────────────────────────────────────────────────────────────

class ViewerScreen extends StatefulWidget {
  const ViewerScreen({super.key});

  @override
  State<ViewerScreen> createState() => _ViewerScreenState();
}

class _ViewerScreenState extends State<ViewerScreen> {
  final _controller = DicomController();
  String? _currentFileName;

  @override
  void initState() {
    super.initState();
    _controller.initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // ── Actions ────────────────────────────────────────────────

  Future<void> _pickFile() async {
    // `withData: true` ensures raw bytes are returned on every platform —
    // loading is bytes-only (there is no local file system on the Web).
    final result =
        await FilePicker.pickFiles(type: FileType.any, withData: true);
    final file = result?.files.single;
    final bytes = file?.bytes;
    if (file == null || bytes == null) return;
    await _loadBytes(bytes, name: file.name);
  }

  Future<void> _loadBytes(Uint8List bytes, {required final String name}) async {
    _currentFileName = name;
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

  void _applyPreset(WindowPreset preset) {
    _controller.updateWindowing(center: preset.center, width: preset.width);
  }

  Future<void> _exportPng(BuildContext context) async {
    final texture = _controller.rawTexture;
    if (texture == null || !mounted) return;

    final bytes = await DicomExport.toPngBytes(texture);
    final name = _currentFileName?.split(RegExp(r'[/\\]')).last ?? 'dicom';

    await FilePicker.saveFile(
      bytes: bytes,
      dialogTitle: 'Save DICOM as PNG',
      fileName: '$name.png',
      type: FileType.custom,
      allowedExtensions: ['png'],
    );
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

  // ── Empty state ────────────────────────────────────────────

  Widget _buildEmptyState() {
    final error = _controller.hasError ? _controller.errorMessage : null;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.biotech,
            size: 72,
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          Text(
            'DICOM Viewer',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Open a .dcm file to begin',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          if (error != null) ...[
            const SizedBox(height: 16),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                error,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                  fontSize: 13,
                ),
              ),
            ),
          ],
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: _pickFile,
            icon: const Icon(Icons.folder_open),
            label: const Text('Open DICOM File'),
          ),
        ],
      ),
    );
  }

  // ── Viewer layout ──────────────────────────────────────────

  Widget _buildViewer() {
    final fileName =
        _currentFileName?.split(RegExp(r'[/\\]')).last ?? 'Unknown';

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 600;

        if (isWide) {
          return Row(
            children: [
              // Viewer — left side
              Expanded(
                flex: 3,
                child: _buildViewerPane(),
              ),
              // Controls panel — right side
              SizedBox(
                width: 320,
                child: _BottomPanel(
                  controller: _controller,
                  fileName: fileName,
                  onPreset: _applyPreset,
                  onExport: (ctx) => _exportPng(ctx),
                ),
              ),
            ],
          );
        }

        return Column(
          children: [
            // Viewer — top
            Expanded(
              flex: 5,
              child: _buildViewerPane(),
            ),
            // Controls — bottom
            Expanded(
              flex: 4,
              child: _BottomPanel(
                controller: _controller,
                fileName: fileName,
                onPreset: _applyPreset,
                onExport: (ctx) => _exportPng(ctx),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildViewerPane() {
    final meta = _controller.metadata!;

    return Stack(
      fit: StackFit.expand,
      children: [
        DicomViewer(controller: _controller),
        // Patient overlay
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
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      meta.patientName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      '${meta.studyDate != 'Unknown' ? '${meta.studyDate}  ·  ' : ''}'
                      '${meta.width}×${meta.height}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 12,
                      ),
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
                    tooltip: 'Open file',
                  ),
                  const SizedBox(height: 6),
                  _OverlayIconButton(
                    icon: Icons.refresh,
                    onTap: _controller.resetWindowing,
                    tooltip: 'Reset windowing',
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ────────────────────────────────────────────────────────────
// Overlay icon button (on the viewer)
// ────────────────────────────────────────────────────────────

class _OverlayIconButton extends StatelessWidget {
  const _OverlayIconButton({
    required this.icon,
    required this.onTap,
    this.tooltip,
  });

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

// ────────────────────────────────────────────────────────────
// Bottom panel: tabbed Controls + Metadata
// ────────────────────────────────────────────────────────────

class _BottomPanel extends StatefulWidget {
  const _BottomPanel({
    required this.controller,
    required this.fileName,
    required this.onPreset,
    required this.onExport,
  });

  final DicomController controller;
  final String fileName;
  final void Function(WindowPreset) onPreset;
  final void Function(BuildContext) onExport;

  @override
  State<_BottomPanel> createState() => _BottomPanelState();
}

class _BottomPanelState extends State<_BottomPanel>
    with SingleTickerProviderStateMixin {
  late final _tabController = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.tune), text: 'Controls'),
            Tab(icon: Icon(Icons.info_outline), text: 'Metadata'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _ControlsTab(
                controller: widget.controller,
                onPreset: widget.onPreset,
                onExport: widget.onExport,
              ),
              _MetadataTab(
                controller: widget.controller,
                fileName: widget.fileName,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ────────────────────────────────────────────────────────────
// Controls tab
// ────────────────────────────────────────────────────────────

class _ControlsTab extends StatelessWidget {
  const _ControlsTab({
    required this.controller,
    required this.onPreset,
    required this.onExport,
  });

  final DicomController controller;
  final void Function(WindowPreset) onPreset;
  final void Function(BuildContext) onExport;

  @override
  Widget build(BuildContext context) {
    final meta = controller.metadata!;

    // Dynamic slider ranges based on the actual DICOM windowing defaults
    final defaultCenter = meta.windowCenter;
    final defaultWidth = meta.windowWidth;
    final centerRange = (defaultWidth * 3).clamp(100.0, 40000.0);
    final widthMax = (defaultWidth * 4).clamp(4.0, 65536.0);

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Preset chips
              Text(
                'Quick Presets',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: WindowPreset.values.map((preset) {
                  return ChoiceChip(
                    label: Text(preset.label),
                    selected: controller.windowCenter == preset.center &&
                        controller.windowWidth == preset.width,
                    onSelected: (_) => onPreset(preset),
                    visualDensity: VisualDensity.compact,
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Level slider — range centered on the DICOM default
              _LabeledSlider(
                label: 'Level',
                value: controller.windowCenter ?? defaultCenter,
                min: (defaultCenter - centerRange).floorToDouble(),
                max: (defaultCenter + centerRange).ceilToDouble(),
                onChanged: (v) => controller.updateWindowing(center: v),
              ),
              const SizedBox(height: 4),

              // Width slider
              _LabeledSlider(
                label: 'Width',
                value: controller.windowWidth ?? defaultWidth,
                min: 1,
                max: widthMax.ceilToDouble(),
                onChanged: (v) => controller.updateWindowing(width: v),
              ),
              const SizedBox(height: 12),

              // Reset + rescale info
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: controller.resetWindowing,
                    icon: const Icon(Icons.restore, size: 18),
                    label: const Text('Reset'),
                  ),
                  const Spacer(),
                  Text(
                    'Default L/W: ${defaultCenter.toStringAsFixed(0)} / ${defaultWidth.toStringAsFixed(0)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Color map toggle
              Text(
                'Color Map',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: DicomColorMap.values.map((map) {
                  final isSelected = controller.colorMap == map;
                  return ChoiceChip(
                    label: Text(
                      map.label,
                      style: TextStyle(fontSize: 12),
                    ),
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

              // Invert + Export row
              Row(
                children: [
                  ChoiceChip(
                    label: const Text('Invert', style: TextStyle(fontSize: 12)),
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
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () => onExport(context),
                    icon: const Icon(Icons.save_alt, size: 16),
                    label: const Text('Export PNG',
                        style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

// ────────────────────────────────────────────────────────────
// Labeled slider
// ────────────────────────────────────────────────────────────

class _LabeledSlider extends StatelessWidget {
  const _LabeledSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final clamped = value.clamp(min, max);
    return Row(
      children: [
        SizedBox(
          width: 48,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: Slider(
            value: clamped,
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 52,
          child: Text(
            value.toStringAsFixed(0),
            textAlign: TextAlign.end,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

// ────────────────────────────────────────────────────────────
// Metadata tab
// ────────────────────────────────────────────────────────────

class _MetadataTab extends StatelessWidget {
  const _MetadataTab({required this.controller, required this.fileName});

  final DicomController controller;
  final String fileName;

  @override
  Widget build(BuildContext context) {
    final meta = controller.metadata;
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
            _MetaTile(label: 'Samples/px', value: '${meta.samplesPerPixel}'),
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
            label: 'SOP Instance',
            value: meta.sopInstanceUid,
            mono: true,
          ),
          const SizedBox(height: 6),
          _MetaTile(
            label: 'Series',
            value: meta.seriesInstanceUid,
            mono: true,
          ),
          const SizedBox(height: 6),
          _MetaTile(
            label: 'Study',
            value: meta.studyInstanceUid,
            mono: true,
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────
// Section header
// ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────
// Metadata grid (2 columns)
// ────────────────────────────────────────────────────────────

class _MetaGrid extends StatelessWidget {
  const _MetaGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: children.map((child) {
            return SizedBox(
              width: (constraints.maxWidth - 8) / 2,
              child: child,
            );
          }).toList(),
        );
      },
    );
  }
}

// ────────────────────────────────────────────────────────────
// Metadata tile
// ────────────────────────────────────────────────────────────

class _MetaTile extends StatelessWidget {
  const _MetaTile({
    required this.label,
    required this.value,
    this.mono = false,
  });

  final String label;
  final String value;
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
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value == 'Unknown' ? '—' : value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              fontFamily: mono ? 'monospace' : null,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
