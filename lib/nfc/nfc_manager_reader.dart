import 'dart:async';

import 'package:flutter/services.dart';
import 'package:moonkage_verify/nfc/ndef_text_decoder.dart';
import 'package:moonkage_verify/nfc/nfc_reader.dart';
import 'package:nfc_manager/ndef_record.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager_ndef/nfc_manager_ndef.dart';

/// [NfcReader] dùng `nfc_manager`. Thẻ demo là NTAG215 (ISO 14443).
final class NfcManagerReader implements NfcReader {
  NfcManagerReader(this._manager);

  final NfcManager _manager;
  Completer<List<String>>? _pending;

  @override
  Future<NfcStatus> checkStatus() async => switch (await _manager.checkAvailability()) {
    NfcAvailability.enabled => NfcStatus.enabled,
    NfcAvailability.disabled => NfcStatus.disabled,
    NfcAvailability.unsupported => NfcStatus.unsupported,
  };

  @override
  Future<List<String>> readTextRecords() async {
    final completer = Completer<List<String>>();
    _pending = completer;
    try {
      await _manager.startSession(
        pollingOptions: {NfcPollingOption.iso14443},
        onDiscovered: (tag) => unawaited(_readTag(tag, completer)),
      );
      return await completer.future;
    } on PlatformException {
      throw const NfcReadException();
    } finally {
      _pending = null;
      await _manager.stopSession();
    }
  }

  @override
  Future<void> cancel() async {
    final pending = _pending;
    if (pending != null && !pending.isCompleted) {
      pending.completeError(const NfcReadCancelled());
    }
  }

  Future<void> _readTag(NfcTag tag, Completer<List<String>> completer) async {
    if (completer.isCompleted) return;
    try {
      final ndef = Ndef.from(tag);
      final message = ndef == null ? null : ndef.cachedMessage ?? await ndef.read();
      final texts = [
        for (final record in message?.records ?? const <NdefRecord>[]) ?decodeTextRecord(record),
      ];
      if (!completer.isCompleted) completer.complete(texts);
    } on PlatformException {
      if (!completer.isCompleted) completer.completeError(const NfcReadException());
    }
  }
}
