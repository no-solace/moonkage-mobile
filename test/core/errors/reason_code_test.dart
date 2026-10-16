import 'package:flutter_test/flutter_test.dart';
import 'package:moonkage_verify/core/errors/reason_code.dart';

void main() {
  test('mỗi reasonCode của máy chủ ánh xạ đúng enum', () {
    expect(ReasonCode.fromCode('SESSION_EXPIRED'), ReasonCode.sessionExpired);
    expect(ReasonCode.fromCode('SESSION_USED'), ReasonCode.sessionUsed);
    expect(ReasonCode.fromCode('SESSION_NOT_OWNED'), ReasonCode.sessionNotOwned);
    expect(ReasonCode.fromCode('LOCKED'), ReasonCode.locked);
    expect(ReasonCode.fromCode('BAD_FORMAT'), ReasonCode.badFormat);
    expect(ReasonCode.fromCode('ID_ALREADY_LINKED'), ReasonCode.idAlreadyLinked);
  });

  test('mã lạ, chuỗi rỗng hoặc null thì trả về unknown', () {
    expect(ReasonCode.fromCode('SOMETHING_NEW'), ReasonCode.unknown);
    expect(ReasonCode.fromCode(''), ReasonCode.unknown);
    expect(ReasonCode.fromCode(null), ReasonCode.unknown);
  });
}
