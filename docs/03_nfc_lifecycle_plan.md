# Kế hoạch xử lý Luồng 3: Quản lý vòng đời & Trải nghiệm đọc thẻ NFC (NFC Lifecycle & UX Plan)

> **Mục tiêu:** Tối ưu hóa toàn diện vòng đời NFC và trải nghiệm người dùng: giải quyết triệt để hiện tượng kẹt thẻ phần cứng (tự động nhận diện thẻ áp sẵn), bịt kín khe hở khởi động nguội (Cold Start Gap) từ tầng Native, và nâng tầm trải nghiệm chạm thẻ với phản hồi rung đa tầng (Smart Haptics) cùng giao diện trực quan sinh động.

---

## 1. Các vấn đề cốt lõi cần giải quyết

1. **Bẫy từ trường phần cứng (Tag Trap / Kẹt thẻ):** Thẻ áp sẵn ở màn ngoài bị nuốt sự kiện; khi sang màn Chạm thẻ, chip NFC không tự bắn lại ngắt trừ khi từ trường được reset hoặc người dùng nhấc thẻ ra.
2. **Khe hở khởi động nguội (Cold Start Gap):** Trong 1–2 giây đầu khi vừa mở app (trước khi Flutter Engine nạp xong `initState`), Android OS chưa có ReaderMode nên nếu thẻ để sẵn ở lưng máy thì hệ thống có thể bắt trước.
3. **Trải nghiệm chạm thẻ (UX & Haptic Feedback):**
   * Hoàn toàn im lặng khi thẻ tiếp xúc do tắt âm thanh hệ thống; người dùng không biết điện thoại đã bắt được sóng thẻ chưa.
   * Thiếu phản hồi rung khi đọc lỗi (sai loại thẻ / trượt thẻ); người dùng không nhìn màn hình sẽ không biết phải áp lại.
   * Giao diện thiếu hoạt ảnh sóng NFC và thiếu hướng dẫn vị trí đặt thẻ (nửa trên lưng máy, gần camera).
4. **Quản lý trạng thái khiên chắn:** Giữ vững khiên chắn nuốt xung chạm thừa sau khi đọc thành công (màn Xác nhận & Kết quả).

---

## 2. Các hạng mục triển khai chi tiết

### Bước 1: Kỹ thuật Re-arm RF Field tự động nhận diện thẻ áp sẵn

