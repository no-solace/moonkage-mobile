import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:moonkage_verify/core/strings.dart';
import 'package:moonkage_verify/features/verify/domain/verify_outcome.dart';
import 'package:moonkage_verify/features/verify/presentation/verify_flow_notifier.dart';
import 'package:moonkage_verify/features/verify/presentation/verify_flow_state.dart';
import 'package:moonkage_verify/router.dart';

/// Kết quả cuối: đã lưu vào tài khoản, hoặc lý do bị từ chối.
class ResultScreen extends ConsumerStatefulWidget {
  const ResultScreen({super.key});

  @override
  ConsumerState<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends ConsumerState<ResultScreen> {
  @override
  void initState() {
    super.initState();
    scheduleMicrotask(() {
      final state = ref.read(verifyFlowProvider);
      if (state is Completed) {
        try {
          if (state.outcome is Verified) {
            HapticFeedback.mediumImpact().ignore();
          } else {
            HapticFeedback.heavyImpact().ignore();
          }
        } on Object catch (_) {}
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final state = ref.watch(verifyFlowProvider);

    void done() {
      ref.read(verifyFlowProvider.notifier).reset();
      context.go(AppRoutes.home);
    }

    final isSuccess = state is Completed && state.outcome is Verified;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) done();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text(Strings.resultTitle),
          automaticallyImplyLeading: false,
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(flex: 1),
                // Icon trạng thái lớn
                Center(
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: isSuccess
                          ? colors.primaryContainer.withValues(alpha: 0.4)
                          : colors.errorContainer.withValues(alpha: 0.4),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(
                        isSuccess ? Icons.check_circle_rounded : Icons.cancel_rounded,
                        size: 64,
                        color: isSuccess ? colors.primary : colors.error,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                // Nội dung kết quả
                if (state is Completed)
                  switch (state.outcome) {
                    Verified() => Column(
                      children: [
                        Text(
                          Strings.verified,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colors.onSurface,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          Strings.verifiedBody,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          Strings.backToWeb,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.outline,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                    Rejected(:final reason, :final attemptsLeft, :final lockedUntil) => Column(
                      children: [
                        Text(
                          Strings.rejected,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colors.error,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: colors.errorContainer.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: colors.error.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Column(
                            children: [
                              Text(
                                Strings.reason(reason),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w500,
                                  color: colors.onErrorContainer,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              if (attemptsLeft != null) ...[
                                const SizedBox(height: 10),
                                Text(
                                  Strings.attemptsLeft(attemptsLeft),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colors.error,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                              if (lockedUntil != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  Strings.lockedUntil(
                                    TimeOfDay.fromDateTime(lockedUntil.toLocal()).format(context),
                                  ),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colors.error,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    PendingConfirmation() => const SizedBox.shrink(),
                  },
                const Spacer(flex: 2),
                FilledButton(
                  onPressed: done,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text(Strings.done),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
