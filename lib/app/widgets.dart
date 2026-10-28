import 'package:flutter/material.dart';

import 'theme.dart';

/// App logo + name.
class Wordmark extends StatelessWidget {
  const Wordmark({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset('assets/images/logo.png', width: 32, height: 32, excludeFromSemantics: true),
        const SizedBox(width: Space.sm + 2),
        Text('Expense Manager', style: Theme.of(context).textTheme.titleLarge!.copyWith(fontWeight: FontWeight.w800)),
      ],
    );
  }
}

/// Recoverable error shown inside a form.
class InlineError extends StatelessWidget {
  const InlineError(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(Space.md),
        decoration: BoxDecoration(
          color: AppColors.coral.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(Radii.input),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: AppColors.coral, size: 20),
            const SizedBox(width: Space.sm),
            Expanded(child: Text(message, style: Theme.of(context).textTheme.bodyMedium)),
          ],
        ),
      ),
    );
  }
}
