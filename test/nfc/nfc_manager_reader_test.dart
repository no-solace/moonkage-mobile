import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moonkage_verify/nfc/nfc_manager_reader.dart';
import 'package:moonkage_verify/nfc/nfc_reader.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/src/nfc_manager_android/pigeon.g.dart';

class _MockNfcManager extends Mock implements NfcManager {}

void main() {
  late _MockNfcManager manager;
  late NfcManagerReader reader;

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    manager = _MockNfcManager();
    when(() => manager.stopSession()).thenAnswer((_) async {});
    reader = NfcManagerReader(manager);
  });

  group('checkStatus', () {
    test('trả về đúng trạng thái tương ứng từ NfcManager', () async {
      when(() => manager.checkAvailability()).thenAnswer((_) async => NfcAvailability.enabled);
      expect(await reader.checkStatus(), NfcStatus.enabled);

      when(() => manager.checkAvailability()).thenAnswer((_) async => NfcAvailability.disabled);
      expect(await reader.checkStatus(), NfcStatus.disabled);

      when(() => manager.checkAvailability()).thenAnswer((_) async => NfcAvailability.unsupported);
      expect(await reader.checkStatus(), NfcStatus.unsupported);
    });
  });

  group('ensureSessionStarted', () {
    test('bật ReaderMode với noPlatformSoundsAndroid khi NFC khả dụng', () async {
      when(() => manager.checkAvailability()).thenAnswer((_) async => NfcAvailability.enabled);
      when(
        () => manager.startSession(
          pollingOptions: any(named: 'pollingOptions'),
          noPlatformSoundsAndroid: any(named: 'noPlatformSoundsAndroid'),
          onDiscovered: any(named: 'onDiscovered'),
        ),
      ).thenAnswer((_) async {});

      await reader.ensureSessionStarted();

      verify(() => manager.checkAvailability()).called(1);
      verify(
        () => manager.startSession(
          pollingOptions: {
            NfcPollingOption.iso14443,
            NfcPollingOption.iso15693,
            NfcPollingOption.iso18092,
          },
          noPlatformSoundsAndroid: true,
          onDiscovered: any(named: 'onDiscovered'),
        ),
      ).called(1);

      // Gọi lại lần 2 không bật thêm session (idempotent)
      await reader.ensureSessionStarted();
      verifyNoMoreInteractions(manager);
    });

    test('không bật session nếu NFC bị tắt hoặc không hỗ trợ', () async {
      when(() => manager.checkAvailability()).thenAnswer((_) async => NfcAvailability.disabled);
      await reader.ensureSessionStarted();
      verifyNever(
        () => manager.startSession(
          pollingOptions: any(named: 'pollingOptions'),
          noPlatformSoundsAndroid: any(named: 'noPlatformSoundsAndroid'),
          onDiscovered: any(named: 'onDiscovered'),
        ),
      );
    });

    test(
      'readTextRecords đăng ký lại callback dù session đã bật (native có thể đã ghi đè)',
      () async {
        when(() => manager.checkAvailability()).thenAnswer((_) async => NfcAvailability.enabled);
        when(
          () => manager.startSession(
            pollingOptions: any(named: 'pollingOptions'),
            noPlatformSoundsAndroid: any(named: 'noPlatformSoundsAndroid'),
            onDiscovered: any(named: 'onDiscovered'),
          ),
        ).thenAnswer((_) async {});

        await reader.ensureSessionStarted();
        unawaited(reader.readTextRecords().catchError((_) => <String>[]));
        await Future<void>.delayed(const Duration(milliseconds: 60));

        verify(
          () => manager.startSession(
            pollingOptions: any(named: 'pollingOptions'),
            noPlatformSoundsAndroid: any(named: 'noPlatformSoundsAndroid'),
            onDiscovered: any(named: 'onDiscovered'),
          ),
        ).called(2);
        await reader.cancel();
      },
    );
  });

  group('rearmSession', () {
    test('làm mới listener nhưng KHÔNG gọi stopSession để duy trì ReaderMode liên tục', () async {
      when(() => manager.checkAvailability()).thenAnswer((_) async => NfcAvailability.enabled);
      when(
        () => manager.startSession(
          pollingOptions: any(named: 'pollingOptions'),
          noPlatformSoundsAndroid: any(named: 'noPlatformSoundsAndroid'),
          onDiscovered: any(named: 'onDiscovered'),
        ),
      ).thenAnswer((_) async {});

      await reader.ensureSessionStarted();
      verify(
        () => manager.startSession(
          pollingOptions: any(named: 'pollingOptions'),
          noPlatformSoundsAndroid: any(named: 'noPlatformSoundsAndroid'),
          onDiscovered: any(named: 'onDiscovered'),
        ),
      ).called(1);

      await reader.rearmSession();

      // stopSession KHÔNG được gọi để tránh khoảng hở cho Android Tag Viewer
      verifyNever(() => manager.stopSession());
      // startSession được gọi lại lần 2 để làm mới listener
      verify(
        () => manager.startSession(
          pollingOptions: any(named: 'pollingOptions'),
          noPlatformSoundsAndroid: any(named: 'noPlatformSoundsAndroid'),
          onDiscovered: any(named: 'onDiscovered'),
        ),
      ).called(1);
    });
  });

  group('cancel', () {
    test('hủy phiên đọc đang chờ thì ném NfcReadCancelled nhưng KHÔNG tắt ReaderMode', () async {
      when(() => manager.checkAvailability()).thenAnswer((_) async => NfcAvailability.enabled);
      when(
        () => manager.startSession(
          pollingOptions: any(named: 'pollingOptions'),
          noPlatformSoundsAndroid: any(named: 'noPlatformSoundsAndroid'),
          onDiscovered: any(named: 'onDiscovered'),
        ),
      ).thenAnswer((_) async {});
      when(() => manager.stopSession()).thenAnswer((_) async {});

      final future = reader.readTextRecords();
      await Future<void>.delayed(Duration.zero);

      expect(future, throwsA(isA<NfcReadCancelled>()));
      await reader.cancel();

      // Ambient Shield: cancel() KHÔNG tắt stopSession để duy trì khiên chắn
      verifyNever(() => manager.stopSession());
    });
  });

  group('readTextRecords and Ambient Shield Mode', () {
    test(
      'onDiscovered đọc thẻ, sau đó nuốt các lần chạm tiếp theo và chỉ stop khi gọi stop()',
      () async {
        void Function(NfcTag)? discoveredCallback;

        when(() => manager.checkAvailability()).thenAnswer((_) async => NfcAvailability.enabled);
        when(
          () => manager.startSession(
            pollingOptions: any(named: 'pollingOptions'),
            noPlatformSoundsAndroid: any(named: 'noPlatformSoundsAndroid'),
            onDiscovered: any(named: 'onDiscovered'),
          ),
        ).thenAnswer((invocation) async {
          discoveredCallback = invocation.namedArguments[#onDiscovered] as void Function(NfcTag);
        });
        when(() => manager.stopSession()).thenAnswer((_) async {});

        final future = reader.readTextRecords();
        await Future<void>.delayed(Duration.zero);
        expect(discoveredCallback, isNotNull);

        final fakeTag = NfcTag(
          data: TagPigeon(handle: 'tag_1', id: Uint8List(0), techList: <String>[]),
        );

        // Bắn event phát hiện thẻ
        discoveredCallback!(fakeTag);

        // Thẻ không có Ndef thì trả về danh sách rỗng
        final records = await future;
        expect(records, isEmpty);

        // Trong Ambient Shield Mode: KHÔNG gọi stopSession ngay sau khi đọc thẻ
        // mà tiếp tục giữ ReaderMode để nuốt các xung quét tiếp theo trong im lặng
        discoveredCallback!(fakeTag);
        discoveredCallback!(fakeTag);
        verifyNever(() => manager.stopSession());

        // Chỉ đóng session khi gọi stop() tường minh lúc đóng app
        await reader.stop();
        verify(() => manager.stopSession()).called(1);
      },
    );
  });
}
