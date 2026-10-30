import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ventureplus/core/app_controller.dart';
import 'package:ventureplus/features/workflows/photo_recovery.dart';
import 'package:ventureplus/features/workflows/picker_recovery_host.dart';
import 'package:ventureplus/features/workflows/venture_detail.dart';

import 'core_data_test.dart' show FakeTransport;

class TestPhoto extends XFile {
  TestPhoto({this.reportedLength = 3, Uint8List? content})
    : content = content ?? Uint8List.fromList([1, 2, 3]),
      super('/cache/test-photo.jpg');
  final int reportedLength;
  final Uint8List content;
  int reads = 0, lengthReads = 0;
  bool missing = false;
  @override
  Future<int> length() async {
    lengthReads++;
    if (missing) throw StateError('Cache file was deleted.');
    return reportedLength;
  }

  @override
  Future<Uint8List> readAsBytes() async {
    reads++;
    return content;
  }
}

class TestPicker implements PhotoPickerGateway {
  LostPhotoData lost = const LostPhotoData();
  XFile? selected;
  Object? failure;
  int retrievals = 0;
  @override
  bool get supportsRecovery => true;
  @override
  Future<XFile?> pick(ImageSource source) async => selected;
  @override
  Future<LostPhotoData> retrieveLostData() async {
    retrievals++;
    if (failure != null) throw failure!;
    return lost;
  }
}

class OtherApiTransport extends FakeTransport {
  @override
  String get baseUrl => 'https://example.test/another-api';
}

