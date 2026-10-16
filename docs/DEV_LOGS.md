# Dev Notes: Moonkage Verify

| Mục | Giá trị |
|---|---|
| Phiên bản | v0.2 |
| Ngày cập nhật | 2026-10-16 |
| Áp dụng cho | `mobile/moonkage_verify` (`edu.fpt.moonkage.mobile`) |
| Dựa trên | Flutter_App_Plan v0.4, [CODE_STANDARD.md](CODE_STANDARD.md) v0.3, `docs/auth.md` |

Tài liệu này ghi lại luồng hiện tại của app, hợp đồng API app đang gọi, cách dựng môi trường, cách chạy và test khi backend chưa xong. Quy ước viết code xem [CODE_STANDARD.md](CODE_STANDARD.md); cách ghi thẻ xem [NFC_CARD_GUIDE.md](NFC_CARD_GUIDE.md).

---

## 1. Trạng thái

| Hạng mục | Trạng thái | Ghi chú |
|---|---|---|
| Quét QR, đọc NDEF Text record trên máy thật | Chạy được | Xác nhận ở v0.1 |
| Luồng mới: đăng nhập → Quét QR → chạm thẻ → lưu tạm → xác nhận → Lưu | Đã viết, có test | **Chưa chạy trên máy thật** |
| Thẻ định dạng `MK2` (11 trường, có ảnh base64) | Xong | App kiểm định dạng trước khi gửi |
| Mock server: đăng nhập, lưu tạm, xác nhận, hủy | Xong | Đã kiểm từng `reasonCode` bằng curl |
| Tool tạo nội dung thẻ `make_card` | Xong | Báo vừa NTAG213/215/216 hay không |
| `flutter analyze` / `flutter test` | Sạch / 46 test pass | |
| Build APK debug | Được | |
| Backend thật (identity-service) | Chưa có endpoint NFC | Hợp đồng đề xuất ở mục 3 |
| Cập nhật Requirement, Software Design, Plan | **Chưa** | Mục 5 |

---

## 2. Luồng

```
Đăng nhập ─▶ Trang chủ (kiểm NFC) ─▶ Quét QR ─▶ Chạm thẻ ─▶ Gửi (máy chủ lưu tạm)
                                                                  │
                     Kết quả ◀── Lưu ◀── Xác nhận (chỉ đọc) ◀──────┘
                                  │
                                 Hủy ─▶ Trang chủ (máy chủ xóa bản lưu tạm)
```

| Màn | File | Việc |
|---|---|---|
| Đăng nhập | `features/auth/presentation/login_screen.dart` | Email hoặc số điện thoại + mật khẩu |
| Trang chủ | `features/verify/presentation/screens/home_screen.dart` | Lời chào, kiểm NFC, nút **Quét QR**, Đăng xuất |
| Quét QR | `scan_qr_screen.dart` | QR phiên trên web `moonkage-verify:v1:<session_id>` |
| Chạm thẻ | `tap_card_screen.dart` | Đọc Text record `MK2\|`, kiểm định dạng, gửi |
| Xác nhận | `confirm_screen.dart` | Ảnh + 9 trường **do máy chủ trả về**, chỉ đọc; nút **Lưu** / **Hủy** |
| Kết quả | `result_screen.dart` | Đã xác minh, hoặc lý do bị từ chối |

**Trạng thái** (`VerifyFlowNotifier`):

```
AwaitingQr ─▶ AwaitingCard ─▶ ReadingCard ─▶ Submitting ─▶ AwaitingConfirmation ─▶ Completed
                  ▲                │              │               │  ▲
                  └─ sai loại thẻ, │              │               └──┘ Lưu lỗi mạng: giữ thông tin, bấm lại
                     sai định dạng,┘              │
                     mất mạng ◀────────────────────┘
```

