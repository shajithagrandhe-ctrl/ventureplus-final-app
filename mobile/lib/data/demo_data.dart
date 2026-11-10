import 'dart:convert';

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
  const updated = '2026-10-24T09:00:00.000Z';
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
              'department': 'Client Advisory',
              'position': 'Senior Relationship Executive',
              'employeeId': 'VP-EMP-001',
              'phoneNumber': '+91 90000 00101',
              'dateOfJoining': '2024-04-15',
              'yearsOfExperience': 6,
              'achievements': 'Top follow-up completion · Q3 fictional demo',
              'emailVerified': false,
              'phoneVerified': false,
            },
        },
      )
      .toList();
  users.firstWhere((user) => user['role'] == 'ADMIN')['adminProfile'] = {
    'department': 'Executive Operations',
    'position': 'Portfolio Director',
    'employeeId': 'VP-ADM-001',
    'phoneNumber': '+91 90000 00001',
    'dateOfJoining': '2022-06-01',
    'yearsOfExperience': 12,
  };
  users.firstWhere((user) => user['role'] == 'CUSTOMER')['customerProfile'] = {
    'customerId': 'VP-CUS-001',
    'phoneNumber': '+91 90000 00101',
    'preferredContact': 'WhatsApp',
    'customerSince': '2026-08-15',
  };
  users.firstWhere((user) => user['role'] == 'AGENT')['agentProfile'] = {
    'agentId': 'VP-AGT-001',
    'agency': 'Fictional Partner Network',
    'phoneNumber': '+91 90000 00404',
    'status': 'ACTIVE',
  };
  users.add({
    'id': 'demo-customer-2',
    'email': 'nisha@fictional.example',
    'displayName': 'Nisha Iyer',
    'fullName': 'Nisha Iyer',
    'role': 'CUSTOMER',
    'createdAt': created,
    'customerProfile': {
      'customerId': 'VP-CUS-002',
      'phoneNumber': '+91 90000 00303',
      'preferredContact': 'Email',
      'customerSince': '2026-09-04',
    },
  });
  users.add({
    'id': 'demo-employee-2',
    'email': 'arjun.employee@fictional.example',
    'displayName': 'Arjun Kulkarni',
    'fullName': 'Arjun Kulkarni',
    'role': 'EMPLOYEE',
    'createdAt': created,
    'employeeProfile': {
      'status': 'ACTIVE',
      'assignedLocationIds': ['demo-loc-2'],
      'assignedVentureIds': ['demo-venture-2'],
      'department': 'Site Operations',
      'position': 'Property Advisor',
      'employeeId': 'VP-EMP-002',
      'phoneNumber': '+91 90000 00202',
      'dateOfJoining': '2025-01-20',
      'yearsOfExperience': 4,
      'achievements': 'Highest fictional conversion rate · September',
      'emailVerified': true,
      'phoneVerified': true,
    },
  });
  users.add({
    'id': 'demo-employee-3',
    'email': 'priya.employee@fictional.example',
    'displayName': 'Priya Nair',
    'fullName': 'Priya Nair',
    'role': 'EMPLOYEE',
    'createdAt': created,
    'employeeProfile': {
      'status': 'ACTIVE',
      'assignedLocationIds': ['demo-loc-3'],
      'assignedVentureIds': ['demo-venture-3'],
      'department': 'Client Experience',
      'position': 'Senior Sales Advisor',
      'employeeId': 'VP-EMP-003',
      'phoneNumber': '+91 90000 00505',
      'dateOfJoining': '2025-06-12',
      'yearsOfExperience': 5,
      'achievements': 'Highest fictional customer satisfaction score',
      'emailVerified': true,
      'phoneVerified': true,
    },
  });
  users.add({
    'id': 'demo-customer-3',
    'email': 'vikram@fictional.example',
    'displayName': 'Vikram Rao',
    'fullName': 'Vikram Rao',
    'role': 'CUSTOMER',
    'createdAt': created,
    'customerProfile': {
      'customerId': 'VP-CUS-003',
      'phoneNumber': '+91 90000 00606',
      'preferredContact': 'Phone',
      'customerSince': '2026-09-18',
    },
  });
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
  plots.addAll(
    List<JsonMap>.generate(6, (offset) {
      final index = offset + 1;
      return {
        'id': 'demo-plot-${12 + index}',
        'plotNumber': 'C-${100 + index}',
        'ventureId': 'demo-venture-3',
        'area': [160, 180, 220][offset % 3],
        'pricePerSqYard': 21000,
        'status': offset == 0
            ? 'ADVANCE'
            : offset == 1
            ? 'SOLD'
            : 'AVAILABLE',
        'x': 0.08 + (offset % 3) * 0.27,
        'y': 0.15 + (offset ~/ 3) * 0.4,
        'width': 0.2,
        'height': 0.25,
        'createdAt': created,
        'updatedAt': updated,
      };
    }),
  );
  final leads = [
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
      'followUpDate': '2026-10-28',
      'notes':
          'Fictional presentation record. Confirm the preferred visit date.',
      'createdAt': created,
      'updatedAt': updated,
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
      'agentId': 'demo-employee-2',
      'followUpDate': '2026-10-26',
      'notes': 'Fictional presentation record.',
      'createdAt': created,
      'updatedAt': updated,
    },
    {
      'id': 'demo-lead-3',
      'plotId': 'demo-plot-2',
      'customerName': 'Riya Shah',
      'email': 'customer@fictional.example',
      'contactNumber': '+91 00000 00101',
      'location': 'Harbour district · Fictional',
      'uniqueId': 'DEMO-RIYA-003',
      'pricePerSqYard': 24000,
      'status': 'QUALIFIED',
      'agentId': 'demo-employee',
      'followUpDate': '2026-11-02',
      'notes': 'Fictional second property preference.',
      'createdAt': '2026-10-08T09:00:00.000Z',
      'updatedAt': updated,
    },
    {
      'id': 'demo-lead-4',
      'plotId': 'demo-plot-3',
      'customerName': 'Riya Shah',
      'email': 'customer@fictional.example',
      'contactNumber': '+91 00000 00101',
      'location': 'Harbour district · Fictional',
      'uniqueId': 'DEMO-RIYA-004',
      'pricePerSqYard': 24000,
      'status': 'NEW',
      'agentId': 'demo-employee',
      'followUpDate': '2026-11-06',
      'notes': 'Fictional alternate plot enquiry.',
      'createdAt': '2026-10-12T09:00:00.000Z',
      'updatedAt': updated,
    },
    {
      'id': 'demo-lead-5',
      'plotId': 'demo-plot-10',
      'customerName': 'Kabir Das',
      'email': 'kabir@fictional.example',
      'contactNumber': '+91 00000 00202',
      'location': 'Orchard district · Fictional',
      'uniqueId': 'DEMO-KABIR-005',
      'pricePerSqYard': 18500,
      'status': 'FOLLOW_UP',
      'agentId': 'demo-employee-2',
      'followUpDate': '2026-10-30',
      'notes': 'Fictional family-site-visit follow-up.',
      'createdAt': '2026-10-14T09:00:00.000Z',
      'updatedAt': updated,
    },
    {
      'id': 'demo-lead-6',
      'plotId': 'demo-plot-11',
      'customerName': 'Nisha Iyer',
      'email': 'nisha@fictional.example',
      'contactNumber': '+91 00000 00303',
      'location': 'Orchard district · Fictional',
      'uniqueId': 'DEMO-NISHA-006',
      'pricePerSqYard': 18500,
      'status': 'LOST',
      'agentId': 'demo-employee-2',
      'followUpDate': '2026-10-18',
      'notes': 'Fictional closed-lost record for report coverage.',
      'createdAt': '2026-10-16T09:00:00.000Z',
      'updatedAt': updated,
    },
  ];
  leads.addAll([
    {
      'id': 'demo-lead-7',
      'plotId': 'demo-plot-13',
      'customerName': 'Vikram Rao',
      'email': 'vikram@fictional.example',
      'contactNumber': '+91 90000 00606',
      'location': 'Lakeside district · Fictional',
      'uniqueId': 'DEMO-VIKRAM-007',
      'pricePerSqYard': 21000,
      'status': 'QUALIFIED',
      'agentId': 'demo-employee-3',
      'followUpDate': '2026-11-04',
      'notes': 'Fictional lakeside family-home enquiry.',
      'createdAt': '2026-10-18T09:00:00.000Z',
      'updatedAt': updated,
    },
    {
      'id': 'demo-lead-8',
      'plotId': 'demo-plot-14',
      'customerName': 'Vikram Rao',
      'email': 'vikram@fictional.example',
      'contactNumber': '+91 90000 00606',
      'location': 'Lakeside district · Fictional',
      'uniqueId': 'DEMO-VIKRAM-008',
      'pricePerSqYard': 21000,
      'status': 'WON',
      'agentId': 'demo-employee-3',
      'followUpDate': '2026-10-29',
      'notes': 'Fictional booking-ready enquiry.',
      'createdAt': '2026-10-20T09:00:00.000Z',
      'updatedAt': updated,
    },
    {
      'id': 'demo-lead-9',
      'plotId': 'demo-plot-15',
      'customerName': 'Vikram Rao',
      'email': 'vikram@fictional.example',
      'contactNumber': '+91 90000 00606',
      'location': 'Lakeside district · Fictional',
      'uniqueId': 'DEMO-VIKRAM-009',
      'pricePerSqYard': 21000,
      'status': 'FOLLOW_UP',
      'agentId': 'demo-employee-3',
      'followUpDate': '2026-11-10',
      'notes': 'Fictional alternate plot follow-up.',
      'createdAt': '2026-10-22T09:00:00.000Z',
      'updatedAt': updated,
    },
  ]);
  final customers = [
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
      'bookingId': 'demo-booking-1',
      'bookingDate': '2026-10-10',
      'bookingAmount': 4320000,
      'advancePaid': 1200000,
      'balanceDue': 3120000,
      'paymentStatus': 'PARTIALLY_PAID',
      'paymentMethod': 'UPI',
      'followUpDate': '2026-10-28',
      'notes': 'Venture: Sage Harbour\nPlot Interested: H-101\nEmail: customer@fictional.example\nFictional presentation record.',
      'createdAt': created,
      'updatedAt': updated,
    },
    {
      'id': 'demo-record-3',
      'contactName': 'Riya Shah',
      'contactNumber': '+91 00000 00101',
      'location': 'Harbour district · Fictional',
      'budget': '4500000',
      'interested': true,
      'status': 'FOLLOWING_UP',
      'recordOwner': 'employee@fictional.example',
      'leadName': 'employee@fictional.example',
      'customerEmail': 'customer@fictional.example',
      'followUpDate': '2026-11-02',
      'notes': 'Venture: Sage Harbour\nPlot Interested: H-102\nFictional presentation record.',
      'createdAt': '2026-10-08T09:00:00.000Z',
      'updatedAt': updated,
    },
    {
      'id': 'demo-record-4',
      'contactName': 'Riya Shah',
      'contactNumber': '+91 00000 00101',
      'location': 'Harbour district · Fictional',
      'budget': '4500000',
      'interested': true,
      'status': 'CONFIRMED_NOT_PAID',
      'recordOwner': 'employee@fictional.example',
      'leadName': 'employee@fictional.example',
      'customerEmail': 'customer@fictional.example',
      'followUpDate': '2026-11-06',
      'notes': 'Venture: Sage Harbour\nPlot Interested: H-103\nFictional presentation record.',
      'createdAt': '2026-10-12T09:00:00.000Z',
      'updatedAt': updated,
    },
    {
      'id': 'demo-record-2',
      'contactName': 'Kabir Das',
      'contactNumber': '+91 00000 00202',
      'location': 'Orchard district · Fictional',
      'budget': '4440000',
      'interested': true,
      'status': 'BOOKED',
      'recordOwner': 'arjun.employee@fictional.example',
      'leadName': 'arjun.employee@fictional.example',
      'customerEmail': 'kabir@fictional.example',
      'bookingId': 'demo-booking-2',
      'bookingDate': '2026-10-06',
      'bookingAmount': 4440000,
      'advancePaid': 4440000,
      'balanceDue': 0,
      'paymentStatus': 'PAID',
      'paymentMethod': 'NEFT',
      'followUpDate': '2026-10-26',
      'notes': 'Venture: Walnut Grove\nPlot Interested: O-101\nFictional presentation record.',
      'createdAt': created,
      'updatedAt': updated,
    },
    {
      'id': 'demo-record-5',
      'contactName': 'Kabir Das',
      'contactNumber': '+91 00000 00202',
      'location': 'Orchard district · Fictional',
      'budget': '4440000',
      'interested': true,
      'status': 'FOLLOWING_UP',
      'recordOwner': 'arjun.employee@fictional.example',
      'leadName': 'arjun.employee@fictional.example',
      'customerEmail': 'kabir@fictional.example',
      'followUpDate': '2026-10-30',
      'notes': 'Venture: Walnut Grove\nPlot Interested: O-102\nFictional presentation record.',
      'createdAt': '2026-10-14T09:00:00.000Z',
      'updatedAt': updated,
    },
    {
      'id': 'demo-record-6',
      'contactName': 'Nisha Iyer',
      'contactNumber': '+91 00000 00303',
      'location': 'Orchard district · Fictional',
      'budget': '3700000',
      'interested': false,
      'status': 'FOLLOWING_UP',
      'recordOwner': 'arjun.employee@fictional.example',
      'leadName': 'arjun.employee@fictional.example',
      'customerEmail': 'nisha@fictional.example',
      'followUpDate': '2026-10-18',
      'notes': 'Venture: Walnut Grove\nPlot Interested: O-103\nFictional presentation record.',
      'createdAt': '2026-10-16T09:00:00.000Z',
      'updatedAt': updated,
    },
  ];
  customers.addAll([
    {
      'id': 'demo-record-7',
      'contactName': 'Vikram Rao',
      'contactNumber': '+91 90000 00606',
      'location': 'Lakeside district · Fictional',
      'budget': '4620000',
      'interested': true,
      'status': 'PAID_ADVANCE',
      'recordOwner': 'priya.employee@fictional.example',
      'leadName': 'priya.employee@fictional.example',
      'customerEmail': 'vikram@fictional.example',
      'bookingId': 'demo-booking-3',
      'bookingDate': '2026-10-24',
      'bookingAmount': 4620000,
      'advancePaid': 1000000,
      'balanceDue': 3620000,
      'paymentStatus': 'PARTIALLY_PAID',
      'paymentMethod': 'UPI',
      'followUpDate': '2026-11-04',
      'notes': 'Venture: Cedar Meadows\nPlot Interested: C-101\nEmail: vikram@fictional.example\nFictional presentation record.',
      'createdAt': '2026-10-18T09:00:00.000Z',
      'updatedAt': updated,
    },
    {
      'id': 'demo-record-8',
      'contactName': 'Vikram Rao',
      'contactNumber': '+91 90000 00606',
      'location': 'Lakeside district · Fictional',
      'budget': '4620000',
      'interested': true,
      'status': 'FOLLOWING_UP',
      'recordOwner': 'priya.employee@fictional.example',
      'leadName': 'priya.employee@fictional.example',
      'customerEmail': 'vikram@fictional.example',
      'followUpDate': '2026-11-10',
      'notes': 'Venture: Cedar Meadows\nPlot Interested: C-103\nFictional presentation record.',
      'createdAt': '2026-10-22T09:00:00.000Z',
      'updatedAt': updated,
    },
  ]);
  final locations = <JsonMap>[
    {'id': 'demo-loc-1', 'name': 'Harbour district · Fictional'},
    {'id': 'demo-loc-2', 'name': 'Orchard district · Fictional'},
    {'id': 'demo-loc-3', 'name': 'Lakeside district · Fictional'},
  ];
  final ventures = <JsonMap>[
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
    {
      'id': 'demo-venture-3',
      'name': 'Cedar Meadows',
      'locationId': 'demo-loc-3',
      'layoutImage': null,
      'layoutRegions': {'roads': [], 'parks': []},
      'createdAt': '2026-10-12T09:00:00.000Z',
    },
  ];
  final employeesByVenture = <String, List<String>>{};
  for (var index = 4; index <= 8; index++) {
    final locationId = 'demo-loc-$index';
    final ventureId = 'demo-venture-$index';
    locations.add({
      'id': locationId,
      'name': [
        'Garden district · Fictional',
        'Riverside district · Fictional',
        'Hillview district · Fictional',
        'Palm Grove district · Fictional',
        'Metro Edge district · Fictional',
      ][index - 4],
    });
    ventures.add({
      'id': ventureId,
      'name': [
        'Willow Park',
        'Riverstone Enclave',
        'Hillview Terraces',
        'Palm Vista',
        'Metro Edge Gardens',
      ][index - 4],
      'locationId': locationId,
      'layoutImage': null,
      'layoutRegions': {'roads': [], 'parks': []},
      'createdAt': '2026-10-${12 + index}T09:00:00.000Z',
    });
  }
  for (var index = 4; index <= 15; index++) {
    final ventureNumber = 4 + ((index - 4) % 5);
    final id = 'demo-employee-$index';
    employeesByVenture
        .putIfAbsent('demo-venture-$ventureNumber', () => [])
        .add(id);
    users.add({
      'id': id,
      'email': 'employee$index@fictional.example',
      'displayName': 'Demo Employee $index',
      'fullName': 'Demo Employee $index',
      'role': 'EMPLOYEE',
      'createdAt': created,
      'employeeProfile': {
        'status': index == 15 ? 'FROZEN' : 'ACTIVE',
        'assignedLocationIds': ['demo-loc-$ventureNumber'],
        'assignedVentureIds': ['demo-venture-$ventureNumber'],
        'department': index.isEven ? 'Site Operations' : 'Client Advisory',
        'position': index.isEven ? 'Property Advisor' : 'Relationship Manager',
        'employeeId': 'VP-EMP-${index.toString().padLeft(3, '0')}',
        'phoneNumber': '+91 90000 ${index.toString().padLeft(5, '0')}',
        'dateOfJoining': '202${index % 4 + 2}-0${index % 8 + 1}-15',
        'yearsOfExperience': 2 + (index % 8),
        'achievements': 'Fictional demo performance profile',
        'emailVerified': true,
        'phoneVerified': index.isEven,
      },
    });
  }
  for (var index = 4; index <= 30; index++) {
    users.add({
      'id': 'demo-customer-$index',
      'email': 'demo.customer.$index@fictional.example',
      'displayName': 'Demo Customer $index',
      'fullName': 'Demo Customer $index',
      'role': 'CUSTOMER',
      'createdAt': created,
      'customerProfile': {
        'customerId': 'VP-CUS-${index.toString().padLeft(3, '0')}',
        'phoneNumber': '+91 91000 ${index.toString().padLeft(5, '0')}',
        'preferredContact': index.isEven ? 'Email' : 'Phone',
        'customerSince':
            '2026-${(index % 8 + 1).toString().padLeft(2, '0')}-10',
      },
    });
  }
  final generatedPlotOwners = <String, String>{};
  for (var index = 19; index <= 30; index++) {
    final ventureNumber = 4 + ((index - 19) % 5);
    final ventureId = 'demo-venture-$ventureNumber';
    final employeeId = employeesByVenture[ventureId]!.first;
    final employee = users.firstWhere((user) => user['id'] == employeeId);
    final plotId = 'demo-plot-$index';
    generatedPlotOwners[plotId] = employee['email'] as String;
    plots.add({
      'id': plotId,
      'plotNumber': 'D-${index + 81}',
      'ventureId': ventureId,
      'area': [150, 175, 210, 240][(index - 19) % 4],
      'pricePerSqYard': 19500 + ((index - 19) % 4) * 500,
      'status': switch ((index - 19) % 5) {
        0 => 'AVAILABLE',
        1 => 'ADVANCE',
        2 => 'SOLD',
        _ => 'AVAILABLE',
      },
      'x': 0.06 + ((index - 19) % 4) * 0.23,
      'y': 0.12 + ((index - 19) ~/ 4 % 3) * 0.28,
      'width': 0.18,
      'height': 0.22,
      'createdAt': created,
      'updatedAt': updated,
    });
  }
  for (var index = 9; index <= 30; index++) {
    final plotId = 'demo-plot-${19 + ((index - 9) % 12)}';
    final ownerEmail = generatedPlotOwners[plotId]!;
    final bookingNumber = index >= 10 && index <= 21 ? index - 6 : null;
    customers.add({
      'id': 'demo-record-$index',
      'contactName': 'Demo Customer $index',
      'contactNumber': '+91 91000 ${index.toString().padLeft(5, '0')}',
      'location': 'Assigned venture district · Fictional',
      'budget': '${3500000 + index * 12500}',
      'interested': index % 5 != 0,
      'status': [
        'HOT_LEAD',
        'FOLLOWING_UP',
        'CONFIRMED_NOT_PAID',
        'BOOKED',
      ][index % 4],
      'recordOwner': ownerEmail,
      'leadName': ownerEmail,
      'customerEmail': 'demo.customer.$index@fictional.example',
      if (bookingNumber != null) ...{
        'bookingId': 'demo-booking-$bookingNumber',
        'bookingDate': '2026-10-${(index % 20 + 1).toString().padLeft(2, '0')}',
        'bookingAmount': 3500000 + index * 12500,
        'advancePaid': 500000 + index * 10000,
        'balanceDue': 3000000 + index * 2500,
        'paymentStatus': index.isEven ? 'PAID' : 'PARTIALLY_PAID',
        'paymentMethod': index.isEven ? 'NEFT' : 'UPI',
      },
      'followUpDate': '2026-11-${(index % 20 + 1).toString().padLeft(2, '0')}',
      'notes':
          'Fictional demo customer record for ${ventures[(index - 9) % ventures.length]['name']}.',
      'createdAt': created,
      'updatedAt': updated,
    });
    leads.add({
      'id': 'demo-lead-$index',
      'plotId': plotId,
      'customerName': 'Demo Customer $index',
      'email': 'demo.customer.$index@fictional.example',
      'contactNumber': '+91 91000 ${index.toString().padLeft(5, '0')}',
      'location': 'Assigned venture district · Fictional',
      'uniqueId': 'DEMO-CUSTOMER-${index.toString().padLeft(3, '0')}',
      'pricePerSqYard': 19500,
      'status': ['NEW', 'FOLLOW_UP', 'QUALIFIED', 'WON', 'LOST'][index % 5],
      'agentId': users.firstWhere((user) => user['email'] == ownerEmail)['id'],
      'followUpDate': '2026-11-${(index % 20 + 1).toString().padLeft(2, '0')}',
      'notes': 'Fictional generated enquiry linked to $plotId.',
      'createdAt': created,
      'updatedAt': updated,
    });
  }
  for (var index = 32; index <= 40; index++) {
    final customerIndex = 9 + ((index - 32) % 22);
    final plotId = 'demo-plot-${19 + ((index - 32) % 12)}';
    final ownerEmail = generatedPlotOwners[plotId]!;
    leads.add({
      'id': 'demo-lead-$index',
      'plotId': plotId,
      'customerName': 'Demo Customer $customerIndex',
      'email': 'demo.customer.$customerIndex@fictional.example',
      'contactNumber': '+91 91000 ${customerIndex.toString().padLeft(5, '0')}',
      'location': 'Assigned venture district · Fictional',
      'uniqueId': 'DEMO-FOLLOWUP-${index.toString().padLeft(3, '0')}',
      'pricePerSqYard': 19500,
      'status': ['NEW', 'FOLLOW_UP', 'QUALIFIED', 'WON', 'LOST'][index % 5],
      'agentId': users.firstWhere((user) => user['email'] == ownerEmail)['id'],
      'followUpDate': '2026-11-${(index % 20 + 1).toString().padLeft(2, '0')}',
      'notes': 'Fictional generated follow-up record.',
      'createdAt': created,
      'updatedAt': updated,
    });
  }
  final generatedBookings = <JsonMap>[];
  final generatedPayments = <JsonMap>[];
  final generatedActivities = <JsonMap>[];
  final generatedInquiries = <JsonMap>[];
  final generatedTracking = <JsonMap>[];
  final generatedFavorites = <JsonMap>[];
  for (var index = 4; index <= 15; index++) {
    final customerIndex = index + 6;
    final plotId = 'demo-plot-${19 + ((customerIndex - 9) % 12)}';
    final amount = 3500000 + customerIndex * 12500;
    generatedBookings.add({
      'id': 'demo-booking-$index',
      'customerId': 'demo-record-$customerIndex',
      'customerName': 'Demo Customer $customerIndex',
      'plotId': plotId,
      'property': 'Portfolio property · $plotId',
      'bookingDate': '2026-10-${(index % 20 + 1).toString().padLeft(2, '0')}',
      'amount': amount,
      'advancePaid': 500000 + customerIndex * 10000,
      'balanceDue': amount - (500000 + customerIndex * 10000),
      'status': index.isEven ? 'COMPLETED' : 'PARTIALLY_PAID',
    });
  }
  for (var index = 4; index <= 30; index++) {
    final bookingNumber = 4 + ((index - 4) % 12);
    generatedPayments.add({
      'id': 'demo-payment-$index',
      'bookingId': 'demo-booking-$bookingNumber',
      'customerName': 'Demo Customer ${bookingNumber + 6}',
      'date': '2026-10-${(index % 20 + 1).toString().padLeft(2, '0')}',
      'amount': 250000 + index * 5000,
      'method': index.isEven ? 'NEFT' : 'UPI',
      'status': index % 7 == 0 ? 'PENDING' : 'SUCCESS',
      'reference': 'DEMO-TXN-${index.toString().padLeft(3, '0')}',
    });
  }
  for (var index = 5; index <= 40; index++) {
    final employeeIndex = 4 + ((index - 5) % 12);
    final customerIndex = 9 + ((index - 5) % 22);
    generatedActivities.add({
      'id': 'demo-activity-$index',
      'kind': ['FOLLOW_UP', 'PAYMENT', 'SITE_VISIT', 'BOOKING'][index % 4],
      'title': [
        'Follow-up scheduled',
        'Payment recorded',
        'Site visit completed',
        'Booking updated',
      ][index % 4],
      'detail': 'Demo Customer $customerIndex · Portfolio activity',
      'actor': 'Demo Employee $employeeIndex',
      'date': '2026-10-${(index % 20 + 1).toString().padLeft(2, '0')}',
    });
  }
  for (var index = 5; index <= 40; index++) {
    final customerIndex = 9 + ((index - 5) % 22);
    final plotId = 'demo-plot-${19 + ((index - 5) % 12)}';
    final ownerEmail = generatedPlotOwners[plotId]!;
    generatedInquiries.add({
      'id': 'demo-inquiry-$index',
      'plotId': plotId,
      'customerName': 'Demo Customer $customerIndex',
      'customerEmail': 'demo.customer.$customerIndex@fictional.example',
      'customerPhone': '+91 91000 ${customerIndex.toString().padLeft(5, '0')}',
      'message':
          'Fictional enquiry regarding availability and site visit timing.',
      'status': ['NEW', 'FOLLOW_UP', 'QUALIFIED', 'COMPLETED'][index % 4],
      'assignedTo': ownerEmail,
      'createdAt':
          '2026-10-${(index % 20 + 1).toString().padLeft(2, '0')}T09:00:00.000Z',
    });
  }
  for (var index = 9; index <= 20; index++) {
    final plotId = 'demo-plot-${19 + ((index - 9) % 12)}';
    final ownerEmail = generatedPlotOwners[plotId]!;
    generatedTracking.add({
      'id': 'demo-tracking-$index',
      'customerId': 'demo-record-$index',
      'latitude': 17.70 + (index - 8) * 0.01,
      'longitude': 83.28 + (index - 8) * 0.01,
      'status': ['ACTIVE', 'MOVING', 'INACTIVE'][index % 3],
      'address': 'Fictional site visit point · portfolio zone $index',
      'updatedAt': updated,
      'updatedBy': users.firstWhere(
        (user) => user['email'] == ownerEmail,
      )['id'],
    });
  }
  for (var index = 4; index <= 15; index++) {
    final plotId = 'demo-plot-${19 + ((index - 4) % 12)}';
    generatedFavorites.add({
      'id': 'demo-favorite-$index',
      'userId': 'demo-employee-$index',
      'plotId': plotId,
      'createdAt':
          '2026-10-${(index % 20 + 1).toString().padLeft(2, '0')}T09:00:00.000Z',
    });
  }
  return {
    'version': 1,
    'users': users,
    'locations': locations,
    'ventures': ventures,
    'plots': plots,
    'leads': leads,
    'customers': customers,
    'tracking': [
      {
        'id': 'demo-tracking-1',
        'customerId': 'demo-record-1',
        'latitude': 17.71,
        'longitude': 83.30,
        'status': 'ACTIVE',
        'address': 'Fictional site visit point · Harbour',
        'updatedAt': updated,
        'updatedBy': 'demo-employee',
      },
      {
        'id': 'demo-tracking-2',
        'customerId': 'demo-record-3',
        'latitude': 17.72,
        'longitude': 83.31,
        'status': 'MOVING',
        'address': 'Fictional site visit point · North gate',
        'updatedAt': '2026-10-22T09:00:00.000Z',
        'updatedBy': 'demo-employee',
      },
      {
        'id': 'demo-tracking-3',
        'customerId': 'demo-record-2',
        'latitude': 17.74,
        'longitude': 83.33,
        'status': 'INACTIVE',
        'address': 'Fictional site visit point · Orchard',
        'updatedAt': '2026-10-20T09:00:00.000Z',
        'updatedBy': 'demo-employee-2',
      },
      {
        'id': 'demo-tracking-4',
        'customerId': 'demo-record-7',
        'latitude': 17.76,
        'longitude': 83.35,
        'status': 'ACTIVE',
        'address': 'Fictional site visit point · Lakeside gate',
        'updatedAt': '2026-10-24T09:00:00.000Z',
        'updatedBy': 'demo-employee-3',
      },
      ...generatedTracking,
    ],
    'bookings': [
      {
        'id': 'demo-booking-1',
        'customerId': 'demo-record-1',
        'customerName': 'Riya Shah',
        'plotId': 'demo-plot-1',
        'property': 'Sage Harbour · H-101',
        'bookingDate': '2026-10-10',
        'amount': 4320000,
        'advancePaid': 1200000,
        'balanceDue': 3120000,
        'status': 'PARTIALLY_PAID',
      },
      {
        'id': 'demo-booking-2',
        'customerId': 'demo-record-2',
        'customerName': 'Kabir Das',
        'plotId': 'demo-plot-9',
        'property': 'Walnut Grove · O-101',
        'bookingDate': '2026-10-06',
        'amount': 4440000,
        'advancePaid': 4440000,
        'balanceDue': 0,
        'status': 'COMPLETED',
      },
      {
        'id': 'demo-booking-3',
        'customerId': 'demo-record-7',
        'customerName': 'Vikram Rao',
        'plotId': 'demo-plot-13',
        'property': 'Cedar Meadows · C-101',
        'bookingDate': '2026-10-24',
        'amount': 4620000,
        'advancePaid': 1000000,
        'balanceDue': 3620000,
        'status': 'PARTIALLY_PAID',
      },
      ...generatedBookings,
    ],
    'payments': [
      {
        'id': 'demo-payment-1',
        'bookingId': 'demo-booking-1',
        'customerName': 'Riya Shah',
        'date': '2026-10-10',
        'amount': 1200000,
        'method': 'UPI',
        'status': 'SUCCESS',
        'reference': 'DEMO-UPI-001',
      },
      {
        'id': 'demo-payment-2',
        'bookingId': 'demo-booking-2',
        'customerName': 'Kabir Das',
        'date': '2026-10-06',
        'amount': 4440000,
        'method': 'NEFT',
        'status': 'SUCCESS',
        'reference': 'DEMO-NEFT-002',
      },
      {
        'id': 'demo-payment-3',
        'bookingId': 'demo-booking-3',
        'customerName': 'Vikram Rao',
        'date': '2026-10-24',
        'amount': 1000000,
        'method': 'UPI',
        'status': 'SUCCESS',
        'reference': 'DEMO-UPI-003',
      },
      ...generatedPayments,
    ],
    'activities': [
      {
        'id': 'demo-activity-1',
        'kind': 'FOLLOW_UP',
        'title': 'Follow-up scheduled',
        'detail': 'Riya Shah · Sage Harbour H-102',
        'actor': 'Maya Sen',
        'date': '2026-10-24',
      },
      {
        'id': 'demo-activity-2',
        'kind': 'PAYMENT',
        'title': 'Advance payment recorded',
        'detail': 'Kabir Das · Walnut Grove O-101',
        'actor': 'Arjun Kulkarni',
        'date': '2026-10-22',
      },
      {
        'id': 'demo-activity-3',
        'kind': 'SITE_VISIT',
        'title': 'Site visit completed',
        'detail': 'Sage Harbour · Harbour district',
        'actor': 'Maya Sen',
        'date': '2026-10-20',
      },
      {
        'id': 'demo-activity-4',
        'kind': 'SITE_VISIT',
        'title': 'New site visit booked',
        'detail': 'Vikram Rao · Cedar Meadows C-101',
        'actor': 'Priya Nair',
        'date': '2026-10-24',
      },
      ...generatedActivities,
    ],
    'favorites': [
      {
        'id': 'demo-favorite-1',
        'userId': 'demo-customer',
        'plotId': 'demo-plot-2',
        'createdAt': '2026-10-21T09:00:00.000Z',
      },
      {
        'id': 'demo-favorite-2',
        'userId': 'demo-employee',
        'plotId': 'demo-plot-4',
        'createdAt': '2026-10-19T09:00:00.000Z',
      },
      {
        'id': 'demo-favorite-3',
        'userId': 'demo-customer-3',
        'plotId': 'demo-plot-15',
        'createdAt': '2026-10-23T09:00:00.000Z',
      },
      {
        'id': 'demo-favorite-4',
        'userId': 'demo-employee-3',
        'plotId': 'demo-plot-16',
        'createdAt': '2026-10-22T09:00:00.000Z',
      },
      ...generatedFavorites,
    ],
    'inquiries': [
      {
        'id': 'demo-inquiry-1',
        'plotId': 'demo-plot-1',
        'customerName': 'Riya Shah',
        'customerEmail': 'customer@fictional.example',
        'customerPhone': '+91 00000 00101',
        'message': 'Please confirm the next fictional site-visit slot.',
        'status': 'FOLLOW_UP',
        'assignedTo': 'employee@fictional.example',
        'createdAt': '2026-10-23T09:00:00.000Z',
      },
      {
        'id': 'demo-inquiry-2',
        'plotId': 'demo-plot-9',
        'customerName': 'Kabir Das',
        'customerEmail': 'kabir@fictional.example',
        'customerPhone': '+91 00000 00202',
        'message': 'Need the fictional payment schedule for this booking.',
        'status': 'IN_PROGRESS',
        'assignedTo': 'arjun.employee@fictional.example',
        'createdAt': '2026-10-22T09:00:00.000Z',
      },
      {
        'id': 'demo-inquiry-3',
        'plotId': 'demo-plot-11',
        'customerName': 'Nisha Iyer',
        'customerEmail': 'nisha@fictional.example',
        'customerPhone': '+91 00000 00303',
        'message': 'Please share the fictional availability for orchard plots.',
        'status': 'COMPLETED',
        'assignedTo': 'arjun.employee@fictional.example',
        'createdAt': '2026-10-18T09:00:00.000Z',
      },
      {
        'id': 'demo-inquiry-4',
        'plotId': 'demo-plot-13',
        'customerName': 'Vikram Rao',
        'customerEmail': 'vikram@fictional.example',
        'customerPhone': '+91 90000 00606',
        'message': 'Please confirm the fictional Cedar Meadows documentation checklist.',
        'status': 'QUALIFIED',
        'assignedTo': 'priya.employee@fictional.example',
        'createdAt': '2026-10-24T09:00:00.000Z',
      },
      ...generatedInquiries,
    ],
    'otps': [],
  };
}

/// Adds newly introduced fictional fixtures to an existing local demo store
/// without replacing edits the user made on this device.
JsonMap mergeDemoData(JsonMap existing) {
  final seed = seedDemoData();
  final merged = jsonObject(jsonDecode(jsonEncode(existing)));
  for (final table in [
    'users',
    'locations',
    'ventures',
    'plots',
    'leads',
    'customers',
    'tracking',
    'bookings',
    'payments',
    'activities',
    'favorites',
    'inquiries',
    'otps',
  ]) {
    final current = merged[table] is List
        ? jsonList(merged[table])
        : <JsonMap>[];
    final ids = current.map((row) => row['id']).whereType<String>().toSet();
    final additions = jsonList(seed[table])
        .where((row) => row['id'] is! String || !ids.contains(row['id']));
    merged[table] = [...current, ...additions];
  }
  return merged;
}
