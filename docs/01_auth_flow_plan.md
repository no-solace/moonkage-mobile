# Kế hoạch xử lý Luồng 1: Đăng nhập & Ghi nhớ phiên (Auth & Remember Me Plan)

> **Trạng thái:** ✅ ĐÃ HOÀN THÀNH (100% Tests Pass, 0 Lint Issues)
> **Mục tiêu:** Hoàn thiện luồng xác thực đăng nhập: hỗ trợ tính năng **Ghi nhớ đăng nhập (Remember Me)** với bảo mật cao qua `flutter_secure_storage`, xử lý linh hoạt phản hồi API từ Backend, và nâng cấp trải nghiệm người dùng (UX) trên giao diện.

---

## 1. Định hướng bảo mật & Lưu trữ (Security & Storage Design)

* [x] **Lưu trữ an toàn bằng `flutter_secure_storage`:**
  * Sử dụng `flutter_secure_storage` (mã hóa cấp phần cứng qua **Android Keystore** / iOS Keychain) để lưu Access Token và `fullName` khi người dùng bật "Ghi nhớ đăng nhập".
  * Dữ liệu thẻ CCCD **tuyệt đối không lưu xuống bộ nhớ** (tuân thủ `CODE_STANDARD.md`).
* [x] **Cơ chế Đăng xuất / Hết hạn:**
  * Khi bấm "Đăng xuất" hoặc API trả về lỗi `401 Unauthorized`: Xóa sạch token trong SecureStorage và reset phiên trên RAM.
* [x] **Tự động đăng nhập (Auto-login):**
  * Khi mở app: Tự động khôi phục token từ SecureStorage để vào thẳng Trang chủ (`/`), không bắt đăng nhập lại.

---

## 2. Kết quả triển khai chi tiết

### Bước 1: Thêm dependency & Xây dựng `TokenStorage` (Hoàn thành)

* Đã thêm `flutter_secure_storage: ^11.2.0` vào [pubspec.yaml](file:///d:/02.%20Project/moonkage-platform/mobile/pubspec.yaml).
* Đã tạo [lib/core/auth/token_storage.dart](file:///d:/02.%20Project/moonkage-platform/mobile/lib/core/auth/token_storage.dart) với các hàm: `saveSession`, `readSession`, `clearSession`.

### Bước 2: Tích hợp vào `SessionNotifier` & Khởi động App (Hoàn thành)

* Cập nhật [lib/core/auth/session_notifier.dart](file:///d:/02.%20Project/moonkage-platform/mobile/lib/core/auth/session_notifier.dart): `signIn(session, {rememberMe})`, `signOut()` xóa storage.
* Cập nhật [lib/main.dart](file:///d:/02.%20Project/moonkage-platform/mobile/lib/main.dart): Nạp sẵn `initialSession` trước khi render app để tránh giật màn hình.

### Bước 3: Khớp nối dữ liệu linh hoạt phía Client (Hoàn thành)

* Cập nhật [lib/features/auth/data/auth_api.dart](file:///d:/02.%20Project/moonkage-platform/mobile/lib/features/auth/data/auth_api.dart):
  * Đọc token từ cả `token` hoặc `accessToken`.
  * Hỗ trợ response phẳng lẫn bọc trong `data` / `result`.
  * Fallback `fullName` về `username` nếu backend không trả về.

### Bước 4: Nâng cấp trải nghiệm giao diện (Hoàn thành)

* Cập nhật [lib/features/auth/presentation/login_screen.dart](file:///d:/02.%20Project/moonkage-platform/mobile/lib/features/auth/presentation/login_screen.dart):
  * Thêm checkbox "Ghi nhớ đăng nhập" (mặc định chọn `true`).
  * Nút con mắt bật/tắt hiển thị mật khẩu (`IconButton`).
  * Tự động hạ bàn phím (`FocusScope.unfocus()`) khi bấm đăng nhập.
  * Vô hiệu hóa các trường khi đang submitting.
  * Tự động xóa thông báo lỗi khi người dùng bắt đầu gõ lại.

### Bước 5: Kiểm thử tự động (Hoàn thành)

* Đã bổ sung bộ test:
  * [test/core/auth/session_notifier_test.dart](file:///d:/02.%20Project/moonkage-platform/mobile/test/core/auth/session_notifier_test.dart): Test Remember Me lưu/xóa/khôi phục token.
  * [test/features/auth/data/auth_api_test.dart](file:///d:/02.%20Project/moonkage-platform/mobile/test/features/auth/data/auth_api_test.dart): Test parse DTO linh hoạt (`token`, `accessToken`, `data`).
  * [test/features/auth/presentation/login_screen_test.dart](file:///d:/02.%20Project/moonkage-platform/mobile/test/features/auth/presentation/login_screen_test.dart): Test UI form, nút ẩn/hiện mật khẩu, checkbox rememberMe.
  * [test/features/auth/presentation/login_notifier_test.dart](file:///d:/02.%20Project/moonkage-platform/mobile/test/features/auth/presentation/login_notifier_test.dart): Test flow login, clear error.
* **Kết quả:** `flutter analyze` 0 lỗi, **70/70 tests passed**.
