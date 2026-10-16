import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moonkage_verify/core/auth/auth_session.dart';

/// `null` khi chưa đăng nhập. Router và interceptor của Dio đọc provider này.
final sessionProvider = NotifierProvider<SessionNotifier, AuthSession?>(SessionNotifier.new);

class SessionNotifier extends Notifier<AuthSession?> {
  @override
  AuthSession? build() => null;

  void signIn(AuthSession session) => state = session;

  void signOut() => state = null;
}
