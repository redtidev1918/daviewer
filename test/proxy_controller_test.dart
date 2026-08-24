import 'package:daviewer/core/network/proxy_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseProxyAddress', () {
    test('accepts host and port', () {
      final value = parseProxyAddress('127.0.0.1:7892');
      expect(value?.host, '127.0.0.1');
      expect(value?.port, 7892);
    });

    test('accepts an HTTP URL', () {
      final value = parseProxyAddress('http://localhost:7892');
      expect(value?.host, 'localhost');
      expect(value?.port, 7892);
    });

    test('uses the HTTP default port', () {
      expect(parseProxyAddress('http://proxy.example')?.port, 80);
    });

    test('rejects missing hosts and credentials', () {
      expect(parseProxyAddress(''), isNull);
      expect(parseProxyAddress('http://user:pass@localhost:7892'), isNull);
      expect(parseProxyAddress('http://:7892'), isNull);
      expect(parseProxyAddress('socks5://localhost:7892'), isNull);
      expect(parseProxyAddress('https://localhost:7892'), isNull);
    });
  });
}
