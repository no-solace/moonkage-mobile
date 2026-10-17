# Hướng dẫn ghi thẻ NFC mẫu

| Mục | Giá trị |
|---|---|
| Phiên bản | v0.4 |
| Ngày cập nhật | 2026-10-17 |
| Dành cho | Thành viên nhóm chuẩn bị thẻ mẫu cho phát triển và demo |
| Dựa trên | Requirement v1.6 (FR-04, A-08), [DEV_LOGS.md](DEV_LOGS.md) |

Theo Requirement A-08, thẻ do người dùng tự có trước, nằm ngoài hệ thống; nền tảng không cấp thẻ. Việc ghi thẻ ở đây chỉ là chuẩn bị thẻ mẫu của nhóm. App Moonkage Verify chỉ đọc thẻ, không ghi. Thẻ được ghi bằng app **NFC Tools** (wakdev) trên Android. Tên nút có thể khác chút tùy phiên bản NFC Tools.

> Thẻ định dạng cũ (`MK1|...`, `MK2|...`) **không còn dùng được**: app sẽ báo "thẻ không đúng loại". Ghi lại theo mục 2.

---

## 1. Chuẩn bị

- Thẻ **NTAG215** (504 byte) hoặc NTAG216 (888 byte). Thẻ mẫu cần khoảng 300 byte; NTAG213 (144 byte) không đủ.
- Điện thoại Android có NFC, đã bật NFC: *Cài đặt → Kết nối → NFC*.
- Cài **NFC Tools** từ Google Play.
- Trên PC (không bắt buộc): Flutter SDK để chạy `tool/make_card.dart` kiểm nội dung trước khi ghi (mục 4).

## 2. Nội dung thẻ

Một NDEF **Text record** chứa một **JSON object**, viết trên một dòng:

```json
{"id_number":"000000000001","full_name":"NGUYEN VAN AN","date_of_birth":"1990-01-01","sex":"Nam","nationality":"Viet Nam","place_of_birth":"Tinh Lam Dong","place_of_residence":"So 1 Duong Thu Nghiem, Phuong Sai Gon, TP Lam Dong","date_of_issue":"2024-01-01","date_of_expiry":"2030-01-01"}
```

| Khóa | Ý nghĩa | Quy định | Ví dụ |
|---|---|---|---|
| `id_number` | Số CCCD | Chuỗi đúng 12 chữ số | `"000000000001"` |
| `full_name` | Họ và tên | **Không dấu, in hoa**, cách nhau một khoảng trắng | `"NGUYEN VAN AN"` |
| `date_of_birth` | Ngày sinh | `yyyy-MM-dd` | `"1990-01-01"` |
| `sex` | Giới tính | `"Nam"`, `"Nu"` hoặc `"Nữ"` | `"Nam"` |
| `nationality` | Quốc tịch | Chuỗi không rỗng | `"Viet Nam"` |
| `place_of_birth` | Nơi sinh | Chuỗi không rỗng | `"Tinh Lam Dong"` |
| `place_of_residence` | Nơi thường trú | Chuỗi không rỗng | `"So 1 Duong Thu Nghiem, Phuong Sai Gon, TP Lam Dong"` |
| `date_of_issue` | Ngày cấp | `yyyy-MM-dd`, sau ngày sinh | `"2024-01-01"` |
| `date_of_expiry` | Có giá trị đến | `yyyy-MM-dd`, sau ngày cấp; không trước ngày hiện tại, nếu không app và máy chủ từ chối (AC-04.8) | `"2030-01-01"` |

- Đủ 9 khóa, giá trị đều là **chuỗi** (kể cả số CCCD, phải có dấu ngoặc kép).
- Thứ tự khóa không quan trọng. Khóa thừa bị bỏ qua.
- App nhận ra thẻ Moonkage nhờ khóa `id_number`: Text record không phải JSON, hoặc JSON không có `id_number`, thì bị coi là thẻ khác loại.
- Nên viết không dấu như ví dụ cho gọn. Có dấu vẫn được (trừ `full_name`), nhưng mỗi chữ có dấu tốn 2–3 byte.

**Chỉ dùng dữ liệu CCCD mẫu (A-08)**: số CCCD, họ tên, địa chỉ không được là của người thật.

## 3. Dung lượng

Thẻ mẫu ở trên cần **303 byte** trên thẻ (288 byte chữ, cộng phần đầu của NDEF).

| Thẻ | Dung lượng | Thẻ mẫu |
|---|---|---|
| NTAG213 | 144 byte | Không vừa |
| NTAG215 | 504 byte | Vừa, còn khoảng 200 byte cho địa chỉ dài hơn |
| NTAG216 | 888 byte | Vừa |

## 4. Kiểm nội dung bằng `make_card` (khuyên dùng)

1. Sao chép `tool/card_sample.json` ra file mới (có thể viết nhiều dòng cho dễ đọc), rồi sửa giá trị.
2. Chạy trong `mobile/moonkage_verify`:
   ```powershell
   dart run tool/make_card.dart the_a.json --out the_a.txt
   ```
3. Tool kiểm định dạng giống app, rút JSON về một dòng, và báo số byte cũng như vừa hay không vừa từng loại thẻ:
   ```
   Văn bản: 288 byte
   Cần trên thẻ: 303 byte
     NTAG213 (144 byte): KHÔNG vừa
     NTAG215 (504 byte): vừa
     NTAG216 (888 byte): vừa
   ```
