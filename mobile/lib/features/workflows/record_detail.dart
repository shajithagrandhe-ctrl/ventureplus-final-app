import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:ventureplus/core/app_controller.dart';
import 'package:ventureplus/ui/components.dart';
import 'package:ventureplus/ui/theme.dart';

import 'forms.dart';
import 'resource_forms.dart';
import 'workflow_exports.dart';
import 'workflow_page.dart';

class RecordDetailPage extends StatefulWidget {
  const RecordDetailPage({
    super.key,
    required this.controller,
    required this.resource,
    required this.record,
  });
  final AppController controller;
  final Resource resource;
  final JsonMap record;
  @override
  State<RecordDetailPage> createState() => _RecordDetailPageState();
}

class _RecordDetailPageState extends State<RecordDetailPage> {
  late JsonMap _row;
  bool _loading = true, _working = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _row = widget.record;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repository = activeRepository(widget.controller);
      Permissions.require(
        Permissions.canRead(repository.user.role, widget.resource),
      );
      final JsonMap row;
      if ([Resource.plots, Resource.agents].contains(widget.resource)) {
        row = await repository.detail(widget.resource, '${_row['id']}');
      } else {
        final rows = await repository.list(widget.resource);
        row = rows.firstWhere(
          (row) => row['id'] == _row['id'],
          orElse: () =>
              throw const AppFailure('This record is no longer available.'),
        );
      }
      if (mounted) setState(() => _row = row);
    } catch (error) {
      if (mounted) setState(() => _error = failureMessage(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_working) return;
    setState(() => _working = true);
    try {
      await action();
    } catch (error) {
      if (mounted) showFeedback(context, failureMessage(error));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext _) {
    final role = widget.controller.user?.role;
    final resource = widget.resource;
    final fields = <String, String>{
      'plotNumber': 'Plot number',
      'area': 'Area (sq yd)',
      'pricePerSqYard': 'Price per sq yd',
      'customerName': 'Customer',
      'contactName': 'Customer',
      'email': 'Email',
      'contactNumber': 'Phone',
      'location': 'Location',
      'uniqueId': 'Reference',
      'budget': 'Budget',
      'recordOwner': 'Record owner',
      'leadName': 'Lead owner',
      'latitude': 'Latitude',
      'longitude': 'Longitude',
      'address': 'Address',
      'fullName': 'Full name',
      'displayName': 'Display name',
      'employeeId': 'Employee code',
      'phoneNumber': 'Phone',
      'department': 'Department',
      'position': 'Position',
      'notes': 'Notes',
      'createdAt': 'Created',
      'updatedAt': 'Last updated',
    };
    final profile = _row['employeeProfile'] is Map
        ? Map<String, dynamic>.from(_row['employeeProfile'])
        : <String, dynamic>{};
    return Scaffold(
      appBar: AppBar(title: Text(recordTitle(resource, _row))),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              PageBody(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ModeStrip(offline: widget.controller.isOffline),
                    const SizedBox(height: Brand.gap),
                    if (_loading)
                      const LoadingSkeleton()
                    else if (_error != null)
                      StateMessage(
                        title: 'Could not load details',
                        message: _error!,
                        action: _load,
                      )
                    else if (role == null ||
                        !Permissions.canRead(role, resource))
                      const StateMessage(
                        title: 'Access unavailable',
                        message: 'Sign in with an authorized account.',
                      )
                    else ...[
                      if (_row['status'] != null || profile['status'] != null)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: StatusBadge(
                            '${_row['status'] ?? profile['status']}',
                          ),
                        ),
                      const SizedBox(height: Brand.gap),
                      ...fields.entries
                          .where(
                            (entry) =>
                                _row[entry.key] != null &&
                                _row[entry.key] is! Map &&
                                '${_row[entry.key]}'.isNotEmpty,
                          )
                          .map(
                            (entry) =>
                                DetailFact(entry.value, '${_row[entry.key]}'),
                          ),
                      if (resource == Resource.plots) ...[
                        if (_row['area'] is num &&
                            _row['pricePerSqYard'] is num)
                          DetailFact(
                            'Total plot value',
                            '${(_row['area'] as num) * (_row['pricePerSqYard'] as num)}',
                          ),
                        if (_row['venture'] is Map)
                          DetailFact(
                            'Venture',
                            '${_row['venture']['name'] ?? ''}',
                          ),
                        if (_row['leads'] is List &&
                            (_row['leads'] as List).isNotEmpty) ...[
                          Text(
                            'Linked leads',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          ...(_row['leads'] as List).map(
                            (lead) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text('${lead['customerName']}'),
                              subtitle: Text('${lead['email']}'),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => RecordDetailPage(
                                    controller: widget.controller,
                                    resource: Resource.leads,
                                    record: Map<String, dynamic>.from(lead),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                        OutlinedButton.icon(
                          onPressed: _working
                              ? null
                              : () => _run(() async {
                                  await activeRepository(widget.controller)
                                      .create(Resource.favorites, {
                                        'plotId': _row['id'],
                                      });
                                  if (mounted) {
                                    showFeedback(
                                      context,
                                      widget.controller.isOffline
                                          ? 'Added to local favorites.'
                                          : 'Added to favorites.',
                                    );
                                  }
                                }),
                          icon: const Icon(Icons.favorite_border),
                          label: const Text('Add to favorites'),
                        ),
                        const SizedBox(height: Brand.compact),
                        OutlinedButton.icon(
                          onPressed: _working
                              ? null
                              : () => _run(() async {
                                  final repository = activeRepository(
                                    widget.controller,
                                  );
                                  final saved = await Navigator.push<bool>(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => RecordFormPage(
                                        title: 'Send inquiry',
                                        fields: inquiryFields,
                                        offline: repository.isOffline,
                                        initial: {
                                          'customerName':
                                              repository.user.fullName,
                                          'customerEmail':
                                              repository.user.email,
                                        },
                                        submitLabel: repository.isOffline
                                            ? 'Save inquiry locally'
                                            : 'Send inquiry',
                                        onSubmit: (values) async {
                                          await repository.submitInquiry({
                                            ...values,
                                            'plotId': _row['id'],
                                          });
                                        },
                                      ),
                                    ),
                                  );
                                  if (saved == true && mounted) {
                                    showFeedback(
                                      context,
                                      repository.isOffline
                                          ? 'Inquiry saved locally. It was not sent.'
                                          : 'Inquiry sent.',
                                    );
                                  }
                                }),
                          icon: const Icon(Icons.chat_bubble_outline),
                          label: const Text('Make an inquiry'),
                        ),
                        if (Permissions.canCreate(role, Resource.leads)) ...[
                          const SizedBox(height: Brand.compact),
                          OutlinedButton.icon(
                            onPressed: _working
                                ? null
                                : () => _run(() async {
                                    if (await openResourceForm(
                                      context,
                                      widget.controller,
                                      Resource.leads,
                                      initial: {
                                        'plotId': _row['id'],
                                        'pricePerSqYard':
                                            _row['pricePerSqYard'],
                                      },
                                    )) {
                                      if (mounted) {
                                        showFeedback(
                                          context,
                                          savedMessage(widget.controller),
                                        );
                                      }
                                      await _load();
                                    }
                                  }),
                            icon: const Icon(Icons.person_add_alt_1_outlined),
                            label: const Text('Add lead'),
                          ),
                        ],
                      ],
                      if (resource == Resource.employeeAccess) ...[
                        ...{
                              'firstName': 'First name',
                              'lastName': 'Last name',
                              'dateOfBirth': 'Date of birth',
                              'yearsOfExperience': 'Years of experience',
                              'currentCompany': 'Current company',
                              'previousCompanies': 'Previous companies',
                              'currentPosition': 'Current position',
                              'roleGiven': 'Role description',
                              'dateOfJoining': 'Joining date',
                              'dateOfRelieving': 'Relieving date',
                              'achievements': 'Achievements',
                              'emailVerified': 'Email verified',
                              'phoneVerified': 'Phone verified',
                            }.entries
                            .where((entry) => profile[entry.key] != null)
                            .map(
                              (entry) => DetailFact(
                                entry.value,
                                '${profile[entry.key]}',
                              ),
                            ),
                        DetailFact(
                          'Assigned locations',
                          '${profile['assignedLocationIds'] is List ? (profile['assignedLocationIds'] as List).length : 0}',
                        ),
                        DetailFact(
                          'Assigned ventures',
                          '${profile['assignedVentureIds'] is List ? (profile['assignedVentureIds'] as List).length : 0}',
                        ),
                        OutlinedButton(
                          onPressed: _working
                              ? null
                              : () => _run(() async {
                                  final next = profile['status'] == 'FROZEN'
                                      ? 'ACTIVE'
                                      : 'FROZEN';
                                  if (!await confirmAction(
                                    context,
                                    next == 'FROZEN'
                                        ? 'Freeze employee?'
                                        : 'Reactivate employee?',
                                    'This changes this employee account’s access status.',
                                  )) {
                                    return;
                                  }
                                  await activeRepository(widget.controller)
                                      .setEmployeeStatus('${_row['id']}', next);
                                  if (mounted) {
                                    showFeedback(
                                      context,
                                      savedMessage(widget.controller),
                                    );
                                  }
                                  await _load();
                                }),
                          child: Text(
                            profile['status'] == 'FROZEN'
                                ? 'Reactivate employee'
                                : 'Freeze employee',
                          ),
                        ),
                      ],
                      if (resource == Resource.customers)
                        OutlinedButton.icon(
                          onPressed: () => saveCustomerReminder(context, _row),
                          icon: const Icon(Icons.event_outlined),
                          label: const Text('Save follow-up reminder'),
                        ),
                      if (_row['contactNumber'] != null ||
                          _row['phoneNumber'] != null)
                        TextButton.icon(
                          onPressed: () async {
                            final phone =
                                '${_row['contactNumber'] ?? _row['phoneNumber']}'
                                    .replaceAll(RegExp(r'[^0-9+]'), '');
                            if (phone.isEmpty) {
                              showFeedback(
                                context,
                                'No callable phone number is available.',
                              );
                              return;
                            }
                            try {
                              final opened = await launchUrl(
                                Uri(scheme: 'tel', path: phone),
                              );
                              if (!opened && mounted) {
                                showFeedback(
                                  context,
                                  'No phone application is available. You can copy the number instead.',
                                );
                              }
                            } catch (_) {
                              if (mounted) {
                                showFeedback(
                                  context,
                                  'Could not open the phone application.',
                                );
                              }
                            }
                          },
                          icon: const Icon(Icons.phone_outlined),
                          label: const Text('Call customer'),
                        ),
                      if (_row['contactNumber'] != null ||
                          _row['phoneNumber'] != null)
                        TextButton.icon(
                          onPressed: () async {
                            await Clipboard.setData(
                              ClipboardData(
                                text:
                                    '${_row['contactNumber'] ?? _row['phoneNumber']}',
                              ),
                            );
                            if (mounted) {
                              showFeedback(context, 'Phone number copied.');
                            }
                          },
                          icon: const Icon(Icons.content_copy),
                          label: const Text('Copy phone number'),
                        ),
                      const SizedBox(height: Brand.gap),
                      if (Permissions.canUpdate(role, resource))
                        BusyButton(
                          label: 'Edit details',
                          busy: _working,
                          onPressed: () => _run(() async {
                            if (await openResourceForm(
                              context,
                              widget.controller,
                              resource,
                              record: _row,
                            )) {
                              if (mounted) {
                                showFeedback(
                                  context,
                                  savedMessage(widget.controller),
                                );
                              }
                              await _load();
                            }
                          }),
                        ),
                      if (Permissions.canDelete(role, resource))
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            foregroundColor: Brand.error,
                          ),
                          onPressed: _working
                              ? null
                              : () => _run(() async {
                                  if (!await confirmAction(
                                    context,
                                    'Delete this record?',
                                    'This removes ${recordTitle(resource, _row)}${widget.controller.isOffline ? ' from this device' : ' from the server'}.',
                                  )) {
                                    return;
                                  }
                                  await activeRepository(widget.controller)
                                      .remove(resource, '${_row['id']}');
                                  if (mounted) {
                                    showFeedback(
                                      context,
                                      widget.controller.isOffline
                                          ? 'Deleted locally.'
                                          : 'Deleted from the server.',
                                    );
                                    Navigator.pop(context, true);
                                  }
                                }),
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Delete record'),
                        ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DetailFact extends StatelessWidget {
  const DetailFact(this.label, this.value, {super.key});
  final String label, value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: Brand.gap),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 2),
        SelectableText(value, style: Theme.of(context).textTheme.bodyLarge),
      ],
    ),
  );
}
