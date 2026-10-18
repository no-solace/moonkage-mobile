# Kế hoạch Luồng 5: Tinh chỉnh mã nguồn, Dọn dẹp Code thừa & Chuẩn hóa Docstrings (Code Cleanup & Refactor Plan)

> **Mục tiêu:** Rà soát và loại bỏ các thành phần mã nguồn dư thừa (Dead Code / Unused States) còn sót lại từ thiết kế 2-step cũ, chuẩn hóa các docstring/chú thích code bị sai lệch sau 4 kế hoạch nâng cấp, và duy trì chất lượng kiểm thử tự động 100% pass với 0 cảnh báo linter.

---

## 1. Các vấn đề cốt lõi cần giải quyết

1. **Dead State `Submitting` trong State Machine:**
   * Trong thiết kế Software Design D-20, app quét thẻ xong sẽ hiển thị ngay tại máy (`AwaitingConfirmation`), và chỉ gửi lên máy chủ khi người dùng bấm Lưu (`AwaitingConfirmation(saving: true)`).
   * Lớp `Submitting` trong [verify_flow_state.dart](file:///d:/02.%20Project/moonkage-platform/mobile/lib/features/verify/presentation/verify_flow_state.dart) không còn nơi nào phát ra (`emit`), dẫn đến nhánh xử lý `Submitting() => ...` trong [tap_card_screen.dart](file:///d:/02.%20Project/moonkage-platform/mobile/lib/features/verify/presentation/screens/tap_card_screen.dart) và chuỗi `Strings.submitting` trở thành code thừa.
2. **Docstrings & Chú thích sai lệch hiện trạng:**
   * [auth_session.dart](file:///d:/02.%20Project/moonkage-platform/mobile/lib/core/auth/auth_session.dart): Vẫn ghi *"Chỉ giữ trong bộ nhớ: tắt app là phải đăng nhập lại"*, trong khi từ Kế hoạch 01 đã có [SecureTokenStorage](file:///d:/02.%20Project/moonkage-platform/mobile/lib/core/auth/token_storage.dart) lưu an toàn vào Android Keystore và tự khôi phục phiên khi mở lại app.
   * [verify_flow_state.dart](file:///d:/02.%20Project/moonkage-platform/mobile/lib/features/verify/presentation/verify_flow_state.dart): Chú thích của `AwaitingConfirmation` vẫn ghi *"Máy chủ đã lưu tạm [card]"*, trái với nguyên tắc Zero Server Footprint của D-20 (dữ liệu thẻ chỉ nằm trong RAM của app, chưa gửi lên máy chủ).
3. **Làm rõ nhánh kết quả legacy `PendingConfirmation`:**
   * Thêm chú thích làm rõ `PendingConfirmation` trong [verify_outcome.dart](file:///d:/02.%20Project/moonkage-platform/mobile/lib/features/verify/domain/verify_outcome.dart) và [session_result_response.dart](file:///d:/02.%20Project/moonkage-platform/mobile/lib/features/verify/data/session_result_response.dart) là tàn dư của API 2-step cũ, chỉ giữ lại để tương thích ngược nếu backend mock/staging cũ trả về.
4. **Kiểm thử tự động đồng bộ:**
   * Cập nhật test cases trong [tap_card_screen_test.dart](file:///d:/02.%20Project/moonkage-platform/mobile/test/features/verify/presentation/tap_card_screen_test.dart) để loại bỏ assertion cho `Submitting`.
   * Đảm bảo `flutter test` và `flutter analyze` tiếp tục đạt 100% pass với 0 cảnh báo.

---

## 2. Các hạng mục triển khai chi tiết

### Bước 1: Cập nhật chuẩn xác Docstrings

* **Trong [auth_session.dart](file:///d:/02.%20Project/moonkage-platform/mobile/lib/core/auth/auth_session.dart):**
  * Sửa lại: *"Phiên đăng nhập người dùng. Giữ trong bộ nhớ và có thể lưu an toàn qua SecureTokenStorage nếu người dùng bật Ghi nhớ đăng nhập."*
* **Trong [verify_flow_state.dart](file:///d:/02.%20Project/moonkage-platform/mobile/lib/features/verify/presentation/verify_flow_state.dart):**
  * Sửa lại chú thích `AwaitingConfirmation`: *"Thông tin thẻ đã giải mã trong RAM; hiển thị chỉ đọc tại máy để người dùng kiểm tra trước khi bấm Lưu (mã hóa JWE gửi máy chủ) hoặc Hủy (xóa RAM) theo Software Design D-20."*

### Bước 2: Dọn dẹp Dead Code `Submitting`

* **Trong [verify_flow_state.dart](file:///d:/02.%20Project/moonkage-platform/mobile/lib/features/verify/presentation/verify_flow_state.dart):**
  * Xóa lớp `final class Submitting extends VerifyFlowState`.
* **Trong [tap_card_screen.dart](file:///d:/02.%20Project/moonkage-platform/mobile/lib/features/verify/presentation/screens/tap_card_screen.dart):**
  * Xóa nhánh `Submitting() => ...` trong `switch (state)` và `switch (next)` của `ref.listen`.
* **Trong [strings.dart](file:///d:/02.%20Project/moonkage-platform/mobile/lib/core/strings.dart):**
  * Xóa hằng số `submitting` (chỉ giữ lại `saving` cho nút Lưu).

### Bước 3: Đồng bộ các bộ Test

* **Trong [test/features/verify/presentation/tap_card_screen_test.dart](file:///d:/02.%20Project/moonkage-platform/mobile/test/features/verify/presentation/tap_card_screen_test.dart):**
  * Xóa test case `hiển thị trạng thái đang gửi thông tin (Submitting)` vì state này đã bị loại bỏ.
* Chạy `flutter test` và `flutter analyze` đảm bảo toàn bộ test suites đều pass hoàn hảo.

### Bước 4: Cập nhật tài liệu nghiệm thu

* Cập nhật [analysis.md](file:///d:/02.%20Project/moonkage-platform/mobile/docs/analysis.md) và ghi nhận kết quả hoàn thành vào Kế hoạch 05.

---

## 3. Tiêu chí nghiệm thu & Kết quả thực tế (Acceptance Criteria & Results)

1. ✅ **Mã nguồn tinh gọn (Zero Dead State):** Đã loại bỏ hoàn toàn state `Submitting` trong [verify_flow_state.dart](file:///d:/02.%20Project/moonkage-platform/mobile/lib/features/verify/presentation/verify_flow_state.dart), xóa nhánh xử lý mồ côi trong [tap_card_screen.dart](file:///d:/02.%20Project/moonkage-platform/mobile/lib/features/verify/presentation/screens/tap_card_screen.dart) và xóa chuỗi không sử dụng trong [strings.dart](file:///d:/02.%20Project/moonkage-platform/mobile/lib/core/strings.dart).
2. ✅ **Tài liệu code trung thực & Chính xác:**
   * [auth_session.dart](file:///d:/02.%20Project/moonkage-platform/mobile/lib/core/auth/auth_session.dart): Đã cập nhật phản ánh đúng tính năng Remember Me qua Keystore [TokenStorage](file:///d:/02.%20Project/moonkage-platform/mobile/lib/core/auth/token_storage.dart).
   * [verify_flow_state.dart](file:///d:/02.%20Project/moonkage-platform/mobile/lib/features/verify/presentation/verify_flow_state.dart): Đã cập nhật chú thích `AwaitingConfirmation` phản ánh chuẩn xác cơ chế Zero Server Footprint (chỉ lưu trong RAM client, chưa gửi server).
   * [verify_outcome.dart](file:///d:/02.%20Project/moonkage-platform/mobile/lib/features/verify/domain/verify_outcome.dart): Đã đánh dấu rõ `PendingConfirmation` là nhánh legacy để tương thích ngược.
3. ✅ **Chất lượng kiểm thử:**
   * `flutter analyze`: 0 warning / 0 issue.
   * `flutter test`: 86/86 tests pass 100%.