4. Chuyển nội dung `the_a.txt` sang điện thoại để dán vào NFC Tools (ví dụ ghi chú đồng bộ, hoặc gửi cho chính mình). Chỉ làm vậy với dữ liệu mẫu.

Gõ thẳng JSON trong NFC Tools cũng được, nhưng dễ thiếu dấu `"` hay `,`.

## 5. Ghi thẻ bằng NFC Tools

**Bước 1: Xóa thẻ** (nếu thẻ đã có dữ liệu)
Tab **OTHER** → **Erase tag** → áp thẻ. Thẻ chỉ nên có một record.

**Bước 2: Ghi**
1. Tab **WRITE** → **Add a record** → **Text**.
2. Dán dòng JSON từ mục 4.
3. **OK**. Danh sách record chỉ có đúng 1 dòng Text.
4. **Write / xx Bytes** → áp thẻ, giữ yên đến khi báo *Write complete*.

**Bước 3: Đọc lại**
Tab **READ** → áp thẻ. Kiểm tra: đúng 1 record **Text**, nội dung bắt đầu bằng `{` và kết thúc bằng `}`, đủ 9 khóa.

**Bước 4: Khóa** (chỉ thẻ demo cuối cùng)
Tab **OTHER** → **Lock tag** → xác nhận → áp thẻ.

> ⚠️ **Khóa thẻ không đảo ngược được.** Chỉ khóa sau khi đọc lại đúng và đã xác minh thành công bằng app. Thẻ dùng khi phát triển thì **không khóa**.

## 6. Bộ thẻ test

| Thẻ | Nội dung (khác thẻ mẫu ở mục 2) | Kết quả mong đợi |
|---|---|---|
| A – hợp lệ | Thẻ mẫu | Màn xác nhận hiện đủ 9 trường → Lưu → Đã xác minh |
| B – hợp lệ thứ hai | `id_number` `"000000000002"`, `full_name` `"TRAN THI BINH"`, `sex` `"Nu"` | Như A (dùng cho tài khoản `other`) |
| C – sai CCCD | `id_number` 11 chữ số | App báo "Nội dung thẻ không hợp lệ", không gửi |
| D – tên có dấu | `full_name` `"NGUYỄN VĂN AN"` | App báo "Nội dung thẻ không hợp lệ", không gửi |
| E – thiếu trường | Bỏ khóa `place_of_residence` | App báo "Nội dung thẻ không hợp lệ", không gửi |
| F – thẻ định dạng cũ | `MK1\|000000000001\|Nguyen Van An` | App báo "thẻ không đúng loại", không gửi |
| G – thẻ URL / thẻ trắng | Record URL, hoặc Erase | App báo "thẻ không đúng loại", không gửi |
| H – CCCD hết hạn | `date_of_issue` `"2010-01-01"`, `date_of_expiry` `"2020-01-01"` | App báo CCCD đã hết hạn, không gửi (AC-04.8) |

`ID_ALREADY_LINKED`: lưu thẻ A ở tài khoản `demo`, rồi đăng nhập `other` và chạm lại thẻ A (xem DEV_LOGS, mục cách test với mock server).

Thẻ C, D, E không tạo được bằng `make_card` (tool từ chối); sửa tay trong NFC Tools.

## 7. Xử lý sự cố

| Hiện tượng | Kiểm tra |
|---|---|
| *Write error*, không nhận thẻ | Giữ thẻ yên lâu hơn, đổi vị trí áp; tháo ốp. Tab READ xem *Writable: No* → thẻ đã khóa |
| NFC Tools báo nội dung quá lớn | Rút ngắn địa chỉ, bỏ dấu tiếng Việt, hoặc dùng NTAG216 |
| App báo "thẻ không đúng loại" | Record phải là **Text** (không phải URL/Data); nội dung phải là JSON hợp lệ có khóa `id_number`. Hay sai: thiếu dấu `"`, dấu `,` thừa trước `}`, dùng ngoặc kép “cong” do bàn phím điện thoại tự đổi |
| App báo "Nội dung thẻ không hợp lệ" | Chạy `make_card` với cùng nội dung. Hay sai: số CCCD không để trong `"..."`, tên có dấu hoặc chữ thường, ngày không theo `yyyy-MM-dd` hoặc không tồn tại (`2000-02-31`), `sex` khác `Nam`/`Nu`/`Nữ` |

## 8. Lịch sử thay đổi

| Phiên bản | Ngày | Nội dung |
|---|---|---|
| v0.1 | 2026-10-16 | Tạo tài liệu: định dạng `MK1`, các bước ghi/đọc/khóa bằng NFC Tools, bộ thẻ test, xử lý sự cố |
| v0.2 | 2026-10-16 | Định dạng `MK2` 11 trường có ảnh base64; giới hạn ảnh theo loại thẻ; tool `make_card` |
| v0.3 | 2026-10-16 | Nội dung thẻ là JSON 9 khóa `snake_case`, bỏ ảnh, thay nơi đăng ký khai sinh bằng nơi thường trú, ngày `yyyy-MM-dd`; NTAG215 là đủ; `make_card` nhận thẳng JSON thẻ |
| v0.4 | 2026-10-17 | Đồng bộ Requirement v1.6: bỏ FR-55 (thẻ do người dùng tự có, việc ghi thẻ chỉ là chuẩn bị thẻ mẫu); quy định ngày hết hạn không trước hôm nay; thêm thẻ test H (CCCD hết hạn) |
