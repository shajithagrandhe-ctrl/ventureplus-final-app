import 'package:flutter/material.dart';

import 'package:ventureplus/core/app_controller.dart';
import 'package:ventureplus/ui/components.dart';
import 'package:ventureplus/ui/theme.dart';

import 'forms.dart';
import 'resource_forms.dart';
import 'venture_detail.dart';
import 'employee_otp.dart';
import 'workflow_exports.dart';
import 'record_detail.dart';
export 'record_detail.dart';

VentureRepository activeRepository(AppController controller) {
  final repository = controller.repository;
  if (repository == null) {
    throw const AppFailure('Sign in to continue.', statusCode: 401);
  }
  return repository;
}

String failureMessage(Object error) => error is AppFailure
    ? error.message
    : 'Could not load this information. Please try again.';

String savedMessage(AppController controller) => controller.isOffline
    ? 'Saved locally in Offline Demo.'
    : 'Saved to the server.';

Future<bool> openResourceForm(
  BuildContext context,
  AppController controller,
  Resource resource, {
  JsonMap? record,
  JsonMap initial = const {},
}) async {
  final repository = activeRepository(controller);
  final editing = record != null;
  Permissions.require(
    editing
        ? Permissions.canUpdate(repository.user.role, resource)
        : Permissions.canCreate(repository.user.role, resource),
  );
  final fields = await resourceFields(repository, resource, editing: editing);
  if (!context.mounted) return false;
  return await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => RecordFormPage(
            title:
                '${editing ? 'Edit' : 'Add'} ${switch (resource) {
                  Resource.ventures => 'venture',
                  Resource.plots => 'plot',
                  Resource.leads => 'lead',
                  Resource.customers => 'customer record',
                  Resource.employeeAccess => 'employee',
                  Resource.tracking => 'tracking update',
                  _ => resourceTitle(resource).toLowerCase(),
                }}',
            fields: fields,
            initial: {...formInitial(repository, resource, record), ...initial},
            offline: repository.isOffline,
            clearEmptyOptional: resource == Resource.employeeAccess,
            confirmationMessage: editing
                ? 'Update this ${resourceTitle(resource).toLowerCase()} record${repository.isOffline ? ' on this device' : ' on the server'}?'
                : null,
            description: resource == Resource.ventures
                ? 'Create a venture and its numbered plots. Add its image and layout coordinates from venture details.'
                : resource == Resource.employeeAccess && repository.isOffline
                ? 'Offline employee profiles are stored on this device. They do not create real login credentials.'
                : null,
            onSubmit: (values) async {
              if (controller.repository != repository) {
                throw const AppFailure(
                  'Your session changed. Reopen this form.',
                );
              }
              if (editing) {
                await repository.update(resource, '${record['id']}', values);
              } else {
                await repository.create(resource, values);
              }
            },
          ),
        ),
      ) ??
      false;
}

class WorkflowPage extends StatefulWidget {
  const WorkflowPage({
    super.key,
    required this.controller,
    required this.resource,
    this.title,
    this.query = const {},
    this.showModeIndicator = true,
  });
  final AppController controller;
  final Resource resource;
  final String? title;
  final JsonMap query;
  final bool showModeIndicator;
  @override
  State<WorkflowPage> createState() => _WorkflowPageState();
}

