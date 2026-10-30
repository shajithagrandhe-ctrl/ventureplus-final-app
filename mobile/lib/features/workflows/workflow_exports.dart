import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:ventureplus/core/app_controller.dart';
import 'package:ventureplus/ui/components.dart';

String csvCell(Object? value) {
  var text = '${value ?? ''}'.replaceAll(RegExp(r'[\r\n]+'), ' ').trim();
  if (RegExp(r'^[=+\-@\t]').hasMatch(text)) text = "'$text";
  return '"${text.replaceAll('"', '""')}"';
}

String customerCsv(List<JsonMap> records) {
  const fields = {
    'contactName': 'Customer Name',
    'contactNumber': 'Phone',
    'location': 'Location',
    'budget': 'Budget',
    'status': 'Status',
    'recordOwner': 'Record Owner',
    'interestedIn': 'Interested In',
    'notes': 'Notes',
    'createdAt': 'Created At',
    'updatedAt': 'Updated At',
  };
  return '\uFEFF${[fields.values.map(csvCell).join(','), ...records.map((row) => fields.keys.map((key) => csvCell(row[key])).join(','))].join('\r\n')}';
}

String _icsEscape(Object? text) => '${text ?? ''}'
    .replaceAll('\\', '\\\\')
    .replaceAll(';', r'\;')
    .replaceAll(',', r'\,')
    .replaceAll(RegExp(r'\r\n|\r|\n'), r'\n');
String _icsDate(DateTime value) =>
    '${value.toUtc().toIso8601String().replaceAll(RegExp(r'[-:]'), '').split('.').first}Z';

String customerReminder(JsonMap record, DateTime start, String notes) {
  final now = DateTime.now();
  final lines = [
    'BEGIN:VCALENDAR',
    'VERSION:2.0',
    'PRODID:-//VenturePlus//Customers//EN',
    'CALSCALE:GREGORIAN',
    'METHOD:PUBLISH',
    'BEGIN:VEVENT',
    'UID:customer-${Uri.encodeComponent('${record['id']}')}-${now.microsecondsSinceEpoch}@ventureplus',
    'DTSTAMP:${_icsDate(now)}',
    'DTSTART:${_icsDate(start)}',
    'DTEND:${_icsDate(start.add(const Duration(minutes: 30)))}',
    'SUMMARY:${_icsEscape('Follow-up: ${record['contactName']}')}',
    'DESCRIPTION:${_icsEscape('Customer: ${record['contactName']}\nPhone: ${record['contactNumber']}\nLocation: ${record['location']}\nStatus: ${record['status']}\nNotes: $notes')}',
    'BEGIN:VALARM',
    'ACTION:DISPLAY',
    'DESCRIPTION:Reminder',
    'TRIGGER:-PT15M',
    'END:VALARM',
    'END:VEVENT',
    'END:VCALENDAR',
  ];
  // Fold by UTF-8 octets, preserving complete code points (RFC 5545).
  return '${lines.map((line) {
    var result = '', count = 0;
    for (final rune in line.runes) {
      final char = String.fromCharCode(rune), length = utf8.encode(String.fromCharCode(rune)).length;
      if (count + length > 75) {
        result += '\r\n ';
        count = 1;
      }
      result += char;
      count += length;
    }
    return result;
  }).join('\r\n')}\r\n';
}

Future<void> exportCustomers(
  BuildContext context,
  List<JsonMap> rows, {
  required bool offline,
}) async {
  try {
    final saved = await FilePicker.saveFile(
      fileName:
          '${offline ? 'offline-demo-' : ''}customers-${DateTime.now().toIso8601String().substring(0, 10)}.csv',
      bytes: Uint8List.fromList(utf8.encode(customerCsv(rows))),
      mimeType: 'text/csv',
    );
    if (saved != null && context.mounted) {
      showFeedback(context, 'Customer export saved to your selected location.');
    }
  } catch (_) {
    if (context.mounted) {
      showFeedback(context, 'Could not save the export. Please try again.');
    }
  }
}

Future<void> saveCustomerReminder(BuildContext context, JsonMap record) async {
  final day = await showDatePicker(
    context: context,
    firstDate: DateTime.now(),
    lastDate: DateTime.now().add(const Duration(days: 3650)),
    initialDate: DateTime.now(),
  );
  if (day == null || !context.mounted) return;
  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.now(),
  );
  if (time == null || !context.mounted) return;
  final start = DateTime(day.year, day.month, day.day, time.hour, time.minute);
  if (!start.isAfter(DateTime.now())) {
    showFeedback(context, 'Choose a future date and time for your reminder.');
    return;
  }
  try {
    final saved = await FilePicker.saveFile(
      fileName: 'ventureplus-follow-up.ics',
      bytes: Uint8List.fromList(
        utf8.encode(
          customerReminder(record, start, '${record['notes'] ?? ''}'),
        ),
      ),
      mimeType: 'text/calendar',
    );
    if (saved != null && context.mounted) {
      showFeedback(
        context,
        'Reminder file saved. Open it in your calendar to add the event.',
      );
    }
  } catch (_) {
    if (context.mounted) {
      showFeedback(context, 'Could not save the reminder. Please try again.');
    }
  }
}
