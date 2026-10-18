import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moonkage_verify/nfc/nfc_manager_reader.dart';
import 'package:nfc_manager/nfc_manager.dart';

enum NfcStatus { enabled, disabled, unsupported }

/// Đọc thẻ NFC. App chỉ đọc, không có thao tác ghi (AC 55.3).
abstract interface class NfcReader {
  Future<NfcStatus> checkStatus();

  /// Đảm bảo phiên ReaderMode (Ambient Shield) đang chạy để chặn hệ thống Android
  /// tự động bật pop-up "New tag scanned".
  /// An toàn khi gọi nhiều lần (idempotent). [force] = true thì đăng ký lại callback
  /// kể cả khi đang chạy (dùng khi Activity resume hoặc khi bắt đầu chờ đọc thẻ).
  Future<void> ensureSessionStarted({bool force = false});

  /// Chờ một thẻ chạm vào và trả về nội dung mọi NDEF Text record theo thứ tự trên thẻ.
  ///
  /// Thẻ không có NDEF hoặc không có Text record thì trả về danh sách rỗng.
  /// Ném [NfcReadException] khi đọc lỗi, [NfcReadCancelled] khi [cancel] được gọi.
  Future<List<String>> readTextRecords();

  /// Hủy việc chờ đọc thẻ hiện tại, nhưng vẫn duy trì Ambient Shield để chặn pop-up của hệ thống.
  Future<void> cancel();

  /// Dừng phiên đọc NFC và tắt ReaderMode (chỉ dùng khi đóng ứng dụng).
  Future<void> stop();
}

final class NfcReadException implements Exception {
  const NfcReadException();
}

final class NfcReadCancelled implements Exception {
  const NfcReadCancelled();
}

final nfcReaderProvider = Provider<NfcReader>((ref) => NfcManagerReader(NfcManager.instance));
