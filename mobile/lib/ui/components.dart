import 'package:flutter/material.dart';

import 'theme.dart';

class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.height = 64});
  final double height;
  @override
  Widget build(BuildContext context) => Image.asset(
    'assets/brand/ventureplus.png',
    height: height,
    fit: BoxFit.contain,
    semanticLabel: 'Venture Plus',
  );
}

class PageBody extends StatelessWidget {
  const PageBody({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: Brand.maxWidth),
      child: Padding(padding: const EdgeInsets.all(Brand.gutter), child: child),
    ),
  );
}

class StateMessage extends StatelessWidget {
  const StateMessage({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.info_outline,
    this.action,
    this.actionLabel = 'Retry',
  });
  final String title, message, actionLabel;
  final IconData icon;
  final VoidCallback? action;
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: Brand.section),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40, color: Brand.sage700),
          const SizedBox(height: Brand.gap),
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: Brand.compact),
          Text(message, textAlign: TextAlign.center),
          if (action != null) ...[
            const SizedBox(height: Brand.gap),
            OutlinedButton(onPressed: action, child: Text(actionLabel)),
          ],
        ],
      ),
    ),
  );
}

class LoadingSkeleton extends StatelessWidget {
  const LoadingSkeleton({super.key});
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Loading content',
    liveRegion: true,
    child: ExcludeSemantics(
      child: Column(
        children: List.generate(
          3,
          (i) => Container(
            height: 116,
            margin: const EdgeInsets.only(bottom: Brand.gap),
            decoration: BoxDecoration(
              color: Brand.muted,
              borderRadius: BorderRadius.circular(Brand.radius),
            ),
            padding: const EdgeInsets.all(Brand.gap),
            alignment: Alignment.topLeft,
            child: FractionallySizedBox(
              widthFactor: .65,
              child: Container(height: 20, color: Brand.border),
            ),
          ),
        ),
      ),
    ),
  );
}

class StatusBadge extends StatelessWidget {
  const StatusBadge(this.label, {super.key});
  final String label;
  @override
  Widget build(BuildContext context) {
    final pending = [
      'ADVANCE',
      'FOLLOW_UP',
      'FOLLOWING_UP',
      'PAID_ADVANCE',
    ].contains(label.toUpperCase());
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: pending ? Brand.amberLight : Brand.sage100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label.replaceAll('_', ' ').toLowerCase(),
        style: TextStyle(
          color: pending ? Brand.warning : Brand.sage900,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}

class BusyButton extends StatelessWidget {
  const BusyButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  @override
  Widget build(BuildContext context) => FilledButton(
    onPressed: busy ? null : onPressed,
    child: busy
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: Brand.compact),
              Flexible(child: Text('$label…')),
            ],
          )
        : Text(label),
  );
}

Future<bool> confirmAction(
  BuildContext context,
  String title,
  String message,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    ) ??
    false;

void showFeedback(BuildContext context, String message) =>
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
