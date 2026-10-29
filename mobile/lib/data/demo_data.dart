import '../core/models.dart';

UserIdentity demoIdentity(Role role) => UserIdentity(
  id: 'demo-${role.name}',
  email: '${role.name}@fictional.example',
  displayName: switch (role) {
    Role.admin => 'Aarav Rao',
    Role.employee => 'Maya Sen',
    Role.customer => 'Riya Shah',
    Role.agent => 'Dev Mehta',
  },
  fullName: switch (role) {
    Role.admin => 'Aarav Rao',
    Role.employee => 'Maya Sen',
    Role.customer => 'Riya Shah',
    Role.agent => 'Dev Mehta',
  },
  role: role,
);

JsonMap seedDemoData() {
  const created = '2026-10-01T09:00:00.000Z';
  final users = Role.values
      .map(
        (role) => {
          ...demoIdentity(role).toJson(),
          'createdAt': created,
          if (role == Role.employee)
            'employeeProfile': {
              'status': 'ACTIVE',
              'assignedLocationIds': ['demo-loc-1'],
              'assignedVentureIds': ['demo-venture-1'],
              'emailVerified': false,
              'phoneVerified': false,
            },
        },
      )
      .toList();
  final plots = List<JsonMap>.generate(12, (index) {
    final first = index < 8;
    return {
      'id': 'demo-plot-${index + 1}',
      'plotNumber': '${first ? 'H' : 'O'}-${(first ? index : index - 8) + 101}',
      'ventureId': first ? 'demo-venture-1' : 'demo-venture-2',
      'area': [180, 200, 240][index % 3],
      'pricePerSqYard': first ? 24000 : 18500,
      'status': index == 0
          ? 'ADVANCE'
          : index == 1 || index == 8
          ? 'SOLD'
          : 'AVAILABLE',
      'x': 0.08 + (index % 4) * 0.22,
      'y': 0.12 + (index ~/ 4 % 2) * 0.38,
      'width': 0.17,
      'height': 0.25,
      'createdAt': created,
      'updatedAt': created,
    };
  });
  return {
    'version': 1,
    'users': users,
    'locations': [
      {'id': 'demo-loc-1', 'name': 'Harbour district · Fictional'},
      {'id': 'demo-loc-2', 'name': 'Orchard district · Fictional'},
    ],
    'ventures': [
      {
        'id': 'demo-venture-1',
        'name': 'Sage Harbour',
        'locationId': 'demo-loc-1',
        'layoutImage': null,
        'layoutRegions': {'roads': [], 'parks': []},
        'createdAt': created,
      },
      {
        'id': 'demo-venture-2',
        'name': 'Walnut Grove',
        'locationId': 'demo-loc-2',
        'layoutImage': null,
        'layoutRegions': {'roads': [], 'parks': []},
        'createdAt': created,
      },
    ],
    'plots': plots,
    'leads': [
      {
        'id': 'demo-lead-1',
        'plotId': 'demo-plot-1',
        'customerName': 'Riya Shah',
        'email': 'customer@fictional.example',
        'contactNumber': '+91 00000 00101',
        'location': 'Harbour district · Fictional',
        'uniqueId': 'DEMO-RIYA-001',
        'pricePerSqYard': 24000,
        'status': 'FOLLOW_UP',
        'agentId': 'demo-employee',
        'notes':
            'Fictional presentation record. Confirm the preferred visit date.',
        'createdAt': created,
        'updatedAt': created,
      },
      {
        'id': 'demo-lead-2',
        'plotId': 'demo-plot-9',
        'customerName': 'Kabir Das',
        'email': 'kabir@fictional.example',
        'contactNumber': '+91 00000 00202',
        'location': 'Orchard district · Fictional',
        'uniqueId': 'DEMO-KABIR-002',
        'pricePerSqYard': 18500,
        'status': 'WON',
        'agentId': 'demo-agent',
        'notes': 'Fictional presentation record.',
        'createdAt': created,
        'updatedAt': created,
      },
    ],
    'customers': [
      {
        'id': 'demo-record-1',
        'contactName': 'Riya Shah',
        'contactNumber': '+91 00000 00101',
        'location': 'Harbour district · Fictional',
        'budget': '4500000',
        'interested': true,
        'status': 'PAID_ADVANCE',
        'recordOwner': 'employee@fictional.example',
        'leadName': 'employee@fictional.example',
        'customerEmail': 'customer@fictional.example',
        'notes': 'Venture: Sage Harbour\nPlot Interested: H-101\nEmail: customer@fictional.example\nFictional presentation record.',
        'createdAt': created,
        'updatedAt': created,
      },
      {
        'id': 'demo-record-2',
        'contactName': 'Kabir Das',
        'contactNumber': '+91 00000 00202',
        'location': 'Orchard district · Fictional',
        'budget': '4440000',
        'interested': true,
        'status': 'BOOKED',
        'recordOwner': 'agent@fictional.example',
        'leadName': 'agent@fictional.example',
        'customerEmail': 'kabir@fictional.example',
        'notes': 'Venture: Walnut Grove\nEmail: kabir@fictional.example\nFictional presentation record.',
        'createdAt': created,
        'updatedAt': created,
      },
    ],
    'tracking': [
      {
        'id': 'demo-tracking-1',
        'customerId': 'demo-record-1',
        'latitude': 17.71,
        'longitude': 83.30,
        'status': 'ACTIVE',
        'address': 'Fictional site visit point',
        'updatedAt': created,
        'updatedBy': 'demo-employee',
      },
    ],
    'favorites': [],
    'inquiries': [],
    'otps': [],
  };
}
