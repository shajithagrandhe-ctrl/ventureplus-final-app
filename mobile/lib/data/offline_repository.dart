import 'dart:convert';
import 'dart:math';

import '../core/models.dart';
import '../core/permissions.dart';
import 'demo_data.dart';
import 'repository.dart';
import 'storage.dart';

class OfflineRepository implements VentureRepository {
  OfflineRepository._(this.store, this.user, this._data);
  static const storageKey = 'ventureplus.offline.v1';
  final KeyValueStore store;
  @override
  final UserIdentity user;
  JsonMap _data;
  bool _writing = false;
  @override
  bool get isOffline => true;

  static Future<OfflineRepository> open(KeyValueStore store, Role role) async {
    final saved = await store.read(storageKey);
    final data = saved == null ? seedDemoData() : jsonObject(jsonDecode(saved));
    if (data['version'] != 1) {
      throw const AppFailure('This saved demo uses an unsupported format.');
    }
    for (final key in [
      'users',
      'locations',
      'ventures',
      'plots',
      'leads',
      'customers',
      'tracking',
      'favorites',
      'inquiries',
      'otps',
    ]) {
      jsonList(data[key]);
    }
    final users = jsonList(data['users'])
        .where((u) => u['id'] == demoIdentity(role).id)
        .toList();
    if (users.length != 1) {
      throw const AppFailure('The saved demo identity is missing or invalid.');
    }
    final identity = UserIdentity.fromJson(users.single);
    if (identity.role != role) {
      throw const AppFailure(
        'The saved demo identity does not match the selected role.',
        statusCode: 403,
      );
    }
    if (role == Role.employee) {
      if (jsonObject(users.single['employeeProfile'])['status'] == 'FROZEN') {
        throw const AppFailure(
          'This offline employee is frozen. Choose Admin to reactivate it.',
          statusCode: 403,
        );
      }
    }
    if (saved == null) await store.write(storageKey, jsonEncode(data));
    return OfflineRepository._(store, identity, data);
  }

  List<JsonMap> _rows(String name, [JsonMap? data]) =>
      (data ?? _data)[name] is List
      ? ((data ?? _data)[name] as List).cast<JsonMap>()
      : <JsonMap>[];
  JsonMap _copy(JsonMap value) => jsonObject(jsonDecode(jsonEncode(value)));
  String _id(String prefix) =>
      '$prefix-${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(10000)}';
  String get _now => DateTime.now().toUtc().toIso8601String();
  JsonMap _find(String table, String id, [JsonMap? data]) =>
      _rows(table, data).firstWhere(
        (row) => row['id'] == id,
        orElse: () => throw const AppFailure(
          'This demo item was not found.',
          statusCode: 404,
        ),
      );

  Future<T> _write<T>(T Function(JsonMap) action) async {
    if (_writing) throw const AppFailure('A save is already in progress.');
    _writing = true;
    try {
      final next = _copy(_data);
      final result = action(next);
      await store.write(storageKey, jsonEncode(next));
      _data = next;
      return result;
    } finally {
      _writing = false;
    }
  }

  Set<String> _visibleVentureIds([JsonMap? source]) {
    final data = source ?? _data;
    if (user.role == Role.customer) {
      final ids = _rows('leads', data)
          .where((lead) => lead['email'] == user.email)
          .map((lead) => lead['plotId'])
          .toSet();
      return _rows('plots', data)
          .where((plot) => ids.contains(plot['id']))
          .map((plot) => plot['ventureId'] as String)
          .toSet();
    }
    if (user.role == Role.employee) {
      final profile = jsonObject(
        _find('users', user.id, data)['employeeProfile'],
      );
      if (profile['status'] == 'FROZEN') return {};
      final locations = (profile['assignedLocationIds'] as List? ?? []).toSet();
      return {
        ...(profile['assignedVentureIds'] as List? ?? []).cast<String>(),
        ..._rows('ventures', data)
            .where((v) => locations.contains(v['locationId']))
            .map((v) => v['id'] as String),
      };
    }
    return _rows('ventures', data).map((v) => v['id'] as String).toSet();
  }

