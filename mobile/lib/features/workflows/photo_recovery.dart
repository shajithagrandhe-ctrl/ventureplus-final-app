import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ventureplus/core/app_controller.dart';

const maxUploadBytes = 4 * 1024 * 1024;

Future<Uint8List> readSizedPhoto(XFile file) async {
  final length = await file.length();
  if (length <= 0 || length > maxUploadBytes) {
    throw const AppFailure('Choose a nonempty file no larger than 4 MiB.');
  }
  final bytes = await file.readAsBytes();
  if (bytes.isEmpty || bytes.length > maxUploadBytes) {
    throw const AppFailure('Choose a nonempty file no larger than 4 MiB.');
  }
  return bytes;
}

class LostPhotoData {
  const LostPhotoData({this.files = const [], this.failed = false});
  final List<XFile> files;
  final bool failed;
}

abstract class PhotoPickerGateway {
  bool get supportsRecovery;
  Future<XFile?> pick(ImageSource source);
  Future<LostPhotoData> retrieveLostData();
}

class NativePhotoPicker implements PhotoPickerGateway {
  final _picker = ImagePicker();
  @override
  bool get supportsRecovery =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  @override
  Future<XFile?> pick(ImageSource source) =>
      _picker.pickImage(source: source, requestFullMetadata: false);
  @override
  Future<LostPhotoData> retrieveLostData() async {
    final data = await _picker.retrieveLostData();
    return LostPhotoData(
      files: data.files ?? [],
      failed: data.exception != null,
    );
  }
}

/// Local intent metadata contains no credentials and is never sent to the API.
/// It binds the plugin's single pending result to its original upload context.
class PhotoIntent {
  const PhotoIntent({
    required this.scope,
    required this.ventureId,
    required this.layout,
    required this.startedAt,
  });
  final JsonMap scope;
  final String ventureId;
  final bool layout;
  final DateTime startedAt;
  JsonMap toJson() => {
    'scope': scope,
    'ventureId': ventureId,
    'layout': layout,
    'startedAt': startedAt.toUtc().toIso8601String(),
  };
  factory PhotoIntent.fromJson(JsonMap value) => PhotoIntent(
    scope: jsonObject(value['scope']),
    ventureId: requiredText(value, 'ventureId'),
    layout: value['layout'] as bool,
    startedAt: DateTime.parse(requiredText(value, 'startedAt')),
  );
}

class RecoveredPhoto {
  const RecoveredPhoto({
    required this.intent,
    required this.path,
    required this.name,
  });
  final PhotoIntent intent;
  final String path, name;
  JsonMap toJson() => {'intent': intent.toJson(), 'path': path, 'name': name};
  factory RecoveredPhoto.fromJson(JsonMap value) => RecoveredPhoto(
    intent: PhotoIntent.fromJson(jsonObject(value['intent'])),
    path: requiredText(value, 'path'),
    name: requiredText(value, 'name'),
  );
}

class PhotoRecoveryNotice {
  const PhotoRecoveryNotice(this.message, {this.photo});
  final String message;
  final RecoveredPhoto? photo;
}

class PhotoRecovery {
  PhotoRecovery(
    this.controller, {
    PhotoPickerGateway? picker,
    DateTime Function()? now,
    XFile Function(String path, String name)? fileFromPath,
  }) : picker = picker ?? NativePhotoPicker(),
       now = now ?? DateTime.now,
       fileFromPath = fileFromPath ?? ((path, name) => XFile(path, name: name));
  final AppController controller;
  final PhotoPickerGateway picker;
  final DateTime Function() now;
  final XFile Function(String path, String name) fileFromPath;
  static const pendingKey = 'ventureplus.photo.pending.v1';
  static const recoveredKey = 'ventureplus.photo.recovered.v1';
  static const reselect =
      'A photo selection was interrupted. Open the intended venture and select the image again. Nothing was uploaded.';

  JsonMap? get currentScope {
    final user = controller.user,
        mode = controller.mode,
        repository = controller.repository;
    if (user == null ||
        user.role != Role.admin ||
        mode == null ||
        repository == null ||
        repository.user.id != user.id ||
        repository.isOffline != controller.isOffline) {
      return null;
    }
    return {
      'userId': user.id,
      'email': user.email,
      'role': user.role.wireName,
      'mode': mode.name,
      'apiBaseUrl': controller.transport.baseUrl,
    };
  }

  bool accepts(PhotoIntent intent, {String? ventureId}) {
    final scope = currentScope;
    final age = now().toUtc().difference(intent.startedAt.toUtc());
    return scope != null &&
        mapEquals(scope, intent.scope) &&
        age >= Duration.zero &&
        age <= const Duration(hours: 24) &&
        (ventureId == null || ventureId == intent.ventureId);
  }

