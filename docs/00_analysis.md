# Phân tích Hệ thống (Analysis)

## 1. Luồng đăng nhập (Auth Flow) — [Kế hoạch 01](01_auth_flow_plan.md) ✅ Đã xử lý

* **Ưu điểm:**
  * Quản lý state tốt (`Riverpod`), tự động chuyển màn hình khi đổi phiên (`GoRouter`).
  * Tự động đăng xuất khi gặp lỗi `401 Unauthorized`.
  * Chặn được pop-up NFC hệ thống ngay tại màn đăng nhập.

* **Đã cải tiến & hoàn thiện:**
  * [x] **Khớp nối Backend:** Đọc linh hoạt cả `token` / `accessToken`, hỗ trợ cả payload phẳng và bọc `data`/`result`.
  * [x] **Ghi nhớ đăng nhập (Remember Me):** Lưu an toàn qua `flutter_secure_storage` (Keystore), tự động đăng nhập khi mở lại app nếu đã tick.
  * [x] **UX:** Có nút ẩn/hiện mật khẩu; tự hạ bàn phím khi submit; disable input khi loading; tự xóa lỗi cũ khi gõ lại.

---

## 2. Luồng quét QR (Scan QR Flow) — [Kế hoạch 02](02_qr_flow_plan.md) ✅ Đã xử lý

* **Ưu điểm:**
  * Chỉ mở camera khi máy đã bật NFC.
  * Có cờ chống quét trùng lặp (`_accepted`).
  * Nuốt sự kiện thẻ nếu người dùng vô tình chạm thẻ lúc đang quét QR (không văng popup hệ thống).

* **Đã cải tiến & hoàn thiện:**
  * [x] **Khắc phục Kẹt thẻ NFC (NFC Trap):** Thêm gợi ý *"Nếu đã áp thẻ sẵn, vui lòng nhấc thẻ ra và chạm lại vào lưng máy"* trên màn Chạm thẻ.
  * [x] **Kiểm tra Session với Server:** Gọi `checkSession` ngay khi nhận diện QR; chặn ngay các mã QR hết hạn/sai tài khoản/đã dùng trước khi cho sang màn Chạm thẻ.
  * [x] **Không hardcode định dạng QR:** Hỗ trợ `moonkage-verify:v1:...`, `v2:...` và cả dạng đường dẫn Web URL (`?session=...`).
  * [x] **Camera UX:** Khung ngắm (Viewfinder Overlay) bo góc sáng, nút bật/tắt đèn Flash (Torch), xử lý thân thiện khi bị từ chối quyền Camera.

---

## 3. Luồng quản lý vòng đời & Trải nghiệm NFC (NFC Lifecycle & UX Flow) — [Kế hoạch 03](03_nfc_lifecycle_plan.md) ✅ Đã xử lý

### 3.1. Cơ chế vận hành (Ambient Shield & Re-arm)

