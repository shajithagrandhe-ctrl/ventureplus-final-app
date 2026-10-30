import 'package:flutter/material.dart';

import '../../core/app_controller.dart';
import '../../ui/components.dart';
import '../../ui/theme.dart';
import '../dashboard/dashboard.dart';
import '../workflows/workflow_page.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.controller});
  final AppController controller;
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int selected = 0;
  AppController get app => widget.controller;
  List<(String, IconData, Resource?)> get destinations =>
      switch (app.user!.role) {
        Role.admin => [
          ('Overview', Icons.space_dashboard_outlined, null),
          ('Inventory', Icons.landscape_outlined, Resource.locations),
          ('Customers', Icons.people_outline, Resource.customers),
          ('Access', Icons.badge_outlined, Resource.employeeAccess),
        ],
        Role.employee => [
          ('Overview', Icons.space_dashboard_outlined, null),
          ('Inventory', Icons.landscape_outlined, Resource.locations),
          ('Customers', Icons.people_outline, Resource.customers),
          ('Leads', Icons.assignment_outlined, Resource.leads),
        ],
        Role.customer => [
          ('Home', Icons.home_outlined, null),
          ('My properties', Icons.landscape_outlined, Resource.locations),
          ('Updates', Icons.location_on_outlined, Resource.tracking),
          ('Favorites', Icons.favorite_outline, Resource.favorites),
        ],
        Role.agent => [
          ('Overview', Icons.space_dashboard_outlined, null),
          ('Inventory', Icons.landscape_outlined, Resource.locations),
          ('Leads', Icons.assignment_outlined, Resource.leads),
          ('Tracking', Icons.location_on_outlined, Resource.tracking),
        ],
      };
  void open(Resource resource, String title) => Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (_) =>
          WorkflowPage(controller: app, resource: resource, title: title),
    ),
  );

  Future<void> profile() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(Brand.gutter),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  app.user!.fullName,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text(app.user!.email),
                const SizedBox(height: Brand.compact),
                Text(
                  '${app.user!.role.label} · ${app.isOffline ? 'Offline Demo' : 'Connected'}',
                ),
                const Divider(height: Brand.section),
                for (final item in <(String, IconData, Resource)>[
                  (
                    'Leads & reports',
                    Icons.assignment_outlined,
                    Resource.leads,
                  ),
                  (
                    'Customer records',
                    Icons.people_outline,
                    Resource.customers,
                  ),
                  (
                    'Tracking updates',
                    Icons.location_on_outlined,
                    Resource.tracking,
                  ),
                  ('Favorites', Icons.favorite_outline, Resource.favorites),
                  (
                    'Agent directory',
                    Icons.support_agent_outlined,
                    Resource.agents,
                  ),
                  ('Employees', Icons.badge_outlined, Resource.employees),
                  (
                    'Customer accounts',
                    Icons.account_circle_outlined,
                    Resource.customerAccounts,
                  ),
                  (
                    'Administrators',
                    Icons.admin_panel_settings_outlined,
                    Resource.admins,
                  ),
                ])
                  if (Permissions.canRead(app.user!.role, item.$3))
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(item.$2),
                      title: Text(item.$1),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.pop(context);
                        open(item.$3, item.$1);
                      },
                    ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.password_outlined),
                  title: const Text('Change password'),
                  subtitle: app.isOffline
                      ? const Text('Unavailable for fictional demo accounts')
                      : null,
                  enabled: !app.isOffline,
                  onTap: app.isOffline
                      ? null
                      : () {
                          Navigator.pop(context);
                          Navigator.push(
                            this.context,
                            MaterialPageRoute<void>(
                              builder: (_) => PasswordPage(controller: app),
                            ),
                          );
                        },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.logout),
                  title: const Text('Log out / switch account'),
                  onTap: () async {
                    Navigator.pop(context);
                    await app.logout();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final destination = destinations[selected];
    final body = destination.$3 == null
        ? DashboardPage(controller: app, onOpen: open)
        : WorkflowPage(
            key: ValueKey(destination.$3),
            controller: app,
            resource: destination.$3!,
            title: destination.$1,
            showModeIndicator: false,
          );
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Brand.gap,
                vertical: Brand.compact,
              ),
              child: Row(
                children: [
                  const BrandLogo(height: 42),
                  const SizedBox(width: Brand.compact),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Venture Plus',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          '${app.user!.role.label} · ${app.isOffline ? 'Offline Demo' : 'Connected'}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Profile and more screens',
                    onPressed: profile,
                    icon: const Icon(Icons.account_circle_outlined),
                  ),
                ],
              ),
            ),
            if (app.isOffline)
              Container(
                width: double.infinity,
                color: Brand.amberLight,
                padding: const EdgeInsets.symmetric(
                  horizontal: Brand.gap,
                  vertical: Brand.compact,
                ),
                child: const Text(
                  'Offline Demo · Fictional data · Changes stay on this device',
                  style: TextStyle(color: Brand.warning, fontSize: 12),
                ),
              ),
            if (!app.isOffline && app.sessionWarning != null)
              Semantics(
                liveRegion: true,
                child: Container(
                  width: double.infinity,
                  color: Brand.amberLight,
                  padding: const EdgeInsets.all(Brand.gap),
                  child: Text(app.sessionWarning!),
                ),
              ),
            Expanded(
              child: AnimatedSwitcher(
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : Brand.transition,
                child: body,
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selected,
        onDestinationSelected: (index) => setState(() => selected = index),
        destinations: destinations
            .map(
              (item) =>
                  NavigationDestination(icon: Icon(item.$2), label: item.$1),
            )
            .toList(),
      ),
    );
  }
}

class PasswordPage extends StatefulWidget {
  const PasswordPage({super.key, required this.controller});
  final AppController controller;
  @override
  State<PasswordPage> createState() => _PasswordPageState();
}

class _PasswordPageState extends State<PasswordPage> {
  final key = GlobalKey<FormState>();
  final current = TextEditingController(),
      next = TextEditingController(),
      repeat = TextEditingController();
  bool busy = false;
  String? error;
  @override
  void dispose() {
    current.dispose();
    next.dispose();
    repeat.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (!key.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.controller.repository!.changePassword(
        current.text,
        next.text,
      );
      await widget.controller.passwordChanged();
    } catch (e) {
      if (mounted) setState(() => error = failureMessage(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Change password')),
    body: SingleChildScrollView(
      child: PageBody(
        child: Form(
          key: key,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: current,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Current password',
                ),
                validator: (v) => (v?.length ?? 0) < 6
                    ? 'Enter your current password.'
                    : null,
              ),
              const SizedBox(height: Brand.gap),
              TextFormField(
                controller: next,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'New password'),
                validator: (v) =>
                    (v?.length ?? 0) < 8 ? 'Use at least 8 characters.' : null,
              ),
              const SizedBox(height: Brand.gap),
              TextFormField(
                controller: repeat,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirm new password',
                ),
                validator: (v) =>
                    v != next.text ? 'Passwords do not match.' : null,
              ),
              if (error != null)
                Text(error!, style: const TextStyle(color: Brand.error)),
              const SizedBox(height: Brand.gap),
              BusyButton(label: 'Update password', onPressed: save, busy: busy),
            ],
          ),
        ),
      ),
    ),
  );
}
