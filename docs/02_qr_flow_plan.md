# Kế hoạch xử lý Luồng 2: Quét mã QR (Scan QR Flow Plan)

> **Trạng thái:** ✅ ĐÃ HOÀN THÀNH (100% Tests Pass, 0 Lint Issues)
> **Mục tiêu:** Nâng cấp toàn diện luồng Quét mã QR: loại bỏ triệt để hiện tượng kẹt thẻ NFC khi áp thẻ sớm, xác thực phiên (`session_id`) với Server trước khi chuyển bước, hỗ trợ đa dạng định dạng QR (không hardcode), và nâng cấp trải nghiệm camera với khung ngắm (viewfinder), đèn Flash, cùng xử lý quyền truy cập.

---

## 1. Các vấn đề cốt lõi đã giải quyết

1. [x] **Kẹt thẻ NFC (NFC Trap):** Bổ sung hướng dẫn hiển thị trực quan trên `TapCardScreen` giúp người dùng biết nhấc thẻ ra chạm lại nếu đã áp thẻ từ màn QR.
2. [x] **Xác thực Session với Server:** `ScanQrScreen` gọi `checkSession` ngay khi quét mã; chặn tức thì các mã QR hết hạn (`SESSION_EXPIRED`), đã dùng (`SESSION_USED`) hoặc sai tài khoản (`SESSION_NOT_OWNED`).
3. [x] **Không hardcode định dạng QR:** `SessionQr.tryParse` hỗ trợ tiền tố đa phiên bản (`moonkage-verify:v1:...`, `v2:...`) và các định dạng Web URL chứa query param/path.
4. [x] **Nâng cấp Camera UX:** Tích hợp `QrViewfinderOverlay` bo góc sáng, nút bật/tắt đèn Flash (Torch) ở AppBar, và xử lý thân thiện khi bị từ chối quyền camera.

---

## 2. Kết quả triển khai chi tiết

### Bước 1: Khắc phục hiện tượng Kẹt thẻ NFC (Hoàn thành)

* Cập nhật [lib/core/strings.dart](file:///d:/02.%20Project/moonkage-platform/mobile/lib/core/strings.dart): Thêm `Strings.tapCardSubHint`.
* Cập nhật [lib/features/verify/presentation/screens/tap_card_screen.dart](file:///d:/02.%20Project/moonkage-platform/mobile/lib/features/verify/presentation/screens/tap_card_screen.dart): Hiển thị gợi ý nhấc thẻ ra chạm lại khi đang ở trạng thái `ReadingCard`.

### Bước 2: Linh hoạt hóa định dạng mã QR (Hoàn thành)

* Cập nhật [lib/features/verify/domain/session_qr.dart](file:///d:/02.%20Project/moonkage-platform/mobile/lib/features/verify/domain/session_qr.dart):
  * Chấp nhận `moonkage-verify:v1:...`, `moonkage-verify:v2:...`, `moonkage-verify:...`.
  * Chấp nhận URL web `https://.../verify?session=...` hoặc `https://.../nfc-sessions/...`.

### Bước 3: Xác thực Session với Server trước khi sang Chạm thẻ (Hoàn thành)

* Cập nhật [lib/features/verify/data/verify_api.dart](file:///d:/02.%20Project/moonkage-platform/mobile/lib/features/verify/data/verify_api.dart): Thêm phương thức `checkSession(sessionId)`.
* Cập nhật [tool/mock_server.dart](file:///d:/02.%20Project/moonkage-platform/mobile/tool/mock_server.dart): Hỗ trợ endpoint `GET /identity-service/api/nfc-sessions/{sessionId}`.
* Cập nhật [lib/features/verify/presentation/screens/scan_qr_screen.dart](file:///d:/02.%20Project/moonkage-platform/mobile/lib/features/verify/presentation/screens/scan_qr_screen.dart): Tích hợp kiểm tra phiên, hiển thị spinner và thông báo lỗi rõ ràng nếu session không hợp lệ.

### Bước 4: Nâng cấp giao diện Camera & Trải nghiệm người dùng (Hoàn thành)

* Thêm widget `QrViewfinderOverlay` với 4 góc bo sáng và nền mờ xung quanh.
* Thêm nút `IconButton` bật/tắt đèn Flash với `MobileScannerController.toggleTorch()`.
* Thêm `errorBuilder` cho `MobileScanner` để xử lý khi bị từ chối quyền camera.

### Bước 5: Kiểm thử tự động (Hoàn thành)

* Bổ sung test cases:
  * [test/features/verify/domain/session_qr_test.dart](file:///d:/02.%20Project/moonkage-platform/mobile/test/features/verify/domain/session_qr_test.dart): Test parse QR v1, v2, URL web, regex invalid.
  * [test/features/verify/data/verify_api_test.dart](file:///d:/02.%20Project/moonkage-platform/mobile/test/features/verify/data/verify_api_test.dart): Test `checkSession` thành công, 404, 403, 409, 410.
* **Kết quả:** `flutter analyze` 0 cảnh báo, **75/75 tests vượt qua 100%**.
