import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moonkage_verify/nfc/nfc_reader.dart';

final nfcStatusProvider = FutureProvider.autoDispose<NfcStatus>(
  (ref) => ref.watch(nfcReaderProvider).checkStatus(),
);