- **Đăng nhập** do `core/auth/session_notifier.dart` giữ. Router đẩy về màn đăng nhập khi chưa đăng nhập. `AuthInterceptor` gắn `Authorization: Bearer <token>`, và gặp 401 thì đăng xuất.
- **Đăng xuất** (bấm nút, hoặc token hết hạn) thì luồng đang dở bị bỏ, kể cả thông tin thẻ trong bộ nhớ.
- Màn xác nhận hiển thị dữ liệu **máy chủ đã lưu tạm**, không phải dữ liệu app tự đọc, nên người dùng kiểm đúng cái sẽ được lưu.

---

## 3. Hợp đồng API (đề xuất cho backend)

Mọi đường dẫn đi qua gateway, theo tiền tố của identity-service như `docs/auth.md`. JSON dùng `camelCase`. Các endpoint `nfc-sessions` cần **Bearer token**. Trong mock server đã chạy đúng hợp đồng này.

### 3.1 Đăng nhập

Dùng nguyên `POST /identity-service/api/auth/login` `{username, password}` → `LoginResponse` (docs/auth.md). App chỉ dùng `token` và `fullName`; chưa dùng `refreshToken` (access token có hạn 12 giờ).

### 3.2 Gửi thẻ: `POST /identity-service/api/nfc-sessions/{sessionId}/card`

```json
{
  "idNumber": "001090000001",
  "fullName": "NGUYEN VAN AN",
  "dateOfBirth": "1990-01-01",
  "gender": "MALE",
  "nationality": "Việt Nam",
  "placeOfBirth": "Hà Nội",
  "birthRegistrationPlace": "UBND phường Hàng Bạc, Hà Nội",
  "issueDate": "2021-08-15",
  "expiryDate": "2036-01-01",
  "photoBase64": "iVBORw0KGgo…",
  "appVersion": "1.0.0+1"
}
```

Ngày dạng `yyyy-MM-dd`, `gender` là `MALE`/`FEMALE`, `photoBase64` là `""` nếu thẻ không có ảnh.

Máy chủ kiểm theo thứ tự, đạt hết thì **lưu tạm** thông tin vào phiên:

| Bước | Kiểm | Không đạt thì `reasonCode` |
|---|---|---|
| 1 | Phiên tồn tại, còn hạn (5 phút) | `SESSION_EXPIRED` |
| 2 | Phiên thuộc tài khoản trong token | `SESSION_NOT_OWNED` (mới) |
| 3 | Phiên chưa xác minh xong | `SESSION_USED` |
| 4 | Tài khoản không đang bị tạm khóa | `LOCKED` |
| 5 | Các trường đúng định dạng (như NFC_CARD_GUIDE mục 2) | `BAD_FORMAT` |
| 6 | Số CCCD chưa gắn với tài khoản khác | `ID_ALREADY_LINKED` |

Bước 5 và 6 tính một lần thử; 5 lần thì khóa 15 phút.

```json
// Đạt
{ "status": "PENDING_CONFIRMATION", "card": { …các trường như request, trừ appVersion… },
  "expiresAt": "2026-10-16T08:15:00Z" }
// Từ chối
{ "status": "REJECTED", "reasonCode": "ID_ALREADY_LINKED", "attemptsLeft": 4, "lockedUntil": null }
```

Gửi lại thẻ trên cùng phiên thì thay bản lưu tạm cũ.

### 3.3 Lưu: `POST /identity-service/api/nfc-sessions/{sessionId}/confirm`

Không có body. Máy chủ kiểm lại bước 1–4 và 6, rồi ghi thông tin đã lưu tạm vào tài khoản, đánh dấu phiên đã dùng, chuyển tài khoản sang "đã xác minh NFC", và đẩy kết quả về web qua WebSocket.

→ `{ "status": "VERIFIED" }`, hoặc `REJECTED` như trên. Chưa có bản lưu tạm thì trả 400 theo dạng lỗi chung.