  List<JsonMap> _plots([JsonMap? source]) {
    final data = source ?? _data;
    final ventures = _visibleVentureIds(data);
    final own = _rows('leads', data)
        .where((lead) => lead['email'] == user.email)
        .map((lead) => lead['plotId'])
        .toSet();
    return _rows('plots', data)
        .where(
          (p) =>
              ventures.contains(p['ventureId']) &&
              (user.role != Role.customer || own.contains(p['id'])),
        )
        .toList();
  }

  List<JsonMap> _customers([JsonMap? source]) => _rows('customers', source)
      .where(
        (c) => switch (user.role) {
          Role.customer => c['customerEmail'] == user.email,
          Role.employee =>
            [
                  user.fullName,
                  user.displayName,
                  user.email,
                ].contains(c['recordOwner']) ||
                [
                  user.fullName,
                  user.displayName,
                  user.email,
                ].contains(c['leadName']),
          _ => true,
        },
      )
      .toList();

  JsonMap _decoratePlot(JsonMap plot) {
    final venture = _find('ventures', plot['ventureId'] as String);
    return {
      ...plot,
      'venture': {
        ...venture,
        'location': _find('locations', venture['locationId'] as String),
      },
      'leads': _rows('leads')
          .where(
            (lead) =>
                lead['plotId'] == plot['id'] &&
                (user.role != Role.customer || lead['email'] == user.email),
          )
          .toList(),
    };
  }

  JsonMap _decorateVenture(JsonMap venture) => {
    ...venture,
    'location': _find('locations', venture['locationId'] as String),
    'plots': _plots()
        .where((p) => p['ventureId'] == venture['id'])
        .map(_decoratePlot)
        .toList(),
  };

  @override
  Future<List<JsonMap>> list(
    Resource resource, {
    JsonMap query = const {},
  }) async {
    Permissions.require(Permissions.canRead(user.role, resource));
    final ventures = _visibleVentureIds();
    final visiblePlots = _plots();
    List<JsonMap> result = switch (resource) {
      Resource.locations =>
        _rows('locations')
            .where(
              (l) => _rows('ventures').any(
                (v) => v['locationId'] == l['id'] && ventures.contains(v['id']),
              ),
            )
            .map((location) {
              final children = _rows('ventures')
                  .where(
                    (v) =>
                        v['locationId'] == location['id'] &&
                        ventures.contains(v['id']),
                  )
                  .map(_decorateVenture)
                  .map((v) {
                    final plots = jsonList(v['plots']);
                    return {
                      ...v,
                      'plotCount': plots.length,
                      'photoUrl': v['layoutImage'],
                      'availablePlots': plots
                          .where((p) => p['status'] == 'AVAILABLE')
                          .length,
                      'soldPlots': plots
                          .where((p) => p['status'] == 'SOLD')
                          .length,
                    };
                  })
                  .toList();
              return {
                ...location,
                'ventures': children,
                'availablePlots': children.fold<int>(
                  0,
                  (sum, v) => sum + (v['availablePlots'] as int),
                ),
              };
            })
            .toList(),
      Resource.ventures => _rows(
        'ventures',
      ).where((v) => ventures.contains(v['id'])).map(_decorateVenture).toList(),
      Resource.plots => visiblePlots.map(_decoratePlot).toList(),
      Resource.leads =>
        _rows('leads')
            .where(
              (l) =>
                  visiblePlots.any((p) => p['id'] == l['plotId']) &&
                  (user.role != Role.customer || l['email'] == user.email),
            )
            .map(
              (l) => {
                ...l,
                'plot': _decoratePlot(_find('plots', l['plotId'] as String)),
              },
            )
            .toList(),
      Resource.customers => _customers(),
      Resource.tracking =>
        _rows('tracking')
            .where(
              (t) =>
                  (user.role != Role.customer && user.role != Role.employee) ||
                  _customers().any((c) => c['id'] == t['customerId']),
            )
            .toList(),
      Resource.favorites =>
        _rows('favorites')
            .where(
              (f) =>
                  f['userId'] == user.id &&
                  visiblePlots.any((p) => p['id'] == f['plotId']),
            )
            .map(
              (f) => {
                ...f,
                'plot': _decoratePlot(_find('plots', f['plotId'] as String)),
              },
            )
            .toList(),
      Resource.employees || Resource.employeeAccess => _rows(
        'users',
      ).where((u) => u['role'] == 'EMPLOYEE').toList(),
      Resource.admins => _rows(
        'users',
      ).where((u) => u['role'] == 'ADMIN').toList(),
      Resource.customerAccounts => _rows(
        'users',
      ).where((u) => u['role'] == 'CUSTOMER').toList(),
      Resource.agents => _rows(
        'users',
      ).where((u) => {'AGENT', 'EMPLOYEE'}.contains(u['role'])).toList(),
    };
    for (final key in ['ventureId', 'locationId', 'status', 'plotId']) {
      if (query[key] != null) {
        result = result.where((row) => row[key] == query[key]).toList();
      }
    }
    return result.map(_copy).toList();
  }

