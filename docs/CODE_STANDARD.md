# Code Standard: Mobile (Moonkage Verify)

| Mục | Giá trị |
|---|---|
| Phiên bản | v0.4 |
| Ngày cập nhật | 2026-10-16 |
| Áp dụng cho | `mobile/` — app Flutter Moonkage Verify (`edu.fpt.moonkage.mobile`) |
| Dựa trên | Flutter_App_Plan v0.4, Requirement v1.3 (FR-54, A-08), Software Design v0.4 (5.1) |

Tài liệu này là quy ước viết code cho phần mobile. Code mới phải theo; code cũ được sửa dần khi đụng tới. Khi tài liệu này khác với plan, theo plan rồi cập nhật lại tài liệu này.

---

## 1. Các tầng kiểm tra

Giống backend (`backend/docs/t0-t1-automation.md`), hai tầng thấp nhất để máy lo, hai tầng trên do người review.

| Tầng | Nội dung | Công cụ | Lệnh |
|---|---|---|---|
| T0 — Định dạng | Thụt lề, xuống dòng, dấu phẩy cuối | `dart format` (cấu hình trong `analysis_options.yaml`) | `dart format .` |
| T1 — Lint | Kiểu chặt, async, `print`, naming… | `flutter_lints` + rule bổ sung trong `analysis_options.yaml` | `flutter analyze` |
| T2 — Thiết kế | Cấu trúc thư mục, state, xử lý lỗi, bảo mật | Review theo mục 3–8 | — |
| T3 — Kiểm thử | Unit, widget test | `flutter_test`, `mocktail` | `flutter test` |

**Trước mỗi commit** chạy, trong thư mục `mobile/`:

```bash
dart format .
flutter analyze        # phải "No issues found!"
flutter test           # phải pass hết
```

Không tắt rule cho cả project để qua lint. Nếu thật sự cần, dùng `// ignore: <rule>` trên đúng dòng đó, kèm một câu giải thích lý do.

> Hook `pre-commit` và CI hiện chỉ chạy cho `backend/`. Bổ sung job mobile là việc còn mở (mục 10).

---

## 2. Cấu hình lint đang dùng

Tóm tắt `analysis_options.yaml`, để biết vì sao analyzer báo lỗi:

| Cấu hình | Ý nghĩa thực tế |
|---|---|
| `strict-casts`, `strict-inference`, `strict-raw-types` | Không gán `dynamic` sang kiểu cụ thể ngầm định; JSON phải ép kiểu rõ |
| `avoid_dynamic_calls` | Không gọi `json['a']['b']` trên `dynamic` |
| `avoid_print: error` | Không dùng `print` (xem mục 7) |
| `unawaited_futures`, `cancel_subscriptions`, `close_sinks` | Future phải `await` hoặc bọc `unawaited(...)`; stream phải hủy |
| `avoid_catches_without_on_clauses` | `catch` phải có `on <Kiểu>` |
| `prefer_single_quotes`, `prefer_final_locals`, `prefer_const_constructors`, `directives_ordering` | Style |
| `formatter.page_width: 100`, `trailing_commas: preserve` | Dòng tối đa 100 ký tự; giữ dấu phẩy cuối để cây widget xuống dòng |

---

## 3. Cấu trúc thư mục

```
lib/
├── main.dart              # chỉ khởi tạo ProviderScope và chạy app
├── app.dart               # MaterialApp.router, theme
├── router.dart            # cấu hình go_router
├── core/
│   ├── auth/              # phiên đăng nhập (token trong bộ nhớ), sessionProvider
│   ├── config/            # AppConfig đọc --dart-define
│   ├── network/           # tạo Dio, interceptor gắn token
│   ├── errors/            # AppFailure, ánh xạ reasonCode
│   └── strings.dart       # mọi câu chữ hiển thị (tiếng Việt)
├── nfc/                   # bọc nfc_manager: kiểm NFC, đọc Text record
└── features/
    ├── auth/              # đăng nhập (data/, presentation/)
    └── verify/
        ├── data/          # gọi API, DTO request/response
        ├── domain/        # model, logic thuần Dart (parse QR, …)
        └── presentation/  # screen, widget, provider của màn hình
test/                      # cùng cấu trúc với lib/
tool/                      # script dev, không đóng gói vào app (mock_server.dart)
env/                       # cấu hình --dart-define-from-file; chỉ commit *.example.json
```

