import 'package:flutter/material.dart';

import '../../core/app_controller.dart';
import '../../ui/components.dart';
import '../../ui/theme.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({
    super.key,
    required this.controller,
    required this.onOpen,
  });
  final AppController controller;
  final void Function(Resource, String) onOpen;
  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  List<JsonMap> plots = [],
      records = [],
      leads = [],
      employees = [],
      locations = [],
      ventures = [];
  bool loading = true;
  String? error;
  int section = 0;
  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final repo = widget.controller.repository!;
      final role = widget.controller.user!.role;
      final values = await Future.wait([
        repo.list(Resource.plots),
        repo.list(Resource.customers),
        repo.list(Resource.leads),
        Permissions.canRead(role, Resource.employees)
            ? repo.list(Resource.employees)
            : Future.value(<JsonMap>[]),
        repo.list(Resource.locations),
        repo.list(Resource.ventures),
      ]);
      if (mounted) {
        setState(() {
          plots = values[0];
          records = values[1];
          leads = values[2];
          employees = values[3];
          locations = values[4];
          ventures = values[5];
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  int countStatus(String status) =>
      plots.where((p) => p['status'] == status).length;
  num valueOf(Iterable<JsonMap> values) => values.fold<num>(
    0,
    (total, p) =>
        total +
        ((p['area'] as num?) ?? 0) * ((p['pricePerSqYard'] as num?) ?? 0),
  );
  String money(num value) =>
      '₹${value.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},')}';

  Widget metrics(List<(String, String)> items) => LayoutBuilder(
    builder: (context, bounds) => Wrap(
      spacing: Brand.gap,
      runSpacing: Brand.gap,
      children: items
          .map(
            (item) => SizedBox(
              width: bounds.maxWidth >= Brand.tablet
                  ? (bounds.maxWidth - Brand.gap * 3) / 4
                  : (bounds.maxWidth - Brand.gap) / 2,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(Brand.gap),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.$1,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: Brand.compact),
                      Text(
                        item.$2,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          )
          .toList(),
    ),
  );
  Widget heading(String text) => Padding(
    padding: const EdgeInsets.only(top: Brand.section, bottom: Brand.gap),
    child: Text(text, style: Theme.of(context).textTheme.titleLarge),
  );

  @override
  Widget build(BuildContext context) {
    final app = widget.controller;
    final admin = app.user!.role == Role.admin;
    final customer = app.user!.role == Role.customer;
    return RefreshIndicator(
      onRefresh: refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          PageBody(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            customer
                                ? 'Your property overview'
                                : 'Workspace overview',
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          const SizedBox(height: Brand.compact),
                          Text(
                            customer
                                ? 'Your linked properties and latest records, in one place.'
                                : 'Inventory and customer activity available to your account.',
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Refresh overview',
                      onPressed: loading ? null : refresh,
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
                const SizedBox(height: Brand.section),
                if (loading)
                  const LoadingSkeleton()
                else if (error != null)
                  StateMessage(
                    title: 'Overview could not load',
                    message: error!,
                    action: refresh,
                  )
                else ...[
                  if (admin)
                    Padding(
                      padding: const EdgeInsets.only(bottom: Brand.gap),
                      child: Wrap(
                        spacing: Brand.compact,
                        runSpacing: Brand.compact,
                        children: [
                          for (final item in [
                            (0, 'Summary'),
                            (1, 'Units & value'),
                            (2, 'Performance'),
                          ])
                            ChoiceChip(
                              label: Text(item.$2),
                              selected: section == item.$1,
                              onSelected: (_) =>
                                  setState(() => section = item.$1),
                            ),
                        ],
                      ),
                    ),
                  if (section == 0 || !admin) ...[
                    metrics([
                      (customer ? 'Your plots' : 'Plots', '${plots.length}'),
                      ('Available', '${countStatus('AVAILABLE')}'),
                      ('Advance', '${countStatus('ADVANCE')}'),
                      ('Sold', '${countStatus('SOLD')}'),
                    ]),
                    heading(customer ? 'My properties' : 'Property inventory'),
                    Card(
                      child: Column(
                        children: [
                          ListTile(
                            leading: const Icon(Icons.location_on_outlined),
                            title: Text('${locations.length} locations'),
                            subtitle: Text(
                              '${ventures.length} ventures available to your account',
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => widget.onOpen(
                              Resource.locations,
                              customer ? 'My properties' : 'Locations',
                            ),
                          ),
                          const Divider(height: 1),
                          ListTile(
                            leading: const Icon(Icons.favorite_outline),
                            title: const Text('Favorites'),
                            subtitle: const Text('Return to your saved plots'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () =>
                                widget.onOpen(Resource.favorites, 'Favorites'),
                          ),
                        ],
                      ),
                    ),
                    heading(customer ? 'Your records' : 'Customer activity'),
                    metrics([
                      ('Records', '${records.length}'),
                      ('Leads', '${leads.length}'),
                      (
                        'Booked',
                        '${records.where((r) => r['status'] == 'BOOKED').length}',
                      ),
                      (
                        admin ? 'Employees' : 'Following up',
                        admin
                            ? '${employees.length}'
                            : '${records.where((r) => r['status'] == 'FOLLOWING_UP').length}',
                      ),
                    ]),
                    const SizedBox(height: Brand.gap),
                    OutlinedButton.icon(
                      onPressed: () => widget.onOpen(
                        Resource.customers,
                        customer ? 'My records' : 'Customer records',
                      ),
                      icon: const Icon(Icons.people_outline),
                      label: Text(
                        customer ? 'View my records' : 'View customer records',
                      ),
                    ),
                    if (records.isEmpty)
                      const StateMessage(
                        title: 'No customer records yet',
                        message: 'Records appear here when they are available to this account.',
                      ),
                    for (final record in records.take(3))
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('${record['contactName'] ?? 'Customer'}'),
                        subtitle: Text('${record['location'] ?? ''}'),
                        trailing: StatusBadge(
                          '${record['status'] ?? 'FOLLOWING_UP'}',
                        ),
                        onTap: () => widget.onOpen(
                          Resource.customers,
                          'Customer records',
                        ),
                      ),
                  ],
                  if (admin && section == 1) ...[
                    metrics([
                      ('Portfolio value', money(valueOf(plots))),
                      (
                        'Available value',
                        money(
                          valueOf(
                            plots.where((p) => p['status'] == 'AVAILABLE'),
                          ),
                        ),
                      ),
                      (
                        'Advance value',
                        money(
                          valueOf(plots.where((p) => p['status'] == 'ADVANCE')),
                        ),
                      ),
                      (
                        'Sold value',
                        money(
                          valueOf(plots.where((p) => p['status'] == 'SOLD')),
                        ),
                      ),
                    ]),
                    const SizedBox(height: Brand.gap),
                    const Text(
                      'Inventory values are area in square yards × price per square yard. These are inventory values, not collected payments.',
                    ),
                    heading('Plot occupancy'),
                    Text(
                      plots.isEmpty
                          ? 'No plots available to calculate occupancy.'
                          : '${((countStatus('SOLD') + countStatus('ADVANCE')) * 100 / plots.length).toStringAsFixed(1)}% sold or held with an advance.',
                    ),
                  ],
                  if (admin && section == 2) ...[
                    Text(
                      'Employee records',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: Brand.compact),
                    const Text(
                      'Counts follow the record owner labels stored by the existing platform.',
                    ),
                    if (employees.isEmpty)
                      const StateMessage(
                        title: 'No employees',
                        message:
                            'Create employee access to begin assigning work.',
                      ),
                    for (final employee in employees)
                      Builder(
                        builder: (context) {
                          final names = [
                            employee['fullName'],
                            employee['displayName'],
                            employee['email'],
                            employee['employeeId'],
                          ].whereType<String>().toSet();
                          final owned = records.where(
                            (r) =>
                                names.contains(r['recordOwner']) ||
                                names.contains(r['leadName']),
                          );
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              '${employee['fullName'] ?? employee['displayName'] ?? 'Employee'}',
                            ),
                            subtitle: Text(
                              '${owned.length} records · ${owned.where((r) => r['status'] == 'BOOKED').length} booked',
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => widget.onOpen(
                              Resource.employeeAccess,
                              'Employee access',
                            ),
                          );
                        },
                      ),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
