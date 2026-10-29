import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:ventureplus/core/app_controller.dart';

import 'layout_image.dart';

// Port of reference-web/client/src/utils/rectangleAutoDetect.ts. Only image
// evidence is used; proposals must be reviewed before persisting coordinates.
List<JsonMap> detectColoredRectangles(Map<String, dynamic> input) {
  final width = input['width'] as int, height = input['height'] as int;
  final pixels = input['pixels'] as Uint8List;
  final mask = Uint8List(width * height);
  for (var i = 0; i < mask.length; i++) {
    final p = i * 4,
        max = math.max(pixels[p], math.max(pixels[p + 1], pixels[p + 2])),
        min = math.min(pixels[p], math.min(pixels[p + 1], pixels[p + 2]));
    mask[i] = max - min >= 35 && max >= 70 && pixels[p + 3] > 0 ? 1 : 0;
  }
  Uint8List morphology(Uint8List source, bool dilate) {
    final output = Uint8List(source.length);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        var value = dilate ? 0 : 1;
        for (
          var yy = math.max(0, y - 1);
          yy <= math.min(height - 1, y + 1);
          yy++
        ) {
          for (
            var xx = math.max(0, x - 1);
            xx <= math.min(width - 1, x + 1);
            xx++
          ) {
            if (dilate && source[yy * width + xx] == 1) value = 1;
            if (!dilate && source[yy * width + xx] == 0) value = 0;
          }
        }
        output[y * width + x] = value;
      }
    }
    return output;
  }

  final closed = morphology(
    morphology(morphology(morphology(mask, true), true), false),
    false,
  );
  final visited = Uint8List(mask.length), rectangles = <Rect>[];
  final minArea = math.max(420, (width * height * .00005).floor());
  for (var i = 0; i < closed.length; i++) {
    if (closed[i] == 0 || visited[i] == 1) continue;
    final stack = [i];
    visited[i] = 1;
    var area = 0, minX = width, minY = height, maxX = 0, maxY = 0;
    while (stack.isNotEmpty) {
      final index = stack.removeLast(), y = index ~/ width, x = index % width;
      area++;
      minX = math.min(minX, x);
      minY = math.min(minY, y);
      maxX = math.max(maxX, x);
      maxY = math.max(maxY, y);
      // Keep row boundaries intact; a pixel at the right edge must not connect
      // to the next row's left edge.
      for (final next in [
        if (x > 0) index - 1,
        if (x < width - 1) index + 1,
        if (y > 0) index - width,
        if (y < height - 1) index + width,
      ]) {
        if (closed[next] == 1 && visited[next] == 0) {
          visited[next] = 1;
          stack.add(next);
        }
      }
    }
    final w = maxX - minX + 1, h = maxY - minY + 1;
    if (area < minArea ||
        w < 18 ||
        h < 18 ||
        area / (w * h) < .55 ||
        w / h < .25 ||
        w / h > 4) {
      continue;
    }
    rectangles.add(
      Rect.fromLTWH(
        minX.toDouble(),
        minY.toDouble(),
        w.toDouble(),
        h.toDouble(),
      ),
    );
  }
  rectangles.sort((a, b) => (b.width * b.height).compareTo(a.width * a.height));
  final merged = <Rect>[];
  for (final rect in rectangles) {
    var didMerge = false;
    for (var i = 0; i < merged.length; i++) {
      final other = merged[i], intersection = rect.intersect(other);
      final area = intersection.width > 0 && intersection.height > 0
          ? intersection.width * intersection.height
          : 0;
      if (area /
              (rect.width * rect.height + other.width * other.height - area) >
          .25) {
        merged[i] = rect.expandToInclude(other);
        didMerge = true;
        break;
      }
    }
    if (!didMerge) merged.add(rect);
  }
  final output = merged
      .where(
        (rect) =>
            rect.width * rect.height > minArea &&
            rect.width / width < .7 &&
            rect.height / height < .7,
      )
      .map(
        (rect) => <String, dynamic>{
          'x': rect.left / width,
          'y': rect.top / height,
          'width': rect.width / width,
          'height': rect.height / height,
        },
      )
      .toList();
  output.sort(
    (a, b) => a['y'] == b['y']
        ? (a['x'] as double).compareTo(b['x'])
        : (a['y'] as double).compareTo(b['y']),
  );
  return output;
}

Future<List<JsonMap>> detectLayoutRectangles(String url) async {
  final stream = layoutImageProvider(url).resolve(ImageConfiguration.empty);
  final completer = Completer<ui.Image>();
  late ImageStreamListener listener;
  listener = ImageStreamListener(
    (info, _) {
      if (!completer.isCompleted) completer.complete(info.image.clone());
    },
    onError: (Object error, StackTrace? trace) {
      if (!completer.isCompleted) {
        completer.completeError(
          const AppFailure(
            'Could not read the image for detection. Choose a PNG or JPEG layout.',
          ),
        );
      }
    },
  );
  stream.addListener(listener);
  ui.Image? source, scaled;
  try {
    source = await completer.future.timeout(const Duration(seconds: 25));
    final scale = math.min(1.0, 1000 / math.max(source.width, source.height));
    final width = math.max(1, (source.width * scale).floor()),
        height = math.max(1, (source.height * scale).floor());
    final recorder = ui.PictureRecorder(), canvas = Canvas(recorder);
    canvas.drawImageRect(
      source,
      Rect.fromLTWH(0, 0, source.width.toDouble(), source.height.toDouble()),
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      Paint(),
    );
    final picture = recorder.endRecording();
    scaled = await picture.toImage(width, height);
    picture.dispose();
    final bytes = await scaled.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (bytes == null) {
      throw const AppFailure('The layout image could not be decoded.');
    }
    return await compute(detectColoredRectangles, {
      'width': width,
      'height': height,
      'pixels': bytes.buffer.asUint8List(),
    });
  } finally {
    stream.removeListener(listener);
    source?.dispose();
    scaled?.dispose();
  }
}
