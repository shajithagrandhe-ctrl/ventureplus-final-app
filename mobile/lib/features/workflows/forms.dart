import 'package:flutter/material.dart';
import 'package:ventureplus/core/app_controller.dart';
import 'package:ventureplus/ui/components.dart';
import 'package:ventureplus/ui/theme.dart';

enum FieldKind {
  text,
  email,
  password,
  integer,
  decimal,
  multiline,
  lines,
  choice,
  choices,
  toggle,
  date,
}

class FormFieldSpec {
  const FormFieldSpec(
    this.name,
    this.label, {
    this.kind = FieldKind.text,
    this.required = true,
    this.minLength = 1,
    this.min,
    this.max,
    this.options = const {},
    this.helper,
    this.readOnly = false,
  });
  final String name, label;
  final FieldKind kind;
  final bool required, readOnly;
  final int minLength;
  final num? min, max;
  final Map<String, String> options;
  final String? helper;

  String? validate(String? input) {
    final value = kind == FieldKind.password
        ? input ?? ''
        : (input ?? '').trim();
    if (value.isEmpty) return required ? 'Enter $label.' : null;
    if (value.length < minLength) return 'Use at least $minLength characters.';
    if (kind == FieldKind.email &&
        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value)) {
      return 'Enter a valid email address.';
    }
    if (kind == FieldKind.integer || kind == FieldKind.decimal) {
      final parsed = kind == FieldKind.integer
          ? int.tryParse(value)
          : double.tryParse(value);
      if (parsed == null || !parsed.isFinite) {
        return kind == FieldKind.integer
            ? 'Enter a whole number.'
            : 'Enter a number.';
      }
      if (min != null && parsed < min!) return 'Enter $min or more.';
      if (max != null && parsed > max!) return 'Enter $max or less.';
    }
    if (kind == FieldKind.date) {
      final parsed = DateTime.tryParse(value);
      if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value) ||
          parsed == null ||
          parsed.toIso8601String().substring(0, 10) != value) {
        return 'Use a valid date in YYYY-MM-DD format.';
      }
    }
    if (kind == FieldKind.choice && !options.containsKey(value)) {
      return 'Choose an available option.';
    }
    return null;
  }
}

class RecordFormPage extends StatefulWidget {
  const RecordFormPage({
    super.key,
    required this.title,
    required this.fields,
    required this.onSubmit,
    this.initial = const {},
    required this.offline,
    this.description,
    this.confirmationMessage,
    this.clearEmptyOptional = false,
    this.submitLabel = 'Save',
  });
  final String title, submitLabel;
  final String? description, confirmationMessage;
  final List<FormFieldSpec> fields;
  final JsonMap initial;
  final bool offline;
  final bool clearEmptyOptional;
  final Future<void> Function(JsonMap) onSubmit;
  @override
  State<RecordFormPage> createState() => _RecordFormPageState();
}

