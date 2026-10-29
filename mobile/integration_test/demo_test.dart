import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ventureplus/app.dart';
import 'package:ventureplus/core/app_controller.dart';
import 'package:ventureplus/features/auth/login_page.dart';
import 'package:ventureplus/features/workflows/workflow_page.dart';
import 'package:ventureplus/ui/theme.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  WidgetController.hitTestWarningShouldBeFatal = true;
  const live = bool.fromEnvironment('LIVE_AUTH_TESTS');

  Future<void> tap(WidgetTester tester, Finder target) async {
    await tester.ensureVisible(target.first);
    await tester.pumpAndSettle();
    await tester.tap(target.first);
    await tester.pumpAndSettle();
  }

  if (live) {
    for (final role in [Role.admin, Role.employee, Role.customer]) {
      testWidgets(
        'native connected ${role.label} prefill, verified identity and logout',
        (tester) async {
          final app = await AppController.create();
          await app.logout();
          await tester.pumpWidget(
            VentureApp(controller: app, restoreSession: false),
          );
          await tester.pumpAndSettle();
          await tap(tester, find.text('Sign in as ${role.label}'));
          expect(app.user, isNull);
          await tap(tester, find.byKey(const Key('sign-in')));
          expect(app.user?.role, role, reason: app.error);
          expect(app.mode, SessionMode.connected);
          final restored = await AppController.create();
          expect(await restored.restore(), true, reason: restored.error);
          expect(restored.user?.role, role);
          await restored.logout();
          restored.dispose();
          await app.logout();
          await tester.pumpAndSettle();
          expect(find.byType(LoginPage), findsOneWidget);
          app.dispose();
        },
      );
    }
  } else {
    testWidgets('offline entry and all role destinations run without network', (
      tester,
    ) async {
      final app = await AppController.create();
      await app.logout();
      await tester.pumpWidget(
        VentureApp(controller: app, restoreSession: false),
      );
      await tester.pumpAndSettle();
      await tap(tester, find.byKey(const Key('offline-entry')));
      await tap(tester, find.text('Explore as Admin'));
      expect(app.mode, SessionMode.offlineDemo);
      await binding.convertFlutterSurfaceToImage();
      await tester.pumpAndSettle();
      await binding.takeScreenshot('android-admin-overview');
      for (final role in Role.values) {
        await app.enterOffline(role);
        await tester.pumpAndSettle();
        for (var i = 0; i < 4; i++) {
          await tap(tester, find.byType(NavigationDestination).at(i));
          expect(tester.takeException(), isNull);
        }
        if (role == Role.customer) {
          await binding.takeScreenshot('android-customer-favorites');
        }
      }
      await app.logout();
      await tester.pumpAndSettle();
      expect(find.byType(LoginPage), findsOneWidget);
      app.dispose();
    });

    testWidgets('offline favorite action persists in native storage', (
      tester,
    ) async {
      final app = await AppController.create();
      await app.enterOffline(Role.customer);
      for (final favorite in await app.repository!.list(Resource.favorites)) {
        if (favorite['plotId'] == 'demo-plot-1') {
          await app.repository!.remove(Resource.favorites, '${favorite['id']}');
        }
      }
      final plot = await app.repository!.detail(Resource.plots, 'demo-plot-1');
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
      await tap(tester, find.text('Add to favorites'));
      expect(
        (await app.repository!.list(Resource.favorites))
            .any((row) => row['plotId'] == 'demo-plot-1'),
        true,
      );
      final restored = await AppController.create();
      expect(await restored.restore(), true);
      expect(restored.mode, SessionMode.offlineDemo);
      expect(
        (await restored.repository!.list(Resource.favorites))
            .any((row) => row['plotId'] == 'demo-plot-1'),
        true,
      );
      restored.dispose();
      app.dispose();
    });

    testWidgets('employee creates a customer record through validated form', (
      tester,
    ) async {
      final app = await AppController.create();
      await app.enterOffline(Role.employee);
      final beforeCount = (await app.repository!.list(Resource.customers))
          .length;
      await tester.pumpWidget(
        MaterialApp(
          theme: Brand.theme,
          home: WorkflowPage(controller: app, resource: Resource.customers),
        ),
      );
      await tester.pumpAndSettle();
      await tap(tester, find.text('Add customer record'));
      await tap(tester, find.text('Save'));
      expect(find.text('Enter Customer name.'), findsOneWidget);
      Future<void> fill(String key, String value) async {
        final field = find.byKey(ValueKey(key));
        await tester.ensureVisible(field);
        await tester.enterText(field, value);
        await tester.pumpAndSettle();
      }

      await fill('contactName', 'Offline persistence check');
      await fill('contactNumber', '0000000011');
      await fill('location', 'Fictional test district');
      await fill('budget', '4500000');
      await tap(tester, find.text('Save'));
      expect(
        (await app.repository!.list(Resource.customers)).length,
        beforeCount + 1,
      );
      expect(
        (await app.repository!.list(Resource.customers))
            .any((row) => row['contactName'] == 'Offline persistence check'),
        true,
      );
      await tester.pumpWidget(
        VentureApp(controller: app, restoreSession: false),
      );
      await tester.pumpAndSettle();
      await binding.convertFlutterSurfaceToImage();
      await tester.pumpAndSettle();
      await binding.takeScreenshot('android-employee-overview');
      app.dispose();
    });
  }
}
