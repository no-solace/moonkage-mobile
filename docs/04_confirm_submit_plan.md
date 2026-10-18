# Kế hoạch xử lý Luồng 4: Xác nhận thông tin & Gửi lên Server (Confirm & Submit Plan)

> **Mục tiêu:** Nâng cấp toàn diện màn hình Xác nhận thông tin ([ConfirmScreen](file:///d:/02.%20Project/moonkage-platform/mobile/lib/features/verify/presentation/screens/confirm_screen.dart)) và màn hình Kết quả ([ResultScreen](file:///d:/02.%20Project/moonkage-platform/mobile/lib/features/verify/presentation/screens/result_screen.dart)), đảm bảo quyền riêng tư ở nơi công cộng (Data Masking), trải nghiệm gửi dữ liệu mượt mà (Loading Overlay), giao diện kết quả sinh động kèm phản hồi rung Haptic, và tuân thủ nghiêm ngặt nguyên tắc **không hardcode** cùng kiểm thử tự động 100%.

---

## 1. Các vấn đề cốt lõi cần giải quyết

1. **Bảo vệ quyền riêng tư nơi công cộng (Privacy & Data Masking):**
   * Số CCCD 12 số hiện đang hiển thị đầy đủ, dễ bị người xung quanh nhìn thấy khi thao tác ở nơi công cộng.
   * Cần có cơ chế che bớt số CCCD (ví dụ: `079 ••• ••• 123` hoặc `079******123`) kèm nút icon con mắt bật/tắt hiển thị toàn bộ.
2. **Trải nghiệm trạng thái Lưu (Loading Overlay UX):**
   * Khi người dùng bấm "Lưu", nút bấm chỉ đổi text thành *"Đang lưu..."*.
   * Cần bổ sung Loading Overlay mờ nhẹ trên toàn màn hình với spinner tiến trình rõ ràng, ngăn chặn hoàn toàn việc chạm nhầm trong lúc đang mã hóa JWE và gửi request.
3. **Nâng cấp Màn hình Kết quả (ResultScreen Visuals & Smart Haptics):**
   * Màn hình kết quả hiện tại chỉ hiển thị text đơn giản, thiếu sinh động.
   * Cần bổ sung icon đồ họa lớn với màu sắc nhận diện trực quan:
     * **Thành công:** Icon tích xanh tròn (`Icons.check_circle_rounded`) với màu `colorScheme.primary` / `Colors.green`.
     * **Bị từ chối:** Icon cảnh báo đỏ (`Icons.cancel_rounded` hoặc `Icons.error_outline`) với màu `colorScheme.error`.
   * Thêm phản hồi rung Haptic khi vào màn kết quả:
     * Rung êm ái (`HapticFeedback.mediumImpact`) khi thành công.
     * Rung cảnh báo (`HapticFeedback.heavyImpact`) khi bị từ chối nghiệp vụ.
4. **Nguyên tắc không Hardcode chuỗi hiển thị:**
   * Mọi nhãn, thông báo, tooltip mới (ví dụ: *"Ẩn số CCCD"*, *"Hiện số CCCD"*) đều phải được khai báo tập trung trong [lib/core/strings.dart](file:///d:/02.%20Project/moonkage-platform/mobile/lib/core/strings.dart).
5. **Kiểm thử tự động toàn diện:**
   * Viết widget test cho [ConfirmScreen](file:///d:/02.%20Project/moonkage-platform/mobile/lib/features/verify/presentation/screens/confirm_screen.dart) (kiểm tra hiển thị dữ liệu thẻ, ẩn/hiện số CCCD, bấm Hủy, bấm Lưu, hiển thị lỗi mạng).
   * Viết widget test cho [ResultScreen](file:///d:/02.%20Project/moonkage-platform/mobile/lib/features/verify/presentation/screens/result_screen.dart) (kiểm tra trạng thái Thành công `Verified` và Thất bại `Rejected` kèm lý do/số lần thử).

---

## 2. Các hạng mục triển khai chi tiết

### Bước 1: Khai báo chuỗi hiển thị trong [strings.dart](file:///d:/02.%20Project/moonkage-platform/mobile/lib/core/strings.dart)

* Bổ sung các hằng số:
  * `static const showIdNumber = 'Hiện số CCCD';`
  * `static const hideIdNumber = 'Ẩn bớt số CCCD';`

### Bước 2: Nâng cấp [CardDetails](file:///d:/02.%20Project/moonkage-platform/mobile/lib/features/verify/presentation/widgets/card_details.dart) với tính năng Ẩn/Hiện số CCCD

* Cho phép người dùng chuyển đổi giữa chế độ che số CCCD (masking: hiển thị 3 số đầu, che 6 số giữa bằng dấu sao/chấm tròn, hiển thị 3 số cuối: `079 ••• ••• 456`) và hiển thị đầy đủ.
* Đặt nút icon con mắt (`Icons.visibility_outlined` / `Icons.visibility_off_outlined`) ngay cạnh trường Số CCCD.

### Bước 3: Nâng cấp [ConfirmScreen](file:///d:/02.%20Project/moonkage-platform/mobile/lib/features/verify/presentation/screens/confirm_screen.dart) với Loading Overlay

* Khi `state.saving == true`:
  * Hiển thị overlay phủ mờ mờ trên body kèm `CircularProgressIndicator` và dòng chữ `Strings.saving`.
  * Giữ nguyên khóa PopScope để ngăn người dùng back khi đang gửi.
  * Giữ nguyên cơ chế retry mạng an toàn: khi gặp `AppFailure`, overlay tự tắt, thông báo lỗi đỏ hiển thị và người dùng bấm "Lưu" lại được ngay.

### Bước 4: Nâng cấp [ResultScreen](file:///d:/02.%20Project/moonkage-platform/mobile/lib/features/verify/presentation/screens/result_screen.dart) với Visuals & Smart Haptics

* Thêm hiệu ứng rung Haptic khi màn hình được tạo:
  * `Verified`: rung `HapticFeedback.mediumImpact()`.
  * `Rejected`: rung `HapticFeedback.heavyImpact()`.
* Bổ sung Icon đồ họa lớn (size 72) ở đầu trang:
  * Thành công: Icon tích tròn màu xanh `Colors.green` hoặc `colorScheme.primary`.
  * Thất bại: Icon dấu X tròn màu đỏ `colorScheme.error`.
* Bố cục thẻ hiển thị thông tin kết quả rõ ràng, phân cấp thị giác hiện đại (Material 3).

### Bước 5: Viết Unit & Widget Tests

* Tạo [test/features/verify/presentation/confirm_screen_test.dart](file:///d:/02.%20Project/moonkage-platform/mobile/test/features/verify/presentation/confirm_screen_test.dart):
  * Test hiển thị đúng 9 trường thông tin CCCD.
  * Test tính năng ẩn/hiện số CCCD (masking).
  * Test bấm "Hủy" điều hướng về Home.
  * Test bấm "Lưu" gọi `confirm()`.
  * Test hiển thị thông báo lỗi mạng khi có `failure`.
* Tạo [test/features/verify/presentation/result_screen_test.dart](file:///d:/02.%20Project/moonkage-platform/mobile/test/features/verify/presentation/result_screen_test.dart):
  * Test trạng thái `Verified` hiển thị đúng icon, lời chúc mừng và nút Xong.
  * Test trạng thái `Rejected` hiển thị lý do từ chối, số lần thử còn lại, thời gian mở khóa.
* Chạy `flutter test` và `flutter analyze` đảm bảo 100% test pass và 0 issues.

---

## 3. Tiêu chí nghiệm thu & Kết quả thực tế (Acceptance Criteria & Results)

1. ✅ **Bảo vệ quyền riêng tư (Data Masking):** Số CCCD mặc định được che 6 số giữa (`079 ••• ••• 890`) trong [CardDetails](file:///d:/02.%20Project/moonkage-platform/mobile/lib/features/verify/presentation/widgets/card_details.dart); có nút icon con mắt bật/tắt xem toàn bộ số CCCD an toàn.
2. ✅ **Giao diện Lưu an toàn (Loading Overlay):** Khi bấm Lưu, [ConfirmScreen](file:///d:/02.%20Project/moonkage-platform/mobile/lib/features/verify/presentation/screens/confirm_screen.dart) hiển thị lớp phủ mờ mịn trên toàn màn hình kèm `CircularProgressIndicator` và `Strings.saving`, khóa tương tác tránh chạm nhầm, giữ nguyên cơ chế retry mạng khi có sự cố.
3. ✅ **Màn hình Kết quả trực quan & Smart Haptics:** [ResultScreen](file:///d:/02.%20Project/moonkage-platform/mobile/lib/features/verify/presentation/screens/result_screen.dart) có icon đồ họa lớn nhận diện rõ trạng thái (Tích tròn xanh thành công / Dấu X tròn đỏ thất bại), kèm phản hồi rung Haptic tương ứng (`mediumImpact` / `heavyImpact`) và thẻ lý do từ chối chi tiết.
4. ✅ **Tuyệt đối không hardcode:** 100% chuỗi hiển thị được khai báo trong [Strings](file:///d:/02.%20Project/moonkage-platform/mobile/lib/core/strings.dart).
5. ✅ **Chất lượng kiểm thử:**
   * `flutter analyze`: 0 warning / 0 issue.
   * `flutter test`: 87/87 tests pass 100% (bao gồm widget tests toàn diện cho [confirm_screen_test.dart](file:///d:/02.%20Project/moonkage-platform/mobile/test/features/verify/presentation/confirm_screen_test.dart) và [result_screen_test.dart](file:///d:/02.%20Project/moonkage-platform/mobile/test/features/verify/presentation/result_screen_test.dart)).