### 3.4 Hủy: `DELETE /identity-service/api/nfc-sessions/{sessionId}/card`

Xóa bản lưu tạm → 204. App không đợi kết quả; nếu gọi lỗi thì bản lưu tạm vẫn tự hết hạn cùng phiên.

### 3.5 Lỗi

- 401 (token thiếu, sai, hết hạn): app đăng xuất và về màn đăng nhập.
- Lỗi khác theo dạng chung `{status, error, message, path, timestamp}`. App hiện `message` nếu có.
- Kết quả `REJECTED` có thể trả kèm 200 hoặc 4xx. App đọc theo `status` dạng chuỗi trong body, nên cả hai cách đều được. Backend chốt một cách.

---

## 4. Quyết định và giả định

| # | Nội dung | Lý do / cần ai xác nhận |
|---|---|---|
| D-1 | Tiền tố `/identity-service/api/...`, JSON `camelCase` | Theo `docs/auth.md` và code backend hiện có. Software Design v0.4 ghi `/api/identity/...` và `snake_case`: cần sửa một bên |
| D-2 | App đăng nhập; phiên QR phải thuộc tài khoản đăng nhập (`SESSION_NOT_OWNED`) | Luồng mới. Trước đây app không đăng nhập, chỉ dựa vào `session_id` |
| D-3 | App tự tách 11 trường từ thẻ và kiểm định dạng trước khi gửi; máy chủ kiểm lại | Báo lỗi sớm, không gửi thẻ sai. Thay nguyên tắc cũ "gửi nguyên văn" |
| D-4 | Token chỉ giữ trong bộ nhớ, không dùng refresh token | Đơn giản, không phải lưu bí mật trên máy. Mở app lại phải đăng nhập |
| D-5 | `session_id` chấp nhận `[A-Za-z0-9_-]{16,128}` | Software Design chỉ ghi "ngẫu nhiên ≥ 128 bit" |
| D-6 | Màn xác nhận hiển thị số CCCD đầy đủ | Người dùng cần kiểm đủ số. Backend cần chốt có trả đầy đủ hay đã che |

---

## 5. Thay đổi so với tài liệu nhóm (cần cập nhật)

Luồng mới khác Requirement v1.3, Software Design v0.4 và Flutter_App_Plan v0.4 ở các điểm sau. Mobile đã làm theo luồng mới, còn **ba tài liệu kia chưa sửa**:

| Tài liệu | Điểm khác |
|---|---|
| Requirement FR-54, A-08 | Thẻ chứa thêm ngày sinh, giới tính, quốc tịch, nơi sinh, nơi đăng ký khai sinh, ngày cấp, ngày hết hạn, ảnh; có bước xác nhận trước khi lưu |
| Requirement AC 54.6 | Đang ghi "không lưu số CCCD đầy đủ". Luồng mới lưu thêm ảnh, ngày sinh, nơi sinh…: cần chốt trường nào lưu dạng gì (băm, che, mã hóa) |
| Software Design 4.2, 5.1, 7.7 | Endpoint `/result` không JWT → ba endpoint `card` / `confirm` / `DELETE card` có JWT (mục 3); thêm `SESSION_NOT_OWNED`, trạng thái `PENDING_CONFIRMATION` |
| Plan 1, 2, 4.2, 4.3 | App có đăng nhập; thẻ `MK2`; app kiểm định dạng; bỏ P-03 (nay trả cả `card`) |
| Plan mục 2 (thẻ NTAG215) | Thẻ có ảnh cần NTAG216 (NFC_CARD_GUIDE mục 3) |

**Dữ liệu cá nhân:** ảnh chân dung, số CCCD, ngày sinh, nơi sinh là dữ liệu cá nhân, trong đó ảnh và CCCD thuộc nhóm nhạy cảm theo Nghị định 13/2023. Kể cả khi chỉ dùng dữ liệu mẫu, thiết kế phía máy chủ nên có: bản lưu tạm tự xóa khi hết phiên hoặc khi Hủy, mã hóa khi lưu, không log body, và người dùng đồng ý trước khi lưu. Bấm **Lưu** trên màn xác nhận là bước đồng ý đó.