class _WorkflowPageState extends State<WorkflowPage> {
  List<JsonMap> _rows = [];
  bool _loading = true, _working = false;
  String? _error;
  String _search = '', _status = 'All';
  int _generation = 0;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant WorkflowPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.resource != widget.resource ||
        oldWidget.query.toString() != widget.query.toString() ||
        oldWidget.controller.user != widget.controller.user) {
      _search = '';
      _status = 'All';
      _searchController.clear();
      _load();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final generation = ++_generation;
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final repository = activeRepository(widget.controller);
      Permissions.require(
        Permissions.canRead(repository.user.role, widget.resource),
      );
      final rows = await repository.list(widget.resource, query: widget.query);
      if (mounted && generation == _generation) setState(() => _rows = rows);
    } catch (error) {
      if (mounted && generation == _generation) {
        setState(() => _error = failureMessage(error));
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _create() async {
    setState(() => _working = true);
    try {
      if (await openResourceForm(
        context,
        widget.controller,
        widget.resource == Resource.locations
            ? Resource.ventures
            : widget.resource,
      )) {
        if (mounted) showFeedback(context, savedMessage(widget.controller));
        await _load();
      }
    } catch (error) {
      if (mounted) showFeedback(context, failureMessage(error));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _open(JsonMap row) async {
    final controller = widget.controller;
    final resource = widget.resource;
    Widget destination;
    if (resource == Resource.locations) {
      destination = WorkflowPage(
        controller: controller,
        resource: Resource.ventures,
        title: '${row['name']}',
        query: {'locationId': row['id']},
      );
    } else if (resource == Resource.ventures) {
      destination = VentureDetailPage(
        controller: controller,
        ventureId: '${row['id']}',
        initial: row,
      );
    } else if (resource == Resource.favorites) {
      final plot = row['plot'] is Map
          ? Map<String, dynamic>.from(row['plot'])
          : <String, dynamic>{};
      destination = RecordDetailPage(
        controller: controller,
        resource: Resource.plots,
        record: {...plot, 'id': row['plotId'] ?? plot['id']},
      );
    } else {
      destination = RecordDetailPage(
        controller: controller,
        resource: resource,
        record: row,
      );
    }
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => destination),
    );
    if (mounted) await _load();
  }

  String _subtitle(JsonMap row) {
    final resource = widget.resource;
    return switch (resource) {
      Resource.locations =>
        '${row['ventures'] is List ? (row['ventures'] as List).length : 0} ventures · ${row['availablePlots'] ?? '—'} available plots',
      Resource.ventures =>
        '${row['location'] is Map ? row['location']['name'] ?? '' : ''}${row['plots'] is List ? ' · ${(row['plots'] as List).length} plots' : ''}',
      Resource.plots =>
        '${row['area'] ?? '—'} sq yd · ${row['pricePerSqYard'] ?? '—'} / sq yd',
      Resource.leads => '${row['email'] ?? ''}\n${row['contactNumber'] ?? ''}',
      Resource.customers =>
        '${row['location'] ?? ''} · Budget ${row['budget'] ?? '—'}',
      Resource.tracking =>
        '${row['latitude'] ?? '—'}, ${row['longitude'] ?? '—'}\n${row['updatedAt'] ?? 'Update time unavailable'}',
      Resource.favorites =>
        '${row['plot'] is Map && row['plot']['venture'] is Map ? row['plot']['venture']['name'] ?? '' : ''}',
      _ =>
        '${row['email'] ?? ''}${row['department'] == null ? '' : '\n${row['department']}'}',
    };
  }

  @override
  Widget build(BuildContext _) {
    final user = widget.controller.user;
    final allowed =
        user != null && Permissions.canRead(user.role, widget.resource);
    final canCreate =
        allowed &&
        Permissions.canCreate(
          user.role,
          widget.resource == Resource.locations
              ? Resource.ventures
              : widget.resource,
        ) &&
        widget.resource != Resource.favorites;
    final rows = _rows.where((row) {
      final text = '${recordTitle(widget.resource, row)} ${_subtitle(row)}'
          .toLowerCase();
      final status =
          row['status'] ??
          (row['employeeProfile'] is Map
              ? row['employeeProfile']['status']
              : null);
      return text.contains(_search.toLowerCase()) &&
          (_status == 'All' || status == _status);
    }).toList();
    final filters = switch (widget.resource) {
      Resource.plots => ['All', 'AVAILABLE', 'ADVANCE', 'SOLD'],
      Resource.leads => ['All', 'NEW', 'FOLLOW_UP', 'QUALIFIED', 'WON', 'LOST'],
      Resource.customers => [
        'All',
        'HOT_LEAD',
        'FOLLOWING_UP',
        'CONFIRMED_NOT_PAID',
        'PAID_ADVANCE',
        'BOOKED',
      ],
      Resource.employeeAccess => ['All', 'ACTIVE', 'FROZEN'],
      _ => <String>[],
    };
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title ?? resourceTitle(widget.resource)),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
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
                    if (widget.showModeIndicator) ...[
                      ModeStrip(offline: widget.controller.isOffline),
                      const SizedBox(height: Brand.gap),
                    ],
                    if (!allowed)
                      const StateMessage(
                        title: 'Access unavailable',
                        message: 'Your current role cannot open this section.',
                        icon: Icons.lock_outline,
                      )
                    else ...[
                      if (widget.resource == Resource.locations &&
                          user.role == Role.customer) ...[
                        const Text(
                          'Only properties linked to your customer account appear here.',
                        ),
                        const SizedBox(height: Brand.gap),
                      ],
                      if (canCreate) ...[
                        Align(
                          alignment: Alignment.centerLeft,
                          child: BusyButton(
                            label: widget.resource == Resource.tracking
                                ? 'Add tracking update'
                                : 'Add ${switch (widget.resource) {
                                    Resource.ventures || Resource.locations => 'venture',
                                    Resource.leads => 'lead',
                                    Resource.customers => 'customer record',
                                    Resource.employeeAccess => 'employee',
                                    _ => 'record',
                                  }}',
                            onPressed: _create,
                            busy: _working,
                          ),
                        ),
                        const SizedBox(height: Brand.gap),
                      ],
                      if (widget.resource == Resource.customerAccounts &&
                          (user.role == Role.admin ||
                              user.role == Role.employee)) ...[
                        OutlinedButton.icon(
                          onPressed: () async {
                            final repository = activeRepository(
                              widget.controller,
                            );
                            final saved = await Navigator.push<bool>(
                              context,
                              MaterialPageRoute(
                                builder: (_) => RecordFormPage(
                                  title: 'Create customer account',
                                  fields: customerAccountFields,
                                  offline: repository.isOffline,
                                  description: 'Create credentials for a customer. This does not automatically link properties; add a lead with the same email to link a plot.',
                                  onSubmit: (values) async {
                                    await repository.provisionCustomer(values);
                                  },
                                ),
                              ),
                            );
                            if (saved == true && mounted) {
                              showFeedback(
                                context,
                                savedMessage(widget.controller),
                              );
                              await _load();
                            }
                          },
                          icon: const Icon(Icons.person_add_outlined),
                          label: const Text('Create customer account'),
                        ),
                        const SizedBox(height: Brand.gap),
                      ],
                      if (widget.resource == Resource.employeeAccess) ...[
                        OutlinedButton.icon(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => EmployeeOtpPage(
                                controller: widget.controller,
                              ),
                            ),
                          ),
                          icon: const Icon(Icons.verified_user_outlined),
                          label: const Text('Demo OTP verification'),
                        ),
                        const SizedBox(height: Brand.gap),
                      ],
                      if (_loading)
                        const LoadingSkeleton()
                      else if (_error != null)
                        StateMessage(
                          title: 'Could not load',
                          message: _error!,
                          action: _load,
                        )
                      else if (_rows.isEmpty)
                        StateMessage(
                          title: widget.resource == Resource.tracking
                              ? 'No tracking update yet'
                              : 'No ${resourceTitle(widget.resource).toLowerCase()} yet',
                          message: widget.resource == Resource.favorites
                              ? 'Open a plot and choose Add to favorites.'
                              : 'Refresh to check for new information.',
                          action: _load,
                          actionLabel: 'Refresh',
                        )
                      else ...[
                        Semantics(
                          container: true,
                          child: TextField(
                            controller: _searchController,
                            decoration: const InputDecoration(
                              labelText: 'Search this list',
                              prefixIcon: Icon(Icons.search),
                            ),
                            onChanged: (value) =>
                                setState(() => _search = value),
                          ),
                        ),
                        if (filters.isNotEmpty) ...[
                          const SizedBox(height: Brand.compact),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: filters
                                .map(
                                  (status) => ChoiceChip(
                                    label: Text(
                                      status.replaceAll('_', ' ').toLowerCase(),
                                    ),
                                    selected: _status == status,
                                    onSelected: (_) =>
                                        setState(() => _status = status),
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                        const SizedBox(height: Brand.gap),
                        if (widget.resource == Resource.customers &&
                            rows.isNotEmpty)
                          OutlinedButton.icon(
                            onPressed: () => exportCustomers(
                              context,
                              rows,
                              offline: widget.controller.isOffline,
                            ),
                            icon: const Icon(Icons.download_outlined),
                            label: const Text('Export filtered customers'),
                          ),
                        Text(
                          '${rows.length} ${rows.length == 1 ? 'result' : 'results'}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: Brand.compact),
                        if (rows.isEmpty)
                          const StateMessage(
                            title: 'No matches',
                            message: 'Try a different name or status.',
                          ),
                        ...rows.map(
                          (row) => Padding(
                            padding: const EdgeInsets.only(
                              bottom: Brand.compact,
                            ),
                            child: Card(
                              child: InkWell(
                                borderRadius: BorderRadius.circular(
                                  Brand.radius,
                                ),
                                onTap: () => _open(row),
                                child: Padding(
                                  padding: const EdgeInsets.all(Brand.gap),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              recordTitle(widget.resource, row),
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleMedium,
                                            ),
                                          ),
                                          const Icon(
                                            Icons.chevron_right,
                                            color: Brand.secondary,
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _subtitle(row),
                                        style: const TextStyle(
                                          color: Brand.secondary,
                                        ),
                                      ),
                                      if (row['status'] != null ||
                                          row['employeeProfile'] is Map) ...[
                                        const SizedBox(height: Brand.compact),
                                        StatusBadge(
                                          '${row['status'] ?? row['employeeProfile']['status'] ?? 'ACTIVE'}',
                                        ),
                                      ],
                                      if (widget.resource == Resource.favorites)
                                        Align(
                                          alignment: Alignment.centerRight,
                                          child: TextButton.icon(
                                            onPressed: () async {
                                              try {
                                                await activeRepository(
                                                  widget.controller,
                                                ).remove(
                                                  Resource.favorites,
                                                  '${row['plotId'] ?? row['plot']?['id']}',
                                                );
                                                if (mounted) {
                                                  showFeedback(
                                                    context,
                                                    widget.controller.isOffline
                                                        ? 'Favorite removed locally.'
                                                        : 'Favorite removed.',
                                                  );
                                                  await _load();
                                                }
                                              } catch (error) {
                                                if (mounted) {
                                                  showFeedback(
                                                    context,
                                                    failureMessage(error),
                                                  );
                                                }
                                              }
                                            },
                                            icon: const Icon(
                                              Icons.favorite_border,
                                            ),
                                            label: const Text(
                                              'Remove favorite',
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
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
