import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ventureplus/core/app_controller.dart';
import 'package:ventureplus/features/workflows/workflow_page.dart';
import 'package:ventureplus/ui/theme.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  WidgetController.hitTestWarningShouldBeFatal = true;

  Future<void> tap(WidgetTester tester, Finder target) async {
    await tester.ensureVisible(target.first);
    await tester.pumpAndSettle();
    await tester.tap(target.first);
    await tester.pumpAndSettle();
  }

  Future<void> fill(WidgetTester tester, String key, String value) async {
    final field = find.byKey(ValueKey(key));
    await tester.ensureVisible(field);
    await tester.pumpAndSettle();
    // Let the real IME finish reconnecting before injecting replacement text.
    await tester.showKeyboard(field);
    await tester.pumpAndSettle();
    await tester.enterText(field, value);
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextFormField>(field).controller!.text,
      value,
      reason: 'Native text entry for $key must reach its controller.',
    );
    // Dismiss the native keyboard so the next action remains reachable.
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextFormField>(field).controller!.text,
      value,
      reason: 'Dismissing the keyboard must preserve $key.',
    );
  }

  Future<AppController> open(
    WidgetTester tester,
    Role role,
    Resource resource,
  ) async {
    final app = await AppController.create();
    expect(await app.enterOffline(role), true, reason: app.error);
    expect(app.mode, SessionMode.offlineDemo);
    expect(app.repository!.isOffline, true);
    await tester.pumpWidget(
      MaterialApp(
        theme: Brand.theme,
        home: WorkflowPage(controller: app, resource: resource),
      ),
    );
    await tester.pumpAndSettle();
    addTearDown(app.dispose);
    return app;
  }

  testWidgets(
    'native admin creates a venture and navigates location to plots',
    (tester) async {
      final app = await open(tester, Role.admin, Resource.locations);
      final before = await app.repository!.list(Resource.ventures);
      final existingIds = before.map((row) => row['id']).toSet();
      final name = 'Native QA venture ${before.length + 1}';
      await tap(tester, find.text('Add venture'));
      await tap(tester, find.text('Save'));
      expect(find.text('Enter Venture name.'), findsOneWidget);
      await fill(tester, 'name', name);
      await fill(tester, 'locationName', 'Native QA district');
      await fill(tester, 'plotCount', '3');
      await fill(tester, 'plotNumberPrefix', 'QA-');
      await fill(tester, 'startingPlotNumber', '701');
      await fill(tester, 'defaultArea', '180');
      await fill(tester, 'defaultPricePerSqYard', '25000');
      await tap(tester, find.text('Save'));
      final created = (await app.repository!.list(Resource.ventures))
          .singleWhere((row) => !existingIds.contains(row['id']));
      expect(created['name'], name);
      final plots = await app.repository!.list(
        Resource.plots,
        query: {'ventureId': created['id']},
      );
      expect(plots, hasLength(3));
      expect(plots.map((row) => row['plotNumber']).toSet(), {
        'QA-701',
        'QA-702',
        'QA-703',
      });
      await tap(tester, find.text('Native QA district'));
      await tap(tester, find.text(name));
      expect(find.text('3 plots'), findsOneWidget);
      await tap(tester, find.text('Plot QA-701'));
      expect(find.text('Edit details'), findsOneWidget);
      expect(find.text('4500000'), findsOneWidget);
      final restored = await AppController.create();
      expect(await restored.restore(), true, reason: restored.error);
      expect(
        (await restored.repository!.list(Resource.ventures))
            .any((row) => row['id'] == created['id']),
        true,
      );
      restored.dispose();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'native agent saves real entered tracking coordinates with validation',
    (tester) async {
      final app = await open(tester, Role.agent, Resource.tracking);
      final customer = (await app.repository!.list(Resource.customers))
          .firstWhere((row) => row['id'] == 'demo-record-2');
      await tap(tester, find.text('Add tracking update'));
      await tap(tester, find.byKey(const ValueKey('customerId')));
      await tap(
        tester,
        find.text('${customer['contactName']} · ${customer['location']}').last,
      );
      await fill(tester, 'latitude', '91');
      await fill(tester, 'longitude', '83.31');
      await tap(tester, find.text('Save'));
      expect(find.text('Enter 90 or less.'), findsOneWidget);
      await fill(tester, 'latitude', '17.72');
      await fill(tester, 'address', 'Native offline QA visit point');
      await tap(tester, find.text('Save'));
      final row = (await app.repository!.list(Resource.tracking))
          .singleWhere((row) => row['customerId'] == customer['id']);
      expect(row['latitude'], 17.72);
      expect(row['longitude'], 83.31);
      expect(row['address'], 'Native offline QA visit point');
      expect(row['updatedBy'], app.user!.id);
      final restored = await AppController.create();
      expect(await restored.restore(), true, reason: restored.error);
      final saved = (await restored.repository!.list(Resource.tracking))
          .singleWhere((row) => row['customerId'] == customer['id']);
      expect(saved['latitude'], 17.72);
      restored.dispose();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'native agent inquiry is validated and persisted locally without staff writes',
    (tester) async {
      // Use Flutter's text-input test binding for this multiline replacement.
      // With the real IME attached, its old composing state races enterText.
      // UI validation, buttons and platform-backed persistence remain real;
      // this test does not claim to verify physical-keyboard composition.
      tester.testTextInput.register();
      addTearDown(tester.testTextInput.unregister);
      final app = await AppController.create();
      expect(await app.enterOffline(Role.agent), true, reason: app.error);
      addTearDown(app.dispose);
      final plot = await app.repository!.detail(Resource.plots, 'demo-plot-3');
      final before = jsonObject(
        jsonDecode((await app.preferences.read(OfflineRepository.storageKey))!),
      );
      final count = jsonList(before['inquiries']).length;
      await tester.pumpWidget(
        MaterialApp(
          theme: Brand.theme,
          home: RecordDetailPage(
            controller: app,
            resource: Resource.plots,
            record: plot,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Edit details'), findsNothing);
      expect(find.text('Add lead'), findsNothing);
      await tap(tester, find.text('Make an inquiry'));
      await fill(tester, 'message', 'Short');
      await tap(tester, find.text('Save inquiry locally'));
      expect(find.text('Use at least 10 characters.'), findsOneWidget);
      const message =
          'Native offline inquiry validation and persistence check.';
      await fill(tester, 'message', message);
      final submit = find.text('Save inquiry locally');
      await tester.ensureVisible(submit);
      await tester.pumpAndSettle();
      await tester.tap(submit);
      final feedback = find.text('Inquiry saved locally. It was not sent.');
      final deadline = DateTime.now().add(const Duration(seconds: 15));
      while (feedback.evaluate().isEmpty && DateTime.now().isBefore(deadline)) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(
        feedback,
        findsOneWidget,
        reason: tester
            .widgetList<Text>(find.byType(Text))
            .map((text) => text.data)
            .join(' | '),
      );
      final restored = await AppController.create();
      expect(await restored.restore(), true, reason: restored.error);
      expect(restored.mode, SessionMode.offlineDemo);
      final after = jsonObject(
        jsonDecode(
          (await restored.preferences.read(OfflineRepository.storageKey))!,
        ),
      );
      final inquiries = jsonList(after['inquiries']);
      expect(inquiries, hasLength(count + 1));
      expect(inquiries.last['plotId'], 'demo-plot-3');
      expect(inquiries.last['message'], message);
      expect(inquiries.last['customerEmail'], app.user!.email);
      restored.dispose();
      expect(tester.takeException(), isNull);
    },
  );
}