---

## 6. Chạy và test

### 6.1 Cấu hình build

| File | `API_BASE_URL` | Dùng khi |
|---|---|---|
| `env/mock.json` | `http://<IP LAN của PC>:8090` | Chạy với mock server |
| `env/dev.json` | `http://<IP LAN của PC>:8080` | Chạy với API gateway thật |

Tạo từ `env/*.example.json` rồi sửa IP (`ipconfig` → *IPv4 Address* của adapter **Wi-Fi**). Thiếu hoặc sai `API_BASE_URL` thì app dừng ở màn "Lỗi cấu hình".

### 6.2 Test với mock server

```powershell
# Terminal 1, trong mobile/moonkage_verify
dart run tool/mock_server.dart

# Terminal 2
flutter run --dart-define-from-file=env/mock.json
```

1. Lần đầu Windows hỏi quyền mạng cho `dart.exe`: chọn **Private network**.
2. Mở `http://localhost:8090` trên PC. Trang hiện 4 QR: phiên mới, phiên hết hạn, phiên của tài khoản khác, QR sai dạng.
3. Đăng nhập app bằng `demo@moonkage.vn` / `123456` (hoặc số `0900000001`). Tài khoản thứ hai: `other@moonkage.vn` / `123456`.
4. Bấm **Quét QR**, quét QR trên màn hình PC, chạm thẻ, kiểm màn xác nhận, bấm **Lưu**.

| Muốn thấy | Làm |
|---|---|
| Xác minh thành công | Quét "Phiên mới", chạm thẻ hợp lệ, bấm **Lưu** |
| Hủy | Như trên nhưng bấm **Hủy** → về trang chủ; console mock in "xóa bản lưu tạm" |
| `SESSION_USED` | Quét lại QR vừa Lưu thành công (không tải lại trang) |
| `SESSION_EXPIRED` | Quét "Phiên hết hạn", hoặc đợi quá 5 phút rồi mới chạm thẻ / bấm Lưu |
| `SESSION_NOT_OWNED` | Đăng nhập `demo`, quét "Phiên tài khoản khác" |
| `ID_ALREADY_LINKED` | Lưu thẻ A ở `demo`; đăng xuất, đăng nhập `other`, tải lại trang, quét "Phiên tài khoản khác" (giờ là phiên của chính `other`), chạm thẻ A |
| `LOCKED` | 5 lần `ID_ALREADY_LINKED` liên tiếp → khóa 15 phút |
| Sai đăng nhập | Sai mật khẩu → "Thông tin đăng nhập không đúng." |
| Thẻ sai định dạng / sai loại | Thẻ C–F trong NFC_CARD_GUIDE mục 6; app báo lỗi, không gọi máy chủ |

Mock không nhận được thẻ sai định dạng vì app chặn trước. Để thử `BAD_FORMAT` phía máy chủ, gửi request bằng curl/Postman.

Nút **"Xóa trạng thái"** trên trang xóa phiên, CCCD đã gắn, số lần sai và khóa. Console chỉ in mã phiên rút gọn và kết quả, không in nội dung thẻ. Trạng thái mất khi tắt mock.

### 6.3 Kiểm tra trước commit

```bash
dart format .
flutter analyze        # "No issues found!"
flutter test           # 46 test
```

