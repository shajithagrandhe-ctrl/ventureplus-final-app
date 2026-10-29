import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:ventureplus/core/app_controller.dart';
import 'package:ventureplus/ui/components.dart';
import 'package:ventureplus/ui/theme.dart';

import 'forms.dart';
import 'workflow_page.dart';
import 'layout_canvas.dart';
import 'layout_editor.dart';

class VentureDetailPage extends StatefulWidget {
  const VentureDetailPage({
    super.key,
    required this.controller,
    required this.ventureId,
    this.initial = const {},
  });
  final AppController controller;
  final String ventureId;
  final JsonMap initial;
  @override
  State<VentureDetailPage> createState() => _VentureDetailPageState();
}

class _VentureDetailPageState extends State<VentureDetailPage> {
  late JsonMap _venture;
  List<JsonMap> _plots = [];
  bool _loading = true, _uploading = false;
  String? _error, _uploadError, _filename, _mime;
  List<int>? _bytes;
  bool _layout = true;
  double? _progress;
  @override
  void initState() {
    super.initState();
    _venture = widget.initial;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repository = activeRepository(widget.controller);
      final venture = await repository.detail(
        Resource.ventures,
        widget.ventureId,
      );
      final plots = await repository.list(
        Resource.plots,
        query: {'ventureId': widget.ventureId},
      );
      if (mounted) {
        setState(() {
          _venture = venture;
          _plots = plots;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = failureMessage(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _chooseUpload(bool layout) async {
    if (widget.controller.user?.role != Role.admin) return;
    final source = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(context, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(context, 'gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.attach_file_outlined),
              title: const Text('Choose a file'),
              onTap: () => Navigator.pop(context, 'file'),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    try {
      final List<int> bytes;
      final String filename;
      if (source == 'file') {
        final selection = await FilePicker.pickFiles(
          type: FileType.custom,
          allowedExtensions: layout
              ? ['png', 'jpg', 'jpeg', 'pdf', 'svg']
              : ['png', 'jpg', 'jpeg', 'webp'],
        );
        if (selection.isEmpty) return;
        final selected = selection.single;
        final length = await selected.length();
        if (length != null && length > 4 * 1024 * 1024) {
          throw const AppFailure('Choose a file no larger than 4 MiB.');
        }
        bytes = await selected.readAsBytes();
        filename = selected.name;
      } else {
        final selected = await ImagePicker().pickImage(
          source: source == 'camera' ? ImageSource.camera : ImageSource.gallery,
          requestFullMetadata: false,
        );
        if (selected == null) return;
        bytes = await selected.readAsBytes();
        filename = selected.name;
      }
      final mime = switch (filename.split('.').last.toLowerCase()) {
        'png' => 'image/png',
        'jpg' || 'jpeg' => 'image/jpeg',
        'webp' => 'image/webp',
        'pdf' => 'application/pdf',
        'svg' => 'image/svg+xml',
        _ => '',
      };
      if (bytes.isEmpty || bytes.length > 4 * 1024 * 1024) {
        throw const AppFailure('Choose a nonempty file no larger than 4 MiB.');
      }
      if (mime.isEmpty ||
          (!layout &&
              !['image/png', 'image/jpeg', 'image/webp'].contains(mime)) ||
          (layout && mime == 'image/webp')) {
        throw const AppFailure(
          'This file type is not supported. Choose one of the listed formats.',
        );
      }
      if (!mounted) return;
      setState(() {
        _bytes = bytes;
        _filename = filename;
        _mime = mime;
        _layout = layout;
        _uploadError = null;
        _progress = null;
      });
    } catch (error) {
      if (mounted) showFeedback(context, failureMessage(error));
    }
  }

  Future<void> _upload() async {
    if (_bytes == null || _filename == null || _mime == null) return;
    if (!await confirmAction(
      context,
      'Replace venture image?',
      'The current backend stores a photo and a layout in the same field. This upload replaces the venture’s current image${widget.controller.isOffline ? ' locally' : ' on the server'}.',
    )) {
      return;
    }
    setState(() {
      _uploading = true;
      _uploadError = null;
      _progress = 0;
    });
    try {
      await activeRepository(widget.controller).uploadVenture(
        widget.ventureId,
        _bytes!,
        _filename!,
        layout: _layout,
        contentType: _mime!,
        onProgress: (sent, total) {
          if (mounted) {
            setState(() => _progress = total > 0 ? sent / total : null);
          }
        },
      );
      if (mounted) {
        setState(() {
          _bytes = null;
          _filename = null;
          _progress = null;
        });
        showFeedback(context, savedMessage(widget.controller));
        await _load();
      }
    } catch (error) {
      if (mounted) setState(() => _uploadError = failureMessage(error));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _openOriginal(String url) async {
    final uri = Uri.tryParse(url);
    if (uri?.scheme == 'data') {
      try {
        final data = uri!.data!;
        final extension = switch (data.mimeType) {
          'application/pdf' => 'pdf',
          'image/svg+xml' => 'svg',
          'image/jpeg' => 'jpg',
          'image/webp' => 'webp',
          _ => 'png',
        };
        final result = await FilePicker.saveFile(
          fileName: 'venture-layout.$extension',
          bytes: Uint8List.fromList(data.contentAsBytes()),
          mimeType: data.mimeType,
        );
        if (result != null && mounted) {
          showFeedback(context, 'Layout saved to your selected location.');
        }
      } catch (_) {
        if (mounted) {
          showFeedback(context, 'Could not save the layout. Please try again.');
        }
      }
      return;
    }
    if (uri == null || !['https', 'http'].contains(uri.scheme)) {
      showFeedback(context, 'This file cannot be opened externally.');
      return;
    }
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
          mounted) {
        showFeedback(context, 'No application could open this file.');
      }
    } catch (_) {
      if (mounted) {
        showFeedback(context, 'Could not open this file. Try again.');
      }
    }
  }

  Future<void> _openPlot(JsonMap plot) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RecordDetailPage(
          controller: widget.controller,
          resource: Resource.plots,
          record: plot,
        ),
      ),
    );
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final repository = widget.controller.repository;
    final imageUrl = repository?.assetUrl(
      _venture['layoutImage'] as String? ?? _venture['photoUrl'] as String?,
    );
    final regions = _venture['layoutRegions'] is Map
        ? Map<String, dynamic>.from(_venture['layoutRegions'])
        : null;
    final admin = widget.controller.user?.role == Role.admin;
    return Scaffold(
      appBar: AppBar(title: Text('${_venture['name'] ?? 'Venture'}')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              PageBody(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ModeStrip(offline: widget.controller.isOffline),
                    const SizedBox(height: Brand.gap),
                    if (_loading)
                      const LoadingSkeleton()
                    else if (_error != null)
                      StateMessage(
                        title: 'Could not load venture',
                        message: _error!,
                        action: _load,
                      )
                    else ...[
                      Text(
                        '${_venture['location'] is Map ? _venture['location']['name'] ?? '' : ''}',
                        style: const TextStyle(color: Brand.secondary),
                      ),
                      const SizedBox(height: Brand.compact),
                      Text(
                        '${_plots.length} plots',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: Brand.gap),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: ['AVAILABLE', 'ADVANCE', 'SOLD']
                            .map(
                              (status) => StatusBadge(
                                '$status · ${_plots.where((plot) => plot['status'] == status).length}',
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: Brand.section),
                      Text(
                        'Venture layout',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: Brand.gap),
                      if (_plots.any(
                            (plot) =>
                                plotRect(plot) != null ||
                                polygonPoints(plot['shapeData']).length >= 3,
                          ) ||
                          imageUrl != null)
                        LayoutCanvas(
                          plots: _plots,
                          imageUrl: imageUrl,
                          regions: regions,
                          onPlot: _openPlot,
                        )
                      else
                        const StateMessage(
                          title: 'No mapped layout yet',
                          message: 'Plot details remain available in the list below.',
                          icon: Icons.map_outlined,
                        ),
                      if (imageUrl != null)
                        TextButton.icon(
                          onPressed: () => _openOriginal(imageUrl),
                          icon: const Icon(Icons.open_in_new),
                          label: Text(
                            widget.controller.isOffline
                                ? 'Save original layout'
                                : 'Open original layout',
                          ),
                        ),
                      if (admin) ...[
                        const SizedBox(height: Brand.gap),
                        OutlinedButton.icon(
                          onPressed: _uploading
                              ? null
                              : () async {
                                  final saved = await Navigator.push<bool>(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => LayoutEditorPage(
                                        controller: widget.controller,
                                        venture: _venture,
                                        plots: _plots,
                                      ),
                                    ),
                                  );
                                  if (saved == true && mounted) await _load();
                                },
                          icon: const Icon(Icons.edit_location_alt_outlined),
                          label: const Text('Edit plot layout'),
                        ),
                        const SizedBox(height: Brand.compact),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            OutlinedButton.icon(
                              onPressed: _uploading
                                  ? null
                                  : () => _chooseUpload(true),
                              icon: const Icon(Icons.upload_file_outlined),
                              label: const Text('Choose layout'),
                            ),
                            OutlinedButton.icon(
                              onPressed: _uploading
                                  ? null
                                  : () => _chooseUpload(false),
                              icon: const Icon(
                                Icons.add_photo_alternate_outlined,
                              ),
                              label: const Text('Choose photo'),
                            ),
                          ],
                        ),
                        const SizedBox(height: Brand.compact),
                        const Text(
                          'Up to 4 MiB. Layout: PNG, JPEG, PDF or SVG. Photo: PNG, JPEG or WebP. Both replace the same stored venture image.',
                          style: TextStyle(color: Brand.secondary),
                        ),
                        if (_filename != null) ...[
                          const SizedBox(height: Brand.gap),
                          Text('Selected: $_filename'),
                          if (_uploading) ...[
                            const SizedBox(height: Brand.compact),
                            LinearProgressIndicator(
                              value: _progress,
                              semanticsLabel: 'Upload progress',
                            ),
                          ],
                          if (_uploadError != null)
                            Semantics(
                              liveRegion: true,
                              child: Text(
                                _uploadError!,
                                style: const TextStyle(color: Brand.error),
                              ),
                            ),
                          const SizedBox(height: Brand.compact),
                          BusyButton(
                            label: _uploadError == null
                                ? 'Upload selected file'
                                : 'Retry upload',
                            busy: _uploading,
                            onPressed: _upload,
                          ),
                          TextButton(
                            onPressed: _uploading
                                ? null
                                : () => setState(() {
                                    _bytes = null;
                                    _filename = null;
                                    _uploadError = null;
                                  }),
                            child: const Text('Discard selection'),
                          ),
                        ],
                      ],
                      const SizedBox(height: Brand.section),
                      Text(
                        'Plots',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: Brand.gap),
                      if (_plots.isEmpty)
                        const StateMessage(
                          title: 'No accessible plots',
                          message: 'No plots are available to this account in this venture.',
                        ),
                      ..._plots.map(
                        (plot) => Padding(
                          padding: const EdgeInsets.only(bottom: Brand.compact),
                          child: Card(
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(Brand.gap),
                              title: Text('Plot ${plot['plotNumber']}'),
                              subtitle: Text(
                                '${plot['area']} sq yd · ${plot['pricePerSqYard']} / sq yd\n${plot['status']}',
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => _openPlot(plot),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