void main() {
  final time = DateTime.utc(2026, 10, 29, 10);
  Future<AppController> admin(
    MemoryStore store, {
    ApiTransport? transport,
    bool restore = false,
  }) async {
    final app = AppController(
      transport: transport ?? FakeTransport(),
      preferences: store,
    );
    expect(
      restore ? await app.restore() : await app.enterOffline(Role.admin),
      true,
    );
    addTearDown(app.dispose);
    return app;
  }

  test(
    'camera/gallery reject oversized selection before reading bytes',
    () async {
      final file = TestPhoto(reportedLength: maxUploadBytes + 1);
      await expectLater(readSizedPhoto(file), throwsA(isA<AppFailure>()));
      expect(file.lengthReads, 1);
      expect(file.reads, 0);
      final empty = TestPhoto(reportedLength: 0);
      await expectLater(readSizedPhoto(empty), throwsA(isA<AppFailure>()));
      expect(empty.reads, 0);
    },
  );

  test('size check also rejects a file that grows after preflight', () async {
    final file = TestPhoto(content: Uint8List(maxUploadBytes + 1));
    await expectLater(readSizedPhoto(file), throwsA(isA<AppFailure>()));
    expect(file.reads, 1);
    expect(await readSizedPhoto(TestPhoto()), [1, 2, 3]);
  });

  test('process-death recovery retains exact venture/layout/account and awaits review', () async {
    final store = MemoryStore();
    final first = await admin(store);
    await PhotoRecovery(
      first,
      picker: TestPicker(),
      now: () => time,
    ).rememberSelection('demo-venture-1', true);
    final restored = await admin(store, restore: true);
    final file = TestPhoto();
    final picker = TestPicker()..lost = LostPhotoData(files: [file]);
    final recovery = PhotoRecovery(
      restored,
      picker: picker,
      now: () => time.add(const Duration(minutes: 1)),
    );
    final notice = await recovery.recoverAtStartup();
    expect(picker.retrievals, 1);
    expect(notice!.photo!.intent.ventureId, 'demo-venture-1');
    expect(notice.photo!.intent.layout, true);
    expect(notice.photo!.intent.scope['mode'], SessionMode.offlineDemo.name);
    expect(notice.photo!.intent.scope['userId'], restored.user!.id);
    expect(
      notice.photo!.intent.scope['apiBaseUrl'],
      restored.transport.baseUrl,
    );
    expect(
      file.reads,
      0,
      reason: 'Startup recovery must not read/upload image bytes.',
    );
    expect(store.values[PhotoRecovery.pendingKey], isNull);
    expect(store.values[PhotoRecovery.recoveredKey], isNotNull);
    expect((restored.transport as FakeTransport).calls, isEmpty);
    expect(
      recovery.accepts(notice.photo!.intent, ventureId: 'demo-venture-2'),
      false,
    );
    await expectLater(
      recovery.readRecovered(notice.photo!, 'demo-venture-2'),
      throwsA(isA<AppFailure>()),
    );
    final nextBoot = PhotoRecovery(
      restored,
      picker: TestPicker(),
      now: () => time.add(const Duration(minutes: 2)),
    );
    expect(
      (await nextBoot.recoverAtStartup())!.photo!.intent.ventureId,
      'demo-venture-1',
    );
  });

  for (final mismatch in ['account', 'mode', 'api path']) {
    test(
      'recovery consumes but never exposes selection after $mismatch change',
      () async {
        final store = MemoryStore();
        final original = await admin(store);
        await PhotoRecovery(
          original,
          now: () => time,
        ).rememberSelection('demo-venture-1', false);
        final current = await admin(
          store,
          restore: true,
          transport: mismatch == 'api path' ? OtherApiTransport() : null,
        );
        if (mismatch == 'account') await current.enterOffline(Role.employee);
        if (mismatch == 'mode') current.mode = SessionMode.connected;
        final file = TestPhoto();
        final picker = TestPicker()..lost = LostPhotoData(files: [file]);
        final notice = await PhotoRecovery(
          current,
          picker: picker,
          now: () => time,
        ).recoverAtStartup();
        expect(picker.retrievals, 1);
        expect(notice!.photo, isNull);
        expect(notice.message, PhotoRecovery.reselect);
        expect(file.reads, 0);
        expect(store.values[PhotoRecovery.pendingKey], isNull);
        expect(store.values[PhotoRecovery.recoveredKey], isNull);
      },
    );
  }

  test(
    'unbound and expired lost files require reselect without byte reads',
    () async {
      final store = MemoryStore();
      final app = await admin(store);
      final file = TestPhoto();
      final picker = TestPicker()..lost = LostPhotoData(files: [file]);
      expect(
        (await PhotoRecovery(
          app,
          picker: picker,
          now: () => time,
        ).recoverAtStartup())!.photo,
        isNull,
      );
      await PhotoRecovery(
        app,
        now: () => time,
      ).rememberSelection('demo-venture-1', true);
      final expired = PhotoRecovery(
        app,
        picker: picker,
        now: () => time.add(const Duration(hours: 25)),
      );
      expect((await expired.recoverAtStartup())!.photo, isNull);
      expect(file.reads, 0);
      expect(store.values[PhotoRecovery.pendingKey], isNull);
    },
  );

  test(
    'recovered oversized file and plugin failure are safe reselect outcomes',
    () async {
      final store = MemoryStore();
      final app = await admin(store);
      final file = TestPhoto(reportedLength: maxUploadBytes + 1);
      final picker = TestPicker()..lost = LostPhotoData(files: [file]);
      final recovery = PhotoRecovery(app, picker: picker, now: () => time);
      await recovery.rememberSelection('demo-venture-1', true);
      final notice = await recovery.recoverAtStartup();
      expect(notice!.photo, isNull);
      expect(notice.message, contains('exceeds 4 MiB'));
      expect(file.reads, 0);
      await recovery.rememberSelection('demo-venture-1', true);
      picker.failure = StateError('Plugin unavailable');
      expect(
        (await recovery.recoverAtStartup())!.message,
        PhotoRecovery.reselect,
      );
      expect(app.user!.role, Role.admin);
      expect(store.values[PhotoRecovery.pendingKey], isNull);
    },
  );

  test('cancelled ordinary picker clears its persisted intent', () async {
    final store = MemoryStore();
    final app = await admin(store);
    final recovery = PhotoRecovery(app, picker: TestPicker(), now: () => time);
    final intent = await recovery.rememberSelection('demo-venture-1', false);
    expect(await recovery.pick(ImageSource.gallery, intent), isNull);
    expect(await recovery.recoverAtStartup(), isNull);
  });

  test(
    'saved recovery rejects a deleted cache file without querying the picker',
    () async {
      final store = MemoryStore();
      final app = await admin(store);
      final file = TestPhoto();
      final picker = TestPicker()..lost = LostPhotoData(files: [file]);
      final recovery = PhotoRecovery(
        app,
        picker: picker,
        now: () => time,
        fileFromPath: (_, _) => file,
      );
      await recovery.rememberSelection('demo-venture-1', true);
      expect((await recovery.recoverAtStartup())!.photo, isNotNull);
      file.missing = true;
      final notice = await recovery.savedRecovery();
      expect(notice!.photo, isNull);
      expect(notice.message, PhotoRecovery.reselect);
      expect(store.values[PhotoRecovery.recoveredKey], isNull);
      expect(picker.retrievals, 1);
      expect(file.reads, 0);
    },
  );

  testWidgets(
    'recovery review then Back restores Review and Discard in the same process',
    (tester) async {
      tester.view.physicalSize = const Size(460, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = MemoryStore();
      final app = await admin(store);
      final file = TestPhoto();
      final picker = TestPicker()..lost = LostPhotoData(files: [file]);
      final recovery = PhotoRecovery(
        app,
        picker: picker,
        now: () => time,
        fileFromPath: (_, _) => file,
      );
      await recovery.rememberSelection('demo-venture-1', true);
      await tester.pumpWidget(
        MaterialApp(
          home: PickerRecoveryHost(
            controller: app,
            recovery: recovery,
            child: const Scaffold(body: Text('Workspace')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Review selection'), findsOneWidget);
      await tester.tap(find.text('Review selection'));
      await tester.pumpAndSettle();
      expect(find.byType(VentureDetailPage), findsOneWidget);
      expect(
        find.text('Selected: ${file.name}'),
        findsOneWidget,
        reason: tester
            .widgetList<Text>(find.byType(Text))
            .map((text) => text.data)
            .join(' | '),
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Review selection'), findsOneWidget);
      expect(find.text('Discard'), findsOneWidget);
      expect(
        picker.retrievals,
        1,
        reason: 'Returning from review should not invoke native lost-data retrieval again.',
      );
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      expect(find.text('Review selection'), findsNothing);
      expect(store.values[PhotoRecovery.recoveredKey], isNull);
      expect(tester.takeException(), isNull);
    },
  );
}
