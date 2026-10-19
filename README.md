# Moonkage Verify (Mobile)

Ứng dụng Flutter cho Android: Hỗ trợ xác minh danh tính người dùng bằng cách quét mã QR phiên từ web Moonkage, đọc chip thẻ CCCD qua sóng NFC, kiểm tra lại thông tin và mã hóa đầu cuối (E2EE) trước khi gửi kết quả lên hệ thống máy chủ.

* **Package name:** `moonkage_verify`
* **Application ID:** `com.moonkage.mobile`
* **Phạm vi nền tảng:** Chỉ hỗ trợ Android (minSdk 26, targetSdk 35).
* **Đặc tính NFC:** Ứng dụng **chỉ đọc** thẻ (NTAG215 / ISO 14443 Type A), không ghi đè dữ liệu lên thẻ.

---

## Mục lục & Bản đồ Tài liệu

| Tài liệu                                                                                 | Nội dung chính                                                                                                  |
| ---------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------- |
| **[README này](README.md)**                                                              | Bức tranh toàn cảnh: Cấu trúc code, luồng nghiệp vụ, cơ chế kỹ thuật và hướng dẫn vận hành                      |
| **[docs/00_analysis.md](docs/00_analysis.md)**                                           | **Báo cáo phân tích chuyên sâu:** Tổng hợp hiện trạng, điểm mạnh, điểm yếu và giải pháp của cả 5 luồng hệ thống |
| **[docs/01_auth_flow_plan.md](docs/01_auth_flow_plan.md)**                               | Kế hoạch Luồng 1: Đăng nhập, Remember Me (Keystore) & DTO parsing linh hoạt                                     |
| **[docs/02_qr_flow_plan.md](docs/02_qr_flow_plan.md)**                                   | Kế hoạch Luồng 2: Quét QR đa định dạng, Viewfinder Overlay, Torch & Check Session                               |
| **[docs/03_nfc_lifecycle_plan.md](docs/03_nfc_lifecycle_plan.md)**                       | Kế hoạch Luồng 3: Vòng đời NFC, Cold Start Shield, Re-arm RF Field & Smart Haptics                              |
| **[docs/04_confirm_submit_plan.md](docs/04_confirm_submit_plan.md)**                     | Kế hoạch Luồng 4: Xác nhận, Data Masking (che CCCD), Loading Overlay & Result Screen                            |
| **[docs/05_code_cleanup_refactor_plan.md](docs/05_code_cleanup_refactor_plan.md)**       | Kế hoạch Luồng 5: Dọn dẹp dead states, chuẩn hóa State Machine và 100% docstrings                               |
| **[docs/06_nfc_shield_reinforcement_plan.md](docs/06_nfc_shield_reinforcement_plan.md)** | Kế hoạch Luồng 6: Gia cố Khiên chắn NFC Toàn diện & Triệt tiêu Pop-up Hệ thống Android                          |

---

## 1. Khởi động nhanh (Quickstart in 3 minutes)

Toàn bộ lệnh chạy từ thư mục gốc `mobile/`:

```powershell
# 1. Cài đặt thư viện phụ thuộc
flutter pub get

# 2. Tạo cấu hình môi trường chạy máy ảo / điện thoại thật qua mạng LAN
# (Sửa API_BASE_URL thành địa chỉ IPv4 máy tính của bạn, tra bằng lệnh 'ipconfig')
copy env\mock.example.json env\mock.json

# 3. Terminal 1: Chạy Mock Server thay thế Backend (mở http://localhost:8090 trên trình duyệt để lấy mã QR)
dart run tool/mock_server.dart

# 4. Terminal 2: Biên dịch và chạy ứng dụng trên thiết bị Android cắm qua USB
flutter run --dart-define-from-file=env/mock.json
```