  @override
  Future<JsonMap> detail(Resource resource, String id) async =>
      (await list(resource)).firstWhere(
        (row) => row['id'] == id,
        orElse: () => throw const AppFailure(
          'This item is unavailable to this demo role.',
          statusCode: 404,
        ),
      );

  @override
  Future<JsonMap> stats() async {
    final plots = await list(Resource.plots);
    final customers = await list(Resource.customers);
    final leads = await list(Resource.leads);
    return {
      'locations': (await list(Resource.locations)).length,
      'plots': plots.length,
      'customers': customers.length,
      'leads': leads.length,
      'employees': user.role == Role.admin
          ? _rows('users').where((u) => u['role'] == 'EMPLOYEE').length
          : 0,
      'plotsByStatus': {
        'available': plots.where((p) => p['status'] == 'AVAILABLE').length,
        'advance': plots.where((p) => p['status'] == 'ADVANCE').length,
        'sold': plots.where((p) => p['status'] == 'SOLD').length,
      },
    };
  }

  void _text(JsonMap values, String key, int minimum) {
    if ((values[key] as String? ?? '').trim().length < minimum) {
      throw AppFailure('$key must contain at least $minimum characters.');
    }
  }

  void _password(JsonMap values, int minimum) {
    final value = values['password'];
    if (value is! String || value.length < minimum) {
      throw AppFailure('password must contain at least $minimum characters.');
    }
  }

  void _number(JsonMap values, String key, {int maximum = 2147483647}) {
    final value = values[key];
    if (value is! num ||
        value != value.round() ||
        value < 1 ||
        value > maximum) {
      throw AppFailure('$key must be a positive whole number up to $maximum.');
    }
  }

