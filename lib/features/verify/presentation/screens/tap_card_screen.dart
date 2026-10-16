import 'dart:async';

import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
    _notifier = ref.read(verifyFlowProvider.notifier);
    // Không đổi state của provider trong lúc dựng cây widget.
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_notifier.readCard()));
  }

  @override
  void dispose() {
    unawaited(_notifier.cancelRead());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(verifyFlowProvider, (_, next) {
      switch (next) {
        case AwaitingConfirmation():
          context.go(AppRoutes.confirm);
        case Completed():
          context.go(AppRoutes.result);
        case AwaitingQr() || AwaitingCard() || ReadingCard() || Submitting():
          break;
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text(Strings.tapCardTitle)),
      body: Center(
        child: switch (ref.watch(verifyFlowProvider)) {
          ReadingCard() => const _Waiting(message: Strings.tapCardHint),
          Submitting() => const _Waiting(message: Strings.submitting),
          AwaitingCard(:final issue, :final failure) => StatusMessage(
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
          AwaitingQr() || AwaitingConfirmation() || Completed() => const SizedBox.shrink(),
        },
      ),
    );
  }
}

class _Waiting extends StatelessWidget {
  const _Waiting({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const CircularProgressIndicator(),
      StatusMessage(message: message),
    ],
  );
}
