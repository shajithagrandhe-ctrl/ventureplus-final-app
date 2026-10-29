import '../core/models.dart';

abstract class VentureRepository {
  UserIdentity get user;
  bool get isOffline;
  Future<List<JsonMap>> list(Resource resource, {JsonMap query = const {}});
  Future<JsonMap> detail(Resource resource, String id);
  Future<JsonMap> stats();
  Future<JsonMap> create(Resource resource, JsonMap values);
  Future<JsonMap> update(Resource resource, String id, JsonMap values);
  Future<void> remove(Resource resource, String id);
  Future<JsonMap> setEmployeeStatus(String id, String status);
  Future<JsonMap> updatePlotCoordinates(String id, JsonMap values);
  Future<List<JsonMap>> updatePlotCoordinatesBatch(List<JsonMap> plots);
  Future<JsonMap> updateRegions(String ventureId, JsonMap regions);
  Future<JsonMap> uploadVenture(
    String id,
    List<int> bytes,
    String filename, {
    required bool layout,
    required String contentType,
    void Function(int, int)? onProgress,
  });
  Future<JsonMap> provisionCustomer(JsonMap values);
  Future<JsonMap> requestOtp(String type, String target);
  Future<JsonMap> verifyOtp(String requestId, String otp);
  Future<JsonMap> submitInquiry(JsonMap values);
  Future<void> changePassword(String current, String next);
  String? assetUrl(String? path);
}

void validateUpload(List<int> bytes, bool layout, String contentType) {
  final accepted = layout
      ? {
          'application/pdf',
          'image/png',
          'image/jpeg',
          'image/jpg',
          'image/svg+xml',
        }
      : {'image/png', 'image/jpeg', 'image/jpg', 'image/webp'};
  if (bytes.isEmpty || bytes.length > 4 * 1024 * 1024) {
    throw const AppFailure('Choose a nonempty file no larger than 4 MiB.');
  }
  if (!accepted.contains(contentType)) {
    throw const AppFailure('This file type is not supported for this upload.');
  }
}