* **Tài khoản kiểm thử mẫu (Mock Account):** `demo@moonkage.vn` / Mật khẩu: `123456`.
* **Môi trường kết nối Backend thật:** Sử dụng `env/dev.json` (kết nối qua API Gateway cổng 8080).
  Bắt buộc điền `NFC_TRANSPORT_PUBLIC_KEY` (PEM viết liền trên một dòng, không có `\n`: trên Windows `flutter build` không truyền được giá trị có xuống dòng) khớp với `NFC_TRANSPORT_PRIVATE_KEY_V1` trong `.env` của platform:
  `openssl pkey -in nfc.pem -pubout`. Thiếu khóa thì app dừng ở màn lỗi cấu hình; khóa demo chỉ dùng với mock server (`NFC_USE_DEMO_KEY`).

### Tiêu chuẩn kiểm tra trước khi commit mã nguồn

```powershell
dart format .
flutter analyze   # Bắt buộc đạt "No issues found!" (0 cảnh báo linter)
flutter test      # Bắt buộc đạt 100% pass (86/86 test cases)
```

---

## 2. Bản đồ cấu trúc Mã nguồn (Project Navigation Map)

### 2.1 Cấu trúc thư mục gốc

```text
mobile/
├── lib/                 # Toàn bộ mã nguồn Dart của ứng dụng
├── test/                # Kiểm thử tự động (86 unit & widget tests)
├── tool/                # Bộ công cụ phục vụ phát triển (Mock server, script tạo thẻ NTAG)
├── env/                 # Cấu hình biến môi trường build (--dart-define-from-file)
├── docs/                # Hệ thống tài liệu phân tích và kế hoạch kỹ thuật
├── android/             # Dự án Native Android (Cấu hình quyền, Cold Start Shield)
├── pubspec.yaml         # Khai báo thư viện và thông tin phiên bản ứng dụng
└── analysis_options.yaml# Cấu hình bộ quy tắc kiểm tra tĩnh (Linter & Style rules)
```

### 2.2 Kiến trúc phân tầng trong `lib/`

Mã nguồn được tổ chức theo chuẩn **Feature-first kết hợp Clean Architecture**:

