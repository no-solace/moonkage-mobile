import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:moonkage_verify/core/auth/session_notifier.dart';
import 'package:moonkage_verify/features/auth/presentation/login_screen.dart';
import 'package:moonkage_verify/features/verify/presentation/screens/confirm_screen.dart';
import 'package:moonkage_verify/features/verify/presentation/screens/home_screen.dart';
import 'package:moonkage_verify/features/verify/presentation/screens/result_screen.dart';
import 'package:moonkage_verify/features/verify/presentation/screens/scan_qr_screen.dart';
import 'package:moonkage_verify/features/verify/presentation/screens/tap_card_screen.dart';

/// Đường dẫn route. Không truyền dữ liệu thẻ qua URL; dữ liệu đi qua `verifyFlowProvider`.
abstract final class AppRoutes {
  static const login = '/login';
  static const home = '/';
  static const scanQr = '/scan-qr';
  static const tapCard = '/tap-card';
  static const confirm = '/confirm';
  static const result = '/result';
}

/// Chưa đăng nhập thì mọi route về [AppRoutes.login]; đã đăng nhập thì rời màn đăng nhập.
final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: AppRoutes.home,
    redirect: (_, state) {
      final signedIn = ref.read(sessionProvider) != null;
      final atLogin = state.matchedLocation == AppRoutes.login;
      if (!signedIn) return atLogin ? null : AppRoutes.login;
      return atLogin ? AppRoutes.home : null;
    },
    routes: [
      GoRoute(path: AppRoutes.login, builder: (_, _) => const LoginScreen()),
      GoRoute(path: AppRoutes.home, builder: (_, _) => const HomeScreen()),
      GoRoute(path: AppRoutes.scanQr, builder: (_, _) => const ScanQrScreen()),
      GoRoute(path: AppRoutes.tapCard, builder: (_, _) => const TapCardScreen()),
      GoRoute(path: AppRoutes.confirm, builder: (_, _) => const ConfirmScreen()),
      GoRoute(path: AppRoutes.result, builder: (_, _) => const ResultScreen()),
    ],
  );
  ref
    ..listen(sessionProvider, (_, _) => router.refresh())
    ..onDispose(router.dispose);
  return router;
});
