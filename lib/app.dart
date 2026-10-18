import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moonkage_verify/core/config/app_config.dart';
import 'package:moonkage_verify/core/strings.dart';
import 'package:moonkage_verify/nfc/nfc_reader.dart';
import 'package:moonkage_verify/router.dart';

class MoonkageVerifyApp extends ConsumerStatefulWidget {
  const MoonkageVerifyApp({this.configValid, super.key});

  /// Chỉ để test ghi đè; mặc định đọc [AppConfig.isValid].
  final bool? configValid;

  @override
  ConsumerState<MoonkageVerifyApp> createState() => _MoonkageVerifyAppState();
}

class _MoonkageVerifyAppState extends ConsumerState<MoonkageVerifyApp> with WidgetsBindingObserver {
  late final NfcReader _nfcReader;

  @override
  void initState() {
    super.initState();
    _nfcReader = ref.read(nfcReaderProvider);
    WidgetsBinding.instance.addObserver(this);
    // Kích hoạt Ambient Shield ngay khi app khởi động để khóa Tag Dispatch System của Android.
    scheduleMicrotask(() {
      if (mounted) {
        unawaited(_nfcReader.ensureSessionStarted());
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // MainActivity.onResume() vừa ghi đè callback bằng callback rỗng của native,
      // nên đăng ký lại callback của plugin để Flutter nhận được thẻ.
      unawaited(_nfcReader.ensureSessionStarted(force: true));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_nfcReader.stop());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo));
    if (!(widget.configValid ?? AppConfig.isValid)) {
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
