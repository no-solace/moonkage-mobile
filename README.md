# Moonkage Verify (mobile)

App Flutter cho Android: người dùng đăng nhập tài khoản Moonkage, quét QR phiên trên web, chạm thẻ NFC; máy chủ lưu tạm thông tin thẻ, người dùng kiểm lại rồi bấm **Lưu** để xác minh tài khoản.

Package `moonkage_verify`, application id `edu.fpt.moonkage.mobile`. App **chỉ đọc** thẻ, không ghi.

| Muốn biết | Đọc |
|---|---|
| Cấu trúc code, file nào làm gì | README này |
| Quy ước viết code, quy tắc bảo mật dữ liệu thẻ | [docs/CODE_STANDARD.md](docs/CODE_STANDARD.md) |
| Luồng, hợp đồng API, dựng môi trường, lỗi đã gặp, trạng thái hiện tại | [docs/DEV_LOGS.md](docs/DEV_LOGS.md) (nhật ký, chỉ ghi thêm ở cuối) |
| Nội dung thẻ, cách ghi thẻ NFC | [docs/NFC_CARD_GUIDE.md](docs/NFC_CARD_GUIDE.md) |

---

## 1. Chạy nhanh

Mọi lệnh chạy trong thư mục `mobile/`.

```powershell
flutter pub get

# Tạo cấu hình build, sửa IP thành IPv4 của PC (ipconfig → adapter Wi-Fi)
copy env\mock.example.json env\mock.json

# Terminal 1: mock server thay backend, mở http://localhost:8090 để lấy QR
dart run tool/mock_server.dart

# Terminal 2: chạy app trên điện thoại Android cắm qua USB
flutter run --dart-define-from-file=env/mock.json
```

Tài khoản mock: `demo@moonkage.vn` / `123456`. Chạy với backend thật thì dùng `env/dev.json` (cổng gateway 8080). Chi tiết và các ca test tay ở DEV_LOGS mục 6.

Trước khi commit:

```bash
dart format .
flutter analyze   # phải "No issues found!"
flutter test
```

---

## 2. Thư mục gốc

```
mobile/
├── lib/                 # code của app (mục 3)
├── test/                # test, cùng cấu trúc với lib/ (mục 5)
├── tool/                # script cho dev, không đóng gói vào app (mục 6)
├── env/                 # cấu hình build cho --dart-define-from-file (mục 6)
├── docs/                # tài liệu mobile
├── android/             # project Android (quyền NFC, minSdk 26, …); app chỉ hỗ trợ Android
├── pubspec.yaml         # thư viện và phiên bản app (version → app_version gửi máy chủ)
└── analysis_options.yaml# lint và formatter (dòng tối đa 100 ký tự, cấm print, …)
```

Không commit: `build/`, `.dart_tool/`, `env/*.json` (trừ `*.example.json`), APK/AAB, keystore.

---

## 3. `lib/`: code của app

### 3.1 Ba vùng lớn

```
lib/
├── main.dart, app.dart, router.dart   # khởi động app và điều hướng
├── core/                              # dùng chung cho mọi tính năng
├── nfc/                               # bọc thư viện nfc_manager
└── features/                          # từng tính năng: auth (đăng nhập), verify (xác minh)
```

Mỗi tính năng trong `features/` chia theo tầng:

| Tầng | Chứa | Được import |
|---|---|---|
| `domain/` | Model và logic thuần Dart (parse QR, parse thẻ) | Chỉ Dart thuần. **Không** import Flutter, Dio, nfc_manager |
| `data/` | Gọi API, chuyển JSON ↔ model | `domain/`, `core/` |
| `presentation/` | Màn hình, widget, notifier giữ state | `domain/`, `data/` (qua provider), `nfc/`, `core/` |

Ngoài ra: `core/` và `nfc/` không import `features/`; widget không gọi Dio hay NfcManager trực tiếp mà luôn qua provider, để test thay được bằng bản giả.

### 3.2 Từng file

