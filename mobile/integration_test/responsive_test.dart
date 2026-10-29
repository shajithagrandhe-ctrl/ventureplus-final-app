import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ventureplus/app.dart';
import 'package:ventureplus/core/app_controller.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'native tablet renders centered role workspace without overflow',
    (tester) async {
      final app = await AppController.create();
      expect(await app.enterOffline(Role.admin), true);
      await tester.pumpWidget(
        VentureApp(controller: app, restoreSession: false),
      );
      await tester.pumpAndSettle();
      expect(
        tester.view.physicalSize.width / tester.view.devicePixelRatio,
        greaterThanOrEqualTo(720),
      );
      expect(tester.takeException(), isNull);
      await binding.convertFlutterSurfaceToImage();
      await tester.pumpAndSettle();
      await binding.takeScreenshot('android-tablet-overview');
      await tester.tap(find.byType(NavigationDestination).at(1));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await binding.takeScreenshot('android-tablet-inventory');
      app.dispose();
    },
  );
}
