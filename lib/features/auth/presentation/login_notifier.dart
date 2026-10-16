import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moonkage_verify/core/auth/session_notifier.dart';
import 'package:moonkage_verify/core/errors/app_failure.dart';
import 'package:moonkage_verify/features/auth/data/auth_api.dart';

final loginProvider = NotifierProvider.autoDispose<LoginNotifier, LoginState>(LoginNotifier.new);

final class LoginState {
  const LoginState({this.submitting = false, this.failure});

  final bool submitting;
  final AppFailure? failure;
}

/// Đăng nhập thành công thì ghi vào `sessionProvider`; router tự chuyển sang trang chủ.
class LoginNotifier extends Notifier<LoginState> {
  @override
  LoginState build() => const LoginState();

  Future<void> login({required String username, required String password}) async {
    if (state.submitting) return;
    state = const LoginState(submitting: true);
    try {
      final session = await ref
          .read(authApiProvider)
          .login(username: username.trim(), password: password);
      if (!ref.mounted) return;
      ref.read(sessionProvider.notifier).signIn(session);
      state = const LoginState();
    } on AppFailure catch (failure) {
      if (!ref.mounted) return;
      state = LoginState(failure: failure);
    }
  }
}
