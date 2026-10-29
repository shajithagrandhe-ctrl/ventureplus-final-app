import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ventureplus/app.dart';
import 'package:ventureplus/core/app_controller.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'offline employee session and mutation survive an app process restart',
    (tester) async {
      final app = await AppController.create();
      expect(await app.restore(), true, reason: app.error);
      expect(app.mode, SessionMode.offlineDemo);
      expect(app.user?.role, Role.employee);
      expect(
        (await app.repository!.list(Resource.customers))
            .any((row) => row['contactName'] == 'Offline persistence check'),
        true,
      );
      await tester.pumpWidget(
        VentureApp(controller: app, restoreSession: false),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Offline Demo'), findsWidgets);
      app.dispose();
    },
  );
}