```text
lib/
├── main.dart                      # Điểm khởi chạy app, bọc trong ProviderScope (Riverpod)
├── app.dart                       # Khởi tạo MaterialApp.router, theme và kích hoạt Ambient Shield
├── router.dart                    # Hệ thống điều hướng (GoRouter) với bộ lọc chuyển hướng xác thực
│
├── core/                          # Nền tảng dùng chung cho toàn bộ dự án
│   ├── strings.dart               # TẬP TRUNG 100% CÂU CHỮ HIỂN THỊ (Tuyệt đối không hardcode)
│   ├── auth/                      # Quản lý phiên đăng nhập và bảo mật token
│   │   ├── auth_session.dart      # Model thông tin phiên đăng nhập
│   │   ├── session_notifier.dart  # Quản lý trạng thái phiên đăng nhập (sessionProvider)
│   │   └── token_storage.dart     # Lưu trữ token an toàn qua Keystore (FlutterSecureStorage)
│   ├── config/                    # Cấu hình môi trường và phiên bản
│   │   ├── app_config.dart        # Đọc cấu hình từ env/*.json; kiểm tra tính hợp lệ của URL
│   │   └── app_version_provider.dart # Đọc chuỗi phiên bản từ PackageInfo
│   ├── network/                   # Cấu hình mạng và HTTP Client
│   │   ├── api_endpoints.dart     # Quản lý tập trung toàn bộ đường dẫn Endpoint API
│   │   ├── dio_provider.dart      # Cung cấp singleton Dio client an toàn
│   │   ├── auth_interceptor.dart  # Tự động đính kèm Bearer token; tự đăng xuất khi gặp lỗi 401
│   │   └── dio_failure.dart       # Ánh xạ ngoại lệ DioException sang AppFailure
│   └── errors/                    # Hệ thống định nghĩa lỗi
│       ├── app_failure.dart       # Lỗi kỹ thuật (Mất mạng, Timeout, Lỗi máy chủ)
│       └── reason_code.dart       # Mã lý do từ chối nghiệp vụ (SESSION_EXPIRED, LOCKED, v.v.)
│
├── nfc/                           # Tầng giao tiếp phần cứng NFC độc lập
│   ├── nfc_reader.dart            # Interface NfcReader, enum NfcStatus và nfcReaderProvider
│   ├── nfc_manager_reader.dart    # Cài đặt ReaderMode, Ambient Shield, Re-arm RF và Haptics
│   └── ndef_text_decoder.dart     # Giải mã chuẩn NDEF Text record (hỗ trợ cả UTF-8 và UTF-16)
│
└── features/                      # Các mô-đun nghiệp vụ độc lập
    ├── auth/                      # Tính năng Đăng nhập
    │   ├── data/auth_api.dart                 # Gọi API đăng nhập, parse DTO linh hoạt
    │   └── presentation/
    │       ├── login_screen.dart              # Màn hình đăng nhập, ẩn/hiện mật khẩu, Remember Me
    │       └── login_notifier.dart            # Notifier xử lý luồng đăng nhập
    │
    └── verify/                    # Tính năng Xác minh Danh tính (Core Feature)
        ├── domain/                # Tầng nghiệp vụ thuần Dart (Không phụ thuộc Framework)
        │   ├── identity_card.dart             # Model thẻ CCCD (9 trường thông tin)
        │   ├── session_qr.dart                # Parser mã QR (hỗ trợ v1, v2 và Web URL)
        │   ├── card_parser.dart               # Parser & validator cấu trúc thẻ CCCD NDEF
        │   └── verify_outcome.dart            # Model kết quả xác minh (Verified / Rejected)
        ├── data/                  # Tầng kết nối dữ liệu & Bảo mật E2EE
        │   ├── verify_api.dart                # Giao tiếp API xác minh (checkSession, submitCard)
        │   ├── card_encryptor.dart            # Bộ mã hóa JWE compact token (RSA-OAEP-256 + A256GCM)
        │   ├── demo_nfc_key.dart              # Khóa công khai RSA dự phòng cho môi trường dev
        │   ├── submit_card_request.dart       # Body gửi dữ liệu lên server kèm encryptedFields
        │   ├── identity_card_json.dart        # Chuyển đổi JSON CCCD ↔ Entity
        │   └── session_result_response.dart   # Chuyển đổi phản hồi máy chủ sang VerifyOutcome
        └── presentation/          # Tầng giao diện người dùng & Điều khiển trạng thái
            ├── verify_flow_notifier.dart      # Bộ điều khiển State Machine trung tâm của luồng
            ├── verify_flow_state.dart         # Định nghĩa các trạng thái (Sealed class)
            ├── nfc_status_provider.dart       # Theo dõi trạng thái phần cứng NFC
            ├── screens/
            │   ├── home_screen.dart           # Màn hình chính sau đăng nhập, kiểm tra NFC
            │   ├── scan_qr_screen.dart        # Màn hình quét QR (Viewfinder bo góc, Torch)
            │   ├── tap_card_screen.dart       # Màn hình chờ chạm thẻ (Sóng NFC xung kích)
            │   ├── confirm_screen.dart        # Màn hình xác nhận (Che CCCD, Loading Overlay)
            │   └── result_screen.dart         # Màn hình kết quả (Đồ họa lớn, Haptics)
            └── widgets/
                ├── card_details.dart          # Widget hiển thị chi tiết thẻ kèm nút ẩn/hiện CCCD
                └── status_message.dart        # Widget hiển thị thông báo trạng thái & nút thử lại
```

### 2.3 Bảng tra cứu nhanh "Muốn sửa... thì vào đâu?"

