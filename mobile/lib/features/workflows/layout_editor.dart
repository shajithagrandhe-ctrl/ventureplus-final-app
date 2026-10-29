import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:ventureplus/core/app_controller.dart';
import 'package:ventureplus/ui/components.dart';
import 'package:ventureplus/ui/theme.dart';

import 'forms.dart';
import 'layout_canvas.dart';
import 'layout_detection.dart';
import 'workflow_page.dart';

List<Offset> parsePointLines(String input) {
  final lines = input
      .trim()
      .split('\n')
      .where((line) => line.trim().isNotEmpty)
      .toList();
  if (lines.length < 3 || lines.length > 200) {
    throw const AppFailure(
      'Enter between 3 and 200 points, one x,y pair per line.',
    );
  }
  return lines.map((line) {
    final values = line.trim().split(',');
    if (values.length != 2) {
      throw const AppFailure('Each point must contain two numbers: x,y.');
    }
    final x = double.tryParse(values[0].trim()),
        y = double.tryParse(values[1].trim());
    if (x == null ||
        y == null ||
        !x.isFinite ||
        !y.isFinite ||
        x < 0 ||
        x > 1 ||
        y < 0 ||
        y > 1) {
      throw const AppFailure('Every coordinate must be between 0 and 1.');
    }
    return Offset(x, y);
  }).toList();
}

JsonMap polygonPayload(List<Offset> points) {
  final left = points.map((point) => point.dx).reduce(math.min),
      top = points.map((point) => point.dy).reduce(math.min);
  final right = points.map((point) => point.dx).reduce(math.max),
      bottom = points.map((point) => point.dy).reduce(math.max);
  if (left == right || top == bottom) {
    throw const AppFailure('A plot needs a nonzero width and height.');
  }
  double area = 0;
  for (var i = 0; i < points.length; i++) {
    final a = points[i], b = points[(i + 1) % points.length];
    area += a.dx * b.dy - b.dx * a.dy;
  }
  if (area.abs() < 0.0000001) {
    throw const AppFailure('The points must enclose a nonzero area.');
  }
  return {
    'x': left,
    'y': top,
    'width': right - left,
    'height': bottom - top,
    'shapeData': {
      'type': 'polygon',
      'points': points.map((point) => {'x': point.dx, 'y': point.dy}).toList(),
    },
  };
}

class LayoutEditorPage extends StatefulWidget {
  const LayoutEditorPage({
    super.key,
    required this.controller,
    required this.venture,
    required this.plots,
  });
  final AppController controller;
  final JsonMap venture;
  final List<JsonMap> plots;
  @override
  State<LayoutEditorPage> createState() => _LayoutEditorPageState();
}

class _LayoutEditorPageState extends State<LayoutEditorPage> {
  final _form = GlobalKey<FormState>();
  final _points = TextEditingController();
  final _numbers = {
    for (final key in ['x', 'y', 'width', 'height'])
      key: TextEditingController(),
  };
  late List<JsonMap> _plots;
  late JsonMap _regions;
  String? _plotId;
  String _mode = 'rectangle';
  int? _regionIndex;
  bool _busy = false, _dirty = false, _allowPop = false, _changed = false;
  String? _error;
  int _selectorRevision = 0;
  @override
  void initState() {
    super.initState();
    _plots = widget.plots.map((plot) => {...plot}).toList();
    final source = widget.venture['layoutRegions'];
    _regions = {
      for (final kind in ['roads', 'parks'])
        kind: source is Map && source[kind] is List
            ? List<dynamic>.from(source[kind])
            : <dynamic>[],
    };
    if (_plots.isNotEmpty) _selectPlot('${_plots.first['id']}');
  }