**Quy tắc phụ thuộc** (chiều mũi tên là "được import"):

- `presentation → domain`, `presentation → data` (qua provider), `data → domain`, `data → core`.
- `domain` không import Flutter, Dio hay `nfc_manager` — chỉ Dart thuần, để test không cần thiết bị.
- `nfc/` và `core/` không import `features/`.
- Widget không gọi `Dio` hay `NfcManager` trực tiếp; luôn đi qua class trong `data/` hoặc `nfc/` được cung cấp bằng provider.

Một file một class public chính. File quá ~300 dòng thì tách.

---

## 4. Đặt tên

| Loại | Quy ước | Ví dụ |
|---|---|---|
| File, thư mục | `snake_case` | `scan_qr_screen.dart` |
| Class, enum, typedef | `UpperCamelCase` | `VerifyResult`, `ReasonCode` |
| Biến, hàm, tham số, giá trị enum | `lowerCamelCase` | `sessionId`, `ReasonCode.sessionExpired` |
| Hằng số | `lowerCamelCase`, không `SCREAMING_CAPS` | `const qrPrefix = 'moonkage-verify:v1:';` |
| Private | tiền tố `_` | `_parseCardText` |
| Screen | hậu tố `Screen` | `ScanQrScreen` |
| Provider | hậu tố `Provider` | `verifyApiProvider` |
| Notifier | hậu tố `Notifier` | `VerifyFlowNotifier` |
| DTO API | hậu tố `Request` / `Response` | `SubmitResultRequest` |
| Test | `<file>_test.dart` | `qr_parser_test.dart` |

Tên trong code viết tiếng Anh. Câu chữ hiển thị cho người dùng viết tiếng Việt, đặt trong `core/strings.dart` (mục 8). Trường JSON giữ nguyên tên của API (backend Spring dùng `camelCase`, xem `docs/auth.md`).

---

## 5. Dart và Flutter

**Kiểu và bất biến**
- Khai báo kiểu cho field, tham số, giá trị trả về của API public. Biến cục bộ dùng `final` (hoặc `var` khi cần gán lại).
- Model là bất biến: field `final`, constructor `const` khi được.
- Không dùng `dynamic` ngoài chỗ đọc JSON thô. Không dùng `!` trừ khi chắc chắn và đã kiểm ngay phía trên.
- Trạng thái có nhiều dạng dùng `sealed class` + `switch` để compiler bắt thiếu trường hợp:

```dart
sealed class VerifyOutcome {
  const VerifyOutcome();
}

final class Verified extends VerifyOutcome {
  const Verified({required this.legalName, required this.idNumberMasked});
  final String legalName;
  final String idNumberMasked;
}

final class Rejected extends VerifyOutcome {
  const Rejected({required this.reason, this.attemptsLeft, this.lockedUntil});
  final ReasonCode reason;
  final int? attemptsLeft;
  final DateTime? lockedUntil;
}
```

**Widget**
- Ưu tiên `StatelessWidget` / `ConsumerWidget`; chỉ dùng `StatefulWidget` khi giữ controller (ví dụ `MobileScannerController`) và phải `dispose`.
- `build()` không gọi API, không đọc NFC, không tạo `Future`. Việc đó làm trong notifier.
- Tách widget thành class riêng, không dùng hàm `Widget _buildX()` trả widget lớn.
- Sau `await` mà dùng `context`, phải kiểm `if (!context.mounted) return;`.
- Không hard-code màu, cỡ chữ: lấy từ `Theme.of(context)`.

**Async**
- Mọi `Future` phải `await`, hoặc bọc `unawaited(...)` có chủ đích.
- Phiên NFC luôn dừng trong `finally` (`NfcManager.instance.stopSession()`), kể cả khi lỗi.

---

## 6. State, điều hướng, mạng, lỗi

