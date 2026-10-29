typedef JsonMap = Map<String, dynamic>;

enum Role {
  admin('ADMIN', 'Admin'),
  employee('EMPLOYEE', 'Employee'),
  customer('CUSTOMER', 'Customer'),
  agent('AGENT', 'Agent');

  const Role(this.wireName, this.label);
  final String wireName;
  final String label;

  static Role parse(Object? value) => Role.values.firstWhere(
    (role) => role.wireName == value,
    orElse: () => throw const AppFailure('This account role is not supported.'),
  );
}

enum SessionMode { connected, offlineDemo }

enum Resource {
  locations('/locations'),
  ventures('/ventures'),
  plots('/plots'),
  leads('/leads'),
  customers('/total-data'),
  tracking('/tracking'),
  favorites('/favorites'),
  employees('/employees'),
  admins('/admins'),
  customerAccounts('/customers'),
  agents('/agents'),
  employeeAccess('/employee-access/employees');

  const Resource(this.path);
  final String path;
}

class AppFailure implements Exception {
  const AppFailure(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}

JsonMap jsonObject(Object? value) {
  if (value is! Map) {
    throw const AppFailure('The server returned an unexpected response.');
  }
  return Map<String, dynamic>.from(value);
}

List<JsonMap> jsonList(Object? value) {
  if (value is! List) {
    throw const AppFailure('The server returned an unexpected list.');
  }
  return value.map(jsonObject).toList();
}

String requiredText(JsonMap json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw AppFailure('The response is missing $key.');
  }
  return value;
}

class UserIdentity {
  const UserIdentity({
    required this.id,
    required this.email,
    required this.displayName,
    required this.fullName,
    required this.role,
  });
  final String id, email, displayName, fullName;
  final Role role;

  factory UserIdentity.fromJson(JsonMap json) => UserIdentity(
    id: requiredText(json, 'id'),
    email: requiredText(json, 'email'),
    displayName: requiredText(json, 'displayName'),
    fullName: json['fullName'] as String? ?? requiredText(json, 'displayName'),
    role: Role.parse(json['role']),
  );

  JsonMap toJson() => {
    'id': id,
    'email': email,
    'displayName': displayName,
    'fullName': fullName,
    'role': role.wireName,
  };
}

class LocationData {
  LocationData.fromJson(this.json)
    : id = requiredText(json, 'id'),
      name = requiredText(json, 'name');
  final JsonMap json;
  final String id, name;
  List<VentureData> get ventures =>
      jsonList(json['ventures'] ?? []).map(VentureData.fromJson).toList();
}

class VentureData {
  VentureData.fromJson(this.json)
    : id = requiredText(json, 'id'),
      name = requiredText(json, 'name');
  final JsonMap json;
  final String id, name;
  String? get layoutImage => json['layoutImage'] as String?;
  List<PlotData> get plots =>
      jsonList(json['plots'] ?? []).map(PlotData.fromJson).toList();
}

enum PlotStatus { available, advance, sold }

class PlotData {
  PlotData.fromJson(this.json)
    : id = requiredText(json, 'id'),
      plotNumber = requiredText(json, 'plotNumber'),
      ventureId = requiredText(json, 'ventureId'),
      area = (json['area'] as num).toInt(),
      pricePerSqYard = (json['pricePerSqYard'] as num).toInt(),
      status = switch (json['status']) {
        'AVAILABLE' => PlotStatus.available,
        'ADVANCE' => PlotStatus.advance,
        'SOLD' => PlotStatus.sold,
        _ => throw const AppFailure('Unknown plot status.'),
      };
  final JsonMap json;
  final String id, plotNumber, ventureId;
  final int area, pricePerSqYard;
  final PlotStatus status;
  int get totalValue => area * pricePerSqYard;
}

class LeadData {
  LeadData.fromJson(this.json)
    : id = requiredText(json, 'id'),
      plotId = requiredText(json, 'plotId'),
      customerName = requiredText(json, 'customerName'),
      email = requiredText(json, 'email');
  final JsonMap json;
  final String id, plotId, customerName, email;
}

class CustomerData {
  CustomerData.fromJson(this.json)
    : id = requiredText(json, 'id'),
      contactName = requiredText(json, 'contactName'),
      contactNumber = requiredText(json, 'contactNumber'),
      status = requiredText(json, 'status');
  final JsonMap json;
  final String id, contactName, contactNumber, status;
}

class TrackingData {
  TrackingData.fromJson(this.json)
    : customerId = requiredText(json, 'customerId'),
      latitude = (json['latitude'] as num).toDouble(),
      longitude = (json['longitude'] as num).toDouble(),
      updatedAt = DateTime.parse(requiredText(json, 'updatedAt'));
  final JsonMap json;
  final String customerId;
  final double latitude, longitude;
  final DateTime updatedAt;
}
