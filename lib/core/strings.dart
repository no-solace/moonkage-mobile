import 'package:moonkage_verify/core/errors/app_failure.dart';
import 'package:moonkage_verify/core/errors/reason_code.dart';

/// Mọi câu chữ hiển thị cho người dùng.
abstract final class Strings {
  static const appTitle = 'Moonkage Verify';
  static const retry = 'Thử lại';
  static const cancel = 'Hủy';

  // Cấu hình
  static const configErrorTitle = 'Lỗi cấu hình';
  static const configErrorBody =
      'Bản build thiếu hoặc sai API_BASE_URL. Build lại với --dart-define-from-file=env/dev.json.';

  // Đăng nhập
  static const loginTitle = 'Đăng nhập';
  static const usernameLabel = 'Email hoặc số điện thoại';
  static const passwordLabel = 'Mật khẩu';
  static const login = 'Đăng nhập';
  static const logout = 'Đăng xuất';
  static const requiredField = 'Vui lòng nhập thông tin này.';
  static const invalidCredentials = 'Thông tin đăng nhập không đúng.';

  // Trang chủ
  static String greeting(String name) => 'Xin chào, $name';
  static const homeHint = 'Mở trang xác minh trên web Moonkage, rồi bấm "Quét QR".';
  static const scanQr = 'Quét QR';
  static const checkingNfc = 'Đang kiểm tra NFC…';
  static const nfcUnsupported = 'Điện thoại này không có NFC. Vui lòng dùng điện thoại khác.';
  static const nfcDisabled = 'NFC đang tắt. Vào Cài đặt → Kết nối → bật NFC rồi thử lại.';

  // Quét QR
  static const scanQrTitle = 'Quét mã QR';
  static const scanQrHint = 'Quét mã QR hiển thị trên trang web Moonkage.';
  static const invalidQr = 'Mã QR không phải mã xác minh Moonkage.';

  // Chạm thẻ
  static const tapCardTitle = 'Chạm thẻ';
  static const tapCardHint = 'Áp thẻ Moonkage vào mặt sau điện thoại và giữ yên.';
  static const wrongCard = 'Thẻ không đúng loại. Vui lòng chạm thẻ Moonkage.';
  static const cardBadFormat = 'Nội dung thẻ không hợp lệ. Liên hệ quản trị để ghi lại thẻ.';
  static const cardReadFailed = 'Không đọc được thẻ. Giữ yên thẻ và chạm lại.';
  static const submitting = 'Đang gửi…';

  // Xác nhận
  static const confirmTitle = 'Xác nhận thông tin';
  static const confirmHint = 'Kiểm tra thông tin đọc từ thẻ. Bấm Lưu để ghi vào tài khoản.';
  static const save = 'Lưu';
  static const saving = 'Đang lưu…';
  static const fieldIdNumber = 'Số CCCD';
  static const fieldFullName = 'Họ và tên';
  static const fieldDateOfBirth = 'Ngày sinh';
  static const fieldSex = 'Giới tính';
  static const fieldNationality = 'Quốc tịch';
  static const fieldPlaceOfBirth = 'Nơi sinh';
  static const fieldPlaceOfResidence = 'Nơi thường trú';
  static const fieldDateOfIssue = 'Ngày cấp';
  static const fieldDateOfExpiry = 'Có giá trị đến';
  static const sexMale = 'Nam';
  static const sexFemale = 'Nữ';

  // Kết quả
  static const resultTitle = 'Kết quả';
  static const verified = 'Đã xác minh NFC';
  static const verifiedBody = 'Thông tin trên thẻ đã được lưu vào tài khoản của bạn.';
  static const rejected = 'Xác minh không thành công';
  static const backToWeb = 'Quay lại trang web để tiếp tục.';
  static const done = 'Xong';
  static String attemptsLeft(int n) => 'Còn $n lần thử.';
  static String lockedUntil(String time) => 'Tạm khóa đến $time.';

  static String date(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year}';
  }

  static String reason(ReasonCode code) => switch (code) {
    ReasonCode.sessionExpired => 'Phiên đã hết hạn. Tạo mã QR mới trên trang web.',
    ReasonCode.sessionUsed => 'Mã QR này đã được dùng. Tạo mã QR mới trên trang web.',
    ReasonCode.sessionNotOwned =>
      'Mã QR thuộc tài khoản khác. Đăng nhập app bằng tài khoản đang mở trên web.',
    ReasonCode.locked => 'Tài khoản đang tạm khóa xác minh do thử sai nhiều lần.',
    ReasonCode.badFormat => 'Nội dung thẻ không hợp lệ.',
    ReasonCode.idAlreadyLinked => 'Số CCCD trên thẻ đã gắn với tài khoản khác.',
    ReasonCode.unknown => 'Máy chủ từ chối xác minh.',
  };

  static String failure(AppFailure failure) => switch (failure) {
    NetworkFailure() => 'Không kết nối được máy chủ. Kiểm tra mạng rồi thử lại.',
    TimeoutFailure() => 'Máy chủ phản hồi quá lâu. Thử lại.',
    UnauthorizedFailure() => 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
    ServerFailure(:final message?) => message,
    ServerFailure() => 'Máy chủ đang lỗi. Thử lại sau.',
    InvalidResponseFailure() => 'Phản hồi từ máy chủ không hợp lệ.',
  };
}