  Future<PhotoIntent> rememberSelection(String ventureId, bool layout) async {
    final scope = currentScope;
    if (scope == null) {
      throw const AppFailure(
        'Sign in as an administrator before choosing an upload.',
      );
    }
    final intent = PhotoIntent(
      scope: scope,
      ventureId: ventureId,
      layout: layout,
      startedAt: now().toUtc(),
    );
    await discard();
    await controller.preferences.write(pendingKey, jsonEncode(intent.toJson()));
    return intent;
  }

  Future<XFile?> pick(ImageSource source, PhotoIntent intent) async {
    try {
      final file = await picker.pick(source);
      if (!accepts(intent)) {
        throw const AppFailure(
          'Your account or mode changed. Select the image again in the intended venture.',
        );
      }
      return file;
    } finally {
      await clearPending();
    }
  }

  Future<void> clearPending() => controller.preferences.remove(pendingKey);

  Future<void> discard() async {
    await controller.preferences.remove(pendingKey);
    await controller.preferences.remove(recoveredKey);
  }

  /// Called once when the app's restored home mounts. The plugin cache is
  /// consumed even when scope metadata is absent; an unbound photo is rejected.
  Future<PhotoRecoveryNotice?> recoverAtStartup() async {
    if (!picker.supportsRecovery) return null;
    String? pending, saved;
    try {
      pending = await controller.preferences.read(pendingKey);
      saved = await controller.preferences.read(recoveredKey);
      final lost = await picker.retrieveLostData().timeout(
        const Duration(seconds: 5),
      );
      if (lost.files.isEmpty &&
          !lost.failed &&
          pending == null &&
          saved == null) {
        return null;
      }
      RecoveredPhoto? photo;
      if (lost.files.length == 1 && !lost.failed && pending != null) {
        final intent = PhotoIntent.fromJson(jsonObject(jsonDecode(pending)));
        if (accepts(intent)) {
          final file = lost.files.single;
          final length = await file.length();
          if (length <= 0 || length > maxUploadBytes) {
            await discard();
            return const PhotoRecoveryNotice(
              'The interrupted photo is empty or exceeds 4 MiB. Select a smaller image. Nothing was uploaded.',
            );
          }
          photo = RecoveredPhoto(
            intent: intent,
            path: file.path,
            name: file.name,
          );
          // Save the cache reference before clearing the request, so another
          // process death during recovery does not silently lose the context.
          await controller.preferences.write(
            recoveredKey,
            jsonEncode(photo.toJson()),
          );
        }
      } else if (lost.files.isEmpty && !lost.failed && saved != null) {
        photo = RecoveredPhoto.fromJson(jsonObject(jsonDecode(saved)));
      }
      await controller.preferences.remove(pendingKey);
      if (photo == null || !accepts(photo.intent)) {
        await discard();
        return const PhotoRecoveryNotice(reselect);
      }
      return PhotoRecoveryNotice(
        'A photo selection was recovered. Review the venture and file before uploading.',
        photo: photo,
      );
    } catch (error) {
      if (error is MissingPluginException && pending == null && saved == null) {
        return null;
      }
      // Recovery must not prevent login. A failed read is a reselect path, never
      // a reason to attach the plugin's result to a new account or venture.
      try {
        await discard();
      } catch (_) {
        /* Storage error is surfaced below. */
      }
      return const PhotoRecoveryNotice(reselect);
    }
  }

  Future<Uint8List> readRecovered(
    RecoveredPhoto photo,
    String ventureId,
  ) async {
    if (!accepts(photo.intent, ventureId: ventureId)) {
      throw const AppFailure(
        'This recovered selection belongs to a different session or venture. Select the image again.',
      );
    }
    try {
      final bytes = await readSizedPhoto(fileFromPath(photo.path, photo.name));
      if (!accepts(photo.intent, ventureId: ventureId)) {
        throw const AppFailure('Your session changed. Select the image again.');
      }
      return bytes;
    } on AppFailure {
      rethrow;
    } catch (_) {
      throw const AppFailure(
        'The recovered image is no longer in the device cache. Select it again.',
      );
    }
  }

  /// Refresh the existing review affordance without invoking the native picker
  /// again. A file deleted from the temporary cache is a reselect outcome.
  Future<PhotoRecoveryNotice?> savedRecovery() async {
    try {
      final saved = await controller.preferences.read(recoveredKey);
      if (saved == null) return null;
      final photo = RecoveredPhoto.fromJson(jsonObject(jsonDecode(saved)));
      if (!accepts(photo.intent)) throw const AppFailure(reselect);
      final length = await fileFromPath(photo.path, photo.name).length();
      if (length <= 0 || length > maxUploadBytes || !accepts(photo.intent)) {
        throw const AppFailure(reselect);
      }
      return PhotoRecoveryNotice(
        'A photo selection was recovered. Review the venture and file before uploading.',
        photo: photo,
      );
    } catch (_) {
      try {
        await controller.preferences.remove(recoveredKey);
      } catch (_) {
        /* Reselect remains explicit when cleanup fails. */
      }
      return const PhotoRecoveryNotice(reselect);
    }
  }
}
