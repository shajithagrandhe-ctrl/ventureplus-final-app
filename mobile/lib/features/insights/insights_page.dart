import 'package:flutter/material.dart';

import '../../core/app_controller.dart';
import '../../ui/components.dart';
import '../../ui/theme.dart';

enum InsightMode { reports, totalData, tracking }

class InsightsPage extends StatefulWidget {
  const InsightsPage({super.key, required this.controller, required this.mode});

  final AppController controller;
  final InsightMode mode;

  @override
  State<InsightsPage> createState() => _InsightsPageState();
}

class _InsightsPageState extends State<InsightsPage> {
  bool loading = true;
  String? error;
  Map<Resource, List<JsonMap>> data = {};
  List<JsonMap> bookings = [], payments = [], activities = [], inquiries = [];

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
      final repository = widget.controller.repository!;
      final role = repository.user.role;
      final resources = <Resource>[
        Resource.locations,
        Resource.ventures,
        Resource.plots,
        Resource.customers,
        Resource.leads,
        if (role == Role.admin) Resource.employees,
        if (widget.mode == InsightMode.tracking) Resource.tracking,
      ];
      final values = await Future.wait(
        resources.map((resource) => repository.list(resource)),
      );
      final demoBookings = repository is OfflineRepository
          ? repository.demoRows('bookings')
          : const <JsonMap>[];
      final demoPayments = repository is OfflineRepository
          ? repository.demoRows('payments')
          : const <JsonMap>[];
      final demoActivities = repository is OfflineRepository
          ? repository.demoRows('activities')
          : const <JsonMap>[];
      final demoInquiries = repository is OfflineRepository
          ? repository.demoRows('inquiries')
          : const <JsonMap>[];
      if (!mounted) return;
      setState(() {
        data = {
          for (var i = 0; i < resources.length; i++) resources[i]: values[i],
        };
        bookings = demoBookings;
        payments = demoPayments;
        activities = demoActivities;
        inquiries = demoInquiries;
      });
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  List<JsonMap> rows(Resource resource) => data[resource] ?? const [];

  String get title => switch (widget.mode) {
    InsightMode.reports => 'Reports & performance',
    InsightMode.totalData => 'Total data',
    InsightMode.tracking => 'Tracking updates',
  };

  String get description => switch (widget.mode) {
    InsightMode.reports => 'Role-scoped summaries calculated from the records available to this account.',
    InsightMode.totalData =>
      'A consolidated view of ventures, inventory, customers and activity.',
    InsightMode.tracking =>
      widget.controller.isOffline
          ? 'Simulated demo updates only; no device location is transmitted.'
          : 'Customer and employee tracking updates visible to your role.',
  };

