import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moonkage_verify/core/errors/app_failure.dart';
import 'package:moonkage_verify/core/strings.dart';
import 'package:moonkage_verify/features/auth/presentation/login_notifier.dart';

/// Đăng nhập bằng tài khoản Moonkage (email hoặc số điện thoại).
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    unawaited(
      ref.read(loginProvider.notifier).login(username: _username.text, password: _password.text),
    );
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? Strings.requiredField : null;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(loginProvider);
    final failure = state.failure;
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text(Strings.loginTitle)),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              TextFormField(
                controller: _username,
                decoration: const InputDecoration(labelText: Strings.usernameLabel),
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                textInputAction: TextInputAction.next,
                validator: _required,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _password,
                decoration: const InputDecoration(labelText: Strings.passwordLabel),
                obscureText: true,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
                validator: _required,
              ),
              if (failure != null) ...[
                const SizedBox(height: 16),
                Text(
                  failure is UnauthorizedFailure
                      ? Strings.invalidCredentials
                      : Strings.failure(failure),
                  style: TextStyle(color: colors.error),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: state.submitting ? null : _submit,
                child: state.submitting
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text(Strings.login),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
