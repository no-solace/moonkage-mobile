import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moonkage_verify/nfc/nfc_reader.dart';

final nfcStatusProvider = FutureProvider.autoDispose<NfcStatus>((ref) async {
  final reader = ref.watch(nfcReaderProvider);
  final status = await reader.checkStatus();
  if (status == NfcStatus.enabled) {
    unawaited(reader.ensureSessionStarted());
  }
  return status;
});