| Nhu cầu chỉnh sửa | Vị trí tệp tin cần can thiệp |
| --- | --- |
| Đổi câu chữ, thông báo lỗi, nhãn hiển thị | [lib/core/strings.dart](lib/core/strings.dart) |
| Thêm/sửa màn hình hoặc đường dẫn điều hướng | [lib/router.dart](lib/router.dart) và thư mục `presentation/screens/` tương ứng |
| Thêm hoặc cập nhật đường dẫn API | [lib/core/network/api_endpoints.dart](lib/core/network/api_endpoints.dart) |
| Chỉnh sửa định dạng QR được hỗ trợ | [lib/features/verify/domain/session_qr.dart](lib/features/verify/domain/session_qr.dart) |
| Thay đổi cấu trúc hoặc quy tắc hợp lệ của thẻ CCCD | [lib/features/verify/domain/card_parser.dart](lib/features/verify/domain/card_parser.dart) & [lib/docs/NFC_CARD_GUIDE.md](docs/NFC_CARD_GUIDE.md) |
| Đổi khóa công khai mã hóa JWE | Tham số `NFC_TRANSPORT_PUBLIC_KEY` trong `env/*.json` |
| Tinh chỉnh hành vi quét sóng NFC hoặc độ trễ Re-arm | [lib/nfc/nfc_manager_reader.dart](lib/nfc/nfc_manager_reader.dart) |

---

## 3. Mạch nghiệp vụ & Vòng đời Trạng thái (Business Workflow & State Machine)

Toàn bộ luồng xác minh tuân thủ nghiêm ngặt nguyên lý **Software Design D-20** (Xác nhận tại máy rồi mới gửi một lần; Zero Server Footprint trước xác nhận).

### 3.1 Bảng luồng đi qua các màn hình

| Bước | Màn hình | Bộ điều khiển (Logic) | Giao tiếp ngoại vi & API |
| :---: | :--- | :--- | :--- |
| **1** | **Đăng nhập** (`/login`) | `login_notifier.dart` $\rightarrow$ `session_notifier.dart` | Gọi `auth_api.dart` lấy JWT; lưu Keystore nếu chọn Remember Me |
| **2** | **Trang chủ** (`/home`) | `nfc_status_provider.dart` | Gọi `nfc_reader.dart` kiểm tra phần cứng; kích hoạt Ambient Shield |
| **3** | **Quét QR** (`/verify/scan-qr`) | `verify_flow_notifier.dart` + `session_qr.dart` | Gọi `verify_api.dart (checkSession)` kiểm tra phiên hợp lệ trước khi cho chạm thẻ |
| **4** | **Chạm thẻ** (`/verify/tap-card`) | `verify_flow_notifier.dart` + `card_parser.dart` | `nfc_manager_reader.dart` đọc NDEF vào RAM; **hoàn toàn không gọi API** (Zero Server Footprint) |
| **5** | **Xác nhận** (`/verify/confirm`) | `verify_flow_notifier.dart` | Bấm Lưu: `card_encryptor.dart` (mã hóa JWE) $\rightarrow$ gọi `verify_api.dart (submitCard)`. Bấm Hủy: xóa RAM, về Trang chủ, không gọi API |
| **6** | **Kết quả** (`/verify/result`) | Đọc `VerifyOutcome` từ state | Hiển thị kết quả (`VERIFIED` hoặc `REJECTED` kèm lý do & số lần thử) |

### 3.2 Sơ đồ State Machine trong `VerifyFlowState`

Trạng thái luồng được quản lý tập trung và an toàn qua `VerifyFlowNotifier`:

