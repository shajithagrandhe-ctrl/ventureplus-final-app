import 'dart:typed_data';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ventureplus/core/app_controller.dart';
import 'package:ventureplus/features/workflows/forms.dart';
import 'package:ventureplus/features/workflows/layout_canvas.dart';
import 'package:ventureplus/features/workflows/layout_detection.dart';
import 'package:ventureplus/features/workflows/layout_editor.dart';
import 'package:ventureplus/features/workflows/layout_image.dart';
import 'package:ventureplus/features/workflows/resource_forms.dart';
import 'package:ventureplus/features/workflows/workflow_exports.dart';
import 'package:ventureplus/features/workflows/workflow_page.dart';
import 'package:ventureplus/ui/theme.dart';

import 'core_data_test.dart' show FakeTransport;

void main() {
  testWidgets('search accessibility target is confined to the input field', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      final app = AppController(
        transport: FakeTransport(),
        preferences: MemoryStore(),
      );
      addTearDown(app.dispose);
      await app.enterOffline(Role.admin);
      await tester.pumpWidget(
        MaterialApp(
          home: WorkflowPage(controller: app, resource: Resource.customers),
        ),
      );
      await tester.pumpAndSettle();
      final field = find.byType(TextField);
      final node = tester.getSemantics(field);
      expect(node.rect.height, lessThan(160));
      expect(node.label, isNot(contains('results')));
      expect(node.rect.height, closeTo(tester.getSize(field).height, 1));
    } finally {
      semantics.dispose();
    }
  });
  test('rejects invalid API inputs and preserves boundary values', () {
    const email = FormFieldSpec('email', 'Email', kind: FieldKind.email);
    const count = FormFieldSpec(
      'count',
      'Plot count',
      kind: FieldKind.integer,
      min: 1,
      max: 200,
    );
    const coordinate = FormFieldSpec(
      'x',
      'Left',
      kind: FieldKind.decimal,
      min: 0,
      max: 1,
    );
    const date = FormFieldSpec('date', 'Date', kind: FieldKind.date);
    expect(email.validate('broken@'), isNotNull);
    expect(count.validate('2.5'), isNotNull);
    expect(count.validate('201'), isNotNull);
    expect(count.validate('200'), isNull);
    expect(coordinate.validate('NaN'), isNotNull);
    expect(coordinate.validate('1'), isNull);
    expect(date.validate('2026-02-30'), isNotNull);
    expect(date.validate('2028-02-29'), isNull);
    const password = FormFieldSpec(
      'password',
      'Password',
      kind: FieldKind.password,
      minLength: 6,
    );
    expect(password.validate(' abcd '), isNull);
    expect(password.validate(' abc '), isNotNull);
  });

  testWidgets('password submission preserves edge spaces while email trims', (
    tester,
  ) async {
    JsonMap? submitted;
    await tester.pumpWidget(
      MaterialApp(
        home: RecordFormPage(
          title: 'Account',
          offline: false,
          fields: const [
            FormFieldSpec('email', 'Email', kind: FieldKind.email),
            FormFieldSpec(
              'password',
              'Password',
              kind: FieldKind.password,
              minLength: 6,
            ),
          ],
          onSubmit: (values) async {
            submitted = values;
            throw const AppFailure('Keep form open.');
          },
        ),
      ),
    );
    await tester.enterText(
      find.byKey(const ValueKey('email')),
      '  test@example.test  ',
    );
    await tester.enterText(find.byKey(const ValueKey('password')), ' abcd ');
    await tester.ensureVisible(find.text('Save'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(submitted!['email'], 'test@example.test');
    expect(submitted!['password'], ' abcd ');
  });

  test(
    'layout polygons use actual coordinates and reject degenerate shapes',
    () {
      final points = parsePointLines('0.1,0.2\n0.4,0.2\n0.4,0.6\n0.1,0.6');
      final payload = polygonPayload(points);
      expect(payload['x'], .1);
      expect(payload['width'], closeTo(.3, .000001));
      final path = plotPath(payload, const Size(1000, 500));
      expect(path.contains(const Offset(200, 200)), isTrue);
      expect(path.contains(const Offset(800, 200)), isFalse);
      expect(
        () => parsePointLines('0,0\n1,1\n2,0'),
        throwsA(isA<AppFailure>()),
      );
      expect(
        () => polygonPayload(parsePointLines('0,0\n.5,.5\n1,1')),
        throwsA(isA<AppFailure>()),
      );
    },
  );

  test(
    'rectangle detector finds image evidence and leaves white images empty',
    () {
      final pixels = Uint8List(160 * 120 * 4);
      for (var i = 0; i < pixels.length; i += 4) {
        pixels[i] = 255;
        pixels[i + 1] = 255;
        pixels[i + 2] = 255;
        pixels[i + 3] = 255;
      }
      expect(
        detectColoredRectangles({
          'width': 160,
          'height': 120,
          'pixels': pixels,
        }),
        isEmpty,
      );
      for (var y = 20; y < 50; y++) {
        for (var x = 25; x < 55; x++) {
          final index = (y * 160 + x) * 4;
          pixels[index] = 30;
          pixels[index + 1] = 170;
          pixels[index + 2] = 70;
        }
      }
      final regions = detectColoredRectangles({
        'width': 160,
        'height': 120,
        'pixels': pixels,
      });
      expect(regions, hasLength(1));
      expect(regions.single['x'], closeTo(25 / 160, .01));
      expect(regions.single['y'], closeTo(20 / 120, .01));
    },
  );

  test('CSV neutralizes formulas and ICS escapes customer text', () {
    final csv = customerCsv([
      {'contactName': '=SUM(1,2)', 'notes': 'hello\n"quoted"'},
    ]);
    expect(csv, contains("'=SUM(1,2)"));
    expect(csv, contains('hello ""quoted""'));
    final ics = customerReminder(
      {'id': 'c', 'contactName': 'A, B; C\nD'},
      DateTime.utc(2030, 1, 1, 9),
      'Meeting',
    );
    expect(ics, contains('DTSTART:20300101T090000Z'));
    expect(ics, contains(r'SUMMARY:Follow-up: A\, B\; C\nD'));
    expect(ics, contains('TRIGGER:-PT15M'));
  });

  test('offline layout images use memory and reject external schemes', () {
    final provider = layoutImageProvider('data:image/png;base64,AQID');
    expect(provider, isA<MemoryImage>());
    expect((provider as MemoryImage).bytes, [1, 2, 3]);
    expect(
      () => layoutImageProvider('file:///private/example.png'),
      throwsA(isA<AppFailure>()),
    );
  });

  test('calendar text escapes bare CR, CRLF and LF without new properties', () {
    final ics = customerReminder(
      {'id': 'line-break-test', 'contactName': 'A\rB\r\nC\nD'},
      DateTime.utc(2030, 1, 1, 9),
      'first\rBEGIN:VEVENT\r\nthird\nfourth',
    );
    final unfolded = ics.replaceAll('\r\n ', '');
    expect(unfolded, contains(r'SUMMARY:Follow-up: A\nB\nC\nD'));
    expect(unfolded, contains(r'Notes: first\nBEGIN:VEVENT\nthird\nfourth'));
    expect(ics.replaceAll('\r\n', ''), isNot(contains('\r')));
    expect(
      ics.split('\r\n').where((line) => line == 'BEGIN:VEVENT'),
      hasLength(1),
    );
  });

  test(
    'customer account password uses the backend eight-character raw minimum',
    () {
      final password = customerAccountFields.singleWhere(
        (field) => field.name == 'password',
      );
      expect(password.validate(' abcdef '), isNull);
      expect(password.validate(' abcde '), isNotNull);
    },
  );

  testWidgets(
    'employee clearing sends null and blank password never resets it',
    (tester) async {
      JsonMap? submitted;
      await tester.pumpWidget(
        MaterialApp(
          home: RecordFormPage(
            title: 'Edit employee',
            offline: false,
            clearEmptyOptional: true,
            fields: const [
              FormFieldSpec('department', 'Department', required: false),
              FormFieldSpec(
                'yearsOfExperience',
                'Experience',
                kind: FieldKind.integer,
                required: false,
              ),
              FormFieldSpec(
                'password',
                'New password',
                kind: FieldKind.password,
                required: false,
              ),
            ],
            initial: const {'department': 'Sales', 'yearsOfExperience': 8},
            onSubmit: (values) async {
              submitted = values;
              throw const AppFailure('Keep form open for review.');
            },
          ),
        ),
      );
      await tester.enterText(find.byKey(const ValueKey('department')), '');
      await tester.enterText(
        find.byKey(const ValueKey('yearsOfExperience')),
        '',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(submitted, containsPair('department', null));
      expect(submitted, containsPair('yearsOfExperience', null));
      expect(submitted!.containsKey('password'), isFalse);
    },
  );

  test(
    'employee edit keeps email immutable and offline cannot reset passwords',
    () async {
      final repository = await OfflineRepository.open(
        MemoryStore(),
        Role.admin,
      );
      final fields = await resourceFields(
        repository,
        Resource.employeeAccess,
        editing: true,
      );
      expect(fields.any((field) => field.name == 'email'), isTrue);
      expect(
        fields.singleWhere((field) => field.name == 'email').readOnly,
        isTrue,
      );
      expect(fields.any((field) => field.name == 'password'), isFalse);
    },
  );

  testWidgets(
    'invalid form cannot submit; network failure keeps values for retry',
    (tester) async {
      var attempts = 0;
      JsonMap? submitted;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RecordFormPage(
                      title: 'Test form',
                      offline: true,
                      fields: const [
                        FormFieldSpec('email', 'Email', kind: FieldKind.email),
                        FormFieldSpec(
                          'count',
                          'Plot count',
                          kind: FieldKind.integer,
                          min: 1,
                        ),
                      ],
                      onSubmit: (values) async {
                        attempts++;
                        submitted = values;
                        if (attempts == 1) {
                          throw const AppFailure('Connection lost. Try again.');
                        }
                      },
                    ),
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(attempts, 0);
      expect(find.text('Enter Email.'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('email')),
        'customer@example.test',
      );
      await tester.enterText(find.byKey(const ValueKey('count')), '4');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('Connection lost. Try again.'), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('email')))
            .controller!
            .text,
        'customer@example.test',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(attempts, 2);
      expect(submitted!['count'], 4);
      expect(find.text('Open'), findsOneWidget);
    },
  );

  Future<AppController> offline(Role role) async {
    final controller = AppController(
      transport: FakeTransport(),
      preferences: MemoryStore(),
    );
    await controller.enterOffline(role);
    addTearDown(controller.dispose);
    return controller;
  }

  testWidgets(
    'agent inquiry accepts corrected message after validation failure',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final app = await offline(Role.agent);
      final plot = await app.repository!.detail(Resource.plots, 'demo-plot-3');
      await tester.pumpWidget(
        MaterialApp(
          theme: Brand.theme,
          home: RecordDetailPage(
            controller: app,
            resource: Resource.plots,
            record: plot,
          ),
        ),
      );
      await tester.pumpAndSettle();
      Future<void> tap(Finder target) async {
        await tester.ensureVisible(target);
        await tester.pumpAndSettle();
        await tester.tap(target);
        await tester.pumpAndSettle();
      }

      Future<void> fillMessage(String text) async {
        final field = find.byKey(const ValueKey('message'));
        await tester.ensureVisible(field);
        await tester.pumpAndSettle();
        await tester.enterText(field, text);
        await tester.pumpAndSettle();
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        expect(tester.widget<TextFormField>(field).controller!.text, text);
        expect(tester.state<FormFieldState<String>>(field).value, text);
      }

      await tap(find.text('Make an inquiry'));
      await fillMessage('Short');
      await tap(find.text('Save inquiry locally'));
      expect(find.text('Use at least 10 characters.'), findsOneWidget);
      expect(
        find.text('Check the highlighted fields before saving.'),
        findsOneWidget,
      );
      const message =
          'Native offline inquiry validation and persistence check.';
      await fillMessage(message);
      await tap(find.text('Save inquiry locally'));
      expect(find.byType(RecordFormPage), findsNothing);
      expect(
        find.text('Inquiry saved locally. It was not sent.'),
        findsOneWidget,
      );
      final data = jsonObject(
        jsonDecode((await app.preferences.read(OfflineRepository.storageKey))!),
      );
      final inquiries = jsonList(data['inquiries']);
      expect(inquiries, hasLength(1));
      expect(inquiries.single['message'], message);
      expect(inquiries.single['customerEmail'], app.user!.email);
      expect((app.transport as FakeTransport).calls, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'customer plot permits favorites and inquiry but hides staff writes',
    (tester) async {
      tester.view.physicalSize = const Size(500, 1500);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = await offline(Role.customer);
      final plots = await controller.repository!.list(Resource.plots);
      expect(plots, isNotEmpty);
      await tester.pumpWidget(
        MaterialApp(
          home: RecordDetailPage(
            controller: controller,
            resource: Resource.plots,
            record: plots.first,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Edit details'), findsNothing);
      expect(find.text('Delete record'), findsNothing);
      expect(find.text('Add lead'), findsNothing);
      expect(find.text('Make an inquiry'), findsOneWidget);
      await tester.ensureVisible(find.text('Add to favorites'));
      await tester.tap(find.text('Add to favorites'));
      await tester.pumpAndSettle();
      final favorites = await controller.repository!.list(Resource.favorites);
      expect(
        favorites.any((row) => row['plotId'] == plots.first['id']),
        isTrue,
      );
      expect(find.text('Added to local favorites.'), findsOneWidget);
      expect((controller.transport as FakeTransport).calls, isEmpty);
    },
  );

  testWidgets('admin can create a venture from the inventory entry page', (
    tester,
  ) async {
    final controller = await offline(Role.admin);
    await tester.pumpWidget(
      MaterialApp(
        home: WorkflowPage(
          controller: controller,
          resource: Resource.locations,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Add venture'), findsOneWidget);
    await tester.tap(find.text('Add venture'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('locationName')), findsOneWidget);
    expect(find.byKey(const ValueKey('plotCount')), findsOneWidget);
    expect((controller.transport as FakeTransport).calls, isEmpty);
  });
}
