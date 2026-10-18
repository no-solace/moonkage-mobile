import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:moonkage_verify/nfc/ndef_text_decoder.dart';
import 'package:moonkage_verify/nfc/nfc_reader.dart';
import 'package:nfc_manager/ndef_record.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager_ndef/nfc_manager_ndef.dart';

/// [NfcReader] dùng `nfc_manager`. Thẻ demo là NTAG215 (ISO 14443).
///
/// Duy trì ReaderMode liên tục (Ambient Shield) từ khi app khởi động để vô hiệu hóa
/// Tag Dispatch System của hệ điều hành Android, ngăn ngừa 100% pop-up "New tag scanned".
final class NfcManagerReader implements NfcReader {
  NfcManagerReader(this._manager);

  final NfcManager _manager;
  Completer<List<String>>? _pending;
  bool _isSessionActive = false;
  bool _isHandlingTag = false;

  @override
  Future<NfcStatus> checkStatus() async {
    try {
      return switch (await _manager.checkAvailability()) {
        NfcAvailability.enabled => NfcStatus.enabled,
        NfcAvailability.disabled => NfcStatus.disabled,
        NfcAvailability.unsupported => NfcStatus.unsupported,
      };
    } on Exception catch (_) {
      return NfcStatus.unsupported;
    }
  }

  @override
  Future<void> ensureSessionStarted({bool force = false}) async {
    if (_isSessionActive && !force) return;
    try {
      final availability = await _manager.checkAvailability();
      if (availability != NfcAvailability.enabled) {
        debugPrint('[NfcManagerReader] NFC availability: $availability');
        return;
      }

      await _manager.startSession(
        pollingOptions: {
          NfcPollingOption.iso14443,
          NfcPollingOption.iso15693,
          NfcPollingOption.iso18092,
        },
        noPlatformSoundsAndroid: true,
        onDiscovered: _handleTagDiscovered,
      );
      _isSessionActive = true;
      debugPrint('[NfcManagerReader] Ambient Shield active with full polling flags');
    } on MissingPluginException catch (e) {
      _isSessionActive = false;
      debugPrint('[NfcManagerReader] MissingPlugin: $e');
    } on PlatformException catch (e) {
      _isSessionActive = false;
      debugPrint('[NfcManagerReader] PlatformException: $e');
    } on Exception catch (e) {
      _isSessionActive = false;
      debugPrint('[NfcManagerReader] Exception: $e');
    }
  }

  void _handleTagDiscovered(NfcTag tag) {
    final pending = _pending;
    // Ambient Shield: Nếu không có màn hình nào đang chờ đọc thẻ (ví dụ đang ở Login,
    // Trang chủ, Quét QR, Xác nhận, Kết quả) hoặc đang xử lý thẻ:
    // Nuốt sự kiện trong im lặng. ReaderMode với noPlatformSoundsAndroid: true
    // đã tắt âm/rung hệ thống và ngăn Android mở TagViewer ("New tag scanned").
    if (pending == null || pending.isCompleted || _isHandlingTag) {
      return;
    }

    _isHandlingTag = true;
    unawaited(_readTag(tag, pending));
  }

  /// Làm mới phiên đọc thẻ mà tuyệt đối không giải phóng ReaderMode.
  /// Gọi trực tiếp `ensureSessionStarted(force: true)` để làm mới callback lắng nghe trong Android
  /// mà không gọi `stopSession()`, triệt tiêu hoàn toàn khoảng hở 25ms cho Tag Dispatcher hệ thống.
  Future<void> rearmSession() async {
    await ensureSessionStarted(force: true);
  }

  @override
  Future<List<String>> readTextRecords() async {
    final previousPending = _pending;
    if (previousPending != null && !previousPending.isCompleted) {
      previousPending.completeError(const NfcReadCancelled());
    }

    final completer = Completer<List<String>>();
    _pending = completer;
    _isHandlingTag = false;

    await rearmSession();
    if (!_isSessionActive) {
      _pending = null;
      throw const NfcReadException();
    }

    return completer.future;
  }

  @override
  Future<void> cancel() async {
    final pending = _pending;
    _pending = null;
    _isHandlingTag = false;
    if (pending != null && !pending.isCompleted) {
      pending.completeError(const NfcReadCancelled());
    }
    // Không gọi stopSession() để duy trì Ambient Shield liên tục.
  }

  @override
  Future<void> stop() async {
    final pending = _pending;
    _pending = null;
    _isHandlingTag = false;
    _isSessionActive = false;
    if (pending != null && !pending.isCompleted) {
      pending.completeError(const NfcReadCancelled());
    }
    try {
      await _manager.stopSession();
    } on Exception catch (_) {}
  }

  Future<void> _readTag(NfcTag tag, Completer<List<String>> completer) async {
    if (completer.isCompleted) return;
    try {
      // Báo hiệu thẻ đã tiếp xúc sóng NFC
      try {
        HapticFeedback.lightImpact().ignore();
      } on Object catch (_) {}

      final ndef = Ndef.from(tag);
      final message = ndef == null ? null : ndef.cachedMessage ?? await ndef.read();
      final texts = [
        for (final record in message?.records ?? const <NdefRecord>[]) ?decodeTextRecord(record),
      ];
      _isHandlingTag = false;
      _pending = null;
      if (!completer.isCompleted) completer.complete(texts);
    } on PlatformException catch (_) {
      _isHandlingTag = false;
      _pending = null;
      if (!completer.isCompleted) completer.completeError(const NfcReadException());
    } on Exception catch (_) {
      _isHandlingTag = false;
      _pending = null;
      if (!completer.isCompleted) completer.completeError(const NfcReadException());
    }
  }
}