```text
┌──────────────┐       Quét QR hợp lệ & Session OK        ┌──────────────┐
│  AwaitingQr  │ ────────────────────────────────────────> │ AwaitingCard │ <───┐ (Áp thẻ lại nếu trượt)
└──────────────┘                                           └──────────────┘     │
                                                                   │            │
                                                      Bắt đầu đọc  │            │ Lỗi đọc thẻ
                                                                   v            │
                                                           ┌──────────────┐     │ (readFailed / wrongCard)
                                                           │ ReadingCard  │ ────┘
                                                           └──────────────┘
                                                                   │
                                                   Đọc NDEF & Parse CCCD hợp lệ
                                                                   v
                                                    ┌──────────────────────────────┐
                                                    │     AwaitingConfirmation     │ <───┐ (Lỗi mạng: Bấm Lưu lại)
                                                    │ (saving: false/true, card)   │ ────┘
                                                    └──────────────────────────────┘
                                                                   │
                                                   Gửi thành công / Máy chủ từ chối
                                                                   v
                                                           ┌──────────────┐
                                                           │  Completed   │
                                                           │ (Verified /  │
                                                           │  Rejected)   │
                                                           └──────────────┘
```

* Dữ liệu thẻ CCCD nằm hoàn toàn trong RAM của `AwaitingConfirmation`, **không bao giờ truyền qua query parameter của URL** và được tự động giải phóng sạch sẽ khi người dùng bấm Lưu xong, Hủy, hoặc đăng xuất.

---

## 4. Điểm sáng Kiến trúc & Công nghệ Cốt lõi (Architectural Highlights)

### 4.1 Giải pháp xử lý NFC toàn diện (Zero Tag-Trap & Zero Cold-Start Gap)

1. **Native Cold Start Shield ([MainActivity.kt](android/app/src/main/kotlin/edu/fpt/moonkage/mobile/MainActivity.kt)):**
   * Kích hoạt `NfcAdapter.enableReaderMode` với cờ `FLAG_READER_NO_PLATFORM_SOUNDS` ngay trong hàm `onStart()` của Activity native.
   * Vô hiệu hóa Tag Dispatch System của Android từ mili-giây đầu tiên mở app, triệt tiêu 100% pop-up hệ thống *"New tag scanned"* kể cả khi thẻ đã áp vào lưng máy từ trước khi bấm icon app.
2. **Kỹ thuật Re-arm RF Field tự động nhận diện thẻ áp sẵn ([nfc_manager_reader.dart](lib/nfc/nfc_manager_reader.dart)):**
   * Khi chuyển sang màn Chạm thẻ, hàm `rearmSession()` thực hiện chớp tắt ReaderMode trong 25ms.
   * Kích hoạt lại chu kỳ polling của chip NFC Android $\rightarrow$ **tự động quét và đọc ngay thẻ đang áp sẵn ở lưng máy** mà người dùng không cần phải nhấc thẻ ra chạm lại.
3. **Cơ chế Khiên chắn Ambient Shield liên tục:**
   * Giữ ReaderMode hoạt động ngầm trên toàn bộ các màn hình ngoài (Login, Quét QR, Xác nhận, Kết quả) với `_pending == null`.
   * Nuốt toàn bộ các xung chạm thẻ thừa trong im lặng; người dùng giữ thẻ ở lưng máy suốt quá trình xác nhận thì app vẫn chạy mượt mà, không phát tiếng kêu hay giật lag.

### 4.2 Bảo mật Dữ liệu & Quyền riêng tư (Privacy & E2EE)

1. **Nguyên tắc Zero Server Footprint (Software Design D-20):**
   * Không có cơ chế "lưu tạm thẻ trên server rồi confirm sau". Mọi thông tin chỉ được gửi lên server đúng 1 lần duy nhất khi người dùng chủ động bấm **Lưu**. Bấm Hủy sẽ xóa sạch dữ liệu khỏi bộ nhớ cục bộ mà không để lại bất kỳ rác dữ liệu nào trên máy chủ.
