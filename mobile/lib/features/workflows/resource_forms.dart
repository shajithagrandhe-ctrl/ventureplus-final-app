import 'package:ventureplus/core/app_controller.dart';

import 'forms.dart';

Future<List<FormFieldSpec>> resourceFields(
  VentureRepository repository,
  Resource resource, {
  bool editing = false,
}) async {
  switch (resource) {
    case Resource.ventures:
      return const [
        FormFieldSpec('name', 'Venture name'),
        FormFieldSpec('locationName', 'Location name'),
        FormFieldSpec(
          'plotCount',
          'Number of plots',
          kind: FieldKind.integer,
          min: 1,
          max: 200,
        ),
        FormFieldSpec(
          'plotNumberPrefix',
          'Plot number prefix',
          required: false,
        ),
        FormFieldSpec(
          'startingPlotNumber',
          'First plot number',
          kind: FieldKind.integer,
          min: 1,
        ),
        FormFieldSpec(
          'defaultArea',
          'Area per plot (sq yd)',
          kind: FieldKind.integer,
          min: 1,
        ),
        FormFieldSpec(
          'defaultPricePerSqYard',
          'Price per sq yd',
          kind: FieldKind.integer,
          min: 1,
        ),
      ];
    case Resource.plots:
      return [
        const FormFieldSpec('plotNumber', 'Plot number'),
        FormFieldSpec(
          'status',
          'Availability',
          kind: FieldKind.choice,
          options: choices(['AVAILABLE', 'ADVANCE', 'SOLD']),
        ),
        const FormFieldSpec(
          'area',
          'Area (sq yd)',
          kind: FieldKind.integer,
          min: 1,
        ),
        const FormFieldSpec(
          'pricePerSqYard',
          'Price per sq yd',
          kind: FieldKind.integer,
          min: 1,
        ),
      ];
    case Resource.leads:
      final plots = editing
          ? <JsonMap>[]
          : await repository.list(Resource.plots);
      return [
        if (!editing) ...[
          FormFieldSpec(
            'plotId',
            'Plot',
            kind: FieldKind.choice,
            options: {
              for (final plot in plots)
                '${plot['id']}':
                    '${plot['venture'] is Map ? plot['venture']['name'] ?? '' : ''} · Plot ${plot['plotNumber']}',
            },
          ),
          const FormFieldSpec('customerName', 'Customer name', minLength: 2),
          const FormFieldSpec('email', 'Customer email', kind: FieldKind.email),
        ],
        const FormFieldSpec('contactNumber', 'Contact number', minLength: 6),
        const FormFieldSpec('location', 'Location', minLength: 2),
        const FormFieldSpec('uniqueId', 'Customer reference', minLength: 3),
        const FormFieldSpec(
          'pricePerSqYard',
          'Price per sq yd',
          kind: FieldKind.integer,
          min: 1,
        ),
        if (editing)
          FormFieldSpec(
            'status',
            'Lead status',
            kind: FieldKind.choice,
            options: choices(['NEW', 'FOLLOW_UP', 'QUALIFIED', 'WON', 'LOST']),
          ),
        const FormFieldSpec(
          'notes',
          'Notes',
          kind: FieldKind.multiline,
          required: false,
        ),
      ];
    case Resource.customers:
      return [
        const FormFieldSpec('contactName', 'Customer name', minLength: 2),
        const FormFieldSpec('contactNumber', 'Contact number', minLength: 6),
        const FormFieldSpec('location', 'Location', minLength: 2),
        const FormFieldSpec('budget', 'Budget'),
        FormFieldSpec(
          'recordOwner',
          'Record owner',
          minLength: 2,
          readOnly: repository.user.role == Role.employee,
          helper: repository.user.role == Role.employee
              ? 'New records belong to your signed-in identity.'
              : 'Use the staff member’s full name.',
        ),
        const FormFieldSpec(
          'leadName',
          'Lead owner name',
          required: false,
          minLength: 2,
        ),
        FormFieldSpec(
          'status',
          'Customer stage',
          kind: FieldKind.choice,
          options: choices([
            'HOT_LEAD',
            'FOLLOWING_UP',
            'CONFIRMED_NOT_PAID',
            'PAID_ADVANCE',
            'BOOKED',
          ]),
        ),
        const FormFieldSpec(
          'interested',
          'Interested',
          kind: FieldKind.toggle,
          required: false,
        ),
        const FormFieldSpec(
          'notes',
          'Notes',
          kind: FieldKind.multiline,
          required: false,
          helper: 'Customer-linked records are created from a property lead. Free-text notes do not grant customer access.',
        ),
      ];
    case Resource.tracking:
      final customers = await repository.list(Resource.customers);
      return [
        FormFieldSpec(
          'customerId',
          'Customer record',
          kind: FieldKind.choice,
          options: {
            for (final customer in customers)
              '${customer['id']}':
                  '${customer['contactName']} · ${customer['location']}',
          },
        ),
        const FormFieldSpec(
          'latitude',
          'Latitude',
          kind: FieldKind.decimal,
          min: -90,
          max: 90,
        ),
        const FormFieldSpec(
          'longitude',
          'Longitude',
          kind: FieldKind.decimal,
          min: -180,
          max: 180,
        ),
        FormFieldSpec(
          'status',
          'Tracking status',
          kind: FieldKind.choice,
          options: choices(['active', 'inactive', 'moving']),
        ),
        const FormFieldSpec('address', 'Address', required: false),
      ];
    case Resource.employeeAccess:
      final locations = await repository.list(Resource.locations);
      final ventures = await repository.list(Resource.ventures);
      return [
        FormFieldSpec(
          'email',
          'Email',
          kind: FieldKind.email,
          readOnly: editing,
          helper: editing
              ? 'Email links existing employee records and cannot be changed here.'
              : null,
        ),
        if (!(editing && repository.isOffline))
          FormFieldSpec(
            'password',
            editing ? 'New password (optional)' : 'Temporary password',
            kind: FieldKind.password,
            required: !editing,
            minLength: 6,
          ),
        const FormFieldSpec('fullName', 'Full name', minLength: 2),
        const FormFieldSpec('displayName', 'Display name', minLength: 2),
        const FormFieldSpec('firstName', 'First name', required: false),
        const FormFieldSpec('lastName', 'Last name', required: false),
        const FormFieldSpec('employeeId', 'Employee code', required: false),
        const FormFieldSpec(
          'phoneNumber',
          'Phone number',
          minLength: 6,
          required: false,
        ),
        const FormFieldSpec('department', 'Department', required: false),
        const FormFieldSpec('position', 'Position', required: false),
        const FormFieldSpec('address', 'Address', required: false),
        const FormFieldSpec(
          'dateOfBirth',
          'Date of birth',
          required: false,
          kind: FieldKind.date,
          helper: 'YYYY-MM-DD',
        ),
        const FormFieldSpec(
          'yearsOfExperience',
          'Years of experience',
          required: false,
          kind: FieldKind.integer,
          min: 0,
          max: 80,
        ),
        const FormFieldSpec(
          'currentCompany',
          'Current company',
          required: false,
        ),
        const FormFieldSpec(
          'previousCompanies',
          'Previous companies',
          required: false,
          kind: FieldKind.lines,
          helper: 'One company per line.',
        ),
        const FormFieldSpec(
          'currentPosition',
          'Current position',
          required: false,
        ),
        const FormFieldSpec('roleGiven', 'Role description', required: false),
        const FormFieldSpec(
          'dateOfJoining',
          'Joining date',
          required: false,
          kind: FieldKind.date,
          helper: 'YYYY-MM-DD',
        ),
        const FormFieldSpec(
          'dateOfRelieving',
          'Relieving date',
          required: false,
          kind: FieldKind.date,
          helper: 'YYYY-MM-DD',
        ),
        const FormFieldSpec(
          'achievements',
          'Achievements',
          required: false,
          kind: FieldKind.lines,
          helper: 'One achievement per line.',
        ),
        FormFieldSpec(
          'status',
          'Account status',
          kind: FieldKind.choice,
          options: choices(['ACTIVE', 'FROZEN']),
        ),
        FormFieldSpec(
          'assignedLocationIds',
          'Assigned locations',
          kind: FieldKind.choices,
          required: false,
          helper: 'Select the locations this employee may access.',
          options: {
            for (final row in locations) '${row['id']}': '${row['name']}',
          },
        ),
        FormFieldSpec(
          'assignedVentureIds',
          'Assigned ventures',
          kind: FieldKind.choices,
          required: false,
          options: {
            for (final row in ventures) '${row['id']}': '${row['name']}',
          },
        ),
        const FormFieldSpec(
          'emailVerified',
          'Email verified',
          kind: FieldKind.toggle,
          required: false,
        ),
        const FormFieldSpec(
          'phoneVerified',
          'Phone verified',
          kind: FieldKind.toggle,
          required: false,
        ),
      ];
    default:
      return const [];
  }
}

