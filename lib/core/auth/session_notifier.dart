import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moonkage_verify/core/auth/auth_session.dart';
import 'package:moonkage_verify/core/auth/token_storage.dart';

final initialSessionProvider = Provider<AuthSession?>((ref) => null);

/// `null` khi chưa đăng nhập. Router và interceptor của Dio đọc provider này.
final sessionProvider = NotifierProvider<SessionNotifier, AuthSession?>(SessionNotifier.new);

class SessionNotifier extends Notifier<AuthSession?> {
  @override
  AuthSession? build() => ref.watch(initialSessionProvider);

  void signIn(AuthSession session, {bool rememberMe = true}) {
    state = session;
    final storage = ref.read(tokenStorageProvider);
    if (rememberMe) {
      unawaited(storage.saveSession(token: session.token, fullName: session.fullName));
    } else {
      unawaited(storage.clearSession());
    }
  }

  void signOut() {
    state = null;
    unawaited(ref.read(tokenStorageProvider).clearSession());
  }
}
