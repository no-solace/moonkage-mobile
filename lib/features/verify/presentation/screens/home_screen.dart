import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:moonkage_verify/core/auth/session_notifier.dart';
import 'package:moonkage_verify/core/strings.dart';
import 'package:moonkage_verify/features/verify/presentation/nfc_status_provider.dart';
import 'package:moonkage_verify/features/verify/presentation/widgets/status_message.dart';
import 'package:moonkage_verify/nfc/nfc_reader.dart';
import 'package:moonkage_verify/router.dart';

/// Trang chủ sau đăng nhập: kiểm NFC, nút Quét QR.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fullName = ref.watch(sessionProvider)?.fullName ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text(Strings.appTitle),
        actions: [
          TextButton(
            onPressed: () => ref.read(sessionProvider.notifier).signOut(),
            child: const Text(Strings.logout),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(Strings.greeting(fullName), style: Theme.of(context).textTheme.titleLarge),
            switch (ref.watch(nfcStatusProvider)) {
              AsyncData(value: NfcStatus.enabled) => StatusMessage(
                message: Strings.homeHint,
                actionLabel: Strings.scanQr,
                onAction: () => context.go(AppRoutes.scanQr),
              ),
              AsyncData(value: NfcStatus.disabled) => StatusMessage(
                message: Strings.nfcDisabled,
                actionLabel: Strings.retry,
                onAction: () => ref.invalidate(nfcStatusProvider),
              ),
              AsyncData(value: NfcStatus.unsupported) || AsyncError() => const StatusMessage(
                message: Strings.nfcUnsupported,
              ),
              AsyncLoading() => const StatusMessage(message: Strings.checkingNfc),
            },
          ],
        ),
      ),
    );
  }
}
