import 'package:daviewer/core/updates/update_checker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('compareVersions orders semantic versions', () {
    expect(compareVersions('0.2.145', '0.2.144'), greaterThan(0));
    expect(compareVersions('0.2.144', '0.2.145'), lessThan(0));
    expect(compareVersions('1.0.0', '1.0.0'), 0);
    expect(compareVersions('0.2.10', '0.2.9'), greaterThan(0));
  });

  test('isSemver rejects non-release build names', () {
    expect(isSemver('0.2.144'), isTrue);
    expect(isSemver('development'), isFalse);
    expect(isSemver('0.2.144-beta'), isFalse);
  });
}
