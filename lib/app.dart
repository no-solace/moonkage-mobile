import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moonkage_verify/core/config/app_config.dart';
import 'package:moonkage_verify/core/strings.dart';
import 'package:moonkage_verify/router.dart';

class MoonkageVerifyApp extends ConsumerWidget {
  const MoonkageVerifyApp({this.configValid, super.key});

  /// Chỉ để test ghi đè; mặc định đọc [AppConfig.isValid].
  final bool? configValid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo));
    if (!(configValid ?? AppConfig.isValid)) {
      return MaterialApp(title: Strings.appTitle, theme: theme, home: const _ConfigErrorScreen());
    }
    return MaterialApp.router(
      title: Strings.appTitle,
      theme: theme,
      routerConfig: ref.watch(routerProvider),
    );
  }
}

class _ConfigErrorScreen extends StatelessWidget {
  const _ConfigErrorScreen();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text(Strings.configErrorTitle)),
    body: const Padding(padding: EdgeInsets.all(24), child: Text(Strings.configErrorBody)),
  );
}