JsonMap formInitial(
  VentureRepository repository,
  Resource resource,
  JsonMap? record,
) => {
  if (resource == Resource.ventures) 'startingPlotNumber': 1,
  if (resource == Resource.customers) ...{
    'recordOwner': repository.user.fullName,
    'leadName': repository.user.fullName,
    'status': 'FOLLOWING_UP',
  },
  if (resource == Resource.employeeAccess) 'status': 'ACTIVE',
  if (resource == Resource.tracking) 'status': 'active',
  ...?record,
  if (record?['employeeProfile'] is Map)
    ...Map<String, dynamic>.from(record!['employeeProfile']),
  if (resource == Resource.customers && repository.user.role == Role.employee)
    'recordOwner': repository.user.fullName,
};

const customerAccountFields = [
  FormFieldSpec('fullName', 'Full name', minLength: 2),
  FormFieldSpec('displayName', 'Display name', minLength: 2),
  FormFieldSpec('email', 'Email', kind: FieldKind.email),
  FormFieldSpec(
    'password',
    'Temporary password',
    kind: FieldKind.password,
    minLength: 8,
  ),
  FormFieldSpec('phoneNumber', 'Phone number', required: false),
  FormFieldSpec('address', 'Address', required: false),
];

const inquiryFields = [
  FormFieldSpec('customerName', 'Your name', minLength: 2),
  FormFieldSpec('customerEmail', 'Your email', kind: FieldKind.email),
  FormFieldSpec('customerPhone', 'Phone number', required: false),
  FormFieldSpec(
    'message',
    'Inquiry message',
    kind: FieldKind.multiline,
    minLength: 10,
  ),
];
