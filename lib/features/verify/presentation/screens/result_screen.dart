import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:moonkage_verify/core/strings.dart';
import 'package:moonkage_verify/features/verify/domain/verify_outcome.dart';
import 'package:moonkage_verify/features/verify/presentation/verify_flow_notifier.dart';
import 'package:moonkage_verify/features/verify/presentation/verify_flow_state.dart';
import 'package:moonkage_verify/router.dart';

/// Kết quả cuối: đã lưu vào tài khoản, hoặc lý do bị từ chối.
class ResultScreen extends ConsumerWidget {
  const ResultScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;

    final lines = switch (ref.watch(verifyFlowProvider)) {
      Completed(outcome: Verified()) => [
        Text(Strings.verified, style: textTheme.headlineSmall),
        const Text(Strings.verifiedBody),
        const Text(Strings.backToWeb),
      ],
      Completed(outcome: Rejected(:final reason, :final attemptsLeft, :final lockedUntil)) => [
        Text(Strings.rejected, style: textTheme.headlineSmall),
        Text(Strings.reason(reason)),
        if (attemptsLeft != null) Text(Strings.attemptsLeft(attemptsLeft)),
        if (lockedUntil != null)
          Text(Strings.lockedUntil(TimeOfDay.fromDateTime(lockedUntil.toLocal()).format(context))),
      ],
      _ => <Widget>[],
    };

    return Scaffold(
      appBar: AppBar(title: const Text(Strings.resultTitle), automaticallyImplyLeading: false),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 12,
          children: [
            ...lines,
            const Spacer(),
            FilledButton(
              onPressed: () {
                ref.read(verifyFlowProvider.notifier).reset();
                context.go(AppRoutes.home);
              },
              child: const Text(Strings.done),
            ),
          ],
        ),
      ),
    );
  }
}
