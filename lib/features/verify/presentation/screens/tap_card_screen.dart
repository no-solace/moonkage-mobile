import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:moonkage_verify/core/strings.dart';
import 'package:moonkage_verify/features/verify/presentation/verify_flow_notifier.dart';
import 'package:moonkage_verify/features/verify/presentation/verify_flow_state.dart';
import 'package:moonkage_verify/features/verify/presentation/widgets/status_message.dart';
import 'package:moonkage_verify/router.dart';

/// Chờ chạm thẻ, rồi gửi lên máy chủ để lưu tạm.
class TapCardScreen extends ConsumerStatefulWidget {
  const TapCardScreen({super.key});

  @override
  ConsumerState<TapCardScreen> createState() => _TapCardScreenState();
}

class _TapCardScreenState extends ConsumerState<TapCardScreen> {
  late final VerifyFlowNotifier _notifier;
  VerifyFlowState? _currentState;

  @override
  void initState() {
    super.initState();
    _notifier = ref.read(verifyFlowProvider.notifier);
    unawaited(_notifier.readCard());
  }

  @override
  void dispose() {
    if (_currentState is! AwaitingConfirmation) {
      unawaited(_notifier.cancelRead());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(verifyFlowProvider, (_, next) {
      switch (next) {
        case AwaitingConfirmation():
          unawaited(HapticFeedback.mediumImpact());
          context.go(AppRoutes.confirm);
        case Completed():
          context.go(AppRoutes.result);
        case AwaitingCard(:final issue, :final failure):
          if (issue != null || failure != null) {
            unawaited(HapticFeedback.heavyImpact());
          }
        case ReadingCard() || AwaitingQr():
          break;
      }
    });

    final state = ref.watch(verifyFlowProvider);
    _currentState = state;

    return Scaffold(
      appBar: AppBar(title: const Text(Strings.tapCardTitle)),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: switch (state) {
            ReadingCard() => const _Waiting(
              message: Strings.tapCardHint,
              subHint: Strings.tapCardSubHint,
              positionHint: Strings.tapCardPositionHint,
            ),
            AwaitingCard(:final issue, :final failure) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (issue != null || failure != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.35),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Icon(
                          Icons.contactless_outlined,
                          size: 44,
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  ),
                StatusMessage(
                  message: switch ((issue, failure)) {
                    (CardIssue.wrongCard, _) => Strings.wrongCard,
                    (CardIssue.badFormat, _) => Strings.cardBadFormat,
                    (CardIssue.readFailed, _) => Strings.cardReadFailed,
                    (null, final failure?) => Strings.failure(failure),
                    (null, null) => Strings.tapCardHint,
                  },
                  actionLabel: Strings.retry,
                  onAction: () => unawaited(_notifier.readCard()),
                ),
              ],
            ),
            AwaitingQr() || AwaitingConfirmation() || Completed() => const SizedBox.shrink(),
          },
        ),
      ),
    );
  }
}

class _Waiting extends StatelessWidget {
  const _Waiting({
    required this.message,
    this.subHint,
    this.positionHint,
  });

  final String message;
  final String? subHint;
  final String? positionHint;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Minh họa sóng chạm thẻ NFC động
        const _NfcPulseIcon(),
        const SizedBox(height: 28),
        const SizedBox.square(
          dimension: 24,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
        const SizedBox(height: 20),
        Text(
          message,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        if (positionHint != null) ...[
          const SizedBox(height: 12),
          Text(
            positionHint!,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colors.primary,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
        if (subHint != null) ...[
          const SizedBox(height: 12),
          Text(
            subHint!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colors.outline,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}

class _NfcPulseIcon extends StatefulWidget {
  const _NfcPulseIcon();

  @override
  State<_NfcPulseIcon> createState() => _NfcPulseIconState();
}

class _NfcPulseIconState extends State<_NfcPulseIcon> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final progress = _controller.value;
        final scale = 1.0 + (progress * 0.3);
        final opacity = (1.0 - progress).clamp(0.0, 1.0) * 0.45;

        return Stack(
          alignment: Alignment.center,
          children: [
            Transform.scale(
              scale: scale,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.primary.withValues(alpha: opacity),
                ),
              ),
            ),
            child!,
          ],
        );
      },
      child: Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          color: colors.primaryContainer.withValues(alpha: 0.35),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Icon(
            Icons.contactless_outlined,
            size: 56,
            color: colors.primary,
          ),
        ),
      ),
    );
  }
}
