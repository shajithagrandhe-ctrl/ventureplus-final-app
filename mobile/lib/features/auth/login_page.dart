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
  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  void prefill(Role role) {
    final credentials = DemoPrefills.forRole(role);
    if (credentials == null) return;
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
    await widget.controller.login(email.text.trim(), password.text);
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
                    leading: const Icon(Icons.person_outline),
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

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: Padding(
              padding: const EdgeInsets.all(Brand.gutter),
              child: AutofillGroup(
                child: Form(
                  key: form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: Brand.section),
                      const Center(child: BrandLogo(height: 112)),
                      const SizedBox(height: Brand.section),
                      Text(
                        'Your property workspace',
                        style: Theme.of(context).textTheme.headlineLarge,
                      ),
                      const SizedBox(height: Brand.compact),
                      const Text(
                        'Sign in to Venture Plus to view the properties and work available to your account.',
                      ),
                      const SizedBox(height: Brand.section),
                      TextFormField(
                        key: const Key('email'),
                        controller: email,
                        enabled: !widget.controller.busy,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.username],
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Email address',
                          prefixIcon: Icon(Icons.mail_outline),
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
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            tooltip: obscure
                                ? 'Show password'
                                : 'Hide password',
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
                        label: 'Sign in',
                        busy: widget.controller.busy,
                        onPressed: submit,
                      ),
                      if (DemoPrefills.enabled) ...[
                        const SizedBox(height: Brand.section),
                        Text(
                          'Demo account details',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: Brand.compact),
                        const Text(
                          'These buttons fill the form. Sign in checks the account with the server.',
                        ),
                        const SizedBox(height: Brand.gap),
                        for (final role in [
                          Role.admin,
                          Role.employee,
                          Role.customer,
                        ])
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: Brand.compact,
                            ),
                            child: OutlinedButton(
                              onPressed: widget.controller.busy
                                  ? null
                                  : () => prefill(role),
                              child: Text('Sign in as ${role.label}'),
                            ),
                          ),
                      ],
                      const SizedBox(height: Brand.gap),
                      const Divider(),
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
                      ),
                      const SizedBox(height: Brand.section),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