  void _email(JsonMap values, String key) {
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
        .hasMatch(values[key] as String? ?? '')) {
      throw const AppFailure('Enter a valid email address.');
    }
  }

  void _status(JsonMap values, String key, Set<String> statuses) {
    if (values[key] != null && !statuses.contains(values[key])) {
      throw AppFailure('Choose a valid $key.');
    }
  }

  @override
  Future<JsonMap> create(Resource resource, JsonMap values) async {
    Permissions.require(Permissions.canCreate(user.role, resource));
    return _write((data) {
      final value = _copy(values);
      final now = _now;
      final row = <String, dynamic>{
        ...value,
        'id': _id('demo-${resource.name}'),
        'createdAt': now,
        'updatedAt': now,
      };
      switch (resource) {
        case Resource.ventures:
          _text(value, 'name', 1);
          _text(value, 'locationName', 1);
          _number(value, 'plotCount', maximum: 200);
          _number(value, 'defaultArea');
          _number(value, 'defaultPricePerSqYard');
          JsonMap? location;
          for (final candidate in _rows('locations', data)) {
            if (candidate['name'] == value['locationName']) {
              location = candidate;
            }
          }
          location ??= {
            'id': _id('demo-location'),
            'name': value['locationName'],
          };
          if (!_rows('locations', data).contains(location)) {
            _rows('locations', data).add(location);
          }
          row['locationId'] = location['id'];
          row['layoutImage'] = null;
          row['layoutRegions'] = {'roads': [], 'parks': []};
          _rows('ventures', data).add(row);
          for (var i = 0; i < (value['plotCount'] as num).toInt(); i++) {
            _rows('plots', data).add({
              'id': _id('demo-plot'),
              'ventureId': row['id'],
              'plotNumber':
                  '${value['plotNumberPrefix'] ?? 'Plot '}${((value['startingPlotNumber'] as num?)?.toInt() ?? 1) + i}',
              'area': value['defaultArea'],
              'pricePerSqYard': value['defaultPricePerSqYard'],
              'status': 'AVAILABLE',
              'createdAt': now,
              'updatedAt': now,
            });
          }
        case Resource.leads:
          _text(value, 'customerName', 2);
          _email(value, 'email');
          _text(value, 'contactNumber', 6);
          _text(value, 'location', 2);
          _text(value, 'uniqueId', 3);
          _number(value, 'pricePerSqYard');
          final plot = _find('plots', requiredText(value, 'plotId'), data);
          Permissions.require(_plots(data).any((p) => p['id'] == plot['id']));
          if (_rows(
            'leads',
            data,
          ).any((l) => l['uniqueId'] == value['uniqueId'])) {
            throw const AppFailure('This unique ID already exists.');
          }
          row['status'] = 'NEW';
          if (user.role == Role.employee) {
            row['agentId'] = user.id;
          } else {
            row['agentId'] ??= user.id;
          }
          _rows('leads', data).add(row);
          _rows('customers', data).add({
            'id': _id('demo-record'),
            'contactName': value['customerName'],
            'contactNumber': value['contactNumber'],
            'location': value['location'],
            'budget': '${value['pricePerSqYard']}',
            'status': 'HOT_LEAD',
            'interested': true,
            'recordOwner': requiredText(
              _find('users', row['agentId'] as String, data),
              'email',
            ),
            'leadName': requiredText(
              _find('users', row['agentId'] as String, data),
              'email',
            ),
            'customerEmail': value['email'],
            'notes': 'Email: ${value['email']}\n${value['notes'] ?? ''}',
            'createdAt': now,
            'updatedAt': now,
          });
        case Resource.customers:
          _validateCustomer(value);
          row['status'] ??= 'FOLLOWING_UP';
          row['interested'] ??= row['status'] != 'FOLLOWING_UP';
          if (user.role == Role.employee) {
            row['recordOwner'] = user.email;
            row['leadName'] = user.email;
          }
          // Customer access is established by a lead, never by editable notes.
          row['customerEmail'] = null;
          _rows('customers', data).add(row);
        case Resource.favorites:
          final plotId = requiredText(value, 'plotId');
          Permissions.require(_plots(data).any((p) => p['id'] == plotId));
          if (_rows(
            'favorites',
            data,
          ).any((f) => f['userId'] == user.id && f['plotId'] == plotId)) {
            throw const AppFailure('This plot is already saved.');
          }
          row['userId'] = user.id;
          _rows('favorites', data).add(row);
        case Resource.tracking:
          _validateTracking(value);
          _find('customers', requiredText(value, 'customerId'), data);
          if (user.role == Role.employee) {
            Permissions.require(
              _customers(data).any((c) => c['id'] == value['customerId']),
            );
          }
          _rows(
            'tracking',
            data,
          ).removeWhere((t) => t['customerId'] == value['customerId']);
          row['status'] = (value['status'] as String? ?? 'ACTIVE')
              .toUpperCase();
          row['updatedBy'] = user.id;
          _rows('tracking', data).add(row);
        case Resource.employeeAccess:
          _email(value, 'email');
          _password(value, 6);
          if (_rows('users', data).any((u) => u['email'] == value['email'])) {
            throw const AppFailure('This email is already in use in the demo.');
          }
          row.remove('password');
          row['role'] = 'EMPLOYEE';
          row['fullName'] ??= value['displayName'] ?? value['email'];
          row['displayName'] ??= row['fullName'];
          row['employeeProfile'] = {
            ...value,
            'status': value['status'] ?? 'ACTIVE',
          }..remove('password');
          _rows('users', data).add(row);
        default:
          throw const AppFailure('This action is not supported.');
      }
      return _copy(row);
    });
  }

  void _validateCustomer(JsonMap value) {
    for (final key in ['contactName', 'location', 'recordOwner']) {
      _text(value, key, 2);
    }
    _text(value, 'contactNumber', 6);
    _text(value, 'budget', 1);
    _status(value, 'status', {
      'HOT_LEAD',
      'FOLLOWING_UP',
      'CONFIRMED_NOT_PAID',
      'PAID_ADVANCE',
      'BOOKED',
    });
  }

  void _validateTracking(JsonMap value) {
    final lat = value['latitude'];
    final lng = value['longitude'];
    if (lat is! num ||
        lng is! num ||
        !lat.isFinite ||
        !lng.isFinite ||
        lat < -90 ||
        lat > 90 ||
        lng < -180 ||
        lng > 180) {
      throw const AppFailure('Enter valid latitude and longitude coordinates.');
    }
    if (value['status'] != null) {
      value['status'] = (value['status'] as String).toUpperCase();
    }
    _status(value, 'status', {'ACTIVE', 'INACTIVE', 'MOVING'});
  }

  @override
  Future<JsonMap> update(Resource resource, String id, JsonMap values) async {
    Permissions.require(Permissions.canUpdate(user.role, resource));
    if (resource == Resource.employeeAccess &&
        (values['password'] as String? ?? '').isNotEmpty) {
      throw const AppFailure(
        'Offline employee profiles have no account password. Clear the password field to save profile details.',
      );
    }
    return _write((data) {
      final table = resource == Resource.employeeAccess
          ? 'users'
          : resource.name;
      final row = _find(table, id, data);
      if (resource == Resource.employeeAccess &&
          values.containsKey('email') &&
          values['email'] != row['email']) {
        throw const AppFailure(
          'Employee email cannot be changed because it identifies existing record ownership.',
          statusCode: 400,
        );
      }
      final value = _copy(values)
        ..remove('id')
        ..remove('role')
        ..remove('password');
      if (resource == Resource.plots) {
        Permissions.require(_plots(data).any((p) => p['id'] == id));
        _status(value, 'status', {'AVAILABLE', 'ADVANCE', 'SOLD'});
        for (final key in ['area', 'pricePerSqYard']) {
          if (value[key] != null) _number(value, key);
        }
      }
      if (resource == Resource.leads) {
        Permissions.require(_plots(data).any((p) => p['id'] == row['plotId']));
        _status(value, 'status', {
          'NEW',
          'FOLLOW_UP',
          'QUALIFIED',
          'WON',
          'LOST',
        });
        if (value['pricePerSqYard'] != null) _number(value, 'pricePerSqYard');
      }
      if (resource == Resource.customers) {
        Permissions.require(_customers(data).any((c) => c['id'] == id));
        _validateCustomer(value);
        if (user.role == Role.employee) {
          value['recordOwner'] = user.email;
          value['leadName'] = user.email;
        }
        value.remove('customerEmail');
      }
      if (resource == Resource.employeeAccess) {
        Permissions.require(row['role'] == 'EMPLOYEE');
        row['employeeProfile'] = {
          ...jsonObject(row['employeeProfile'] ?? {}),
          ...value,
        };
      }
      row.addAll(value);
      row['updatedAt'] = _now;
      return _copy(row);
    });
  }

  @override
  Future<void> remove(Resource resource, String id) async {
    Permissions.require(Permissions.canDelete(user.role, resource));
    await _write((data) {
      if (resource == Resource.favorites) {
        _rows(
          'favorites',
          data,
        ).removeWhere((f) => f['userId'] == user.id && f['plotId'] == id);
      } else {
        final row = _find(resource.name, id, data);
        if (resource == Resource.leads) {
          Permissions.require(
            _plots(data).any((p) => p['id'] == row['plotId']),
          );
        }
        if (resource == Resource.customers) {
          Permissions.require(_customers(data).any((c) => c['id'] == id));
          _rows('tracking', data).removeWhere((t) => t['customerId'] == id);
        }
        _rows(resource.name, data).removeWhere((row) => row['id'] == id);
      }
    });
  }

  @override
  Future<JsonMap> setEmployeeStatus(String id, String status) async {
    Permissions.require(user.role == Role.admin);
    _status({'status': status}, 'status', {'ACTIVE', 'FROZEN'});
    return update(Resource.employeeAccess, id, {'status': status});
  }

  void _validateCoords(JsonMap value, {bool point = false}) {
    if (point && (value['x'] == null || value['y'] == null)) {
      throw const AppFailure('Every point needs x and y coordinates.');
    }
    if (![
      'x',
      'y',
      'width',
      'height',
      'shapeData',
    ].any((key) => value[key] != null)) {
      throw const AppFailure('Provide coordinates or a polygon shape.');
    }
    for (final key in ['x', 'y', 'width', 'height']) {
      if (value[key] != null &&
          (value[key] is! num ||
              !(value[key] as num).isFinite ||
              value[key] < 0 ||
              value[key] > 1)) {
        throw const AppFailure('Layout coordinates must be between 0 and 1.');
      }
    }
    if (value['shapeData'] != null) {
      final shape = jsonObject(value['shapeData']);
      final points = jsonList(shape['points']);
      if (shape['type'] != 'polygon' || points.length < 3) {
        throw const AppFailure('A plot polygon needs at least three points.');
      }
      for (final point in points) {
        _validateCoords(point, point: true);
      }
    }
  }

  @override
  Future<JsonMap> updatePlotCoordinates(String id, JsonMap values) async =>
      (await updatePlotCoordinatesBatch([
        {...values, 'id': id},
      ])).single;

  @override
  Future<List<JsonMap>> updatePlotCoordinatesBatch(List<JsonMap> plots) async {
    Permissions.require(user.role == Role.admin);
    return _write(
      (data) => plots.map((value) {
        _validateCoords(value);
        final row = _find('plots', requiredText(value, 'id'), data);
        for (final key in ['x', 'y', 'width', 'height', 'shapeData']) {
          if (value[key] != null) row[key] = value[key];
        }
        return _copy(row);
      }).toList(),
    );
  }

  @override
  Future<JsonMap> updateRegions(String ventureId, JsonMap regions) async {
    Permissions.require(user.role == Role.admin);
    for (final key in ['roads', 'parks']) {
      final items = jsonList(regions[key]);
      if (items.length > 200) {
        throw const AppFailure('Use at most 200 regions of each kind.');
      }
      for (final region in items) {
        final points = jsonList(region['points']);
        if (points.length < 3 || points.length > 500) {
          throw const AppFailure('Each region needs 3 to 500 points.');
        }
        for (final point in points) {
          _validateCoords(point, point: true);
        }
      }
    }
    return _write((data) {
      final venture = _find('ventures', ventureId, data);
      venture['layoutRegions'] = _copy(regions);
      return _copy(venture);
    });
  }

  @override
  Future<JsonMap> uploadVenture(
    String id,
    List<int> bytes,
    String filename, {
    required bool layout,
    required String contentType,
    void Function(int, int)? onProgress,
  }) async {
    Permissions.require(user.role == Role.admin);
    validateUpload(bytes, layout, contentType);
    final result = await _write((data) {
      final venture = _find('ventures', id, data);
      venture['layoutImage'] =
          'data:$contentType;base64,${base64Encode(bytes)}';
      venture['localFilename'] = filename;
      return _copy(venture);
    });
    onProgress?.call(bytes.length, bytes.length);
    return result;
  }

  @override
  Future<JsonMap> provisionCustomer(JsonMap values) async {
    Permissions.require(user.role == Role.admin || user.role == Role.employee);
    _email(values, 'email');
    _password(values, 8);
    _text(values, 'displayName', 2);
    _text(values, 'fullName', 2);
    return _write((data) {
      if (_rows('users', data).any((u) => u['email'] == values['email'])) {
        throw const AppFailure('This email already exists in the local demo.');
      }
      final account = {
        ...values,
        'id': _id('demo-customer'),
        'role': 'CUSTOMER',
      }..remove('password');
      _rows('users', data).add(account);
      return {'user': _copy(account), 'localOnly': true};
    });
  }

  @override
  Future<JsonMap> requestOtp(String type, String target) async {
    Permissions.require(user.role == Role.admin);
    if (!{'email', 'phone'}.contains(type) || target.trim().length < 3) {
      throw const AppFailure('Enter an email address or phone number.');
    }
    return _write((data) {
      final item = {
        'id': _id('demo-otp'),
        'requestId': _id('demo-request'),
        'type': type,
        'target': target,
        'otp': Random.secure().nextInt(1000000).toString().padLeft(6, '0'),
        'expiresAt': DateTime.now()
            .add(const Duration(minutes: 5))
            .millisecondsSinceEpoch,
        'attempts': 0,
        'verified': false,
      };
      _rows('otps', data).add(item);
      return _copy(item);
    });
  }

  @override
  Future<JsonMap> verifyOtp(String requestId, String otp) async {
    Permissions.require(user.role == Role.admin);
    final result = await _write((data) {
      final item = _rows('otps', data).firstWhere(
        (o) => o['requestId'] == requestId,
        orElse: () => throw const AppFailure('Request a new demo code.'),
      );
      if (item['verified'] == true ||
          (item['attempts'] as int) >= 5 ||
          (item['expiresAt'] as int) <= DateTime.now().millisecondsSinceEpoch) {
        throw const AppFailure('The code expired or was already used.');
      }
      item['attempts'] = (item['attempts'] as int) + 1;
      if (item['otp'] != otp.trim()) return <String, dynamic>{'invalid': true};
      item['verified'] = true;
      return <String, dynamic>{
        'type': item['type'],
        'target': item['target'],
        'verifiedAt': DateTime.now().millisecondsSinceEpoch,
      };
    });
    if (result['invalid'] == true) {
      throw const AppFailure('The demo code does not match.');
    }
    return result;
  }

  @override
  Future<JsonMap> submitInquiry(JsonMap values) async {
    _text(values, 'customerName', 2);
    _email(values, 'customerEmail');
    _text(values, 'message', 10);
    return _write((data) {
      final inquiry = {...values, 'id': _id('demo-inquiry'), 'createdAt': _now};
      _rows('inquiries', data).add(inquiry);
      return _copy(inquiry);
    });
  }

  @override
  Future<void> changePassword(String current, String next) async {
    throw const AppFailure(
      'Offline Demo uses local role selection and has no account password.',
    );
  }

  @override
  String? assetUrl(String? path) =>
      path != null && path.startsWith('data:') ? path : null;
}
