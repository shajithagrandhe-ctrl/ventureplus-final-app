import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:ventureplus/core/app_controller.dart';
import 'package:ventureplus/ui/theme.dart';

import 'layout_image.dart';

List<Offset> polygonPoints(dynamic shape) {
  if (shape is! Map || shape['points'] is! List) return [];
  final result = <Offset>[];
  for (final point in shape['points'] as List) {
    if (point is! Map || point['x'] is! num || point['y'] is! num) return [];
    final x = (point['x'] as num).toDouble(),
        y = (point['y'] as num).toDouble();
    if (!x.isFinite || !y.isFinite || x < 0 || x > 1 || y < 0 || y > 1) {
      return [];
    }
    result.add(Offset(x, y));
  }
  return result;
}

Rect? plotRect(JsonMap plot) {
  final values = ['x', 'y', 'width', 'height'].map((key) => plot[key]).toList();
  if (values.any((value) => value is! num || !(value).isFinite)) {
    return null;
  }
  final x = (values[0] as num).toDouble(), y = (values[1] as num).toDouble();
  final width = (values[2] as num).toDouble(),
      height = (values[3] as num).toDouble();
  if (x < 0 ||
      y < 0 ||
      width <= 0 ||
      height <= 0 ||
      x + width > 1.00001 ||
      y + height > 1.00001) {
    return null;
  }
  return Rect.fromLTWH(x, y, width, height);
}

Path plotPath(JsonMap plot, Size size) {
  final points = polygonPoints(plot['shapeData']);
  final path = Path();
  if (points.length >= 3) {
    path.moveTo(points.first.dx * size.width, points.first.dy * size.height);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx * size.width, point.dy * size.height);
    }
    path.close();
  } else {
    final rect = plotRect(plot);
    if (rect != null) {
      path.addRect(
        Rect.fromLTWH(
          rect.left * size.width,
          rect.top * size.height,
          rect.width * size.width,
          rect.height * size.height,
        ),
      );
    }
  }
  return path;
}

class LayoutCanvas extends StatefulWidget {
  const LayoutCanvas({
    super.key,
    required this.plots,
    this.imageUrl,
    this.regions,
    this.onPlot,
    this.onPoint,
  });
  final List<JsonMap> plots;
  final String? imageUrl;
  final JsonMap? regions;
  final void Function(JsonMap)? onPlot;
  final void Function(Offset)? onPoint;
  @override
  State<LayoutCanvas> createState() => _LayoutCanvasState();
}

class _LayoutCanvasState extends State<LayoutCanvas> {
  ImageStream? _stream;
  ImageStreamListener? _listener;
  double _ratio = 1.4;
  bool _failed = false;
  ImageProvider<Object>? _provider;
  @override
  void initState() {
    super.initState();
    _resolveImage();
  }

  @override
  void didUpdateWidget(covariant LayoutCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) _resolveImage();
  }

  void _resolveImage() {
    if (_listener != null) _stream?.removeListener(_listener!);
    _failed = false;
    _provider = null;
    _ratio = 1.4;
    if (widget.imageUrl == null) return;
    try {
      _provider = layoutImageProvider(widget.imageUrl!);
      _stream = _provider!.resolve(ImageConfiguration.empty);
    } catch (_) {
      _failed = true;
      return;
    }
    _listener = ImageStreamListener(
      (info, _) {
        if (mounted) {
          setState(() {
            _ratio = info.image.width / info.image.height;
            _failed = false;
          });
        }
      },
      onError: (_, _) {
        if (mounted) setState(() => _failed = true);
      },
    );
    _stream!.addListener(_listener!);
  }

  @override
  void dispose() {
    if (_listener != null) _stream?.removeListener(_listener!);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (_failed)
        const Padding(
          padding: EdgeInsets.only(bottom: Brand.compact),
          child: Text(
            'This layout cannot be previewed as an image. Open the original file to view it.',
          ),
        ),
      ClipRRect(
        borderRadius: BorderRadius.circular(Brand.radius),
        child: ColoredBox(
          color: Brand.surface,
          child: AspectRatio(
            aspectRatio: _ratio,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final size = Size(constraints.maxWidth, constraints.maxHeight);
                return InteractiveViewer(
                  minScale: 1,
                  maxScale: 5,
                  child: GestureDetector(
                    onTapUp: (event) {
                      final point = event.localPosition;
                      if (widget.onPoint != null) {
                        widget.onPoint!(
                          Offset(
                            (point.dx / size.width).clamp(0, 1),
                            (point.dy / size.height).clamp(0, 1),
                          ),
                        );
                        return;
                      }
                      for (final plot in widget.plots.reversed) {
                        if (plotPath(plot, size).contains(point)) {
                          widget.onPlot?.call(plot);
                          break;
                        }
                      }
                    },
                    child: Semantics(
                      label: 'Venture plot layout. Pinch to zoom. The plot list below provides accessible details.',
                      image: true,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (_provider != null && !_failed)
                            Image(
                              image: _provider!,
                              fit: BoxFit.fill,
                              excludeFromSemantics: true,
                              errorBuilder: (_, _, _) =>
                                  const SizedBox.shrink(),
                            ),
                          CustomPaint(
                            painter: _LayoutPainter(
                              widget.plots,
                              widget.regions,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
      const SizedBox(height: Brand.compact),
      Text(
        widget.imageUrl == null
            ? 'Coordinate diagram · no layout image available'
            : 'Pinch to zoom · tap a mapped plot',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    ],
  );
}

class _LayoutPainter extends CustomPainter {
  _LayoutPainter(this.plots, this.regions);
  final List<JsonMap> plots;
  final JsonMap? regions;
  @override
  void paint(Canvas canvas, Size size) {
    for (final kind in ['roads', 'parks']) {
      final values = regions?[kind];
      if (values is! List) continue;
      for (final region in values) {
        final points = polygonPoints(region);
        if (points.length < 3) continue;
        final path = Path()
          ..moveTo(points.first.dx * size.width, points.first.dy * size.height);
        for (final point in points.skip(1)) {
          path.lineTo(point.dx * size.width, point.dy * size.height);
        }
        path.close();
        canvas.drawPath(
          path,
          Paint()
            ..color = (kind == 'parks' ? Brand.sage500 : Brand.secondary)
                .withValues(alpha: .3),
        );
        canvas.drawPath(
          path,
          Paint()
            ..color = Brand.secondary
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1,
        );
      }
    }
    for (final plot in plots) {
      final path = plotPath(plot, size);
      final bounds = path.getBounds();
      if (bounds.isEmpty) continue;
      final color = switch (plot['status']) {
        'SOLD' => Brand.walnut700,
        'ADVANCE' => Brand.warning,
        _ => Brand.sage700,
      };
      canvas.drawPath(path, Paint()..color = color.withValues(alpha: .18));
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
      final text = TextPainter(
        text: TextSpan(
          text: '${plot['plotNumber'] ?? ''}',
          style: TextStyle(
            color: Brand.ink,
            backgroundColor: Brand.surface.withValues(alpha: .9),
            fontSize: math.min(14, math.max(10, bounds.height / 3)),
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: bounds.width);
      if (text.height <= bounds.height) {
        text.paint(
          canvas,
          bounds.center - Offset(text.width / 2, text.height / 2),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LayoutPainter oldDelegate) => true;
}
