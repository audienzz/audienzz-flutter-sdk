import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// Example-only opt-in for Dart HTTP, which does not use Android's Wi-Fi proxy.
/// Native Google/Prebid requests use the device proxy and debug network config.
void configureCharlesProxy({
  String proxy = const String.fromEnvironment('CHARLES_PROXY'),
  String certificateBase64 = const String.fromEnvironment('CHARLES_CA_BASE64'),
}) {
  if (!kDebugMode || (proxy.isEmpty && certificateBase64.isEmpty)) return;
  if (proxy.isEmpty || certificateBase64.isEmpty) {
    throw ArgumentError(
        'Set both CHARLES_PROXY=host:port and CHARLES_CA_BASE64. '
        'See LOCAL_TESTING.md.');
  }
  HttpOverrides.global = CharlesProxyOverrides(
    proxy: proxy,
    certificateBytes: base64Decode(certificateBase64),
  );
  debugPrint('Charles proxy enabled for Dart HTTP: $proxy');
}

class CharlesProxyOverrides extends HttpOverrides {
  CharlesProxyOverrides({
    required String proxy,
    required List<int> certificateBytes,
  }) : _proxy = _validateProxy(proxy) {
    _context.setTrustedCertificatesBytes(certificateBytes);
  }

  final String _proxy;
  final SecurityContext _context = SecurityContext(withTrustedRoots: true);

  static String _validateProxy(String proxy) {
    final uri = Uri.parse('http://$proxy');
    if (uri.host.isEmpty ||
        !uri.hasPort ||
        uri.port < 1 ||
        uri.port > 65535 ||
        uri.userInfo.isNotEmpty ||
        uri.path.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        proxy.contains(';')) {
      throw ArgumentError.value(proxy, 'CHARLES_PROXY', 'Expected host:port');
    }
    return 'PROXY ${uri.authority}';
  }

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    // Normal chain/hostname verification stays enabled. No badCertificateCallback
    // and no DIRECT fallback: a failed proxy must be visible during investigation.
    return super.createHttpClient(context ?? _context)
      ..findProxy = (_) => _proxy;
  }
}
