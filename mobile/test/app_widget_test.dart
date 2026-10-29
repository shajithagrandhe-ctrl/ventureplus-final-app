import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ventureplus/app.dart';
import 'package:ventureplus/core/app_controller.dart';
import 'package:ventureplus/features/auth/login_page.dart';
import 'package:ventureplus/features/shell/shell.dart';

import 'core_data_test.dart' show FakeTransport, identity;

void main() {
  Future<AppController> start(WidgetTester tester, {Role? role}) async {
    final app = AppController(
      transport: FakeTransport(),
      preferences: MemoryStore(),
    );
    if (role != null) await app.enterOffline(role);
    await tester.pumpWidget(VentureApp(controller: app, restoreSession: false));
    await tester.pumpAndSettle();
    addTearDown(app.dispose);
    return app;
  }

  testWidgets('catalogue is gated and every prefill only fills the form', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final app = await start(tester);
    expect(find.byType(LoginPage), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    for (final role in [Role.admin, Role.employee, Role.customer]) {
      final button = find.text('Sign in as ${role.label}');
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      final expected = DemoPrefills.forRole(role)!;
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('email')))
            .controller!
            .text,
        expected.email,
      );
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('password')))
            .controller!
            .text,
        expected.password,
      );
      expect((app.transport as FakeTransport).calls, isEmpty);
      expect(app.user, isNull);
    }
  });

  testWidgets(
    'invalid form and server failure never authenticate or select offline',
    (tester) async {
      final app = await start(tester);
      await tester.ensureVisible(find.byKey(const Key('sign-in')));
      await tester.tap(find.byKey(const Key('sign-in')));
      await tester.pumpAndSettle();
      expect(find.text('Enter a valid email address.'), findsOneWidget);
      expect((app.transport as FakeTransport).calls, isEmpty);
      await tester.enterText(
        find.byKey(const Key('email')),
        'test@example.test',
      );
      await tester.enterText(
        find.byKey(const Key('password')),
        'long-password',
      );
      await tester.ensureVisible(find.byKey(const Key('sign-in')));
      await tester.tap(find.byKey(const Key('sign-in')));
      await tester.pumpAndSettle();
      expect(find.text('Network unavailable.'), findsOneWidget);
      expect(app.mode, isNull);
    },
  );

  testWidgets('successful login uses the identity returned by me', (
    tester,
  ) async {
    final app = await start(tester);
    (app.transport as FakeTransport).handler =
        (method, path, data, query) async {
          if (path == '/auth/me') {
            return {
              'data': {'user': identity(Role.customer)},
            };
          }
          return {'data': <Object>[]};
        };
    await tester.enterText(find.byKey(const Key('email')), 'test@example.test');
    await tester.enterText(find.byKey(const Key('password')), 'long-password');
    await tester.ensureVisible(find.byKey(const Key('sign-in')));
    await tester.tap(find.byKey(const Key('sign-in')));
    await tester.pumpAndSettle();
    expect(app.user!.role, Role.customer);
    expect(find.byType(AppShell), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('My properties'),
      ),
      findsOneWidget,
    );
    expect(find.text('Access'), findsNothing);
  });

  for (final role in Role.values) {
    testWidgets('${role.label} offline navigation, profile and logout', (
      tester,
    ) async {
      final app = await start(tester, role: role);
      expect(find.textContaining('Offline Demo'), findsWidgets);
      final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(bar.destinations.length, 4);
      for (var i = 0; i < 4; i++) {
        await tester.tap(find.byType(NavigationDestination).at(i));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      await tester.tap(find.byTooltip('Profile and more screens'));
      await tester.pumpAndSettle();
      if (role != Role.admin) expect(find.text('Administrators'), findsNothing);
      final logout = find.text('Log out / switch account');
      await tester.ensureVisible(logout);
      await tester.tap(logout);
      await tester.pumpAndSettle();
      expect(find.byType(LoginPage), findsOneWidget);
      expect(app.user, isNull);
      expect((app.transport as FakeTransport).calls, isEmpty);
    });
  }

  for (final size in [const Size(360, 800), const Size(1024, 1366)]) {
    testWidgets(
      'phone/tablet ${size.width} handles large text and reduced motion',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            FakeAccessibilityFeatures(disableAnimations: true);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
        );
        await start(tester, role: Role.customer);
        expect(tester.takeException(), isNull);
        await tester.tap(find.byType(NavigationDestination).at(1));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }
}
