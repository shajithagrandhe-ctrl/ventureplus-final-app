import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ventureplus/core/app_controller.dart';

class FakeTransport implements ApiTransport {
  FakeTransport({this.handler});
  Future<JsonMap> Function(String, String, Object?, JsonMap)? handler;
  final calls = <String>[];
  int restores = 0;
  int clears = 0;
  @override
  String get baseUrl => 'https://example.test/api';
  @override
  Future<void> restore() async => restores++;
  @override
  Future<void> clear() async => clears++;
  @override
  Future<JsonMap> request(
    String method,
    String path, {
    Object? data,
    JsonMap query = const {},
    void Function(int, int)? onSendProgress,
  }) async {
    calls.add('$method $path');
    if (handler == null) throw const AppFailure('Network unavailable.');
    return handler!(method, path, data, query);
  }
}

class FailingStore extends MemoryStore {
  bool fail = false;
  @override
  Future<void> write(String key, String value) async {
    if (fail) throw StateError('Storage unavailable');
    await super.write(key, value);
  }
}

JsonMap identity([Role role = Role.admin]) => {
  'id': 'server-user',
  'email': 'test@example.test',
  'displayName': 'Test User',
  'fullName': 'Test User',
  'role': role.wireName,
};

void main() {
  group('identity and permissions', () {
    test('identity round trips all server roles and rejects unknown role', () {
      for (final role in Role.values) {
        final user = UserIdentity.fromJson(identity(role));
        expect(user.role, role);
        expect(
          UserIdentity.fromJson(jsonDecode(jsonEncode(user.toJson()))).role,
          role,
        );
      }
      expect(
        () => UserIdentity.fromJson({...identity(), 'role': 'OWNER'}),
        throwsA(isA<AppFailure>()),
      );
      expect(
        () => UserIdentity.fromJson({...identity(), 'id': null}),
        throwsA(isA<AppFailure>()),
      );
    });

    test('customer and agent writes deny by default', () {
      for (final resource in Resource.values) {
        expect(Permissions.canUpdate(Role.customer, resource), false);
        expect(Permissions.canUpdate(Role.agent, resource), false);
        expect(
          Permissions.canCreate(Role.customer, resource),
          resource == Resource.favorites,
        );
        expect(
          Permissions.canCreate(Role.agent, resource),
          {Resource.favorites, Resource.tracking}.contains(resource),
        );
      }
      expect(Permissions.canCreate(Role.employee, Resource.ventures), false);
      expect(
        Permissions.canRead(Role.employee, Resource.employeeAccess),
        false,
      );
      expect(Permissions.canRead(Role.agent, Resource.customerAccounts), false);
    });

    test('domain DTO preserves values and rejects unknown plot status', () {
      final data = {
        'id': 'p1',
        'ventureId': 'v1',
        'plotNumber': '101',
        'area': 200,
        'pricePerSqYard': 24000,
        'status': 'AVAILABLE',
      };
      expect(PlotData.fromJson(data).totalValue, 4800000);
      expect(PlotData.fromJson(data).status, PlotStatus.available);
      expect(
        () => PlotData.fromJson({...data, 'status': 'MYSTERY'}),
        throwsA(isA<AppFailure>()),
      );
      expect(DemoPrefills.forRole(Role.agent), isNull);
    });
  });

  group('mode isolation and authentication', () {
    test(
      'offline enter, reads, writes, restore and logout call no transport',
      () async {
        final transport = FakeTransport();
        final store = MemoryStore();
        final controller = AppController(
          transport: transport,
          preferences: store,
        );
        expect(await controller.enterOffline(Role.admin), true);
        expect(controller.mode, SessionMode.offlineDemo);
        await controller.repository!.update(Resource.plots, 'demo-plot-3', {
          'status': 'SOLD',
        });
        final restored = AppController(
          transport: transport,
          preferences: store,
        );
        expect(await restored.restore(), true);
        expect(
          (await restored.repository!.detail(
            Resource.plots,
            'demo-plot-3',
          ))['status'],
          'SOLD',
        );
        expect(await restored.logout(), true);
        expect(transport.calls, isEmpty);
        expect(transport.restores, 0);
        expect(transport.clears, 0);
        expect(restored.user, isNull);
        controller.dispose();
        restored.dispose();
      },
    );

    test('failed connected login never falls back to offline', () async {
      final store = MemoryStore();
      final transport = FakeTransport();
      final controller = AppController(
        transport: transport,
        preferences: store,
      );
      expect(await controller.login('test@example.test', 'password'), false);
      expect(controller.user, isNull);
      expect(controller.repository, isNull);
      expect(controller.mode, isNull);
      expect(controller.error, 'Network unavailable.');
      expect(await store.read(AppController.modeKey), isNull);
      expect(await store.read(OfflineRepository.storageKey), isNull);
      controller.dispose();
    });

    test(
      'identity comes from me, not login response or selected role',
      () async {
        final transport = FakeTransport(
          handler: (method, path, data, query) async => {
            'success': true,
            'data': {
              'user': identity(path == '/auth/me' ? Role.employee : Role.admin),
            },
          },
        );
        final store = MemoryStore();
        final controller = AppController(
          transport: transport,
          preferences: store,
        );
        expect(await controller.login('test@example.test', 'password'), true);
        expect(controller.user!.role, Role.employee);
        expect(controller.repository!.isOffline, false);
        expect(transport.calls, ['POST /auth/login', 'GET /auth/me']);
        expect(await store.read(AppController.modeKey), 'connected');
        controller.dispose();
      },
    );

    test(
      'me failure after accepted login does not publish authenticated state',
      () async {
        final transport = FakeTransport(
          handler: (method, path, data, query) async {
            if (path == '/auth/me') {
              throw const AppFailure('Session invalid', statusCode: 401);
            }
            return {
              'success': true,
              'data': {'user': identity()},
            };
          },
        );
        final controller = AppController(
          transport: transport,
          preferences: MemoryStore(),
        );
        expect(await controller.login('test@example.test', 'password'), false);
        expect(controller.user, isNull);
        expect(controller.repository, isNull);
        expect(transport.clears, 2);
        controller.dispose();
      },
    );

    test(
      'expired restored cookie clears persisted session, no fake dashboard',
      () async {
        final store = MemoryStore();
        await store.write(AppController.modeKey, 'connected');
        final transport = FakeTransport(
          handler: (method, path, data, query) async =>
              throw const AppFailure('Expired', statusCode: 401),
        );
        final controller = AppController(
          transport: transport,
          preferences: store,
        );
        expect(await controller.restore(), false);
        expect(controller.user, isNull);
        expect(transport.restores, 1);
        expect(await store.read(AppController.modeKey), isNull);
        controller.dispose();
      },
    );

    test('repository 401 expires current session', () async {
      final transport = FakeTransport(
        handler: (method, path, data, query) async {
          if (path == '/plots') {
            throw const AppFailure('Expired', statusCode: 401);
          }
          return {
            'success': true,
            'data': {'user': identity()},
          };
        },
      );
      final controller = AppController(
        transport: transport,
        preferences: MemoryStore(),
      );
      await controller.login('test@example.test', 'password');
      await expectLater(
        controller.repository!.list(Resource.plots),
        throwsA(isA<AppFailure>()),
      );
      expect(controller.user, isNull);
      expect(controller.error, contains('expired'));
      await Future<void>.delayed(Duration.zero);
      controller.dispose();
    });

    test(
      'failed remote logout still clears local identity and reports limitation',
      () async {
        final store = MemoryStore();
        final transport = FakeTransport(
          handler: (method, path, data, query) async {
            if (path == '/auth/logout') {
              throw const AppFailure('Network unavailable');
            }
            return {
              'success': true,
              'data': {'user': identity()},
            };
          },
        );
        final controller = AppController(
          transport: transport,
          preferences: store,
        );
        await controller.login('test@example.test', 'password');
        expect(await controller.logout(), false);
        expect(controller.user, isNull);
        expect(await store.read(AppController.modeKey), isNull);
        expect(controller.error, contains('Signed out on this device'));
        controller.dispose();
      },
    );
  });

  group('offline repository', () {
    test('offline identity restores persisted employee names', () async {
      final store = MemoryStore();
      final originalEmployee = await OfflineRepository.open(
        store,
        Role.employee,
      );
      final created = await originalEmployee.create(Resource.customers, {
        'contactName': 'New Fictional Customer',
        'contactNumber': '0000012345',
        'location': 'Fictional district',
        'budget': '100',
        'recordOwner': 'Maya Sen',
      });
      await originalEmployee.create(Resource.leads, {
        'plotId': 'demo-plot-3',
        'customerName': 'Lead Fictional Customer',
        'email': 'lead@fictional.example',
        'contactNumber': '0000043210',
        'location': 'Fictional district',
        'uniqueId': 'DEMO-NAME-CHANGE',
        'pricePerSqYard': 24000,
      });
      final admin = await OfflineRepository.open(store, Role.admin);
      await admin.update(Resource.employeeAccess, 'demo-employee', {
        'fullName': 'Maya Example',
        'displayName': 'Maya E',
        'email': 'employee@fictional.example',
        'phoneNumber': null,
        'yearsOfExperience': null,
      });
      final employee = await OfflineRepository.open(store, Role.employee);
      expect(employee.user.fullName, 'Maya Example');
      expect(employee.user.displayName, 'Maya E');
      expect(employee.user.email, 'employee@fictional.example');
      expect(employee.user.role, Role.employee);
      final records = await employee.list(Resource.customers);
      expect(records.length, 3);
      expect(
        records.every((record) => record['recordOwner'] == employee.user.email),
        true,
      );
      await employee.update(Resource.customers, created['id'], {
        ...created,
        'notes': 'Still owned after profile rename.',
      });
      expect(
        (await employee.detail(
          Resource.customers,
          created['id'],
        ))['recordOwner'],
        employee.user.email,
      );
      final account = await admin.detail(
        Resource.employeeAccess,
        'demo-employee',
      );
      expect(account['phoneNumber'], isNull);
      expect(account['employeeProfile']['yearsOfExperience'], isNull);
    });

    test(
      'offline employee email changes fail without altering ownership identity',
      () async {
        final store = MemoryStore();
        final admin = await OfflineRepository.open(store, Role.admin);
        await expectLater(
          admin.update(Resource.employeeAccess, 'demo-employee', {
            'email': 'new@fictional.example',
          }),
          throwsA(isA<AppFailure>().having((e) => e.statusCode, 'status', 400)),
        );
        final employee = await OfflineRepository.open(store, Role.employee);
        expect(employee.user.email, 'employee@fictional.example');
        expect(
          (await employee.list(Resource.customers)).map((row) => row['id']),
          ['demo-record-1'],
        );
      },
    );

    test('persisted demo role cannot elevate the selected identity', () async {
      final store = MemoryStore();
      await OfflineRepository.open(store, Role.employee);
      final data = jsonObject(
        jsonDecode((await store.read(OfflineRepository.storageKey))!),
      );
      final employee = jsonList(data['users'])
          .singleWhere((row) => row['id'] == 'demo-employee');
      employee['role'] = 'ADMIN';
      data['users'] = jsonList(data['users'])
          .map((row) => row['id'] == employee['id'] ? employee : row)
          .toList();
      await store.write(OfflineRepository.storageKey, jsonEncode(data));
      await expectLater(
        OfflineRepository.open(store, Role.employee),
        throwsA(isA<AppFailure>().having((e) => e.statusCode, 'status', 403)),
      );
    });
    test(
      'notes cannot grant customer access and lead linkage survives edits',
      () async {
        final store = MemoryStore();
        final admin = await OfflineRepository.open(store, Role.admin);
        await admin.create(Resource.customers, {
          'contactName': 'Unrelated Person',
          'contactNumber': '0000000000',
          'location': 'Fictional district',
          'budget': '100',
          'recordOwner': 'Aarav Rao',
          'notes': 'Email: customer@fictional.example',
        });
        final linked = await admin.detail(Resource.customers, 'demo-record-1');
        await admin.update(Resource.customers, 'demo-record-1', {
          ...linked,
          'notes': 'Updated notes without email.',
        });
        final customer = await OfflineRepository.open(store, Role.customer);
        expect(
          (await customer.list(Resource.customers)).map((row) => row['id']),
          ['demo-record-1'],
        );
      },
    );

    test('frozen employee cannot enter a local session and passwords cannot claim saved', () async {
      final store = MemoryStore();
      final admin = await OfflineRepository.open(store, Role.admin);
      await expectLater(
        admin.update(Resource.employeeAccess, 'demo-employee', {
          'password': 'not-a-real-password',
        }),
        throwsA(isA<AppFailure>()),
      );
      await admin.setEmployeeStatus('demo-employee', 'FROZEN');
      await expectLater(
        OfflineRepository.open(store, Role.employee),
        throwsA(isA<AppFailure>().having((e) => e.statusCode, 'status', 403)),
      );
      await admin.setEmployeeStatus('demo-employee', 'ACTIVE');
      expect(
        (await OfflineRepository.open(store, Role.employee)).user.role,
        Role.employee,
      );
    });
    test('customer sees own lead-linked properties and records only', () async {
      final repo = await OfflineRepository.open(MemoryStore(), Role.customer);
      expect((await repo.list(Resource.plots)).map((r) => r['id']), [
        'demo-plot-1',
      ]);
      expect((await repo.list(Resource.customers)).map((r) => r['id']), [
        'demo-record-1',
      ]);
      expect((await repo.list(Resource.leads)).map((r) => r['email']), [
        'customer@fictional.example',
      ]);
      await expectLater(
        repo.detail(Resource.plots, 'demo-plot-9'),
        throwsA(isA<AppFailure>()),
      );
      await expectLater(
        repo.create(Resource.favorites, {'plotId': 'demo-plot-9'}),
        throwsA(isA<AppFailure>()),
      );
      expect(repo.assetUrl('https://example.test/image.png'), isNull);
    });

    test('employee assignment bounds plot writes and local records', () async {
      final repo = await OfflineRepository.open(MemoryStore(), Role.employee);
      expect((await repo.list(Resource.plots)).length, 8);
      expect((await repo.list(Resource.customers)).length, 1);
      expect((await repo.list(Resource.leads)).map((row) => row['id']), [
        'demo-lead-1',
      ]);
      await expectLater(
        repo.update(Resource.leads, 'demo-lead-2', {'status': 'WON'}),
        throwsA(isA<AppFailure>()),
      );
      await expectLater(
        repo.remove(Resource.leads, 'demo-lead-2'),
        throwsA(isA<AppFailure>()),
      );
      await expectLater(
        repo.update(Resource.plots, 'demo-plot-9', {'status': 'SOLD'}),
        throwsA(isA<AppFailure>()),
      );
      await expectLater(
        repo.remove(Resource.customers, 'demo-record-2'),
        throwsA(isA<AppFailure>()),
      );
      await expectLater(
        repo.updatePlotCoordinates('demo-plot-1', {'x': 0.5}),
        throwsA(isA<AppFailure>()),
      );
    });

    test('saved fictional changes survive reopening and returned maps are detached', () async {
      final store = MemoryStore();
      final repo = await OfflineRepository.open(store, Role.admin);
      final row = await repo.update(Resource.plots, 'demo-plot-3', {
        'status': 'SOLD',
      });
      row['status'] = 'AVAILABLE';
      final reopened = await OfflineRepository.open(store, Role.employee);
      expect(
        (await reopened.detail(Resource.plots, 'demo-plot-3'))['status'],
        'SOLD',
      );
      expect(
        store.values[OfflineRepository.storageKey],
        contains('Sage Harbour'),
      );
      expect(
        store.values[OfflineRepository.storageKey],
        isNot(contains('estatehub_access')),
      );
    });

    test('failed persistence does not fabricate a saved mutation', () async {
      final store = FailingStore();
      final repo = await OfflineRepository.open(store, Role.admin);
      store.fail = true;
      await expectLater(
        repo.update(Resource.plots, 'demo-plot-3', {'status': 'SOLD'}),
        throwsStateError,
      );
      expect(
        (await repo.detail(Resource.plots, 'demo-plot-3'))['status'],
        'AVAILABLE',
      );
    });

    test('batch validation failure is atomic', () async {
      final repo = await OfflineRepository.open(MemoryStore(), Role.admin);
      final before = (await repo.detail(Resource.plots, 'demo-plot-1'))['x'];
      await expectLater(
        repo.updatePlotCoordinatesBatch([
          {'id': 'demo-plot-1', 'x': 0.5},
          {'id': 'demo-plot-2', 'x': 2},
        ]),
        throwsA(isA<AppFailure>()),
      );
      expect((await repo.detail(Resource.plots, 'demo-plot-1'))['x'], before);
    });

    test(
      'empty shapes and malformed regions cannot claim a successful save',
      () async {
        final repo = await OfflineRepository.open(MemoryStore(), Role.admin);
        await expectLater(
          repo.updatePlotCoordinates('demo-plot-1', {}),
          throwsA(isA<AppFailure>()),
        );
        await expectLater(
          repo.updateRegions('demo-venture-1', {
            'roads': [
              {
                'points': [
                  {'x': 0.2},
                ],
              },
            ],
            'parks': [],
          }),
          throwsA(isA<AppFailure>()),
        );
        expect(
          (await repo.detail(
            Resource.ventures,
            'demo-venture-1',
          ))['layoutRegions'],
          {'roads': [], 'parks': []},
        );
      },
    );

    test('region object and upload bytes persist locally', () async {
      final store = MemoryStore();
      final repo = await OfflineRepository.open(store, Role.admin);
      final regions = {
        'roads': [
          {
            'points': [
              {'x': 0.1, 'y': 0.2},
              {'x': 0.4, 'y': 0.5},
              {'x': 0.8, 'y': 0.2},
            ],
          },
        ],
        'parks': [],
      };
      await repo.updateRegions('demo-venture-1', regions);
      await repo.uploadVenture(
        'demo-venture-1',
        [1, 2, 3],
        'demo.png',
        layout: true,
        contentType: 'image/png',
      );
      final reopened = await OfflineRepository.open(store, Role.admin);
      final venture = await reopened.detail(
        Resource.ventures,
        'demo-venture-1',
      );
      expect(venture['layoutRegions'], regions);
      expect(venture['layoutImage'], 'data:image/png;base64,AQID');
    });

    test('bad saved state fails explicitly instead of resetting', () async {
      final store = MemoryStore();
      await store.write(OfflineRepository.storageKey, '{"version":999}');
      await expectLater(
        OfflineRepository.open(store, Role.admin),
        throwsA(isA<AppFailure>()),
      );
      expect(await store.read(OfflineRepository.storageKey), '{"version":999}');
    });

    test('local OTP persists attempts and accepts a code only once', () async {
      final repo = await OfflineRepository.open(MemoryStore(), Role.admin);
      final code = await repo.requestOtp('email', 'test@fictional.example');
      await expectLater(
        repo.verifyOtp(code['requestId'], 'incorrect'),
        throwsA(isA<AppFailure>()),
      );
      final verified = await repo.verifyOtp(code['requestId'], code['otp']);
      expect(verified['target'], 'test@fictional.example');
      await expectLater(
        repo.verifyOtp(code['requestId'], code['otp']),
        throwsA(isA<AppFailure>()),
      );
    });
  });

  group('connected repository boundaries', () {
    test('read exhausts pagination without fabricated records', () async {
      final transport = FakeTransport(
        handler: (method, path, data, query) async => {
          'success': true,
          'data': [
            {'id': 'plot-${query['page']}'},
          ],
          'pagination': {'pageCount': 3},
        },
      );
      final repo = ConnectedRepository(
        transport,
        UserIdentity.fromJson(identity()),
      );
      expect((await repo.list(Resource.plots)).map((p) => p['id']), [
        'plot-1',
        'plot-2',
        'plot-3',
      ]);
      expect(transport.calls.length, 3);
    });

    test('forbidden mutations fail before transport call', () async {
      final transport = FakeTransport();
      final repo = ConnectedRepository(
        transport,
        UserIdentity.fromJson(identity(Role.agent)),
      );
      await expectLater(
        repo.create(Resource.leads, {}),
        throwsA(isA<AppFailure>()),
      );
      await expectLater(
        repo.updatePlotCoordinates('p1', {}),
        throwsA(isA<AppFailure>()),
      );
      await expectLater(repo.provisionCustomer({}), throwsA(isA<AppFailure>()));
      expect(transport.calls, isEmpty);
    });
  });
}