  @override
  void dispose() {
    _points.dispose();
    for (final controller in _numbers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _selectPlot(String id) {
    _plotId = id;
    final plot = _plots.firstWhere((plot) => plot['id'] == id);
    for (final entry in _numbers.entries) {
      entry.value.text =
          '${plot[entry.key] ?? (entry.key == 'width' || entry.key == 'height' ? .1 : 0)}';
    }
    final points = polygonPoints(plot['shapeData']);
    _points.text = points.map((point) => '${point.dx},${point.dy}').join('\n');
  }

  JsonMap? _draft() {
    try {
      if (_mode == 'rectangle') {
        final x = double.parse(_numbers['x']!.text),
            y = double.parse(_numbers['y']!.text);
        final width = double.parse(_numbers['width']!.text),
            height = double.parse(_numbers['height']!.text);
        if (x < 0 ||
            y < 0 ||
            width <= 0 ||
            height <= 0 ||
            x + width > 1 ||
            y + height > 1) {
          return null;
        }
        // Rectangles also replace any previously saved polygon for this plot.
        return polygonPayload([
          Offset(x, y),
          Offset(x + width, y),
          Offset(x + width, y + height),
          Offset(x, y + height),
        ]);
      }
      return polygonPayload(parsePointLines(_points.text));
    } catch (_) {
      return null;
    }
  }

  Future<void> _save() async {
    if (widget.controller.user?.role != Role.admin) return;
    if (!_form.currentState!.validate()) return;
    final draft = _draft();
    if (draft == null) {
      setState(
        () => _error = 'Check the coordinates. The shape must fit inside 0–1 and enclose a nonzero area.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final repository = activeRepository(widget.controller);
      if (_mode == 'road' || _mode == 'park') {
        final kind = _mode == 'road' ? 'roads' : 'parks';
        final regions = List<dynamic>.from(_regions[kind]);
        final region = {'points': draft['shapeData']['points']};
        if (_regionIndex == null) {
          regions.add(region);
        } else {
          regions[_regionIndex!] = region;
        }
        final updated = {..._regions, kind: regions};
        await repository.updateRegions('${widget.venture['id']}', updated);
        if (mounted) {
          setState(() {
            _regions = updated;
            _regionIndex = null;
            _points.clear();
          });
        }
      } else {
        if (_plotId == null) throw const AppFailure('Select a plot first.');
        await repository.updatePlotCoordinates(_plotId!, draft);
        if (mounted) {
          setState(() {
            _plots = _plots
                .map(
                  (plot) => plot['id'] == _plotId ? {...plot, ...draft} : plot,
                )
                .toList();
          });
        }
      }
      if (mounted) {
        setState(() {
          _dirty = false;
          _changed = true;
        });
        showFeedback(context, savedMessage(widget.controller));
      }
    } catch (error) {
      if (mounted) setState(() => _error = failureMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _exit() async {
    if (_busy) return;
    if (_dirty &&
        !await confirmAction(
          context,
          'Discard layout draft?',
          'Your saved layout is kept. The current unsaved draft will be discarded.',
        )) {
      return;
    }
    if (!mounted) return;
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context, _changed);
    });
  }

  Future<void> _changeSelection(VoidCallback change) async {
    if (_dirty &&
        !await confirmAction(
          context,
          'Discard layout draft?',
          'Switching selection discards the current unsaved draft.',
        )) {
      if (mounted) setState(() => _selectorRevision++);
      return;
    }
    if (!mounted) return;
    setState(() {
      change();
      _dirty = false;
      _error = null;
      _selectorRevision++;
    });
  }

  Future<void> _detect() async {
    if (widget.controller.user?.role != Role.admin) return;
    final url = widget.controller.repository?.assetUrl(
      widget.venture['layoutImage'] as String?,
    );
    if (url == null ||
        RegExp(r'\.(pdf|svg)(\?|$)', caseSensitive: false).hasMatch(url)) {
      showFeedback(
        context,
        'A PNG or JPEG layout image is needed for detection.',
      );
      return;
    }
    if (_dirty &&
        !await confirmAction(
          context,
          'Review detected rectangles?',
          'The current unsaved draft will be discarded before detection.',
        )) {
      return;
    }
    if (!mounted) return;
    final targets = _plots
        .where(
          (plot) =>
              plotRect(plot) == null &&
              polygonPoints(plot['shapeData']).length < 3,
        )
        .toList();
    targets.sort((a, b) {
      final aNumber = int.tryParse(
        RegExp(r'\d+').firstMatch('${a['plotNumber']}')?.group(0) ?? '',
      );
      final bNumber = int.tryParse(
        RegExp(r'\d+').firstMatch('${b['plotNumber']}')?.group(0) ?? '',
      );
      return aNumber != null && bNumber != null
          ? aNumber.compareTo(bNumber)
          : '${a['plotNumber']}'.compareTo('${b['plotNumber']}');
    });
    if (targets.isEmpty) {
      showFeedback(context, 'All plots already have coordinates.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _dirty = false;
    });
    try {
      final rectangles = await detectLayoutRectangles(url);
      if (!mounted) return;
      if (rectangles.isEmpty) {
        showFeedback(
          context,
          'No plot-like colored rectangles were detected. Enter coordinates manually.',
        );
        return;
      }
      final updates = List.generate(
        math.min(rectangles.length, targets.length),
        (index) => <String, dynamic>{
          'id': targets[index]['id'],
          ...rectangles[index],
        },
      );
      final proposals = List.generate(
        updates.length,
        (index) => <String, dynamic>{...targets[index], ...updates[index]},
      );
      final approved = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Review detected rectangles'),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${updates.length} unmapped plots matched in plot-number order to image regions from top to bottom. Verify each label before saving; detection can mistake other colored areas for plots.',
                  ),
                  const SizedBox(height: Brand.gap),
                  LayoutCanvas(plots: proposals, imageUrl: url),
                  if (rectangles.length > targets.length)
                    Text(
                      '${rectangles.length - targets.length} additional regions will be ignored.',
                    ),
                  for (final proposal in proposals)
                    ListTile(
                      title: Text('Plot ${proposal['plotNumber']}'),
                      subtitle: Text(
                        'x ${proposal['x'].toStringAsFixed(3)}, y ${proposal['y'].toStringAsFixed(3)}',
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Save detected mapping'),
            ),
          ],
        ),
      );
      if (approved != true || !mounted) return;
      await activeRepository(widget.controller)
          .updatePlotCoordinatesBatch(updates);
      if (!mounted) return;
      setState(() {
        _plots = _plots.map((plot) {
          final matching = updates.where(
            (update) => update['id'] == plot['id'],
          );
          return matching.isEmpty
              ? plot
              : <String, dynamic>{...plot, ...matching.first};
        }).toList();
        _changed = true;
        if (_plotId != null) _selectPlot(_plotId!);
      });
      showFeedback(context, savedMessage(widget.controller));
    } catch (error) {
      if (mounted) setState(() => _error = failureMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext _) {
    final draft = _draft();
    final plotMode = _mode == 'rectangle' || _mode == 'polygon';
    final preview = _plots
        .map(
          (plot) => plotMode && draft != null && plot['id'] == _plotId
              ? {...plot, ...draft}
              : plot,
        )
        .toList();
    final regions = {..._regions};
    if (!plotMode && draft != null) {
      final kind = _mode == 'road' ? 'roads' : 'parks';
      final entries = List<dynamic>.from(regions[kind]);
      final region = {'points': draft['shapeData']['points']};
      if (_regionIndex == null) {
        entries.add(region);
      } else {
        entries[_regionIndex!] = region;
      }
      regions[kind] = entries;
    }
    return PopScope(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _exit();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Edit plot layout'),
          leading: IconButton(
            tooltip: 'Back',
            onPressed: _exit,
            icon: const Icon(Icons.arrow_back),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            child: PageBody(
              child: widget.controller.user?.role != Role.admin
                  ? const StateMessage(
                      title: 'Admin access required',
                      message: 'Only administrators can edit a layout.',
                    )
                  : Form(
                      key: _form,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ModeStrip(offline: widget.controller.isOffline),
                          const SizedBox(height: Brand.gap),
                          OutlinedButton.icon(
                            onPressed: _busy ? null : _detect,
                            icon: const Icon(Icons.auto_fix_high_outlined),
                            label: Text(
                              _busy
                                  ? 'Working…'
                                  : 'Detect rectangles from image',
                            ),
                          ),
                          const SizedBox(height: Brand.gap),
                          const Text(
                            'Coordinates are fractions of the full layout: 0 is the top/left edge; 1 is the bottom/right edge. Changes below are a draft until saved.',
                          ),
                          const SizedBox(height: Brand.gap),
                          LayoutCanvas(
                            plots: preview,
                            regions: regions,
                            imageUrl: widget.controller.repository?.assetUrl(
                              widget.venture['layoutImage'] as String?,
                            ),
                            onPoint: _busy
                                ? null
                                : (point) => setState(() {
                                    if (_mode == 'rectangle') {
                                      _numbers['x']!.text = point.dx
                                          .toStringAsFixed(6);
                                      _numbers['y']!.text = point.dy
                                          .toStringAsFixed(6);
                                    } else {
                                      _points.text =
                                          '${_points.text}${_points.text.isEmpty ? '' : '\n'}${point.dx.toStringAsFixed(6)},${point.dy.toStringAsFixed(6)}';
                                    }
                                    _dirty = true;
                                  }),
                          ),
                          const SizedBox(height: Brand.gap),
                          DropdownButtonFormField<String>(
                            key: ValueKey('mode-$_selectorRevision-$_mode'),
                            initialValue: _mode,
                            decoration: const InputDecoration(
                              labelText: 'Shape to edit',
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'rectangle',
                                child: Text('Plot rectangle'),
                              ),
                              DropdownMenuItem(
                                value: 'polygon',
                                child: Text('Plot polygon'),
                              ),
                              DropdownMenuItem(
                                value: 'road',
                                child: Text('Road region'),
                              ),
                              DropdownMenuItem(
                                value: 'park',
                                child: Text('Park region'),
                              ),
                            ],
                            onChanged: _busy
                                ? null
                                : (value) => _changeSelection(() {
                                    _mode = value!;
                                    _regionIndex = null;
                                    _dirty = false;
                                    if ((_mode == 'rectangle' ||
                                            _mode == 'polygon') &&
                                        _plotId != null) {
                                      _selectPlot(_plotId!);
                                    } else {
                                      _points.clear();
                                    }
                                  }),
                          ),
                          if (plotMode) ...[
                            const SizedBox(height: Brand.gap),
                            DropdownButtonFormField<String>(
                              key: ValueKey('plot-$_selectorRevision-$_plotId'),
                              initialValue: _plotId,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Plot',
                              ),
                              items: _plots
                                  .map(
                                    (plot) => DropdownMenuItem(
                                      value: '${plot['id']}',
                                      child: Text('Plot ${plot['plotNumber']}'),
                                    ),
                                  )
                                  .toList(),
                              validator: (value) =>
                                  value == null ? 'Choose a plot.' : null,
                              onChanged: _busy
                                  ? null
                                  : (value) => _changeSelection(() {
                                      _selectPlot(value!);
                                      _dirty = false;
                                    }),
                            ),
                          ],
                          const SizedBox(height: Brand.gap),
                          if (_mode == 'rectangle')
                            ..._numbers.entries.expand(
                              (entry) => [
                                TextFormField(
                                  controller: entry.value,
                                  enabled: !_busy,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  decoration: InputDecoration(
                                    labelText: switch (entry.key) {
                                      'x' => 'Left (x)',
                                      'y' => 'Top (y)',
                                      'width' => 'Width',
                                      _ => 'Height',
                                    },
                                  ),
                                  validator: FormFieldSpec(
                                    entry.key,
                                    entry.key,
                                    kind: FieldKind.decimal,
                                    min:
                                        entry.key == 'width' ||
                                            entry.key == 'height'
                                        ? .000001
                                        : 0,
                                    max: 1,
                                  ).validate,
                                  onChanged: (_) =>
                                      setState(() => _dirty = true),
                                ),
                                const SizedBox(height: Brand.gap),
                              ],
                            )
                          else ...[
                            TextFormField(
                              controller: _points,
                              enabled: !_busy,
                              minLines: 4,
                              maxLines: 10,
                              keyboardType: TextInputType.multiline,
                              decoration: const InputDecoration(
                                labelText: 'Polygon points',
                                helperText: 'One x,y pair per line. Tap the layout to add points, or enter coordinates here.',
                                helperMaxLines: 3,
                              ),
                              validator: (value) {
                                try {
                                  parsePointLines(value ?? '');
                                  return null;
                                } catch (error) {
                                  return failureMessage(error);
                                }
                              },
                              onChanged: (_) => setState(() => _dirty = true),
                            ),
                            TextButton(
                              onPressed: _busy
                                  ? null
                                  : () => setState(() {
                                      _points.clear();
                                      _dirty = true;
                                    }),
                              child: const Text('Clear draft points'),
                            ),
                          ],
                          if (_error != null) ...[
                            Semantics(
                              liveRegion: true,
                              child: Text(
                                _error!,
                                style: const TextStyle(color: Brand.error),
                              ),
                            ),
                            const SizedBox(height: Brand.gap),
                          ],
                          BusyButton(
                            label: 'Save layout changes',
                            busy: _busy,
                            onPressed: _save,
                          ),
                          const SizedBox(height: Brand.section),
                          Text(
                            'Saved road & park regions',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          for (final kind in ['roads', 'parks']) ...[
                            if ((_regions[kind] as List).isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: Brand.compact,
                                ),
                                child: Text('No saved $kind.'),
                              ),
                            ...List.generate(
                              (_regions[kind] as List).length,
                              (index) => ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  '${kind == 'roads' ? 'Road' : 'Park'} ${index + 1}',
                                ),
                                subtitle: Text(
                                  '${polygonPoints((_regions[kind] as List)[index]).length} points',
                                ),
                                trailing: Wrap(
                                  children: [
                                    IconButton(
                                      tooltip:
                                          'Edit ${kind == 'roads' ? 'road' : 'park'} ${index + 1}',
                                      onPressed: _busy
                                          ? null
                                          : () => _changeSelection(() {
                                              _mode = kind == 'roads'
                                                  ? 'road'
                                                  : 'park';
                                              _regionIndex = index;
                                              _points.text =
                                                  polygonPoints(
                                                        (_regions[kind]
                                                            as List)[index],
                                                      )
                                                      .map(
                                                        (point) =>
                                                            '${point.dx},${point.dy}',
                                                      )
                                                      .join('\n');
                                              _dirty = false;
                                            }),
                                      icon: const Icon(Icons.edit_outlined),
                                    ),
                                    IconButton(
                                      tooltip:
                                          'Delete ${kind == 'roads' ? 'road' : 'park'} ${index + 1}',
                                      onPressed: _busy
                                          ? null
                                          : () async {
                                              if (!await confirmAction(
                                                context,
                                                'Delete region?',
                                                'This removes the saved ${kind == 'roads' ? 'road' : 'park'} region.',
                                              )) {
                                                return;
                                              }
                                              setState(() => _busy = true);
                                              try {
                                                final entries =
                                                    List<dynamic>.from(
                                                      _regions[kind],
                                                    )..removeAt(index);
                                                final updated = {
                                                  ..._regions,
                                                  kind: entries,
                                                };
                                                await activeRepository(
                                                  widget.controller,
                                                ).updateRegions(
                                                  '${widget.venture['id']}',
                                                  updated,
                                                );
                                                if (mounted) {
                                                  setState(() {
                                                    _regions = updated;
                                                    _changed = true;
                                                    _regionIndex = null;
                                                    _points.clear();
                                                    _dirty = false;
                                                  });
                                                }
                                              } catch (error) {
                                                if (mounted) {
                                                  showFeedback(
                                                    context,
                                                    failureMessage(error),
                                                  );
                                                }
                                              } finally {
                                                if (mounted) {
                                                  setState(() => _busy = false);
                                                }
                                              }
                                            },
                                      icon: const Icon(Icons.delete_outline),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
