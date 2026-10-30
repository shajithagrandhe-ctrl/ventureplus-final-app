import 'package:flutter/material.dart';
import 'package:ventureplus/core/app_controller.dart';
import 'package:ventureplus/ui/components.dart';

import 'photo_recovery.dart';
import 'venture_detail.dart';

/// Mount after session restoration, inside MaterialApp's Navigator.
class PickerRecoveryHost extends StatefulWidget {
  const PickerRecoveryHost({
    super.key,
    required this.controller,
    required this.child,
    this.recovery,
  });
  final AppController controller;
  final Widget child;
  final PhotoRecovery? recovery;
  @override
  State<PickerRecoveryHost> createState() => _PickerRecoveryHostState();
}

class _PickerRecoveryHostState extends State<PickerRecoveryHost> {
  late final PhotoRecovery _recovery =
      widget.recovery ?? PhotoRecovery(widget.controller);
  PhotoRecoveryNotice? _notice;
  bool _busy = false, _recovering = true;
  @override
  void initState() {
    super.initState();
    _recover();
  }

  Future<void> _recover() async {
    final notice = await _recovery.recoverAtStartup();
    if (mounted) {
      setState(() {
        _notice = notice;
        _recovering = false;
      });
    }
  }

  Future<void> _discard() async {
    setState(() => _busy = true);
    try {
      await _recovery.discard();
      if (mounted) setState(() => _notice = null);
    } catch (_) {
      if (mounted) {
        showFeedback(
          context,
          'Could not clear the interrupted selection. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _review() async {
    final photo = _notice?.photo;
    if (photo == null || !_recovery.accepts(photo.intent)) {
      await _discard();
      return;
    }
    setState(() => _notice = null);
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => VentureDetailPage(
          controller: widget.controller,
          ventureId: photo.intent.ventureId,
          recoveredPhoto: photo,
          recovery: _recovery,
        ),
      ),
    );
    if (!mounted) return;
    final notice = await _recovery.savedRecovery();
    if (mounted) setState(() => _notice = notice);
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      if (_recovering)
        const LinearProgressIndicator(
          semanticsLabel: 'Checking interrupted photo selection',
        ),
      if (_notice != null)
        SafeArea(
          bottom: false,
          child: MaterialBanner(
            content: Text(_notice!.message),
            leading: const Icon(Icons.photo_library_outlined),
            actions: [
              if (_notice!.photo != null)
                TextButton(
                  onPressed: _busy ? null : _review,
                  child: const Text('Review selection'),
                ),
              TextButton(
                onPressed: _busy ? null : _discard,
                child: Text(_notice!.photo == null ? 'Dismiss' : 'Discard'),
              ),
            ],
          ),
        ),
      Expanded(
        child: AbsorbPointer(
          absorbing: _recovering,
          child: ExcludeSemantics(excluding: _recovering, child: widget.child),
        ),
      ),
    ],
  );
}