```
lib/
├── main.dart                      # chạy app trong ProviderScope (Riverpod)
├── app.dart                       # MaterialApp.router, theme; cấu hình sai → màn "Lỗi cấu hình"
├── router.dart                    # đường dẫn các màn (AppRoutes); chưa đăng nhập → về /login
│
├── core/
│   ├── strings.dart               # MỌI câu chữ hiển thị (tiếng Việt), kể cả lý do từ chối
│   ├── config/
│   │   ├── app_config.dart        # API_BASE_URL lấy từ env/*.json; không có URL mặc định
│   │   └── app_version_provider.dart  # version từ pubspec, gửi kèm thẻ
│   ├── auth/
│   │   ├── auth_session.dart      # token + tên người dùng, chỉ giữ trong bộ nhớ
│   │   └── session_notifier.dart  # sessionProvider: null = chưa đăng nhập; đăng nhập / đăng xuất
│   ├── network/
│   │   ├── dio_provider.dart      # instance Dio duy nhất (baseUrl, timeout)
│   │   ├── auth_interceptor.dart  # gắn "Bearer <token>"; gặp 401 thì đăng xuất
│   │   └── dio_failure.dart       # DioException → AppFailure
│   └── errors/
│       ├── app_failure.dart       # lỗi kỹ thuật: mất mạng, timeout, 401, máy chủ lỗi
│       └── reason_code.dart       # reasonCode nghiệp vụ (SESSION_EXPIRED, LOCKED, …) → enum
│
├── nfc/
│   ├── nfc_reader.dart            # interface NfcReader, NfcStatus, nfcReaderProvider
│   ├── nfc_manager_reader.dart    # cài đặt thật bằng nfc_manager; luôn dừng phiên NFC
│   └── ndef_text_decoder.dart     # giải mã NDEF Text record (UTF-8 / UTF-16) thành chuỗi
│
└── features/
    ├── auth/
    │   ├── data/auth_api.dart                 # POST /identity-service/api/auth/login
    │   └── presentation/
    │       ├── login_screen.dart              # form email/SĐT + mật khẩu
    │       └── login_notifier.dart            # gọi AuthApi, thành công thì ghi sessionProvider
    │
    └── verify/
        ├── domain/
        │   ├── session_qr.dart                # parse QR "moonkage-verify:v1:<session_id>"
        │   ├── card_parser.dart               # chọn record JSON có id_number, kiểm 9 trường
        │   ├── identity_card.dart             # model IdentityCard, enum Sex
        │   └── verify_outcome.dart            # PendingConfirmation / Verified / Rejected
        ├── data/
        │   ├── verify_api.dart                # gửi thẻ, xác nhận (Lưu), hủy
        │   ├── submit_card_request.dart       # body gửi thẻ
        │   ├── identity_card_json.dart        # IdentityCard ↔ JSON camelCase của API
        │   └── session_result_response.dart   # JSON phản hồi → VerifyOutcome
        └── presentation/
            ├── verify_flow_state.dart         # các trạng thái của luồng (sealed class)
            ├── verify_flow_notifier.dart      # điều khiển cả luồng; màn hình chỉ đọc state
            ├── nfc_status_provider.dart       # NFC bật / tắt / không hỗ trợ
            ├── screens/
            │   ├── home_screen.dart           # chào, kiểm NFC, nút Quét QR, Đăng xuất
            │   ├── scan_qr_screen.dart        # camera quét QR
            │   ├── tap_card_screen.dart       # chờ chạm thẻ rồi gửi lên máy chủ
            │   ├── confirm_screen.dart        # thông tin máy chủ đã lưu tạm, nút Lưu / Hủy
            │   └── result_screen.dart         # đã xác minh, hoặc lý do bị từ chối
            └── widgets/
                ├── card_details.dart          # bảng thông tin thẻ chỉ đọc
                └── status_message.dart        # thông báo giữa màn + nút hành động
```

---

## 4. Đọc code theo luồng

Một lần xác minh đi qua các file như sau:

| Bước | Màn hình | Logic | Gọi ra ngoài |
|---|---|---|---|
| 1. Đăng nhập | `login_screen.dart` | `login_notifier.dart` → `session_notifier.dart` | `auth_api.dart` |
| 2. Trang chủ | `home_screen.dart` | `nfc_status_provider.dart` | `nfc_reader.dart` |
| 3. Quét QR | `scan_qr_screen.dart` | `verify_flow_notifier.dart` + `session_qr.dart` | — |
| 4. Chạm thẻ, gửi | `tap_card_screen.dart` | `verify_flow_notifier.dart` + `card_parser.dart` | `nfc_manager_reader.dart`, `verify_api.dart` (gửi thẻ) |
| 5. Xác nhận | `confirm_screen.dart` | `verify_flow_notifier.dart` | `verify_api.dart` (Lưu hoặc Hủy) |
| 6. Kết quả | `result_screen.dart` | đọc `VerifyOutcome` | — |

Trạng thái luồng nằm trong `verify_flow_state.dart`:

