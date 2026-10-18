import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:moonkage_verify/core/errors/app_failure.dart';
import 'package:moonkage_verify/core/strings.dart';
import 'package:moonkage_verify/features/verify/data/verify_api.dart';
import 'package:moonkage_verify/features/verify/domain/session_qr.dart';
import 'package:moonkage_verify/features/verify/presentation/verify_flow_notifier.dart';
import 'package:moonkage_verify/router.dart';

/// Bước 2: quét mã QR phiên xác minh trên trang web.
class ScanQrScreen extends ConsumerStatefulWidget {
  const ScanQrScreen({super.key});

  @override
  ConsumerState<ScanQrScreen> createState() => _ScanQrScreenState();
}

class _ScanQrScreenState extends ConsumerState<ScanQrScreen> {
  final _controller = MobileScannerController(formats: const [BarcodeFormat.qrCode]);
  String? _errorMessage;
  bool _isValidating = false;
  bool _accepted = false;

  @override
  void dispose() {
    unawaited(_controller.dispose());
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (_accepted || _isValidating || raw == null) return;

    final qr = SessionQr.tryParse(raw);
    if (qr == null) {
      if (_errorMessage != Strings.invalidQr) {
        setState(() => _errorMessage = Strings.invalidQr);
      }
      return;
    }

    setState(() {
      _isValidating = true;
      _errorMessage = null;
    });

    try {
      await ref.read(verifyApiProvider).checkSession(qr.sessionId);
      if (!mounted) return;
      if (ref.read(verifyFlowProvider.notifier).acceptQr(raw)) {
        _accepted = true;
        context.go(AppRoutes.tapCard);
      }
    } on AppFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _isValidating = false;
        _errorMessage = Strings.failure(failure);
      });
    } on Exception catch (_) {
      if (!mounted) return;
      setState(() {
        _isValidating = false;
        _errorMessage = Strings.invalidQr;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(Strings.scanQrTitle),
        actions: [
          ValueListenableBuilder<MobileScannerState>(
            valueListenable: _controller,
            builder: (context, state, _) {
              final isTorchOn = state.torchState == TorchState.on;
              return IconButton(
                icon: Icon(isTorchOn ? Icons.flash_on : Icons.flash_off),
                tooltip: isTorchOn ? Strings.flashOff : Strings.flashOn,
                onPressed: () => unawaited(_controller.toggleTorch()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                MobileScanner(
                  controller: _controller,
                  onDetect: (capture) => unawaited(_onDetect(capture)),
                  errorBuilder: (context, error) {
                    final isPermission = error.errorCode == MobileScannerErrorCode.permissionDenied;
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.videocam_off_outlined,
                              size: 48,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              isPermission
                                  ? Strings.cameraPermissionDenied
                                  : (error.errorDetails?.message ?? Strings.cameraError),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const QrViewfinderOverlay(),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
            color: Theme.of(context).cardColor,
            child: _isValidating
                ? const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 12),
                      Text(Strings.checkingSession),
                    ],
                  )
                : Text(
                    _errorMessage ?? Strings.scanQrHint,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: _errorMessage != null ? colors.error : null,
                      fontWeight: _errorMessage != null ? FontWeight.bold : null,
                    ),
                    textAlign: TextAlign.center,
                  ),
          ),
        ],
      ),
    );
  }
}

/// Khung ngắm căn chỉnh mã QR với 4 góc bo sáng và nền tối mờ xung quanh.
class QrViewfinderOverlay extends StatelessWidget {
  const QrViewfinderOverlay({super.key, this.cutoutSize = 250.0});

  final double cutoutSize;

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        final size = cutoutSize.clamp(0.0, width * 0.85);
        final left = (width - size) / 2;
        final top = (height - size) / 2;
        final cutoutRect = Rect.fromLTWH(left, top, size, size);

        return Stack(
          children: [
            ColorFiltered(
              colorFilter: ColorFilter.mode(
                Colors.black.withValues(alpha: 0.55),
                BlendMode.srcOut,
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      color: Colors.black,
                      backgroundBlendMode: BlendMode.dstOut,
                    ),
                  ),
                  Positioned.fromRect(
                    rect: cutoutRect,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned.fromRect(
              rect: cutoutRect,
              child: CustomPaint(
                painter: _CornerPainter(
                  color: primaryColor,
                  cornerLength: 30,
                  strokeWidth: 4,
                  radius: 16,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CornerPainter extends CustomPainter {
  const _CornerPainter({
    required this.color,
    required this.cornerLength,
    required this.strokeWidth,
    required this.radius,
  });

  final Color color;
  final double cornerLength;
  final double strokeWidth;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final w = size.width;
    final h = size.height;

    // Top-Left
    final pathTL = Path()
      ..moveTo(0, cornerLength)
      ..lineTo(0, radius)
      ..arcToPoint(Offset(radius, 0), radius: Radius.circular(radius))
      ..lineTo(cornerLength, 0);
    canvas.drawPath(pathTL, paint);

    // Top-Right
    final pathTR = Path()
      ..moveTo(w - cornerLength, 0)
      ..lineTo(w - radius, 0)
      ..arcToPoint(Offset(w, radius), radius: Radius.circular(radius))
      ..lineTo(w, cornerLength);
    canvas.drawPath(pathTR, paint);

    // Bottom-Left
    final pathBL = Path()
      ..moveTo(0, h - cornerLength)
      ..lineTo(0, h - radius)
      ..arcToPoint(Offset(radius, h), radius: Radius.circular(radius), clockwise: false)
      ..lineTo(cornerLength, h);
    canvas.drawPath(pathBL, paint);

    // Bottom-Right
    final pathBR = Path()
      ..moveTo(w - cornerLength, h)
      ..lineTo(w - radius, h)
      ..arcToPoint(Offset(w, h - radius), radius: Radius.circular(radius), clockwise: false)
      ..lineTo(w, h - cornerLength);
    canvas.drawPath(pathBR, paint);
  }

  @override
  bool shouldRepaint(covariant _CornerPainter oldDelegate) =>
      color != oldDelegate.color ||
      cornerLength != oldDelegate.cornerLength ||
      strokeWidth != oldDelegate.strokeWidth;
}
