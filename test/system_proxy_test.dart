import 'package:daviewer/core/network/system_proxy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseWindowsProxyServer', () {
    test('parses a single endpoint', () {
      expect(
        parseWindowsProxyServer('127.0.0.1:7892')?.toString(),
        '127.0.0.1:7892',
      );
    });

    test('prefers https in a protocol-specific value', () {
      final value = parseWindowsProxyServer(
        'http=127.0.0.1:7890;https=127.0.0.1:7892;socks=127.0.0.1:7891',
      );
      expect(value?.toString(), '127.0.0.1:7892');
    });

    test('rejects unusable values', () {
      expect(parseWindowsProxyServer('socks=127.0.0.1:7891'), isNull);
      expect(parseWindowsProxyServer('http='), isNull);
    });
  });

  group('parseLinuxProxySettings', () {
    test('ignores stale hosts while GNOME proxy mode is disabled', () {
      expect(
        parseLinuxProxySettings(
          mode: 'none',
          httpsHost: 'stale.example',
          httpsPort: '443',
          httpHost: 'stale.example',
          httpPort: '8080',
        ),
        isNull,
      );
    });

    test('prefers the HTTPS endpoint in manual mode', () {
      expect(
        parseLinuxProxySettings(
          mode: 'manual',
          httpsHost: 'secure-proxy.example',
          httpsPort: '8443',
          httpHost: 'proxy.example',
          httpPort: '8080',
        )?.toString(),
        'secure-proxy.example:8443',
      );
    });

    test('falls back to HTTP and rejects PAC mode', () {
      expect(
        parseLinuxProxySettings(
          mode: 'manual',
          httpsHost: '',
          httpsPort: '0',
          httpHost: '127.0.0.1',
          httpPort: '7892',
        )?.toString(),
        '127.0.0.1:7892',
      );
      expect(
        parseLinuxProxySettings(
          mode: 'auto',
          httpsHost: 'ignored',
          httpsPort: '8443',
          httpHost: '',
          httpPort: '',
        ),
        isNull,
      );
    });
  });
}
