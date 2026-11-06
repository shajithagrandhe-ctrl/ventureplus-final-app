import 'package:flutter/material.dart';

import '../../core/app_controller.dart';
import '../../ui/components.dart';
import '../../ui/theme.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.controller});
  final AppController controller;
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final form = GlobalKey<FormState>();
  final email = TextEditingController();
  final password = TextEditingController();
  bool obscure = true;
  Role activePortal = Role.employee;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Color portalColor(Role role) => switch (role) {
    Role.employee => Brand.blue,
    Role.admin => Brand.purple,
    Role.customer => Brand.green,
    Role.agent => Brand.blue,
  };

  IconData portalIcon(Role role) => switch (role) {
    Role.employee => Icons.business_center_outlined,
    Role.admin => Icons.shield_outlined,
    Role.customer => Icons.people_outline,
    Role.agent => Icons.support_agent_outlined,
  };

  String portalTitle(Role role) => switch (role) {
    Role.employee => 'Employee Portal',
    Role.admin => 'Admin Portal',
    Role.customer => 'Customer Portal',
    Role.agent => 'Agent Portal',
  };

  String portalSubtitle(Role role) => switch (role) {
    Role.employee => 'Manage properties and customers',
    Role.admin => 'System administration',
    Role.customer => 'View your properties',
    Role.agent => 'Manage your property relationships',
  };

  void prefill(Role role) {
    final credentials = DemoPrefills.forRole(role);
    if (credentials == null) return;
    setState(() => activePortal = role);
    email.text = credentials.email;
    password.text = credentials.password;
    widget.controller.clearError();
    showFeedback(
      context,
      '${role.label} details filled. Press Sign in to authenticate.',
    );
  }

  Future<void> submit() async {
    if (!form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    await widget.controller.login(
      email.text.trim(),
      password.text,
      activePortal,
    );
  }

  Future<void> offline() async {
    final role = await showModalBottomSheet<Role>(
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
                  'Offline Demo',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: Brand.compact),
                const Text(
                  'Explore fictional properties and records. Changes stay on this device and are never sent to the server.',
                ),
                const SizedBox(height: Brand.gap),
                for (final role in Role.values)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(portalIcon(role)),
                    title: Text('Explore as ${role.label}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.pop(context, role),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    if (role != null) await widget.controller.enterOffline(role);
  }

  Widget portalTabs() => Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: const Color(0x1AFFFFFF),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Brand.border),
    ),
    child: Row(
      children: [
        for (final role in [Role.employee, Role.admin, Role.customer])
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => activePortal = role),
              child: AnimatedContainer(
                duration: Brand.press,
                padding: const EdgeInsets.symmetric(
                  vertical: 11,
                  horizontal: 6,
                ),
                decoration: BoxDecoration(
                  color: activePortal == role
                      ? portalColor(role)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(portalIcon(role), size: 16, color: Brand.ink),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        role.label,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Brand.ink,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    ),
  );

  Widget loginCard(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: Padding(
      padding: const EdgeInsets.all(Brand.gap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Choose Your Portal',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: Brand.compact),
          const Text(
            'Select your role to continue',
            textAlign: TextAlign.center,
            style: TextStyle(color: Brand.secondary),
          ),
          const SizedBox(height: Brand.gap),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0x1AFFFFFF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: null,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.login, size: 17),
                        SizedBox(width: 6),
                        Text('Login'),
                      ],
                    ),
                  ),
                ),
                const Expanded(
                  child: TextButton(onPressed: null, child: Text('Sign Up')),
                ),
              ],
            ),
          ),
          const SizedBox(height: Brand.gap),
          portalTabs(),
          const SizedBox(height: Brand.gap),
          Container(
            alignment: Alignment.center,
            child: Column(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: portalColor(activePortal),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Icon(
                      portalIcon(activePortal),
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                ),
                const SizedBox(height: Brand.compact),
                Text(
                  portalTitle(activePortal),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  portalSubtitle(activePortal),
                  style: const TextStyle(color: Brand.secondary, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: Brand.gap),
          AutofillGroup(
            child: Form(
              key: form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    key: const Key('email'),
                    controller: email,
                    enabled: !widget.controller.busy,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.username],
                    textInputAction: TextInputAction.next,
                    style: const TextStyle(color: Brand.ink),
                    decoration: const InputDecoration(
                      labelText: 'Email Address',
                      prefixIcon: Icon(Icons.mail_outline),
                      hintText: 'Enter your email',
                    ),
                    validator: (value) =>
                        value == null ||
                            !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                .hasMatch(value.trim())
                        ? 'Enter a valid email address.'
                        : null,
                  ),
                  const SizedBox(height: Brand.gap),
                  TextFormField(
                    key: const Key('password'),
                    controller: password,
                    enabled: !widget.controller.busy,
                    obscureText: obscure,
                    autofillHints: const [AutofillHints.password],
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => submit(),
                    style: const TextStyle(color: Brand.ink),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      hintText: 'Enter your password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        tooltip: obscure ? 'Show password' : 'Hide password',
                        onPressed: () => setState(() => obscure = !obscure),
                        icon: Icon(
                          obscure
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                    validator: (value) => value == null || value.length < 6
                        ? 'Enter a password with at least 6 characters.'
                        : null,
                  ),
                  if (widget.controller.sessionNotice != null)
                    Padding(
                      padding: const EdgeInsets.only(top: Brand.gap),
                      child: Semantics(
                        liveRegion: true,
                        child: Text(widget.controller.sessionNotice!),
                      ),
                    ),
                  if (widget.controller.error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: Brand.gap),
                      child: Semantics(
                        liveRegion: true,
                        child: Text(
                          widget.controller.error!,
                          style: const TextStyle(color: Brand.error),
                        ),
                      ),
                    ),
                  const SizedBox(height: Brand.gap),
                  BusyButton(
                    key: const Key('sign-in'),
                    label: 'Sign in as ${activePortal.label}',
                    busy: widget.controller.busy,
                    onPressed: submit,
                  ),
                ],
              ),
            ),
          ),
          if (DemoPrefills.enabled) ...[
            const SizedBox(height: Brand.gap),
            const Divider(color: Brand.border),
            const SizedBox(height: Brand.gap),
            const Text(
              'Quick Demo Access',
              textAlign: TextAlign.center,
              style: TextStyle(color: Brand.secondary, fontSize: 13),
            ),
            const SizedBox(height: Brand.compact),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: Brand.compact,
              runSpacing: Brand.compact,
              children: [
                for (final role in [Role.admin, Role.employee, Role.customer])
                  OutlinedButton(
                    key: ValueKey('demo-prefill-${role.wireName}'),
                    onPressed: widget.controller.busy
                        ? null
                        : () => prefill(role),
                    child: Text('Sign in as ${role.label}'),
                  ),
              ],
            ),
          ],
          const SizedBox(height: Brand.gap),
          OutlinedButton.icon(
            key: const Key('offline-entry'),
            onPressed: widget.controller.busy ? null : offline,
            icon: const Icon(Icons.offline_bolt_outlined),
            label: const Text('Offline Demo'),
          ),
          const SizedBox(height: Brand.compact),
          const Text(
            'No internet needed. Fictional data, saved only on this device.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Brand.secondary, fontSize: 12),
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          padding: const EdgeInsets.all(Brand.gutter),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight - Brand.gutter * 2,
              maxWidth: Brand.maxWidth,
            ),
            child: Center(
              child: Flex(
                direction: constraints.maxWidth >= 900
                    ? Axis.horizontal
                    : Axis.vertical,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (constraints.maxWidth >= 900)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(Brand.gap),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: constraints.maxWidth >= 900
                              ? CrossAxisAlignment.start
                              : CrossAxisAlignment.center,
                          children: [
                            Row(
                              mainAxisAlignment: constraints.maxWidth >= 900
                                  ? MainAxisAlignment.start
                                  : MainAxisAlignment.center,
                              children: [
                                const BrandLogo(height: 56),
                                const SizedBox(width: Brand.compact),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'EstateHub',
                                      style: TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.w700,
                                        color: Brand.ink,
                                      ),
                                    ),
                                    Text(
                                      'Real Estate Management',
                                      style: TextStyle(
                                        color: Color(0xFFBFDBFE),
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: Brand.section),
                            Text(
                              'Welcome Back!',
                              textAlign: constraints.maxWidth >= 900
                                  ? TextAlign.left
                                  : TextAlign.center,
                              style: Theme.of(context).textTheme.headlineLarge,
                            ),
                            const SizedBox(height: Brand.compact),
                            const Text(
                              'Secure access to your real estate dashboard',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Color(0xFFBFDBFE),
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.all(Brand.gap),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              BrandLogo(height: 56),
                              SizedBox(width: Brand.compact),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'EstateHub',
                                    style: TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w700,
                                      color: Brand.ink,
                                    ),
                                  ),
                                  Text(
                                    'Real Estate Management',
                                    style: TextStyle(
                                      color: Color(0xFFBFDBFE),
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: Brand.gap),
                          Text(
                            'Welcome Back!',
                            style: Theme.of(context).textTheme.headlineLarge,
                          ),
                          const SizedBox(height: Brand.compact),
                          const Text(
                            'Secure access to your real estate dashboard',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(0xFFBFDBFE),
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (constraints.maxWidth >= 900)
                    Expanded(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: loginCard(context),
                      ),
                    )
                  else
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: loginCard(context),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