class _RecordFormPageState extends State<RecordFormPage> {
  final _form = GlobalKey<FormState>();
  final _text = <String, TextEditingController>{};
  final _selected = <String, dynamic>{};
  bool _busy = false, _dirty = false, _allowPop = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    for (final field in widget.fields) {
      final initial = widget.initial[field.name];
      if (field.kind == FieldKind.toggle) {
        _selected[field.name] = initial == true;
      } else if (field.kind == FieldKind.choices) {
        _selected[field.name] =
            (initial is List ? initial.map((e) => '$e') : <String>[]).toSet();
      } else if (field.kind == FieldKind.choice) {
        _selected[field.name] =
            initial != null && field.options.containsKey('$initial')
            ? '$initial'
            : null;
      } else {
        final value = initial == null
            ? ''
            : field.kind == FieldKind.lines && initial is List
            ? initial.join('\n')
            : '$initial';
        _text[field.name] = TextEditingController(
          text: field.kind == FieldKind.date && value.length >= 10
              ? value.substring(0, 10)
              : value,
        );
      }
    }
  }

  @override
  void dispose() {
    for (final controller in _text.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _exit() async {
    if (_busy) return;
    if (_dirty &&
        !await confirmAction(
          context,
          'Discard changes?',
          'Your unsaved changes will be lost.',
        )) {
      return;
    }
    if (!mounted) return;
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context);
    });
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) {
      setState(() => _error = 'Check the highlighted fields before saving.');
      return;
    }
    if (widget.confirmationMessage != null &&
        !await confirmAction(
          context,
          'Save changes?',
          widget.confirmationMessage!,
        )) {
      return;
    }
    if (!mounted) return;
    final values = <String, dynamic>{};
    for (final field in widget.fields) {
      if (field.kind == FieldKind.toggle) {
        values[field.name] = _selected[field.name] == true;
        continue;
      }
      if (field.kind == FieldKind.choices) {
        values[field.name] = (_selected[field.name] as Set<String>).toList();
        continue;
      }
      final value = field.kind == FieldKind.choice
          ? _selected[field.name] as String? ?? ''
          : field.kind == FieldKind.password
          ? _text[field.name]!.text
          : _text[field.name]!.text.trim();
      if (!field.required && value.isEmpty) {
        if (widget.clearEmptyOptional && field.kind != FieldKind.password) {
          values[field.name] = field.kind == FieldKind.lines
              ? <String>[]
              : null;
          continue;
        }
        if (field.kind == FieldKind.multiline || field.kind == FieldKind.date) {
          values[field.name] = '';
        }
        if (field.kind == FieldKind.lines) values[field.name] = <String>[];
        continue;
      }
      values[field.name] = switch (field.kind) {
        FieldKind.integer => int.parse(value),
        FieldKind.decimal => double.parse(value),
        FieldKind.lines =>
          value
              .split('\n')
              .map((line) => line.trim())
              .where((line) => line.isNotEmpty)
              .toList(),
        _ => value,
      };
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onSubmit(values);
      if (!mounted) return;
      setState(() {
        _allowPop = true;
        _dirty = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context, true);
      });
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is AppFailure
              ? error.message
              : 'Could not save. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _field(FormFieldSpec field) {
    if (field.kind == FieldKind.toggle) {
      return SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        title: Text(field.label),
        subtitle: field.helper == null ? null : Text(field.helper!),
        value: _selected[field.name] == true,
        onChanged: _busy || field.readOnly
            ? null
            : (value) => setState(() {
                _selected[field.name] = value;
                _dirty = true;
              }),
      );
    }
    if (field.kind == FieldKind.choices) {
      final selected = _selected[field.name] as Set<String>;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(field.label, style: Theme.of(context).textTheme.titleMedium),
          if (field.helper != null)
            Text(field.helper!, style: Theme.of(context).textTheme.bodySmall),
          if (field.options.isEmpty) const Text('No options are available.'),
          ...field.options.entries.map(
            (entry) => CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(entry.value),
              value: selected.contains(entry.key),
              onChanged: _busy || field.readOnly
                  ? null
                  : (value) => setState(() {
                      value == true
                          ? selected.add(entry.key)
                          : selected.remove(entry.key);
                      _dirty = true;
                    }),
            ),
          ),
        ],
      );
    }
    if (field.kind == FieldKind.choice) {
      return DropdownButtonFormField<String>(
        key: ValueKey(field.name),
        initialValue: _selected[field.name] as String?,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: field.label,
          helperText: field.helper,
          helperMaxLines: 3,
        ),
        validator: field.validate,
        items: field.options.entries
            .map(
              (entry) => DropdownMenuItem(
                value: entry.key,
                child: Text(entry.value, overflow: TextOverflow.ellipsis),
              ),
            )
            .toList(),
        onChanged: _busy || field.readOnly
            ? null
            : (value) => setState(() {
                _selected[field.name] = value;
                _dirty = true;
              }),
      );
    }
    return TextFormField(
      key: ValueKey(field.name),
      controller: _text[field.name],
      readOnly: field.readOnly,
      enabled: !_busy,
      obscureText: field.kind == FieldKind.password,
      autocorrect:
          field.kind != FieldKind.password && field.kind != FieldKind.email,
      enableSuggestions: field.kind != FieldKind.password,
      minLines: [FieldKind.multiline, FieldKind.lines].contains(field.kind)
          ? 3
          : 1,
      maxLines: [FieldKind.multiline, FieldKind.lines].contains(field.kind)
          ? 6
          : 1,
      keyboardType: switch (field.kind) {
        FieldKind.email => TextInputType.emailAddress,
        FieldKind.integer => TextInputType.number,
        FieldKind.decimal => const TextInputType.numberWithOptions(
          decimal: true,
          signed: true,
        ),
        FieldKind.multiline || FieldKind.lines => TextInputType.multiline,
        FieldKind.date => TextInputType.datetime,
        _ => TextInputType.text,
      },
      decoration: InputDecoration(
        labelText: field.label,
        helperText: field.helper,
        helperMaxLines: 4,
      ),
      validator: field.validate,
      onChanged: (_) {
        _dirty = true;
      },
    );
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _allowPop || (!_dirty && !_busy),
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) _exit();
    },
    child: Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        leading: IconButton(
          tooltip: 'Back',
          onPressed: _exit,
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: PageBody(
            child: Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ModeStrip(offline: widget.offline),
                  const SizedBox(height: Brand.gap),
                  if (widget.description != null) ...[
                    Text(widget.description!),
                    const SizedBox(height: Brand.gap),
                  ],
                  ...widget.fields.expand(
                    (field) => [
                      _field(field),
                      const SizedBox(height: Brand.gap),
                    ],
                  ),
                  if (_error != null) ...[
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Brand.error),
                      ),
                    ),
                    const SizedBox(height: Brand.gap),
                  ],
                  BusyButton(
                    label: widget.submitLabel,
                    busy: _busy,
                    onPressed: _save,
                  ),
                  const SizedBox(height: Brand.section),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class ModeStrip extends StatelessWidget {
  const ModeStrip({super.key, required this.offline});
  final bool offline;
  @override
  Widget build(BuildContext context) => Semantics(
    label: offline
        ? 'Offline Demo. Changes remain on this device.'
        : 'Connected to the server.',
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: Brand.gap, vertical: 10),
      decoration: BoxDecoration(
        color: offline ? Brand.amberLight : Brand.sage100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            offline ? Icons.cloud_off_outlined : Icons.cloud_done_outlined,
            size: 20,
            color: offline ? Brand.warning : Brand.sage900,
          ),
          const SizedBox(width: Brand.compact),
          Expanded(
            child: Text(
              offline ? 'Offline Demo · saved on this device' : 'Connected',
              style: TextStyle(color: offline ? Brand.warning : Brand.sage900),
            ),
          ),
        ],
      ),
    ),
  );
}