2. **Mã hóa trường nhạy cảm cấp độ vận chuyển (Field-Level E2EE JWE):**
   * Ba trường thông tin định danh nhạy cảm nhất (`idNumber`, `dateOfBirth`, `placeOfResidence`) được bọc và mã hóa bằng chuẩn **JWE Compact Token** (`RSA-OAEP-256 + AES-256-GCM`) trước khi gửi qua mạng.
   * Kể cả khi đường truyền đi qua các Reverse Proxy trung gian, API Gateway hoặc hệ thống Log máy chủ, kẻ tấn công cũng không thể giải mã được số CCCD nếu không có Private Key của server.
3. **Bảo vệ quyền riêng tư nơi công cộng (Data Masking):**
   * Màn hình Xác nhận mặc định che 6 chữ số giữa của CCCD (`079 ••• ••• 890`). Tích hợp nút icon con mắt giúp người dùng linh hoạt bật/tắt xem toàn bộ số khi ở nơi an toàn.
4. **Bảo vệ Token bằng phần cứng Keystore:**
   * Token đăng nhập được lưu trữ mã hóa qua `FlutterSecureStorage` (Android Keystore), chống đọc trộm dữ liệu trên các thiết bị đã bị can thiệp root.

### 4.3 Trải nghiệm Người dùng (Smart Haptics & Visuals)

* **Phản hồi xúc giác đa tầng:**
  * Rung nhẹ 1 nhịp (`HapticFeedback.lightImpact`) khi điện thoại vừa bắt sóng thẻ.
  * Rung xác nhận êm ái (`HapticFeedback.mediumImpact`) khi đọc thẻ thành công và khi hoàn thành xác minh.
  * Rung cảnh báo dứt khoát (`HapticFeedback.heavyImpact`) khi đọc trượt thẻ, sai loại thẻ hoặc khi bị máy chủ từ chối.
* **Chỉ dẫn trực quan:**
  * Hiệu ứng sóng lan tỏa (`_NfcPulseIcon`) sinh động tại màn Chạm thẻ kèm dòng chỉ dẫn vị trí đặt thẻ ở nửa trên mặt lưng máy (gần cụm camera).
  * Lớp phủ mờ bảo vệ (`Loading Overlay`) trong lúc mã hóa và lưu dữ liệu, ngăn chặn việc chạm nhầm hoặc bấm đúp.
  * Màn hình Kết quả với icon đồ họa lớn rõ ràng (Tích tròn xanh thành công / Dấu X tròn đỏ thất bại).

---

## 5. Kiểm thử Tự động & Công cụ Phát triển

### 5.1 Hệ thống Kiểm thử (`test/`)

Toàn bộ dự án được bao phủ bởi **86 bài kiểm thử tự động**, chia thành các tầng:

* `test/app_test.dart`: Kiểm tra điều kiện cấu hình khởi động và chuyển hướng router.
* `test/core/`: Kiểm tra ánh xạ mã lỗi nghiệp vụ, bảo vệ token trong `AuthInterceptor` và lưu trữ `TokenStorage`.
* `test/nfc/`: Kiểm tra giải mã NDEF UTF-8/UTF-16, kiểm thử `rearmSession` và tính năng duy trì khiên chắn Ambient Shield nuốt xung.
* `test/features/auth/`: Kiểm thử đăng nhập đúng/sai, ẩn hiện mật khẩu và checkbox Remember Me.
* `test/features/verify/domain/`: Kiểm thử phân tích QR (v1/v2/Web URL), kiểm tra tính hợp lệ của 9 trường CCCD.
* `test/features/verify/data/`: Kiểm thử mã hóa JWE RSA-OAEP, format JSON ngày tháng và xử lý phản hồi máy chủ.
* `test/features/verify/presentation/`: Kiểm thử toàn diện widget cho tất cả các màn hình (`TapCardScreen`, `ConfirmScreen`, `ResultScreen`, `LoginScreen`).

### 5.2 Bộ công cụ Phát triển (`tool/` & `env/`)

