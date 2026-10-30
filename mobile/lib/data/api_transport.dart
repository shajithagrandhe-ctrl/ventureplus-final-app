import 'dart:convert';

import 'package:dio/dio.dart';

import '../core/models.dart';
import 'storage.dart';
import 'transport_adapter.dart'
    if (dart.library.js_interop) 'transport_adapter_web.dart'
    as platform;

abstract class ApiTransport {
  String get baseUrl;
  Future<void> restore();
  Future<void> clear();
  Future<JsonMap> request(
    String method,
    String path, {
    Object? data,
    JsonMap query = const {},
    void Function(int, int)? onSendProgress,
  });
}

class DioApiTransport implements ApiTransport {
  DioApiTransport({required this.baseUrl, required this.cookieStore, Dio? dio})
    : dio = dio ?? Dio() {
    final uri = Uri.tryParse(baseUrl);
    if (uri == null ||
        !uri.hasAuthority ||
        uri.userInfo.isNotEmpty ||
        !{'https', 'http'}.contains(uri.scheme)) {
      throw const AppFailure('Configure a valid API base URL.');
    }
    final local = {'localhost', '127.0.0.1', '10.0.2.2'}.contains(uri.host);
    if (uri.scheme != 'https' && !local) {
      throw const AppFailure('Use HTTPS for a remote API server.');
    }
    this.dio.options = BaseOptions(
      baseUrl: baseUrl.replaceAll(RegExp(r'/$'), ''),
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 25),
      sendTimeout: const Duration(seconds: 25),
      followRedirects: false,
      validateStatus: (status) => status != null && status < 600,
    );
    platform.configureDio(this.dio);
  }

  @override
  final String baseUrl;
  final KeyValueStore cookieStore;
  final Dio dio;
  final Map<String, String> _cookies = {};
  String? _csrf;
  bool _cookieSavePending = false;
  void Function(String?)? onSessionWarning;
  Future<void> _writes = Future<void>.value();
  String get _storageKey =>
      'ventureplus.cookies.${Uri.encodeComponent(baseUrl)}';
  static const accessCookie = String.fromEnvironment(
    'ACCESS_TOKEN_COOKIE_NAME',
    defaultValue: 'estatehub_access',
  );
  static const csrfCookie = String.fromEnvironment(
    'CSRF_COOKIE_NAME',
    defaultValue: 'estatehub_csrf',
  );

  @override
  Future<void> restore() async {
    if (platform.usesBrowserCookies) return;
    _cookies.clear();
    final saved = await cookieStore.read(_storageKey);
    if (saved == null) return;
    try {
      final values = jsonObject(jsonDecode(saved));
      for (final name in [accessCookie, csrfCookie]) {
        final value = values[name];
        if (value is String && !RegExp(r'[\r\n;]').hasMatch(value)) {
          _cookies[name] = value;
        }
      }
    } on Object {
      await clear();
    }
  }

  @override
  Future<void> clear() async {
    _cookies.clear();
    _csrf = null;
    if (!platform.usesBrowserCookies) await cookieStore.remove(_storageKey);
    _cookieSavePending = false;
    onSessionWarning?.call(null);
  }

  Future<void> _rememberCookies(Response<dynamic> response) async {
    if (platform.usesBrowserCookies) return;
    final before = jsonEncode(_cookies);
    for (final header in response.headers['set-cookie'] ?? <String>[]) {
      final parts = header.split(';');
      final equals = parts.first.indexOf('=');
      if (equals < 1) continue;
      final name = parts.first.substring(0, equals).trim();
      if (name != accessCookie && name != csrfCookie) continue;
      final value = parts.first.substring(equals + 1);
      final expired = parts.any(
        (part) => part.trim().toLowerCase() == 'max-age=0',
      );
      if (value.isEmpty || expired) {
        _cookies.remove(name);
      } else if (!RegExp(r'[\r\n]').hasMatch(value)) {
        _cookies[name] = value;
      }
    }
    final current = jsonEncode(_cookies);
    if (current == before && !_cookieSavePending) return;
    try {
      await cookieStore.write(_storageKey, current);
      _cookieSavePending = false;
      onSessionWarning?.call(null);
    } on Object {
      // A confirmed server write must not become a retryable business failure
      // just because this device cannot persist its refreshed cookie jar.
      _cookieSavePending = true;
      onSessionWarning?.call(
        'This device could not save your sign-in session. You may need to sign in again after restarting the app.',
      );
    }
  }

  @override
  Future<JsonMap> request(
    String method,
    String path, {
    Object? data,
    JsonMap query = const {},
    void Function(int, int)? onSendProgress,
  }) async {
    if (!path.startsWith('/') ||
        path.startsWith('//') ||
        path.contains('://') ||
        path.contains('..')) {
      throw const AppFailure('Invalid API request path.');
    }
    final verb = method.toUpperCase();
    if (!{'GET', 'HEAD', 'OPTIONS'}.contains(verb)) {
      // Serialize token rotation with its write. Browsers share the cookie jar.
      final pending = _writes.then((_) async {
        final token = await _send('GET', '/auth/csrf');
        _csrf = requiredText(jsonObject(token['data']), 'token');
        return _send(
          verb,
          path,
          data: data,
          query: query,
          onSendProgress: onSendProgress,
        );
      });
      _writes = pending.then<void>((_) {}, onError: (Object _) {});
      return pending;
    }
    return _send(
      verb,
      path,
      data: data,
      query: query,
      onSendProgress: onSendProgress,
    );
  }

  Future<JsonMap> _send(
    String method,
    String path, {
    Object? data,
    JsonMap query = const {},
    void Function(int, int)? onSendProgress,
  }) async {
    try {
      final response = await dio.request<dynamic>(
        path,
        data: data,
        queryParameters: query,
        options: Options(
          method: method,
          headers: {
            if (!platform.usesBrowserCookies && _cookies.isNotEmpty)
              'Cookie': _cookies.entries
                  .map((e) => '${e.key}=${e.value}')
                  .join('; '),
            if (_csrf != null) 'X-CSRF-Token': _csrf,
          },
        ),
        onSendProgress: onSendProgress,
      );
      await _rememberCookies(response);
      final status = response.statusCode ?? 500;
      if (status >= 300) {
        final message = switch (status) {
          401 =>
            'Sign-in failed or your session has expired. Please sign in again.',
          403 =>
            'Your account cannot perform this action. Refresh and try again.',
          404 => 'This item is no longer available. Refresh the list.',
          409 => 'This entry already exists. Check the details and try again.',
          413 => 'The file is too large. Choose a file no larger than 4 MiB.',
          429 => 'Too many requests. Wait a moment and try again.',
          >= 500 =>
            'The server could not complete the request. Please try again.',
          _ => 'The request was rejected. Check the fields and try again.',
        };
        throw AppFailure(message, statusCode: status);
      }
      final payload = jsonObject(response.data);
      if (payload['success'] != true) {
        throw const AppFailure('The server did not confirm this action.');
      }
      return payload;
    } on DioException catch (error) {
      throw AppFailure(switch (error.type) {
        DioExceptionType.connectionTimeout ||
        DioExceptionType.receiveTimeout ||
        DioExceptionType.sendTimeout =>
          'The connection timed out. Please try again.',
        DioExceptionType.cancel => 'The request was cancelled.',
        _ => 'Cannot reach the server. Check your connection or choose Offline Demo.',
      });
    }
  }
}
