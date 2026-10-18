import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:moonkage_verify/app.dart';
import 'package:moonkage_verify/core/auth/auth_session.dart';
import 'package:moonkage_verify/core/auth/session_notifier.dart';
import 'package:moonkage_verify/core/auth/token_storage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AuthSession? initialSession;
  try {
    const storage = SecureTokenStorage(
      FlutterSecureStorage(
        aOptions: AndroidOptions.defaultOptions,
      ),
    );
    initialSession = await storage.readSession();
  } on Exception catch (_) {
    initialSession = null;
  }

  runApp(
    ProviderScope(
      overrides: [
        if (initialSession != null) initialSessionProvider.overrideWithValue(initialSession),
      ],
      child: const MoonkageVerifyApp(),
    ),
  );
}