| Test | Nội dung |
|---|---|
| `test/core/errors/reason_code_test.dart` | Mỗi `reasonCode` + mã lạ |
| `test/core/network/auth_interceptor_test.dart` | Gắn Bearer token; 401 thì đăng xuất, lỗi khác thì giữ phiên |
| `test/features/auth/presentation/login_notifier_test.dart` | Đăng nhập đúng / sai |
| `test/features/verify/domain/*` | Parse QR; parse `MK2` (đủ trường, tên có dấu, ngày không tồn tại, base64 hỏng…) |
| `test/features/verify/data/verify_api_test.dart` | Đường dẫn, JSON, `PENDING_CONFIRMATION`, `REJECTED` kèm 4xx, 401, lỗi chung, `DELETE` (adapter HTTP giả) |
| `test/features/verify/presentation/verify_flow_notifier_test.dart` | Cả luồng: lưu tạm, Lưu, Lưu lỗi mạng, Hủy, sai thẻ, đăng xuất giữa chừng |
| `test/nfc/ndef_text_decoder_test.dart` | Text record UTF-8, UTF-16, record khác loại, payload hỏng |
| `test/app_test.dart` | Thiếu `API_BASE_URL` → lỗi cấu hình; chưa đăng nhập → màn đăng nhập |

---

## 7. Dựng môi trường

### 7.1 Yêu cầu

| Thành phần | Phiên bản đang dùng |
|---|---|
| Flutter | 3.47.5 stable (Dart 3.13) |
| Android Gradle Plugin / Gradle | 9.1.0 / 9.3.1 |
| Android SDK Platform | **API 36** (đúng `platforms/android-36`, không phải 36.1) |
| NDK | 28.2.13676358 |
| `minSdk` | 26 (P-01) |

### 7.2 Cấu hình Android

| File | Thay đổi |
|---|---|
| `android/app/src/main/AndroidManifest.xml` | Quyền `NFC`, `INTERNET`; `android.hardware.nfc` `required="false"` để máy không có NFC vẫn cài được và app tự báo "dùng điện thoại khác". `CAMERA` do `mobile_scanner` tự khai báo |
| `android/app/src/debug/AndroidManifest.xml` | `usesCleartextTraffic="true"`: bản debug gọi gateway/mock bằng `http` qua IP LAN |
| `android/app/build.gradle.kts` | `minSdk = 26` |
| `android/gradle.properties` | `kotlin.incremental=false` (xem 7.3) |

### 7.3 Lỗi môi trường đã gặp

| Triệu chứng | Nguyên nhân | Cách sửa |
|---|---|---|
| VS Code tô đỏ `lib/`, `test/` ngay sau khi tạo project | Analyzer chạy trước khi có `.dart_tool/package_config.json` | `flutter pub get`, rồi *Dart: Restart Analysis Server* |
| `Android sdkmanager did not install NDK 28.2.13676358` | Gradle chạy trong môi trường bị chặn ghi vào thư mục SDK | Chạy build từ terminal thường; NDK đã cài đủ |
| `Could not determine the dependencies of task ':app:compileDebugJavaWithJavac'` / `Cannot query the value of this provider` | `platforms/android-36` cài thiếu, không có `android.jar` | Cài lại API 36 (lệnh dưới). Cài 36.1 từ SDK Manager **không** sửa được |
| `Could not close incremental caches ... caches-jvm` ở `:package_info_plus`, `:mobile_scanner` | Project ở ổ `D:`, pub cache ở ổ `C:`; cache incremental của Kotlin không xử lý được đường dẫn khác ổ | `kotlin.incremental=false` trong `android/gradle.properties` |
| Mock server báo `Only one usage of each socket address` | Còn một mock server khác đang chạy ở cổng 8090 | Tắt terminal cũ, hoặc `Get-NetTCPConnection -LocalPort 8090` để tìm tiến trình |

Cài lại API 36 (`sdkmanager` mới chuyển sang Android CLI, cú pháp dùng `/`; chạy trong PowerShell):

```powershell
$a = 'C:\Toolkits\Android\Sdk\cmdline-tools\latest\bin\android.exe'
& $a --sdk='C:\Toolkits\Android\Sdk' sdk remove platforms/android-36
& $a --sdk='C:\Toolkits\Android\Sdk' sdk install platforms/android-36
```

