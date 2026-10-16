import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moonkage_verify/nfc/nfc_manager_reader.dart';
import 'package:nfc_manager/nfc_manager.dart';

enum NfcStatus { enabled, disabled, unsupported }

/// Đọc thẻ NFC. App chỉ đọc, không có thao tác ghi (AC 55.3).
abstract interface class NfcReader {
  Future<NfcStatus> checkStatus();

  /// Chờ một thẻ chạm vào và trả về nội dung mọi NDEF Text record theo thứ tự trên thẻ.
  ///
  /// Thẻ không có NDEF hoặc không có Text record thì trả về danh sách rỗng.
  /// Ném [NfcReadException] khi đọc lỗi, [NfcReadCancelled] khi [cancel] được gọi.
  Future<List<String>> readTextRecords();

  Future<void> cancel();
}

final class NfcReadException implements Exception {
  const NfcReadException();
}

final class NfcReadCancelled implements Exception {
  const NfcReadCancelled();
}

final nfcReaderProvider = Provider<NfcReader>((ref) => NfcManagerReader(NfcManager.instance));
