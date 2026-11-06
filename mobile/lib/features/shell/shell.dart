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
          ('Venture Locations', Icons.map_outlined, Resource.locations),
          ('Customer records', Icons.people_outline, Resource.customers),
          (
            'Employee access',
            Icons.person_search_outlined,
            Resource.employeeAccess,
          ),
        ],
        Role.employee => [
          ('Dashboard', Icons.dashboard_outlined, null),
          ('Venture Locations', Icons.map_outlined, Resource.locations),
          ('Customer records', Icons.people_outline, Resource.customers),
          ('Track Customers', Icons.groups_outlined, Resource.leads),
        ],
        Role.customer => [
          ('Dashboard', Icons.dashboard_outlined, null),
          ('My properties', Icons.map_outlined, Resource.locations),
          ('Plot Updates', Icons.navigation_outlined, Resource.tracking),
          ('Favorites', Icons.favorite_outline, Resource.favorites),
        ],
        Role.agent => [
          ('Dashboard', Icons.dashboard_outlined, null),
          ('Venture Locations', Icons.map_outlined, Resource.locations),
          ('Track Customers', Icons.groups_outlined, Resource.leads),
          ('Live Tracking', Icons.navigation_outlined, Resource.tracking),
        ],
      };

  void open(Resource resource, String title) => Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (_) =>
          WorkflowPage(controller: app, resource: resource, title: title),
    ),
  );

  Widget pageBody() {
    final currentIndex = selected >= destinations.length
        ? destinations.length - 1
        : selected;
    final destination = destinations[currentIndex];
    return AnimatedSwitcher(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : Brand.transition,
      child: destination.$3 == null
          ? DashboardPage(
              key: const ValueKey('dashboard'),
              controller: app,
              onOpen: open,
            )
          : WorkflowPage(
              key: ValueKey(destination.$3),
              controller: app,
              resource: destination.$3!,
              title: destination.$1,
              showModeIndicator: false,
            ),
    );
  }

  Future<void> changePassword() async {
    if (app.isOffline) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => PasswordPage(controller: app)),
    );
  }

  Future<void> profile() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Brand.sidebar,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          children: [
            ListTile(
              leading: const Icon(Icons.person_outline, color: Brand.cream),
              title: Text(
                app.user!.displayName,
                style: const TextStyle(color: Brand.ink),
              ),
              subtitle: Text(
                app.user!.email,
                style: const TextStyle(color: Brand.secondary),
              ),
            ),
            if (Permissions.canRead(app.user!.role, Resource.admins))
              const ListTile(
                leading: Icon(
                  Icons.admin_panel_settings_outlined,
                  color: Brand.secondary,
                ),
                title: Text(
                  'Administrators',
                  style: TextStyle(color: Brand.secondary),
                ),
              ),
            ListTile(
              leading: const Icon(Icons.key_outlined, color: Brand.secondary),
              title: const Text(
                'Change Password',
                style: TextStyle(color: Brand.secondary),
              ),
              enabled: !app.isOffline,
              onTap: app.isOffline ? null : changePassword,
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: Brand.secondary),
              title: const Text(
                'Log out / switch account',
                style: TextStyle(color: Brand.secondary),
              ),
              onTap: () {
                Navigator.pop(context);
                app.logout();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget bottomNavigation({bool stressScale = false}) =>
      MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1,
        child: Builder(
          builder: (context) {
            return NavigationBar(
              height: stressScale ? 56 : null,
              labelBehavior: stressScale
                  ? NavigationDestinationLabelBehavior.alwaysHide
                  : null,
              selectedIndex: selected,
              onDestinationSelected: (index) {
                setState(() => selected = index);
              },
              destinations: [
                for (final item in destinations)
                  NavigationDestination(icon: Icon(item.$2), label: item.$1),
              ],
            );
          },
        ),
      );

  Widget sidebar({bool closeOnSelect = false}) {
    final currentIndex = selected >= destinations.length
        ? destinations.length - 1
        : selected;
    final active = destinations[currentIndex];
    final nameParts = app.user!.displayName.trim().split(RegExp(r'\s+'));
    final initials = nameParts
        .take(2)
        .map((part) => part[0])
        .join()
        .toUpperCase();
    return Material(
      color: Brand.sidebar,
      child: SafeArea(
        child: SizedBox(
          width: 264,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 16, 20),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Brand.sidebarAccent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Text(
                          'V',
                          style: TextStyle(
                            color: Brand.ink,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Venture Plus',
                            style: TextStyle(
                              color: Brand.ink,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'For a Better Tomorrow',
                            style: TextStyle(
                              color: Brand.secondary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(color: Brand.border, height: 1),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 19,
                      backgroundColor: Brand.sidebarAccent,
                      child: Text(
                        initials,
                        style: const TextStyle(
                          color: Brand.ink,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            app.user!.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Brand.ink,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            app.user!.role.label,
                            style: const TextStyle(
                              color: Brand.secondary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Profile and more screens',
                      onPressed: profile,
                      icon: const Icon(
                        Icons.account_circle_outlined,
                        color: Brand.secondary,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: app.isOffline
                        ? Brand.amberLight
                        : const Color(0x3322C55E),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.circle,
                          size: 8,
                          color: app.isOffline ? Brand.warning : Brand.success,
                        ),
                        const SizedBox(width: 7),
                        Text(
                          app.isOffline ? 'Offline Demo' : 'Connected',
                          style: TextStyle(
                            color: app.isOffline
                                ? Brand.warning
                                : Brand.success,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: destinations.length,
                  itemBuilder: (context, index) {
                    final item = destinations[index];
                    final isActive = item == active;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () {
                          setState(() => selected = index);
                          if (closeOnSelect) Navigator.pop(context);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 13,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: isActive
                                ? Brand.sidebarAccent
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                item.$2,
                                size: 20,
                                color: isActive ? Brand.ink : Brand.secondary,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  item.$1,
                                  style: TextStyle(
                                    color: isActive
                                        ? Brand.ink
                                        : const Color(0xCCCBD5E1),
                                    fontSize: 13,
                                    fontWeight: isActive
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const Divider(color: Brand.border, height: 1),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(
                        Icons.key_outlined,
                        color: Brand.secondary,
                      ),
                      title: const Text(
                        'Change Password',
                        style: TextStyle(color: Brand.secondary, fontSize: 13),
                      ),
                      enabled: !app.isOffline,
                      onTap: app.isOffline ? null : changePassword,
                    ),
                    ListTile(
                      leading: const Icon(Icons.logout, color: Brand.secondary),
                      title: const Text(
                        'Logout',
                        style: TextStyle(color: Brand.secondary, fontSize: 13),
                      ),
                      onTap: () async => app.logout(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget mobileHeader() => Container(
    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
    decoration: const BoxDecoration(
      color: Brand.sidebar,
      border: Border(bottom: BorderSide(color: Brand.border)),
    ),
    child: Row(
      children: [
        Builder(
          builder: (context) => IconButton(
            tooltip: 'Open navigation',
            onPressed: () => Scaffold.of(context).openDrawer(),
            icon: const Icon(Icons.menu, color: Brand.ink),
          ),
        ),
        const SizedBox(width: 4),
        const Expanded(
          child: Text(
            'Venture Plus',
            style: TextStyle(
              color: Brand.ink,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Text(
          app.user!.role.label,
          style: const TextStyle(color: Brand.secondary, fontSize: 12),
        ),
        IconButton(
          tooltip: 'Profile and more screens',
          onPressed: profile,
          icon: const Icon(
            Icons.account_circle_outlined,
            color: Brand.secondary,
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final stressScale =
        MediaQuery.textScalerOf(context).scale(14) > 20 ||
        MediaQuery.sizeOf(context).width < 500;
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.3,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final desktop = constraints.maxWidth >= Brand.tablet;
          if (desktop) {
            return Scaffold(
              body: SafeArea(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Row(
                      children: [
                        sidebar(),
                        Expanded(child: pageBody()),
                      ],
                    ),
                    Positioned(
                      left: 264,
                      right: 0,
                      bottom: 0,
                      child: bottomNavigation(stressScale: stressScale),
                    ),
                  ],
                ),
              ),
            );
          }
          return Scaffold(
            bottomNavigationBar: bottomNavigation(stressScale: stressScale),
            drawer: Drawer(width: 280, child: sidebar(closeOnSelect: true)),
            body: SafeArea(
              child: Column(
                children: [
                  mobileHeader(),
                  if (app.isOffline) const _ModeBanner(),
                  Expanded(child: pageBody()),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ModeBanner extends StatelessWidget {
  const _ModeBanner();
  @override
  Widget build(BuildContext context) => Container(
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
  );
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