Hai cảnh báo còn lại khi build là vô hại: `nfc_manager` còn dùng Kotlin Gradle Plugin cũ, và `SDK XML version 4` (Android Studio mới hơn AGP).

---

## 8. Việc tiếp theo

| # | Việc | Ghi chú |
|---|---|---|
| N-01 | Chạy luồng mới trên máy thật với mock server, theo bảng ở mục 6.2 | Chưa chạy |
| N-02 | Nhóm chốt luồng mới và cập nhật Requirement, Software Design, Plan (mục 5) | Trước khi backend làm endpoint |
| N-03 | Backend làm 3 endpoint ở mục 3, chốt D-1 và D-6 | |
| N-04 | Chốt cách lưu dữ liệu cá nhân phía máy chủ (AC 54.6, mục 5) | |
| N-05 | Mua NTAG216 cho thẻ có ảnh | NTAG215 chỉ đủ ảnh rất nhỏ |
| N-06 | Bản release cho demo (GĐ 3) | Debug mới cho phép `http`; release dùng tunnel `https`, hoặc thêm cleartext cho release nếu nhóm chấp nhận |
| N-07 | M-01, M-02 trong CODE_STANDARD (CI, pre-commit cho `mobile/`) | CI cần `kotlin.incremental=false` nếu runner có pub cache khác ổ |

---

## 9. Lịch sử thay đổi

| Phiên bản | Ngày | Nội dung |
|---|---|---|
| v0.1 | 2026-10-16 | Tạo tài liệu: kiến trúc đã dựng, cấu hình Android, lỗi môi trường và cách sửa, mock server, cách test GĐ 1. Quét QR và đọc thẻ NFC chạy được trên máy thật |
| v0.2 | 2026-10-16 | Luồng mới: đăng nhập, nút Quét QR, thẻ `MK2` 11 trường có ảnh, máy chủ lưu tạm, màn xác nhận chỉ đọc, Lưu/Hủy. Hợp đồng API đề xuất (3 endpoint, `SESSION_NOT_OWNED`). Mock server và `make_card`. Danh sách điểm khác tài liệu nhóm |

---

# Nhật ký

Từ đây tài liệu là nhật ký: mỗi lần có thay đổi thì **ghi thêm một mục mới ở cuối**, không sửa các phần phía trên. Phần nào phía trên đã lỗi thời thì mục mới ghi rõ nó thay cho phần đó.

## 2026-10-16 — Đổi tên thành DEV_LOGS; nội dung thẻ chuyển sang JSON

**Tài liệu**
- `DEV_NOTES.md` đổi tên thành `DEV_LOGS.md`. Nội dung v0.1, v0.2 phía trên giữ nguyên.
- Đã sửa các liên kết tới file này trong `NFC_CARD_GUIDE.md` (v0.3) và `CODE_STANDARD.md` (v0.4).

**Nội dung thẻ** (thay cho định dạng `MK2` ở các mục 1, 2, 3.2 phía trên; chi tiết ở NFC_CARD_GUIDE v0.3 mục 2)

Thẻ chứa một NDEF Text record là JSON object, khóa `snake_case`:

```json
{"id_number":"000000000001","full_name":"NGUYEN VAN AN","date_of_birth":"1990-01-01","sex":"Nam","nationality":"Viet Nam","place_of_birth":"Tinh Lam Dong","place_of_residence":"So 1 Duong Thu Nghiem, Phuong Sai Gon, TP Lam Dong","date_of_issue":"2024-01-01","date_of_expiry":"2030-01-01"}
```

