import 'package:dio/dio.dart';

import '../core/models.dart';
import '../core/permissions.dart';
import 'api_transport.dart';
import 'repository.dart';

class ConnectedRepository implements VentureRepository {
  ConnectedRepository(this.transport, this.user, {this.onUnauthorized});
  final ApiTransport transport;
  @override
  final UserIdentity user;
  final void Function()? onUnauthorized;
  @override
  bool get isOffline => false;

  Future<JsonMap> _call(
    String method,
    String path, {
    Object? data,
    JsonMap query = const {},
    void Function(int, int)? onSendProgress,
  }) async {
    try {
      return await transport.request(
        method,
        path,
        data: data,
        query: query,
        onSendProgress: onSendProgress,
      );
    } on AppFailure catch (error) {
      if (error.statusCode == 401) onUnauthorized?.call();
      rethrow;
    }
  }

  String _path(Resource resource, [String? id]) =>
      '${resource.path}${id == null ? '' : '/${Uri.encodeComponent(id)}'}';

  @override
  Future<List<JsonMap>> list(
    Resource resource, {
    JsonMap query = const {},
  }) async {
    Permissions.require(Permissions.canRead(user.role, resource));
    final result = <JsonMap>[];
    var page = 1;
    while (true) {
      final response = await _call(
        'GET',
        _path(resource),
        query: {...query, 'page': page, 'pageSize': 100},
      );
      result.addAll(jsonList(response['data']));
      final pagination = response['pagination'];
      if (pagination is! Map ||
          page >= (pagination['pageCount'] as num? ?? 1)) {
        return result;
      }
      page++;
      if (page > 10000) {
        throw const AppFailure(
          'Too many records to load. Narrow the selection.',
        );
      }
    }
  }

  @override
  Future<JsonMap> detail(Resource resource, String id) async {
    Permissions.require(Permissions.canRead(user.role, resource));
    if ({
      Resource.locations,
      Resource.ventures,
      Resource.plots,
      Resource.agents,
    }.contains(resource)) {
      return jsonObject((await _call('GET', _path(resource, id)))['data']);
    }
    final rows = await list(resource);
    return rows.firstWhere(
      (row) => row['id'] == id,
      orElse: () => throw const AppFailure(
        'This item is no longer available.',
        statusCode: 404,
      ),
    );
  }

  @override
  Future<JsonMap> stats() async {
    if (user.role == Role.customer) {
      // The upstream /stats leaks global totals to customers; derive own counts.
      final plots = await list(Resource.plots);
      final customers = await list(Resource.customers);
      final leads = await list(Resource.leads);
      return {
        'locations': plots
            .map((p) => (p['venture'] as Map?)?['location']?['id'])
            .whereType<String>()
            .toSet()
            .length,
        'plots': plots.length,
        'customers': customers.length,
        'leads': leads.length,
        'employees': 0,
        'plotsByStatus': {
          'available': plots.where((p) => p['status'] == 'AVAILABLE').length,
          'advance': plots.where((p) => p['status'] == 'ADVANCE').length,
          'sold': plots.where((p) => p['status'] == 'SOLD').length,
        },
      };
    }
    return jsonObject((await _call('GET', '/stats'))['data']);
  }

  @override
  Future<JsonMap> create(Resource resource, JsonMap values) async {
    Permissions.require(Permissions.canCreate(user.role, resource));
    return jsonObject(
      (await _call('POST', _path(resource), data: values))['data'],
    );
  }

  @override
  Future<JsonMap> update(Resource resource, String id, JsonMap values) async {
    Permissions.require(Permissions.canUpdate(user.role, resource));
    return jsonObject(
      (await _call('PUT', _path(resource, id), data: values))['data'],
    );
  }

  @override
  Future<void> remove(Resource resource, String id) async {
    Permissions.require(Permissions.canDelete(user.role, resource));
    await _call('DELETE', _path(resource, id));
  }

  @override
  Future<JsonMap> setEmployeeStatus(String id, String status) async {
    Permissions.require(user.role == Role.admin);
    if (!{'ACTIVE', 'FROZEN'}.contains(status)) {
      throw const AppFailure('Choose Active or Frozen.');
    }
    return jsonObject(
      (await _call(
        'POST',
        '/employee-access/employees/${Uri.encodeComponent(id)}/status',
        data: {'status': status},
      ))['data'],
    );
  }

  @override
  Future<JsonMap> updatePlotCoordinates(String id, JsonMap values) async {
    Permissions.require(user.role == Role.admin);
    return jsonObject(
      (await _call(
        'PUT',
        '/plots/${Uri.encodeComponent(id)}/coords',
        data: values,
      ))['data'],
    );
  }

  @override
  Future<List<JsonMap>> updatePlotCoordinatesBatch(List<JsonMap> plots) async {
    Permissions.require(user.role == Role.admin);
    return jsonList(
      (await _call('PUT', '/plots/coords', data: {'plots': plots}))['data'],
    );
  }

  @override
  Future<JsonMap> updateRegions(String ventureId, JsonMap regions) async {
    Permissions.require(user.role == Role.admin);
    return jsonObject(
      (await _call(
        'PUT',
        '/ventures/${Uri.encodeComponent(ventureId)}/regions',
        data: {'regions': regions},
      ))['data'],
    );
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
    final field = layout ? 'layout' : 'photo';
    final form = FormData.fromMap({
      field: MultipartFile.fromBytes(
        bytes,
        filename: filename,
        contentType: DioMediaType.parse(contentType),
      ),
    });
    return jsonObject(
      (await _call(
        'POST',
        '/ventures/${Uri.encodeComponent(id)}/$field',
        data: form,
        onSendProgress: onProgress,
      ))['data'],
    );
  }

  @override
  Future<JsonMap> provisionCustomer(JsonMap values) async {
    Permissions.require(user.role == Role.admin || user.role == Role.employee);
    return jsonObject(
      (await _call('POST', '/auth/customers', data: values))['data'],
    );
  }

  @override
  Future<JsonMap> requestOtp(String type, String target) async {
    Permissions.require(user.role == Role.admin);
    return jsonObject(
      (await _call(
        'POST',
        '/employee-access/otp/request',
        data: {'type': type, 'target': target},
      ))['data'],
    );
  }

  @override
  Future<JsonMap> verifyOtp(String requestId, String otp) async {
    Permissions.require(user.role == Role.admin);
    return jsonObject(
      (await _call(
        'POST',
        '/employee-access/otp/verify',
        data: {'requestId': requestId, 'otp': otp},
      ))['data'],
    );
  }

  @override
  Future<JsonMap> submitInquiry(JsonMap values) async =>
      jsonObject((await _call('POST', '/inquiries', data: values))['data']);

  @override
  Future<void> changePassword(String current, String next) async {
    if (current.length < 6 || next.length < 8) {
      throw const AppFailure('Use a new password with at least 8 characters.');
    }
    await _call(
      'POST',
      '/auth/change-password',
      data: {'currentPassword': current, 'newPassword': next},
    );
  }

  @override
  String? assetUrl(String? path) {
    if (path == null || path.isEmpty) return null;
    final base = Uri.parse(transport.baseUrl);
    final uri = base.resolve(path);
    if (!{'https', 'http'}.contains(uri.scheme)) return null;
    return uri.toString();
  }
}