Map<String, String> choices(Iterable<String> values) => {
  for (final value in values) value: value.replaceAll('_', ' ').toLowerCase(),
};

String resourceTitle(Resource resource) => switch (resource) {
  Resource.locations => 'Locations',
  Resource.ventures => 'Ventures',
  Resource.plots => 'Plots',
  Resource.leads => 'Leads',
  Resource.customers => 'Customer records',
  Resource.tracking => 'Tracking updates',
  Resource.favorites => 'Favorites',
  Resource.employees => 'Employees',
  Resource.admins => 'Administrators',
  Resource.customerAccounts => 'Customer accounts',
  Resource.agents => 'Agents & employees',
  Resource.employeeAccess => 'Employee access',
};

String recordTitle(Resource resource, JsonMap row) => switch (resource) {
  Resource.locations || Resource.ventures => '${row['name'] ?? 'Unnamed'}',
  Resource.plots => 'Plot ${row['plotNumber'] ?? '—'}',
  Resource.leads => '${row['customerName'] ?? 'Lead'}',
  Resource.customers => '${row['contactName'] ?? 'Customer'}',
  Resource.tracking =>
    '${(row['customer'] is Map ? row['customer']['contactName'] : null) ?? row['address'] ?? 'Tracking update'}',
  Resource.favorites =>
    'Plot ${(row['plot'] is Map ? row['plot']['plotNumber'] : null) ?? '—'}',
  _ => '${row['fullName'] ?? row['displayName'] ?? row['name'] ?? 'Account'}',
};
