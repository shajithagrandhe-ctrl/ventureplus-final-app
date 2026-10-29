import 'package:flutter/material.dart';

import 'core/app_controller.dart';
import 'features/auth/login_page.dart';
import 'features/shell/shell.dart';
import 'ui/components.dart';
import 'ui/theme.dart';

class VentureApp extends StatefulWidget {
  const VentureApp({
    super.key,
    required this.controller,
    this.restoreSession = true,
  });
  final AppController controller;
  final bool restoreSession;
  @override
  State<VentureApp> createState() => _VentureAppState();
}

class _VentureAppState extends State<VentureApp> {
  bool ready = false;
  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    if (widget.restoreSession) await widget.controller.restore();
    if (mounted) setState(() => ready = true);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final controller = widget.controller;
      return MaterialApp(
        key: ValueKey('${controller.user?.id}-${controller.mode}'),
        title: 'Venture Plus',
        debugShowCheckedModeBanner: false,
        theme: Brand.theme,
        themeMode: ThemeMode.light,
        home: !ready
            ? const StartupPage()
            : controller.user == null
            ? LoginPage(controller: controller)
            : AppShell(controller: controller),
        onUnknownRoute: (_) => MaterialPageRoute<void>(
          builder: (_) => Scaffold(
            appBar: AppBar(title: const Text('Page unavailable')),
            body: const PageBody(
              child: StateMessage(
                title: 'This page is not available',
                message: 'Use the navigation in your workspace.',
              ),
            ),
          ),
        ),
      );
    },
  );
}

class StartupPage extends StatelessWidget {
  const StartupPage({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          BrandLogo(height: 128),
          SizedBox(height: Brand.section),
          Text('Opening your workspace'),
          SizedBox(height: Brand.gap),
          CircularProgressIndicator(),
        ],
      ),
    ),
  );
}
