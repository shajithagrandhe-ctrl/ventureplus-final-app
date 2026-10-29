import 'dart:typed_data';

import 'package:flutter/painting.dart';
import 'package:ventureplus/core/models.dart';

ImageProvider<Object> layoutImageProvider(String url) {
  final uri = Uri.tryParse(url);
  if (uri?.scheme == 'data') {
    final data = uri!.data;
    if (data == null || !data.mimeType.startsWith('image/')) {
      throw const AppFailure(
        'This layout file cannot be previewed as an image.',
      );
    }
    return MemoryImage(Uint8List.fromList(data.contentAsBytes()));
  }
  if (uri == null || !{'https', 'http'}.contains(uri.scheme)) {
    throw const AppFailure('The layout image address is invalid.');
  }
  return NetworkImage(url);
}
