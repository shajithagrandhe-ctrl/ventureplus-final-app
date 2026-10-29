import 'package:flutter/material.dart';

import 'app.dart';
import 'core/app_controller.dart';
import 'ui/components.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final controller = await AppController.create();
    runApp(VentureApp(controller: controller));
  } catch (_) {
    runApp(
      MaterialApp(
        theme: Brand.theme,
        home: Scaffold(
          body: PageBody(
            child: StateMessage(
              title: 'Unable to open local storage',
              message: 'Close and reopen the app. Your saved data has not been reset.',
              actionLabel: 'Retry',
              action: main,
            ),
          ),
        ),
      ),
    );
  }
}