| Tệp tin | Vai trò & Hướng dẫn sử dụng |
| --- | --- |
| `tool/mock_server.dart` | Server giả lập viết bằng Dart thuần cổng 8090: Cung cấp API đăng nhập, kiểm tra session, nhận diện JWE và trang web sinh mã QR trực quan tại `http://localhost:8090` |
| `tool/make_card.dart` | Tiện ích kiểm tra tính hợp lệ của file JSON thẻ CCCD, nén thành 1 dòng và tính toán dung lượng byte để biết có nạp vừa chip NTAG213/NTAG215 hay không |
| `tool/card_sample.json` | Mẫu nội dung thẻ CCCD chuẩn để copy và ghi thẻ thực nghiệm |
| `env/mock.example.json` | Mẫu cấu hình chạy cùng Mock Server nội bộ máy tính |
| `env/dev.example.json` | Mẫu cấu hình chạy cùng hệ thống Backend thật của Moonkage |

---

## 6. Tiêu chuẩn Bất biến & Quy ước Bảo mật (Non-negotiables)

1. **Tuyệt đối không log dữ liệu nhạy cảm:** Cấm dùng `print()` hoặc xuất log chứa nội dung thẻ CCCD, mật khẩu đăng nhập, hoặc Private Key.
2. **Không hardcode chuỗi hiển thị:** Mọi câu chữ tiếng Việt xuất hiện trên UI đều phải được định nghĩa trong `lib/core/strings.dart`.
3. **Nguồn cấu hình duy nhất:** URL máy chủ chỉ được cung cấp qua cờ `--dart-define-from-file`, không đọc từ QR và không cho người dùng tự nhập.
4. **Chỉ dùng dữ liệu mẫu trong code:** Mọi số CCCD xuất hiện trong test, mock data, tài liệu đều là thông tin giả định mẫu (ví dụ: `000000000001`).
5. **Quy chuẩn Git Commit:** Tuân thủ Conventional Commits (`feat(mobile): ...`, `fix(mobile): ...`, `refactor(mobile): ...`).

---

## 7. Hướng dẫn Tạo & Ghi Thẻ NFC (NFC Card Guide)

Tài liệu chi tiết xem tại [docs/NFC_CARD_GUIDE.md](docs/NFC_CARD_GUIDE.md). Dưới đây là tóm tắt quy trình chuẩn bị và ghi thẻ NFC phục vụ kiểm thử và demo:

### 7.1 Yêu cầu Phần cứng Thẻ NFC

* ✅ **NTAG215 (Khuyên dùng):** Dung lượng khả dụng 504 byte — Vừa vặn tuyệt đối cho payload JSON CCCD (khoảng 280–320 byte).
* ✅ **NTAG216:** Dung lượng 888 byte — Vừa vặn, thoải mái.
* ✅ **Chuẩn thẻ:** ISO 14443 Type A, chuẩn truyền thông NFC Forum Type 2 Tag.
* ❌ **NTAG213 (144 byte) — KHÔNG VỪA:** Dung lượng thẻ nhỏ hơn kích thước chuỗi JSON 9 trường, cố ghi sẽ bị lỗi tràn bộ nhớ thẻ.

### 7.2 Quy định 9 trường Dữ liệu Thẻ CCCD

Dữ liệu nạp vào thẻ là một JSON object duy nhất nằm trong **NDEF Text Record**:

| Khóa JSON | Kiểu | Quy chuẩn bắt buộc | Ví dụ mẫu |
| --- | --- | --- | --- |
| `id_number` | Chuỗi | Đúng 12 chữ số | `"000000000001"` |
| `full_name` | Chuỗi | Chữ in hoa không dấu | `"NGUYEN VAN AN"` |
| `date_of_birth` | Chuỗi | Định dạng `yyyy-MM-dd` | `"1990-01-01"` |
| `gender` | Chuỗi | `"Nam"` hoặc `"Nu"` (hoặc `"Nữ"`) | `"Nam"` |
| `nationality` | Chuỗi | Tên quốc gia | `"Viet Nam"` |
| `place_of_birth` | Chuỗi | Quê quán / Nơi sinh | `"Tinh Lam Dong"` |
| `place_of_residence` | Chuỗi | Địa chỉ thường trú | `"So 1 Duong Thu Nghiem, TP Da Lat"` |
| `date_of_issue` | Chuỗi | Định dạng `yyyy-MM-dd` | `"2024-01-01"` |
| `date_of_expiry` | Chuỗi | Định dạng `yyyy-MM-dd` | `"2030-01-01"` |

