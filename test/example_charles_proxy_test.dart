import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// The example is not a dependency of the plugin under test.
// ignore: avoid_relative_lib_imports
import '../example/lib/charles_proxy.dart';

void main() {
  late Directory certificates;
  late String certificatePath;
  late String keyPath;
  setUpAll(() async {
    // Generate the host-side OpenSSL fixture per run so it cannot expire in CI.
    certificates =
        await Directory.systemTemp.createTemp('audienzz-proxy-test-');
    certificatePath = '${certificates.path}/server.pem';
    keyPath = '${certificates.path}/server.key';
    final config = File('${certificates.path}/openssl.cnf');
    await config.writeAsString('''
[req]
distinguished_name=dn
x509_extensions=extensions
prompt=no
[dn]
CN=config.proxy-test.invalid
[extensions]
subjectAltName=DNS:config.proxy-test.invalid
keyUsage=critical,digitalSignature,keyEncipherment,keyCertSign
basicConstraints=critical,CA:TRUE
extendedKeyUsage=serverAuth
''');
    final generated = await Process.run('openssl', [
      'req',
      '-x509',
      '-newkey',
      'rsa:2048',
      '-nodes',
      '-days',
      '2',
      '-config',
      config.path,
      '-keyout',
      keyPath,
      '-out',
      certificatePath,
    ]);
    expect(generated.exitCode, 0, reason: '${generated.stderr}');
  });
  tearDownAll(() async {
    await certificates.delete(recursive: true);
  });

  test('example Dart requests actually travel through the configured proxy',
      () async {
    final proxy = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final seen = <Uri>[];
    proxy.listen((request) async {
      seen.add(request.uri);
      request.response.write('proxied');
      await request.response.close();
    });
    final previous = HttpOverrides.current;
    HttpClient? client;
    try {
      configureCharlesProxy(
        proxy: '127.0.0.1:${proxy.port}',
        certificateBase64: base64Encode(
          File(certificatePath).readAsBytesSync(),
        ),
      );
      client = HttpClient();
      // This host cannot resolve directly. Bypassing Charles must fail instead
      // of passing against an unrelated direct fetch.
      final target = Uri.parse('http://remote-config.invalid/publishers/35');
      final request =
          await client.getUrl(target).timeout(const Duration(seconds: 3));
      final response = await request.close();
      expect(await utf8.decoder.bind(response).join(), 'proxied');
      expect(seen, [target]);
    } finally {
      client?.close(force: true);
      HttpOverrides.global = previous;
      await proxy.close(force: true);
    }
  });

  test('unconfigured startup leaves the existing HTTP configuration alone', () {
    final previous = HttpOverrides.current;
    configureCharlesProxy();
    expect(HttpOverrides.current, same(previous));
  });

  test('HTTPS proxy trusts the selected CA but still rejects wrong hostnames',
      () async {
    // Test-only certificate for a reserved hostname, never used by an app.
    final serverContext = SecurityContext()
      ..useCertificateChain(certificatePath)
      ..usePrivateKey(keyPath);
    final upstream = await HttpServer.bindSecure(
      InternetAddress.loopbackIPv4,
      0,
      serverContext,
    );
    upstream.listen(
      (request) async {
        request.response.write('verified TLS');
        await request.response.close();
      },
      onError: (Object error) {
        // The client intentionally rejects the second handshake.
        if (error is! HandshakeException) {
          fail('$error');
        }
      },
    );
    final proxy = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final tunnels = <String>[];
    final sockets = <Socket>[];
    proxy.listen((request) async {
      expect(request.method, 'CONNECT');
      tunnels.add(request.uri.toString());
      final remote =
          await Socket.connect(InternetAddress.loopbackIPv4, upstream.port);
      final local = await request.response.detachSocket(writeHeaders: false);
      sockets.addAll([remote, local]);
      local.write('HTTP/1.1 200 Connection Established\r\n\r\n');
      await local.flush();
      unawaited(local.addStream(remote).catchError((Object _) {}));
      unawaited(remote.addStream(local).catchError((Object _) {}));
    });
    final previous = HttpOverrides.current;
    HttpClient? client;
    try {
      configureCharlesProxy(
        proxy: '127.0.0.1:${proxy.port}',
        certificateBase64: base64Encode(
          File(certificatePath).readAsBytesSync(),
        ),
      );
      client = HttpClient()..connectionTimeout = const Duration(seconds: 3);
      final request = await client
          .getUrl(Uri.parse('https://config.proxy-test.invalid/publishers/35'));
      final response = await request.close();
      expect(await utf8.decoder.bind(response).join(), 'verified TLS');
      await expectLater(
        client.getUrl(
          Uri.parse('https://wrong.proxy-test.invalid/publishers/35'),
        ),
        throwsA(isA<HandshakeException>()),
      );
      expect(
        tunnels,
        ['config.proxy-test.invalid:443', 'wrong.proxy-test.invalid:443'],
      );
    } finally {
      client?.close(force: true);
      HttpOverrides.global = previous;
      for (final socket in sockets) {
        socket.destroy();
      }
      await proxy.close(force: true);
      await upstream.close(force: true);
    }
  });
}