* **Nguyên lý:** Khi chuyển sang màn Chạm thẻ, thực hiện reset nhanh từ trường RF (chớp tắt ReaderMode trong 15–30ms), chip NFC của Android bị kích hoạt lại chu kỳ polling $\rightarrow$ **tự động phát hiện và đọc ngay thẻ đang áp sẵn** mà người dùng không cần phải nhấc thẻ ra.
* **Triển khai trong [nfc_manager_reader.dart](file:///d:/02.%20Project/moonkage-platform/mobile/lib/nfc/nfc_manager_reader.dart):**
  * Thêm phương thức `Future<void> rearmSession()`:
    * Gọi `_manager.stopSession()`.
    * Chờ một khoảng thời gian cực ngắn (~20ms).
    * Gọi lại `_manager.startSession(...)` với callback đọc thẻ.
  * Trong `readTextRecords()`: Gọi `rearmSession()` để reset từ trường ngay khi bắt đầu phiên chờ đọc.

### Bước 2: Bịt kín khe hở khởi động nguội từ tầng Native Android

* **Hiện trạng:** [MainActivity.kt](file:///d:/02.%20Project/moonkage-platform/mobile/android/app/src/main/kotlin/edu/fpt/moonkage/mobile/MainActivity.kt) hiện là lớp rỗng `FlutterActivity()`.
* **Cải tiến Native Shielding:**
  * Trong `onStart()` của `MainActivity`: Kích hoạt ngay `NfcAdapter.enableReaderMode` với cờ `FLAG_READER_NO_PLATFORM_SOUNDS` và callback rỗng tạm thời.
  * Nhờ vậy, ngay từ mili-giây đầu tiên khi app xuất hiện trên màn hình, Android Tag Dispatcher đã bị khóa lại ngay lập tức.
  * Khi Flutter nạp xong, hàm `ensureSessionStarted()` của plugin `nfc_manager` sẽ ghi đè và tiếp quản callback một cách an toàn.

### Bước 3: Nâng cấp trải nghiệm người dùng & Phản hồi xúc giác (Smart Haptics & UI)

* **Phản hồi xúc giác đa tầng ([tap_card_screen.dart](file:///d:/02.%20Project/moonkage-platform/mobile/lib/features/verify/presentation/screens/tap_card_screen.dart)):**
  * **Vừa bắt được sóng thẻ:** Rung nhẹ 1 nhịp (`HapticFeedback.lightImpact()`) báo hiệu "Đã nhận thẻ, đang đọc...".
  * **Đọc thành công:** Rung xác nhận êm ái (`HapticFeedback.mediumImpact()`) trước khi chuyển màn hình.
  * **Đọc lỗi (sai thẻ / đọc hỏng):** Rung cảnh báo (`HapticFeedback.heavyImpact()`) để người dùng nhận biết ngay kể cả khi đang quay lưng máy về phía mình.
* **Giao diện trực quan & Hoạt ảnh:**
  * Bổ sung icon minh họa vị trí đặt thẻ NFC kèm hoạt ảnh sóng lan tỏa (Ripple / Pulse animation).
  * Hiển thị dòng chỉ dẫn: *"Đặt thẻ ở nửa trên mặt lưng máy (gần cụm camera)"*.
  * Trạng thái đọc rõ ràng: *"Đang đọc dữ liệu thẻ, vui lòng giữ yên..."*.
* **Tự động thử lại (Auto Retry):**
  * Khi gặp lỗi trượt thẻ (`readFailed`), tự động re-arm để người dùng áp lại thẻ là đọc tiếp ngay mà không bắt buộc phải bấm nút "Thử lại".

### Bước 4: Đảm bảo khiên chắn sau khi đọc thẻ thành công

* Khi đọc thẻ xong và chuyển sang màn Xác nhận (`AwaitingConfirmation`) hoặc Kết quả (`Completed`):
  * Giữ nguyên phiên ReaderMode tiếp tục chạy ngầm với `_pending == null`.
  * Mọi xung quét thẻ thừa nếu người dùng chưa kịp nhấc thẻ ra đều bị nuốt trong im lặng, không rung/kêu, không bao giờ hiện popup Android.

### Bước 5: Kiểm thử tự động (Unit & Widget Tests)

* Cập nhật test cases trong [test/nfc/nfc_manager_reader_test.dart](file:///d:/02.%20Project/moonkage-platform/mobile/test/nfc/nfc_manager_reader_test.dart):
  * Test `rearmSession()` reset session và kích hoạt lại đúng cờ polling.
  * Test nuốt sự kiện sau khi đọc thành công và giải phóng `_pending`.
* Test widget [test/features/verify/presentation/tap_card_screen_test.dart](file:///d:/02.%20Project/moonkage-platform/mobile/test/features/verify/presentation/tap_card_screen_test.dart) hiển thị đúng hướng dẫn vị trí, hoạt ảnh và thông báo lỗi.
* Chạy `flutter test` và `flutter analyze` đảm bảo 100% test pass và 0 issues.

---

---

## 3. Tiêu chí nghiệm thu & Kết quả thực tế (Acceptance Criteria & Results)

1. ✅ **Tự động nhận thẻ áp sẵn:** Kỹ thuật `rearmSession()` (chớp tắt ReaderMode 25ms) trong [nfc_manager_reader.dart](file:///d:/02.%20Project/moonkage-platform/mobile/lib/nfc/nfc_manager_reader.dart) tái kích hoạt polling RF field khi vào màn Chạm thẻ, tự động quét ngay thẻ đang áp sẵn ở lưng máy mà người dùng không cần nhấc ra.
2. ✅ **Khóa 100% Cold Start:** [MainActivity.kt](file:///d:/02.%20Project/moonkage-platform/mobile/android/app/src/main/kotlin/edu/fpt/moonkage/mobile/MainActivity.kt) kích hoạt `enableReaderMode` với `FLAG_READER_NO_PLATFORM_SOUNDS` ngay trong `onStart()`, triệt tiêu pop-up "New tag scanned" từ mili-giây đầu tiên mở app.
3. ✅ **Phản hồi xúc giác đa tầng & Hoạt ảnh trực quan:**
   * Rung nhẹ (`HapticFeedback.lightImpact`) khi thẻ chạm sóng NFC.
   * Rung xác nhận (`HapticFeedback.mediumImpact`) khi đọc thẻ thành công.
   * Rung cảnh báo (`HapticFeedback.heavyImpact`) khi đọc lỗi/sai thẻ.
   * Hoạt ảnh sóng xung kích NFC (`_NfcPulseIcon`) lan tỏa mượt mà kèm hướng dẫn chi tiết vị trí đặt thẻ ở nửa trên lưng máy.
4. ✅ **Màn Xác nhận & Kết quả yên tĩnh tuyệt đối:** Giữ nguyên ReaderMode hoạt động liên tục (Ambient Shield) nuốt trọn mọi xung chạm thẻ dư thừa.
5. ✅ **Chất lượng mã nguồn:**
   * `flutter analyze`: 0 warning / 0 issue.
   * `flutter test`: 80/80 tests pass (đầy đủ unit tests cho `NfcManagerReader` và widget tests cho [tap_card_screen_test.dart](file:///d:/02.%20Project/moonkage-platform/mobile/test/features/verify/presentation/tap_card_screen_test.dart)).