**Riverpod**
- Dùng `flutter_riverpod` không codegen: `Provider`, `NotifierProvider`, `AsyncNotifierProvider`.
- Phụ thuộc ngoài (Dio, NFC reader, API) được cung cấp qua `Provider` để test override được.
- Luồng xác minh (QR → chạm thẻ → gửi → xác nhận → kết quả) do một notifier giữ; màn hình chỉ đọc state và gọi method.
- Không dùng biến toàn cục hay singleton tự viết để giữ state.

**go_router**
- Khai báo route ở `router.dart`, đường dẫn là hằng số, không gõ chuỗi rải rác.
- Không truyền dữ liệu thẻ qua tham số URL; dữ liệu đi qua state của notifier.

**Dio và JSON**
- Chỉ có một instance `Dio`, tạo ở `core/network`, `baseUrl` lấy từ `AppConfig` (mục 7). Đặt `connectTimeout` và `receiveTimeout`.
- Parse JSON ở DTO trong `data/`, ép kiểu rõ ràng; không để `Map<String, dynamic>` lọt lên `presentation`:

```dart
// features/verify/data/session_result_response.dart (rút gọn)
final lockedUntil = json['lockedUntil'] as String?;
return Rejected(
  reason: ReasonCode.fromCode(json['reasonCode'] as String?),
  attemptsLeft: json['attemptsLeft'] as int?,
  lockedUntil: lockedUntil == null ? null : DateTime.parse(lockedUntil),
);
```

**Lỗi**
- `reason_code` từ máy chủ được map sang `enum ReasonCode` một chỗ duy nhất (`core/errors`). Giá trị lạ map sang `ReasonCode.unknown`, không crash.
- Lớp `data/` bắt `DioException` và trả về kiểu lỗi của app (`AppFailure`: mất mạng, timeout, máy chủ lỗi, …); `presentation` không biết tới Dio.
- `catch` luôn có `on <Kiểu>`. Không nuốt lỗi im lặng: hoặc chuyển thành state lỗi hiển thị cho người dùng, hoặc ném lại.

---

## 7. Bảo mật và dữ liệu thẻ (bắt buộc)

Các điểm dưới đây xuất phát từ FR-54 và nguyên tắc ở plan mục 4.2. Thẻ nay chứa số CCCD, ngày sinh, nơi sinh, nơi thường trú: đây là dữ liệu cá nhân, nên các điểm này càng phải giữ. Vi phạm là chặn merge.

1. **Không log dữ liệu thẻ và thông tin đăng nhập.** Không in nội dung thẻ, bất kỳ trường nào của thẻ, mật khẩu hay token ra console, crash report hay analytics. `print` đã bị lint chặn; `debugPrint`/`log` cũng không được dùng với các giá trị này. Interceptor log của Dio (nếu có) chỉ bật ở debug và không log body hay header `Authorization`.
2. **Không lưu dữ liệu thẻ và token trên máy.** Không ghi vào file, `SharedPreferences`, database, cache. Giữ trong bộ nhớ của notifier; thông tin thẻ bị bỏ khi bấm Lưu xong, bấm Hủy, quay về trang chủ hoặc đăng xuất.
3. **URL máy chủ chỉ lấy từ cấu hình build**, không đọc từ QR, không cho người dùng nhập.
4. **Kiểm QR trước khi dùng:** đúng tiền tố `moonkage-verify:v1:` và `session_id` hợp lệ; sai thì báo lỗi, không gọi API.
5. **App kiểm nội dung thẻ (JSON, NFC_CARD_GUIDE mục 2) trước khi gửi** (`domain/card_parser.dart`) để báo lỗi sớm và không gửi thẻ sai lên máy chủ. Máy chủ **vẫn phải kiểm lại**; không tin kết quả kiểm ở app.
6. **App không có chức năng ghi thẻ** (AC 55.3): không gọi API ghi NDEF của `nfc_manager`.
7. Chỉ dùng **dữ liệu CCCD mẫu** (A-08) trong test, fixture, ảnh chụp màn hình.

---

## 8. Cấu hình môi trường và câu chữ

**Cấu hình** dùng `--dart-define-from-file`, đọc một lần trong `core/config`:

```dart
abstract final class AppConfig {
  static const apiBaseUrl = String.fromEnvironment('API_BASE_URL');
}
```

```bash
flutter run --dart-define-from-file=env/dev.json
```

- `env/*.json` bị gitignore; commit `env/dev.example.json` làm mẫu.
- Thiếu `API_BASE_URL` thì app báo lỗi cấu hình ngay khi khởi động, không âm thầm dùng URL mặc định.

**Câu chữ**: mọi chuỗi hiển thị đặt trong `core/strings.dart`, không viết thẳng trong widget. Lý do của từng `reason_code` cũng nằm ở đây, để sửa câu chữ tiếng Việt ở GĐ 3 chỉ đụng một file.

---

## 9. Kiểm thử

| Phần | Loại test | Bắt buộc |
|---|---|---|
| `domain/` (parse QR, parse nội dung thẻ) | Unit | Có, đủ ca đúng và sai |
| Ánh xạ `reason_code`, parse DTO | Unit | Có, mỗi `reason_code` một ca + ca giá trị lạ |
| Notifier luồng xác minh | Unit, override provider bằng `mocktail` | Có |
| Màn hình | Widget test | Màn kết quả (thành công / từng loại lỗi) |
| Đọc NFC thật, camera | Thủ công trên máy Android, theo bảng kiểm thử ở plan mục 5 | — |

- Test không gọi mạng thật, không cần thiết bị; mock `Dio`/API và NFC reader qua provider.
- Đặt tên test mô tả hành vi: `test('QR sai tiền tố thì trả về lỗi định dạng', ...)`.
- Sửa bug thì thêm test tái hiện bug đó.

---

## 10. Git và pull request

- Nhánh tách từ `develop`: `feature/mobile-<tên>`, `fix/mobile-<tên>`.
- Commit theo [Conventional Commits](https://www.conventionalcommits.org), scope `mobile`:
  `feat(mobile): scan session QR`, `fix(mobile): stop NFC session on error`.
- Không commit: `env/*.json` (trừ file mẫu), keystore, `key.properties`, APK/AAB, `build/`.

**Checklist trước khi mở PR**

- [ ] `dart format .` không đổi gì thêm
- [ ] `flutter analyze` sạch
- [ ] `flutter test` pass, có test cho code mới trong `domain/`, `data/`
- [ ] Không có log, lưu trữ hay URL nào vi phạm mục 7
- [ ] Chuỗi hiển thị mới nằm trong `core/strings.dart`
- [ ] Đã chạy thử trên máy Android thật nếu đụng tới NFC hoặc camera

**Việc còn mở**

| # | Việc |
|---|---|
| M-01 | Thêm job `flutter analyze` + `flutter test` cho `mobile/**` vào `.github/workflows/code-quality.yml` |
| M-02 | Mở rộng `.githooks/pre-commit` để chạy `dart format --set-exit-if-changed` và `flutter analyze` khi có file `.dart` trong `mobile/` |

---

## 11. Lịch sử thay đổi

| Phiên bản | Ngày | Nội dung |
|---|---|---|
| v0.1 | 2026-10-16 | Tạo tài liệu (đổi từ `CODE_QUALITY.MD` rỗng): tầng T0–T3, cấu trúc thư mục, đặt tên, state, lỗi, bảo mật dữ liệu thẻ, test, quy trình PR |
| v0.2 | 2026-10-16 | Mục 3: thêm `tool/` (mock server) và `env/`. Trạng thái và cách chạy xem `DEV_NOTES.md` |
| v0.3 | 2026-10-16 | Luồng mới (DEV_NOTES v0.2): thêm `core/auth`, `features/auth`; JSON theo `camelCase` của backend; mục 7 thêm token, mật khẩu, ảnh; app kiểm định dạng `MK2` trước khi gửi, máy chủ kiểm lại |
| v0.4 | 2026-10-16 | Thẻ đổi sang JSON (NFC_CARD_GUIDE v0.3), bỏ ảnh. `DEV_NOTES.md` đổi tên thành `DEV_LOGS.md` (nhật ký, chỉ ghi thêm) |