* **Ràng buộc ngày tháng:** Bắt buộc `date_of_birth` < `date_of_issue` < `date_of_expiry`.

### 7.3 Cách tạo file JSON nén 1 dòng bằng Tool

Sử dụng tiện ích `tool/make_card.dart` để kiểm tra cú pháp, rút gọn JSON về một dòng và đo dung lượng byte:

```powershell
# Chạy tool từ thư mục mobile/:
dart run tool/make_card.dart tool/card_sample.json the_a.txt
```

Kết quả in ra terminal sẽ báo rõ kích thước văn bản và xác nhận có vừa chip NTAG215 hay không:

```text
Văn bản: 288 byte
Cần trên thẻ: 303 byte
  NTAG213 (144 byte): KHÔNG vừa
  NTAG215 (504 byte): vừa
  NTAG216 (888 byte): vừa
```

### 7.4 Hướng dẫn 4 bước Ghi thẻ bằng ứng dụng NFC Tools (Android / iOS)

Cài đặt ứng dụng miễn phí **NFC Tools** từ Google Play Store hoặc Apple App Store:

1. **Bước 1: Xóa thẻ cũ (Erase Tag)**
   * Mở NFC Tools $\rightarrow$ Chuyển sang tab **OTHER** $\rightarrow$ Chọn **Erase tag** $\rightarrow$ Áp thẻ vào lưng máy để xóa sạch các record cũ. *(Thẻ bắt buộc chỉ được chứa đúng 1 record)*.
2. **Bước 2: Ghi dữ liệu CCCD (Write Record)**
   * Chuyển sang tab **WRITE** $\rightarrow$ Bấm **Add a record** $\rightarrow$ Chọn **Text**.
   * Dán toàn bộ chuỗi JSON 1 dòng đã tạo từ file `the_a.txt` vào ô nội dung $\rightarrow$ Bấm **OK**.
   * Bấm nút **Write / [xx] Bytes** $\rightarrow$ Áp thẻ vào nửa trên lưng máy (gần cụm camera) và giữ yên đến khi màn hình báo tích xanh *Write complete*.
3. **Bước 3: Đọc lại kiểm tra (Read Tag)**
   * Chuyển sang tab **READ** $\rightarrow$ Áp thẻ vào lưng máy.
   * Kiểm tra: Danh sách chỉ có đúng 1 record **Text**, nội dung bắt đầu bằng `{` và kết thúc bằng `}`, chứa đủ 9 khóa JSON.
4. **Bước 4: Khóa thẻ chống ghi đè (Chỉ dùng cho thẻ Demo cuối cùng)**
   * Tab **OTHER** $\rightarrow$ Chọn **Lock tag** $\rightarrow$ Bấm xác nhận và áp thẻ. *(Lưu ý: Khóa thẻ là vĩnh viễn, không thể mở lại).*

### 7.5 Mẫu Dữ liệu Thẻ CCCD Chuẩn

```json
{
  "id_number": "000000000001",
  "full_name": "NGUYEN VAN AN",
  "date_of_birth": "1990-01-01",
  "gender": "Nam",
  "nationality": "Viet Nam",
  "place_of_birth": "Tinh Lam Dong",
  "place_of_residence": "So 1 Duong Thu Nghiem, Phuong Sai Gon, TP Lam Dong",
  "date_of_issue": "2024-01-01",
  "date_of_expiry": "2030-01-01"
}
```