* **1. Khóa từ tầng Native Android (Cold Start Shield):** Kích hoạt `enableReaderMode` với `FLAG_READER_NO_PLATFORM_SOUNDS` ngay trong `onStart()` của [MainActivity.kt](file:///d:/02.%20Project/moonkage-platform/mobile/android/app/src/main/kotlin/edu/fpt/moonkage/mobile/MainActivity.kt), triệt tiêu pop-up "New tag scanned" từ mili-giây đầu tiên khi app mở.
* **2. Khởi tạo toàn diện khi mở App:** Duy trì `ReaderMode` từ [app.dart](file:///d:/02.%20Project/moonkage-platform/mobile/lib/app.dart) với 3 cờ polling (`iso14443`, `iso15693`, `iso18092`) và `noPlatformSoundsAndroid: true`.
* **3. Tự động nhận diện thẻ áp sẵn (Re-arm RF Field):** Khi vào màn Chạm thẻ, hàm `rearmSession()` thực hiện chớp tắt ReaderMode trong 25ms, buộc chip NFC của Android kích hoạt lại chu kỳ polling $\rightarrow$ **tự động đọc ngay thẻ đang áp sẵn ở lưng máy** mà không bắt buộc người dùng phải nhấc thẻ ra.
* **4. Màn hình ngoài (Login, Home, Scan QR, Confirm, Result):** Nuốt mọi sự kiện thẻ trong im lặng, không văng popup hệ thống.
* **5. Khi Hủy / Rời màn Chạm thẻ (Cancel):** Chỉ hủy `_pending`, **tuyệt đối không gọi `stopSession()`** để tiếp tục duy trì khiên chắn nuốt xung chạm thừa.
* **6. Lifecycle Ứng dụng (Background / Resume / Exit):** Tự động `ensureSessionStarted(force: true)` khi resume; chỉ giải phóng phần cứng khi tắt app hoàn toàn (`dispose`).

### 3.2. Đã cải tiến & hoàn thiện (Resolved)

* [x] **Giải quyết triệt để Kẹt thẻ phần cứng:** Re-arm RF field quét ngay thẻ áp sẵn từ màn ngoài.
* [x] **Bịt kín 100% Cold Start Gap:** Khóa Tag Dispatcher từ `MainActivity.onStart()`.
* [x] **Phản hồi xúc giác đa tầng (Smart Haptics):** Rung nhẹ khi bắt đầu tiếp xúc thẻ, rung xác nhận khi thành công, rung cảnh báo khi lỗi/sai thẻ.
* [x] **Giao diện trực quan & Hoạt ảnh:** Hoạt ảnh sóng xung kích NFC lan tỏa liên tục (`_NfcPulseIcon`), chỉ dẫn đặt thẻ ở nửa trên lưng máy (gần camera), và icon cảnh báo trực quan khi đọc lỗi.
* [x] **Chất lượng kiểm thử:** Bổ sung unit tests cho `rearmSession` và widget tests toàn diện cho [tap_card_screen_test.dart](file:///d:/02.%20Project/moonkage-platform/mobile/test/features/verify/presentation/tap_card_screen_test.dart) (100% pass, 0 lint warnings).

---

## 4. Luồng xác nhận thông tin & Gửi lên Server (Confirm & Submit Flow) — [Kế hoạch 04](04_confirm_submit_plan.md) ✅ Đã xử lý

### 4.1. Cơ chế vận hành

* **1. Chuyển tiếp màn hình:** Sau khi [NfcManagerReader](file:///d:/02.%20Project/moonkage-platform/mobile/lib/nfc/nfc_manager_reader.dart) đọc và phân tích NDEF thành công, app rung xác nhận (`mediumImpact`) và chuyển sang [ConfirmScreen](file:///d:/02.%20Project/moonkage-platform/mobile/lib/features/verify/presentation/screens/confirm_screen.dart).
* **2. Hiển thị thông tin tại máy (Zero Server Footprint):** Hiển thị 9 trường CCCD dạng chỉ đọc. Toàn bộ dữ liệu nằm trong RAM thiết bị, chưa gửi bất kỳ byte nào lên server. Nếu người dùng bấm "Hủy" hoặc thoát, app tự giải phóng dữ liệu bộ nhớ và quay về Home mà không cần gọi API (không để lại rác trên server).
* **3. Mã hóa trường nhạy cảm E2EE (JWE Compact Token):** Khi bấm "Lưu", [JweCardEncryptor](file:///d:/02.%20Project/moonkage-platform/mobile/lib/features/verify/data/card_encryptor.dart) bọc 3 trường nhạy cảm nhất (`idNumber`, `dateOfBirth`, `placeOfResidence`) mã hóa bằng chuẩn `RSA-OAEP-256 + AES-256-GCM` tạo thành chuỗi JWE duy nhất `encryptedFields`.
* **4. Gửi kết quả lên Server:** Gọi `POST /nfc-sessions/{id}/card` gửi dữ liệu thường + `encryptedFields` + `appVersion` kèm `Authorization: Bearer <token>`.
* **5. Xử lý phản hồi:**
  * **Thành công (VERIFIED):** Chuyển sang màn Kết quả [ResultScreen](file:///d:/02.%20Project/moonkage-platform/mobile/lib/features/verify/presentation/screens/result_screen.dart).
  * **Bị từ chối nghiệp vụ (REJECTED):** Chuyển sang màn Kết quả với `reasonCode`, số lần thử còn lại và thời gian tạm khóa.
  * **Lỗi mạng / Timeout / 500:** Giữ nguyên toàn bộ thông tin thẻ trên màn hình Xác nhận, hiển thị dòng thông báo lỗi đỏ, cho phép người dùng bấm "Lưu" để thử lại mà không phải quét thẻ lại từ đầu.

### 4.2. Điểm mạnh (Strengths)

* **Bảo mật dữ liệu tuyệt đối (Zero Stale State & E2EE):** Không lưu tạm thẻ rác trên server; 3 trường định danh nhạy cảm được mã hóa JWE trước khi truyền qua mạng, an toàn cả khi qua các reverse proxy/log trung gian.
* **Khả năng tự phục hồi mạng (Retryable Resilience):** Sự cố mạng không làm mất dữ liệu đã quét, người dùng bấm thử lại trực tiếp.
* **Kiểm soát điều hướng an toàn (`PopScope`):** Khóa nút back vật lý và cử chỉ vuốt trong lúc đang gửi (`saving: true`), loại bỏ nguy cơ submit trùng lặp.
* **Duy trì Khiên chắn (Ambient Shield):** Giữ ReaderMode im lặng trên màn Xác nhận và Kết quả, không bị văng popup Android khi thẻ vẫn áp ở lưng máy.

### 4.3. Đã cải tiến & hoàn thiện (Resolved)

* [x] **Bảo vệ quyền riêng tư (Data Masking):** Số CCCD mặc định được che 6 số giữa (`079 ••• ••• 890`) trong [CardDetails](file:///d:/02.%20Project/moonkage-platform/mobile/lib/features/verify/presentation/widgets/card_details.dart); có nút icon con mắt bật/tắt xem toàn bộ số CCCD an toàn.
* [x] **Trải nghiệm Lưu an toàn (Loading Overlay):** [ConfirmScreen](file:///d:/02.%20Project/moonkage-platform/mobile/lib/features/verify/presentation/screens/confirm_screen.dart) hiển thị lớp phủ mờ mịn trên toàn màn hình kèm spinner tiến trình và `Strings.saving` khi `saving: true`, khóa tương tác tránh chạm nhầm.
* [x] **Nâng cấp Màn hình Kết quả (ResultScreen Visuals & Smart Haptics):** Bổ sung icon đồ họa lớn nhận diện rõ trạng thái (Tích tròn xanh thành công / Dấu X tròn đỏ thất bại), kèm phản hồi rung Haptic tương ứng (`mediumImpact` / `heavyImpact`) và thẻ hiển thị lý do từ chối chi tiết.
* [x] **Tuyệt đối không hardcode:** 100% chuỗi hiển thị được khai báo trong [Strings](file:///d:/02.%20Project/moonkage-platform/mobile/lib/core/strings.dart).
* [x] **Chất lượng kiểm thử:** Bổ sung widget tests toàn diện cho [confirm_screen_test.dart](file:///d:/02.%20Project/moonkage-platform/mobile/test/features/verify/presentation/confirm_screen_test.dart) và [result_screen_test.dart](file:///d:/02.%20Project/moonkage-platform/mobile/test/features/verify/presentation/result_screen_test.dart) (100% pass, 0 lint warnings).

---

## 5. Tinh chỉnh mã nguồn & Chuẩn hóa Docstrings (Code Cleanup & Refactor) — [Kế hoạch 05](05_code_cleanup_refactor_plan.md) ✅ Đã xử lý

### 5.1. Các vấn đề cần xử lý

* **1. Dead State `Submitting`:** Lớp `Submitting` trong `VerifyFlowState` không còn được phát ra trong thiết kế D-20; cần dọn dẹp khỏi State Machine, màn Chạm thẻ và test tương ứng.
* **2. Docstrings lỗi thời:** Cập nhật chú thích trong `AuthSession` (phản ánh Remember Me với Keystore) và `AwaitingConfirmation` (phản ánh Zero Server Footprint).
* **3. Làm rõ nhánh legacy:** Ghi chú rõ `PendingConfirmation` là nhánh fallback tương thích ngược của API 2-step cũ.

### 5.2. Đã cải tiến & hoàn thiện (Resolved)

* [x] **Dọn dẹp Dead Code:** Đã xóa class `Submitting` trong `VerifyFlowState`, xóa nhánh `Submitting` trong `TapCardScreen` và xóa chuỗi `Strings.submitting`.
* [x] **Chuẩn hóa Docstrings:** Đã sửa lại chú thích trong `AuthSession` (Remember Me) và `AwaitingConfirmation` (RAM-only D-20).
* [x] **Gắn nhãn Legacy:** Ghi rõ `PendingConfirmation` trong `VerifyOutcome` là nhánh tương thích ngược.
* [x] **Kiểm thử đồng bộ:** 86/86 tests pass 100%, `flutter analyze` 0 cảnh báo.