```
AwaitingQr → AwaitingCard → ReadingCard → Submitting → AwaitingConfirmation → Completed
```

Dữ liệu thẻ đi qua state của notifier, **không** qua URL của router, và bị xóa khi Lưu xong, Hủy, về trang chủ hoặc đăng xuất.

### Muốn sửa … thì vào đâu

| Việc | File |
|---|---|
| Đổi câu chữ, thông báo lỗi | `core/strings.dart` |
| Thêm màn hình | `features/<tính năng>/presentation/screens/` + khai báo route trong `router.dart` |
| Thêm / đổi endpoint | `features/<tính năng>/data/` (và `tool/mock_server.dart` để mock khớp) |
| Đổi tên trường JSON gửi máy chủ | `features/verify/data/identity_card_json.dart` |
| Đổi nội dung / quy định trên thẻ | `features/verify/domain/card_parser.dart`, `identity_card.dart`, `docs/NFC_CARD_GUIDE.md` |
| Thêm `reasonCode` mới | `core/errors/reason_code.dart` + câu chữ trong `core/strings.dart` |
| Đổi URL máy chủ | `env/*.json` (không sửa code) |
| Đổi cách đọc NFC | `nfc/` |

---

## 5. `test/`

Cùng cấu trúc với `lib/`: test của `lib/a/b.dart` nằm ở `test/a/b_test.dart`. Test không gọi mạng thật, không cần điện thoại.

```
test/
├── app_test.dart                    # thiếu API_BASE_URL → lỗi cấu hình; chưa đăng nhập → màn đăng nhập
├── helpers/
│   ├── card_fixtures.dart           # nội dung thẻ mẫu, có thể thay từng khóa
│   └── fake_http_adapter.dart       # thay mạng cho Dio, ghi lại request cuối
├── core/                            # reasonCode, AuthInterceptor
├── nfc/                             # giải mã Text record
└── features/
    ├── auth/presentation/           # đăng nhập đúng / sai
    └── verify/
        ├── domain/                  # parse QR, parse thẻ (nhiều ca sai)
        ├── data/                    # đường dẫn, JSON, các loại phản hồi
        └── presentation/            # cả luồng trong VerifyFlowNotifier
```

Đọc NFC thật và camera thì kiểm tay trên máy Android.

---

## 6. `tool/` và `env/`

| File | Dùng để |
|---|---|
| `tool/mock_server.dart` | Giả identity-service ở cổng 8090 (đăng nhập, gửi thẻ, Lưu, Hủy, các reasonCode). Trang `http://localhost:8090` hiện QR để quét |
| `tool/make_card.dart` | Kiểm file JSON của thẻ giống app, rút về một dòng, báo số byte và vừa NTAG213/215/216 không |
| `tool/card_sample.json` | Thẻ mẫu để sao chép rồi sửa: `dart run tool/make_card.dart tool/card_sample.json` |
| `env/mock.example.json` | Mẫu cấu hình chạy với mock server (`http://<IP PC>:8090`) |
| `env/dev.example.json` | Mẫu cấu hình chạy với API gateway thật (`http://<IP PC>:8080`) |

`env/mock.json`, `env/dev.json` là bản riêng trên máy mỗi người (chứa IP LAN), không commit.

---

## 7. Quy tắc phải nhớ

Tóm tắt từ CODE_STANDARD; vi phạm là chặn merge.

- **Không log, không lưu** dữ liệu thẻ, mật khẩu, token (không `print`, không file, không SharedPreferences).
- URL máy chủ **chỉ** lấy từ `env/*.json`, không đọc từ QR, không cho người dùng nhập.
- App không có chức năng ghi thẻ.
- Câu chữ hiển thị đặt trong `core/strings.dart`, không viết thẳng trong widget.
- Chỉ dùng dữ liệu CCCD mẫu trong test, fixture, ảnh chụp màn hình.
- Commit theo dạng `feat(mobile): …`, `fix(mobile): …`; nhánh `feature/mobile-<tên>` tách từ `develop`.

## 8. CCCD Json Sample
```
{
  "id_number": "000000000001",
  "full_name": "NGUYEN VAN AN",
  "date_of_birth": "1990-01-01",
  "sex": "Nam",
  "nationality": "Viet Nam",
  "place_of_birth": "Tinh Lam Dong",
  "place_of_residence": "So 1 Duong Thu Nghiem, Phuong Sai Gon, TP Lam Dong",
  "date_of_issue": "2024-01-01",
  "date_of_expiry": "2030-01-01"
}
```