  String money(num value) =>
      '₹${value.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},')}';

  Widget metric(BuildContext context, String label, String value) => Expanded(
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(Brand.gap),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: Brand.compact),
            Text(value, style: Theme.of(context).textTheme.headlineSmall),
          ],
        ),
      ),
    ),
  );

  Widget section(BuildContext context, String heading, List<Widget> children) =>
      Card(
        child: Padding(
          padding: const EdgeInsets.all(Brand.gap),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(heading, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: Brand.compact),
              ...children,
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final plots = rows(Resource.plots);
    final available = plots.where((p) => p['status'] == 'AVAILABLE').length;
    final held = plots.where((p) => p['status'] == 'ADVANCE').length;
    final sold = plots.where((p) => p['status'] == 'SOLD').length;
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: loading ? null : refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(Brand.gap),
          children: [
            Text(description),
            const SizedBox(height: Brand.gap),
            if (loading)
              const LoadingSkeleton()
            else if (error != null)
              StateMessage(
                title: 'Could not load insights',
                message: error!,
                action: refresh,
              )
            else ...[
              Row(
                children: [
                  metric(
                    context,
                    'Ventures',
                    '${rows(Resource.ventures).length}',
                  ),
                  const SizedBox(width: Brand.compact),
                  metric(context, 'Plots', '${plots.length}'),
                ],
              ),
              const SizedBox(height: Brand.compact),
              Row(
                children: [
                  metric(
                    context,
                    'Customers',
                    '${rows(Resource.customers).length}',
                  ),
                  const SizedBox(width: Brand.compact),
                  metric(context, 'Leads', '${rows(Resource.leads).length}'),
                ],
              ),
              if (widget.controller.isOffline) ...[
                const SizedBox(height: Brand.compact),
                Row(
                  children: [
                    metric(context, 'Bookings', '${bookings.length}'),
                    const SizedBox(width: Brand.compact),
                    metric(
                      context,
                      'Collected',
                      money(
                        payments.fold<num>(
                          0,
                          (sum, row) => sum + ((row['amount'] as num?) ?? 0),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: Brand.gap),
              if (widget.mode != InsightMode.tracking)
                section(context, 'Plot availability', [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Available'),
                    trailing: StatusBadge('$available'),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Held with advance'),
                    trailing: StatusBadge('$held'),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Sold'),
                    trailing: StatusBadge('$sold'),
                  ),
                ]),
              if (widget.mode == InsightMode.reports)
                section(context, 'Recent activity', [
                  for (final row
                      in (widget.controller.isOffline
                              ? activities
                              : rows(Resource.leads))
                          .take(5))
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        row['kind'] == 'PAYMENT'
                            ? Icons.payments_outlined
                            : Icons.person_add_alt_outlined,
                      ),
                      title: Text(
                        '${row['title'] ?? row['customerName'] ?? 'Lead'}',
                      ),
                      subtitle: Text(
                        '${row['detail'] ?? row['status'] ?? 'NEW'} · ${row['date'] ?? row['location'] ?? ''}',
                      ),
                    ),
                  if ((widget.controller.isOffline
                          ? activities
                          : rows(Resource.leads))
                      .isEmpty)
                    const Text('No lead activity is available for this role.'),
                  if (widget.controller.isOffline) ...[
                    const Divider(),
                    for (final row in bookings.take(3))
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.event_available_outlined),
                        title: Text('${row['property'] ?? 'Booking'}'),
                        subtitle: Text(
                          '${row['customerName'] ?? ''} · ${row['status'] ?? ''}',
                        ),
                        trailing: Text(money((row['amount'] as num?) ?? 0)),
                      ),
                    const Divider(),
                    Text(
                      'Enquiry pipeline',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    for (final row in inquiries.take(4))
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.question_answer_outlined),
                        title: Text('${row['customerName'] ?? 'Enquiry'}'),
                        subtitle: Text('${row['message'] ?? ''}'),
                        trailing: StatusBadge('${row['status'] ?? 'NEW'}'),
                      ),
                  ],
                ]),
              if (widget.mode == InsightMode.totalData)
                section(context, 'Records by area', [
                  for (final item in <(String, int)>[
                    ('Locations', rows(Resource.locations).length),
                    ('Ventures', rows(Resource.ventures).length),
                    ('Plots', rows(Resource.plots).length),
                    ('Customers', rows(Resource.customers).length),
                    ('Leads', rows(Resource.leads).length),
                    if (widget.controller.isOffline)
                      ('Bookings', bookings.length),
                    if (widget.controller.isOffline)
                      ('Payments', payments.length),
                    if (widget.controller.isOffline)
                      ('Enquiries', inquiries.length),
                  ])
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(item.$1),
                      trailing: Text('${item.$2}'),
                    ),
                ]),
              if (widget.mode == InsightMode.tracking)
                section(context, 'Latest updates', [
                  for (final row in rows(Resource.tracking))
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        row['status'] == 'ACTIVE'
                            ? Icons.my_location_outlined
                            : Icons.location_on_outlined,
                      ),
                      title: Text('${row['address'] ?? 'Tracking update'}'),
                      subtitle: Text(
                        '${row['latitude'] ?? '—'}, ${row['longitude'] ?? '—'}',
                      ),
                      trailing: StatusBadge('${row['status'] ?? 'ACTIVE'}'),
                    ),
                  if (rows(Resource.tracking).isEmpty)
                    const Text('No tracking updates are available.'),
                ]),
            ],
          ],
        ),
      ),
    );
  }
}