| So với `MK2` | Thay đổi |
|---|---|
| Dạng | Dòng ngăn bằng `\|` → JSON object |
| Nhận diện thẻ | Tiền tố `MK2\|` → Text record là JSON có khóa `id_number` |
| Ảnh chân dung | **Bỏ** |
| Nơi đăng ký khai sinh | Thay bằng **nơi thường trú** (`place_of_residence`) |
| Ngày | `ddMMyyyy` → `yyyy-MM-dd` |
| Giới tính | Khóa `sex`; nhận `Nam`, `Nu`, `Nữ` (thẻ viết không dấu) |
| Dung lượng | Thẻ mẫu cần 303 byte → **NTAG215 là đủ**, không cần NTAG216 (thay N-05 ở mục 8 phía trên) |

**API gửi máy chủ** (thay body ở mục 3.2 phía trên)

Vẫn dùng `camelCase` như các endpoint khác của backend (quyết định D-1). Body `POST .../nfc-sessions/{sessionId}/card`, và `card` trong phản hồi `PENDING_CONFIRMATION`:

```json
{
  "idNumber": "000000000001",
  "fullName": "NGUYEN VAN AN",
  "dateOfBirth": "1990-01-01",
  "sex": "MALE",
  "nationality": "Viet Nam",
  "placeOfBirth": "Tinh Lam Dong",
  "placeOfResidence": "So 1 Duong Thu Nghiem, Phuong Sai Gon, TP Lam Dong",
  "dateOfIssue": "2024-01-01",
  "dateOfExpiry": "2030-01-01",
  "appVersion": "1.0.0+1"
}
```

Đổi tên trường: `gender` → `sex`, `issueDate` → `dateOfIssue`, `expiryDate` → `dateOfExpiry`. Bỏ `birthRegistrationPlace`, `photoBase64`. Thêm `placeOfResidence`. Các endpoint, `status`, `reasonCode` không đổi.

> Câu hỏi cho nhóm: thẻ dùng `snake_case`, API dùng `camelCase`. Nếu muốn API dùng nguyên khóa của thẻ thì chỉ cần sửa `identity_card_json.dart` và mock server.

**Code**

| File | Thay đổi |
|---|---|
| `domain/identity_card.dart` | 9 trường mới; `Gender` → `Sex`; bỏ `photo` |
| `domain/card_parser.dart` | Đọc JSON; `pickCardText` chọn record là JSON có `id_number`; khóa lạ bị bỏ qua |
| `data/identity_card_json.dart` | Tên trường API mới |
| `presentation/widgets/card_details.dart` | Bỏ ảnh; thêm "Nơi thường trú"; "Ngày hết hạn" → "Có giá trị đến" (như trên CCCD) |
| `core/strings.dart` | Nhãn trường theo trên |
| `tool/mock_server.dart` | Kiểm trường mới |
| `tool/make_card.dart`, `tool/card_sample.json` | Nhận thẳng JSON của thẻ, rút về một dòng, báo số byte |

**Kiểm tra**
- `flutter analyze` sạch; `flutter test` **49 test** pass. Parser có thêm ca: JSON hỏng, thiếu trường, sai kiểu, khóa lạ, `Nu`/`Nữ`.
- Đã gọi mock server bằng curl: gửi thẻ → `PENDING_CONFIRMATION` với đủ 9 trường → Lưu → `VERIFIED`.
- **Chưa chạy trên máy thật.** Thẻ đã ghi theo `MK2` phải ghi lại theo JSON.

**Việc tiếp theo** (thay mục 8 phía trên)

| # | Việc |
|---|---|
| N-01 | Ghi lại thẻ theo JSON; chạy luồng trên máy thật với mock server |
| N-02 | Nhóm chốt luồng và cập nhật Requirement, Software Design, Plan (mục 5 phía trên; nay không còn ảnh, có thêm nơi thường trú) |
| N-03 | Backend làm 3 endpoint; chốt `camelCase` hay `snake_case` cho API |
| N-04 | Chốt cách máy chủ lưu dữ liệu cá nhân (AC 54.6) |
| N-06, N-07 | Như mục 8 phía trên |
