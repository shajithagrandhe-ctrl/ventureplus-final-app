import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ventureplus/core/app_controller.dart';

class RecordingAdapter implements HttpClientAdapter {
  RecordingAdapter(this.reply);
  final Future<ResponseBody> Function(RequestOptions) reply;
  final requests = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return reply(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody response(
  Object? data, {
  int status = 200,
  List<String> cookies = const [],
}) => ResponseBody.fromString(
  jsonEncode({'success': status < 300, 'data': data}),
  status,
  headers: {
    'content-type': ['application/json'],
    if (cookies.isNotEmpty) 'set-cookie': cookies,
  },
);

void main() {
  test('login keeps HttpOnly access cookie, rotates CSRF and persists only cookies', () async {
    final store = MemoryStore();
    final adapter = RecordingAdapter((request) async {
      if (request.path == '/auth/csrf') {
        return response(
          {'token': 'csrf-before'},
          cookies: ['estatehub_csrf=csrf-before; Path=/'],
        );
      }
      if (request.path == '/auth/login') {
        return response(
          {
            'user': {'role': 'ADMIN'},
          },
          cookies: [
            'estatehub_access=server-issued-access; Path=/; HttpOnly; Secure',
            'estatehub_csrf=csrf-after; Path=/; Secure',
          ],
        );
      }
      return response({
        'user': {'role': 'ADMIN'},
      });
    });
    final dio = Dio()..httpClientAdapter = adapter;
    final transport = DioApiTransport(
      baseUrl: 'https://example.test/api',
      cookieStore: store,
      dio: dio,
    );
    await transport.request(
      'POST',
      '/auth/login',
      data: {
        'email': 'test@example.test',
        'password': 'sensitive-not-persisted',
      },
    );
    expect(adapter.requests.map((r) => r.path), ['/auth/csrf', '/auth/login']);
    expect(
      adapter.requests.last.uri.toString(),
      'https://example.test/api/auth/login',
    );
    expect(adapter.requests.last.headers['X-CSRF-Token'], 'csrf-before');
    expect(
      adapter.requests.last.headers['Cookie'],
      'estatehub_csrf=csrf-before',
    );
    expect(store.values.values.single, contains('server-issued-access'));
    expect(
      store.values.values.single,
      isNot(contains('sensitive-not-persisted')),
    );

    final restoredAdapter = RecordingAdapter(
      (request) async => response({
        'user': {'role': 'ADMIN'},
      }),
    );
    final restored = DioApiTransport(
      baseUrl: 'https://example.test/api',
      cookieStore: store,
      dio: Dio()..httpClientAdapter = restoredAdapter,
    );
    await restored.restore();
    await restored.request('GET', '/auth/me');
    expect(
      restoredAdapter.requests.single.headers['Cookie'],
      contains('estatehub_access=server-issued-access'),
    );
    await restored.clear();
    expect(store.values, isEmpty);
    await restored.request('GET', '/auth/me');
    expect(restoredAdapter.requests.last.headers.containsKey('Cookie'), false);
  });

  test(
    'concurrent writes rotate CSRF serially and never replay rejected mutation',
    () async {
      var token = 0;
      final adapter = RecordingAdapter((request) async {
        if (request.path == '/auth/csrf') {
          token++;
          return response(
            {'token': 'token-$token'},
            cookies: ['estatehub_csrf=token-$token; Path=/'],
          );
        }
        expect(request.headers['X-CSRF-Token'], 'token-$token');
        expect(request.headers['Cookie'], 'estatehub_csrf=token-$token');
        return response({}, status: 403);
      });
      final transport = DioApiTransport(
        baseUrl: 'https://example.test/api',
        cookieStore: MemoryStore(),
        dio: Dio()..httpClientAdapter = adapter,
      );
      final first = transport.request('POST', '/leads', data: {});
      final second = transport.request('POST', '/total-data', data: {});
      await Future.wait([
        expectLater(
          first,
          throwsA(isA<AppFailure>().having((e) => e.statusCode, 'status', 403)),
        ),
        expectLater(
          second,
          throwsA(isA<AppFailure>().having((e) => e.statusCode, 'status', 403)),
        ),
      ]);
      expect(adapter.requests.map((r) => r.path), [
        '/auth/csrf',
        '/leads',
        '/auth/csrf',
        '/total-data',
      ]);
    },
  );

  test(
    'unconfirmed JSON result is an error and remote server text is not leaked',
    () async {
      final adapter = RecordingAdapter(
        (request) async => ResponseBody.fromString(
          '{"success":false,"message":"database password secret"}',
          200,
          headers: {
            'content-type': ['application/json'],
          },
        ),
      );
      final transport = DioApiTransport(
        baseUrl: 'https://example.test/api',
        cookieStore: MemoryStore(),
        dio: Dio()..httpClientAdapter = adapter,
      );
      await expectLater(
        transport.request('GET', '/plots'),
        throwsA(
          isA<AppFailure>().having(
            (e) => e.message,
            'message',
            isNot(contains('secret')),
          ),
        ),
      );
    },
  );

  test(
    'cross-origin paths and remote HTTP are rejected before networking',
    () async {
      final adapter = RecordingAdapter((request) async => response([]));
      final transport = DioApiTransport(
        baseUrl: 'https://example.test/api',
        cookieStore: MemoryStore(),
        dio: Dio()..httpClientAdapter = adapter,
      );
      for (final path in [
        'https://attacker.test',
        '//attacker.test',
        '/../admin',
      ]) {
        await expectLater(
          transport.request('GET', path),
          throwsA(isA<AppFailure>()),
        );
      }
      expect(adapter.requests, isEmpty);
      expect(
        () => DioApiTransport(
          baseUrl: 'http://example.test/api',
          cookieStore: MemoryStore(),
        ),
        throwsA(isA<AppFailure>()),
      );
    },
  );

  test('expired cookies and unrelated cookie names are not retained', () async {
    final store = MemoryStore();
    final adapter = RecordingAdapter(
      (request) async => response(
        [],
        cookies: [
          'estatehub_access=gone; Path=/; Max-Age=0',
          'unrelated=ignored; Path=/',
        ],
      ),
    );
    final transport = DioApiTransport(
      baseUrl: 'https://example.test/api',
      cookieStore: store,
      dio: Dio()..httpClientAdapter = adapter,
    );
    await transport.request('GET', '/plots');
    expect(jsonDecode(store.values.values.single), isEmpty);
  });
}
