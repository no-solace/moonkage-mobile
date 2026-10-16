import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:moonkage_verify/core/strings.dart';
import 'package:moonkage_verify/features/verify/presentation/verify_flow_notifier.dart';
import 'package:moonkage_verify/router.dart';

/// Bước 2: quét QR `moonkage-verify:v1:<session_id>` trên trang web.
class ScanQrScreen extends ConsumerStatefulWidget {
  const ScanQrScreen({super.key});

  @override
  ConsumerState<ScanQrScreen> createState() => _ScanQrScreenState();
}

class _ScanQrScreenState extends ConsumerState<ScanQrScreen> {
  final _controller = MobileScannerController(formats: const [BarcodeFormat.qrCode]);
  bool _invalidQr = false;
  bool _accepted = false;

  @override
  void dispose() {
    unawaited(_controller.dispose());
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (_accepted || raw == null) return;
    if (ref.read(verifyFlowProvider.notifier).acceptQr(raw)) {
      _accepted = true;
      context.go(AppRoutes.tapCard);
    } else if (!_invalidQr) {
      setState(() => _invalidQr = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(Strings.scanQrTitle)),
      body: Column(
        children: [
          Expanded(
            child: MobileScanner(controller: _controller, onDetect: _onDetect),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              _invalidQr ? Strings.invalidQr : Strings.scanQrHint,
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
