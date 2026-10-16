import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:moonkage_verify/core/strings.dart';
import 'package:moonkage_verify/features/verify/presentation/verify_flow_notifier.dart';
import 'package:moonkage_verify/features/verify/presentation/verify_flow_state.dart';
import 'package:moonkage_verify/features/verify/presentation/widgets/card_details.dart';
import 'package:moonkage_verify/router.dart';

/// Hiển thị chỉ đọc thông tin máy chủ đã lưu tạm; người dùng bấm Lưu hoặc Hủy.
class ConfirmScreen extends ConsumerWidget {
  const ConfirmScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(verifyFlowProvider, (_, next) {
      if (next is Completed) context.go(AppRoutes.result);
    });

    final state = ref.watch(verifyFlowProvider);
    if (state is! AwaitingConfirmation) {
      return const Scaffold(body: SizedBox.shrink());
    }
    final notifier = ref.read(verifyFlowProvider.notifier);
    final failure = state.failure;

    void cancel() {
      unawaited(notifier.discard());
      context.go(AppRoutes.home);
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !state.saving) cancel();
      },
      child: Scaffold(
        appBar: AppBar(title: const Text(Strings.confirmTitle), automaticallyImplyLeading: false),
        body: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text(Strings.confirmHint),
            const SizedBox(height: 16),
            CardDetails(card: state.card),
            if (failure != null) ...[
              const SizedBox(height: 16),
              Text(
                Strings.failure(failure),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              spacing: 12,
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: state.saving ? null : cancel,
                    child: const Text(Strings.cancel),
                  ),
                ),
                Expanded(
                  child: FilledButton(
                    onPressed: state.saving ? null : () => unawaited(notifier.confirm()),
                    child: Text(state.saving ? Strings.saving : Strings.save),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
