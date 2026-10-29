import 'package:flutter/material.dart';
import 'package:ventureplus/core/app_controller.dart';
import 'package:ventureplus/ui/components.dart';
import 'package:ventureplus/ui/theme.dart';

import 'forms.dart';
import 'workflow_page.dart';

class EmployeeOtpPage extends StatefulWidget {
  const EmployeeOtpPage({super.key, required this.controller});
  final AppController controller;
  @override
  State<EmployeeOtpPage> createState() => _EmployeeOtpPageState();
}

class _EmployeeOtpPageState extends State<EmployeeOtpPage> {
  final _target = TextEditingController();
  final _code = TextEditingController();
  String _type = 'email';
  JsonMap? _request;
  String? _error, _success;
  bool _busy = false;
  @override
  void dispose() {
    _target.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _requestCode() async {
    final target = _target.text.trim();
    if (target.length < 3 ||
        (_type == 'email' &&
            const FormFieldSpec(
                  'email',
                  'Email',
                  kind: FieldKind.email,
                ).validate(target) !=
                null)) {
      setState(
        () => _error =
            'Enter a valid ${_type == 'email' ? 'email address' : 'phone number'}.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _success = null;
    });
    try {
      final request = await activeRepository(widget.controller)
          .requestOtp(_type, target);
      if (mounted) {
        setState(() {
          _request = request;
          _code.clear();
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = failureMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verify() async {
    if (_code.text.trim().length < 4 || _code.text.trim().length > 10) {
      setState(() => _error = 'Enter the 4–10 character code.');
      return;
    }
    final requestId = _request?['requestId'];
    if (requestId is! String) {
      setState(() => _error = 'Request a new code first.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _success = null;
    });
    try {
      await activeRepository(widget.controller)
          .verifyOtp(requestId, _code.text.trim());
      if (mounted) {
        setState(() {
          _request = null;
          _code.clear();
          _success = widget.controller.isOffline
              ? 'Code verified locally. No account settings were changed.'
              : 'Code verified. No employee profile settings were changed.';
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = failureMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Demo OTP verification')),
    body: SafeArea(
      child: SingleChildScrollView(
        child: PageBody(
          child: widget.controller.user?.role != Role.admin
              ? const StateMessage(
                  title: 'Admin access required',
                  message:
                      'Only administrators can request or verify demo codes.',
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ModeStrip(offline: widget.controller.isOffline),
                    const SizedBox(height: Brand.gap),
                    const Text(
                      'The existing demo service displays its verification code here. It does not send an email or SMS.',
                    ),
                    const SizedBox(height: Brand.gap),
                    DropdownButtonFormField<String>(
                      initialValue: _type,
                      decoration: const InputDecoration(
                        labelText: 'Verification type',
                      ),
                      items: const [
                        DropdownMenuItem(value: 'email', child: Text('Email')),
                        DropdownMenuItem(value: 'phone', child: Text('Phone')),
                      ],
                      onChanged: _busy
                          ? null
                          : (value) => setState(() {
                              _type = value!;
                              _request = null;
                              _success = null;
                            }),
                    ),
                    const SizedBox(height: Brand.gap),
                    TextField(
                      controller: _target,
                      enabled: !_busy,
                      keyboardType: _type == 'email'
                          ? TextInputType.emailAddress
                          : TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: _type == 'email'
                            ? 'Email address'
                            : 'Phone number',
                      ),
                    ),
                    const SizedBox(height: Brand.gap),
                    BusyButton(
                      label: 'Request demo code',
                      busy: _busy,
                      onPressed: _requestCode,
                    ),
                    if (_request != null) ...[
                      const SizedBox(height: Brand.section),
                      Text(
                        'Verification challenge',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: Brand.gap),
                      DetailFact(
                        'Demo code',
                        '${_request!['otp'] ?? 'Unavailable'}',
                      ),
                      if (_request!['expiresAt'] != null)
                        DetailFact('Expires', '${_request!['expiresAt']}'),
                      const Text(
                        'Codes can be used once. An expired code or too many incorrect attempts requires a new request.',
                      ),
                      const SizedBox(height: Brand.gap),
                      TextField(
                        controller: _code,
                        enabled: !_busy,
                        autofillHints: const [AutofillHints.oneTimeCode],
                        decoration: const InputDecoration(
                          labelText: 'Verification code',
                        ),
                      ),
                      const SizedBox(height: Brand.gap),
                      BusyButton(
                        label: 'Verify code',
                        busy: _busy,
                        onPressed: _verify,
                      ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: Brand.gap),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Brand.error),
                        ),
                      ),
                    ],
                    if (_success != null) ...[
                      const SizedBox(height: Brand.gap),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          _success!,
                          style: const TextStyle(color: Brand.success),
                        ),
                      ),
                    ],
                  ],
                ),
        ),
      ),
    ),
  );
}
