import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ventureplus/core/app_controller.dart';

import 'core_data_test.dart' show FakeTransport, identity;

class FailingRemoveStore extends MemoryStore {
  @override
  Future<void> remove(String key) async => throw StateError('locked');
}

class DelayedRemoveStore extends MemoryStore {
  final release = Completer<void>();
  @override
  Future<void> remove(String key) async {
    await release.future;
    await super.remove(key);
  }
}

void main() {
  test(
    'new sessions are blocked until old session cleanup completes',
    () async {
      final store = DelayedRemoveStore();
      final transport = FakeTransport();
      final app = AppController(transport: transport, preferences: store)
        ..user = UserIdentity.fromJson(identity())
        ..mode = SessionMode.connected;
      addTearDown(app.dispose);
      final cleanup = app.passwordChanged();
      expect(app.user, isNull);
      expect(app.busy, isTrue);
      expect(await app.enterOffline(Role.admin), isFalse);
      expect(await app.login('test@example.com', 'validpassword'), isFalse);
      expect(transport.calls, isEmpty);
      store.release.complete();
      await cleanup;
      expect(app.busy, isFalse);
      expect(await app.enterOffline(Role.admin), isTrue);
      expect(store.values[AppController.modeKey], SessionMode.offlineDemo.name);
    },
  );

  test(
    'confirmed password change ends local session without another mutation',
    () async {
      final store = MemoryStore();
      await store.write(AppController.modeKey, SessionMode.connected.name);
      final transport = FakeTransport();
      final app = AppController(transport: transport, preferences: store)
        ..user = UserIdentity.fromJson(identity())
        ..mode = SessionMode.connected;
      addTearDown(app.dispose);
      await app.passwordChanged();
      expect(app.user, isNull);
      expect(app.mode, isNull);
      expect(app.sessionNotice, contains('Password updated'));
      expect(store.values, isEmpty);
      expect(transport.clears, 1);
      expect(transport.calls, isEmpty);
    },
  );

  test('local cleanup failure never presents a confirmed password change as retryable', () async {
    final transport = FakeTransport();
    final app =
        AppController(transport: transport, preferences: FailingRemoveStore())
          ..user = UserIdentity.fromJson(identity())
          ..mode = SessionMode.connected;
    addTearDown(app.dispose);
    await app.passwordChanged();
    expect(app.user, isNull);
    expect(app.mode, isNull);
    expect(app.error, contains('password was updated'));
    expect(app.error, isNot(contains('try again')));
    expect(transport.calls, isEmpty);
  });
}
