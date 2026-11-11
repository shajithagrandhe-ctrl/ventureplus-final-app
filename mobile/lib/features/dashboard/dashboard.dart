import 'package:flutter/material.dart';

import '../../core/app_controller.dart';
import '../../ui/components.dart';
import '../../ui/theme.dart';
import '../insights/insights_page.dart';
import '../workflows/workflow_page.dart';

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
  List<JsonMap> bookings = [], payments = [], inquiries = [];
  bool loading = true, secondaryLoading = false;
  String? error, secondaryError;
  int section = 0;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    final generation = ++_generation;
    setState(() {
      loading = true;
      secondaryLoading = true;
      error = null;
      secondaryError = null;
    });
    try {
      final repo = widget.controller.repository!;
      final role = widget.controller.user!.role;
      // Start every independent read together, but only wait for plots before
      // painting the first dashboard frame. Location, venture and activity
      // lists continue in the background and update the dashboard when ready.
      // This keeps a slow secondary endpoint from delaying the first useful
      // screen after authentication.
      final plotsFuture = repo.list(Resource.plots);
      final secondaryFuture = Future.wait<List<JsonMap>>([
        repo.list(Resource.locations),
        repo.list(Resource.ventures),
        repo.list(Resource.customers),
        repo.list(Resource.leads),
        Permissions.canRead(role, Resource.employees)
            ? repo.list(Resource.employees)
            : Future.value(<JsonMap>[]),
      ]);
      // Keep a listener attached even if the page is disposed while the
      // critical plots request is still in flight.
      secondaryFuture.catchError((_) => <List<JsonMap>>[]);
      final criticalPlots = await plotsFuture;
      if (!mounted || generation != _generation) return;
      setState(() {
        plots = criticalPlots;
        loading = false;
      });
      final values = await secondaryFuture;
      final extraBookings = repo is OfflineRepository
          ? repo.demoRows('bookings')
          : const <JsonMap>[];
      final extraPayments = repo is OfflineRepository
          ? repo.demoRows('payments')
          : const <JsonMap>[];
      final extraInquiries = repo is OfflineRepository
          ? repo.demoRows('inquiries')
          : const <JsonMap>[];
      if (mounted && generation == _generation) {
        setState(() {
          locations = values[0];
          ventures = values[1];
          records = values[2];
          leads = values[3];
          employees = values[4];
          bookings = extraBookings;
          payments = extraPayments;
          inquiries = extraInquiries;
          secondaryLoading = false;
        });
      }
    } catch (e) {
      if (mounted && generation == _generation) {
        if (loading) {
          error = e.toString();
          loading = false;
        } else {
          secondaryError = e.toString();
        }
        secondaryLoading = false;
        setState(() {});
      }
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

  Future<void> openResource(
    Resource resource,
    String title, {
    JsonMap query = const {},
  }) async {
    if (query.isEmpty) {
      widget.onOpen(resource, title);
      return;
    }
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => WorkflowPage(
          controller: widget.controller,
          resource: resource,
          title: title,
          query: query,
        ),
      ),
    );
  }

  Widget metrics(
    List<(String, String)> items, {
    Map<String, VoidCallback> actions = const {},
  }) => LayoutBuilder(
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
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: actions[item.$1],
                  child: Padding(
                    padding: const EdgeInsets.all(Brand.gap),
                    child: Row(
                      children: [
                        Expanded(
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
                        if (actions.containsKey(item.$1))
                          const Icon(Icons.chevron_right, size: 18),
                      ],
                    ),
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
                    ], actions: {
                      (customer ? 'Your plots' : 'Plots'): () => openResource(
                        Resource.plots,
                        customer ? 'My plots' : 'Plots',
                      ),
                      'Available': () => openResource(
                        Resource.plots,
                        'Available plots',
                        query: {'status': 'AVAILABLE'},
                      ),
                      'Advance': () => openResource(
                        Resource.plots,
                        'Plots with advance',
                        query: {'status': 'ADVANCE'},
                      ),
                      'Sold': () => openResource(
                        Resource.plots,
                        'Sold plots',
                        query: {'status': 'SOLD'},
                      ),
                    }),
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
                      if (app.isOffline) ...[
                        ('Bookings', '${bookings.length}'),
                        ('Enquiries', '${inquiries.length}'),
                        (
                          'Collected',
                          money(
                            payments.fold<num>(
                              0,
                              (sum, row) =>
                                  sum + ((row['amount'] as num?) ?? 0),
                            ),
                          ),
                        ),
                      ],
                    ], actions: {
                      'Records': () => openResource(
                        Resource.customers,
                        customer ? 'My records' : 'Customer records',
                      ),
                      'Leads': () => openResource(Resource.leads, 'Leads'),
                      'Booked': () => openResource(
                        Resource.customers,
                        'Booked customer records',
                        query: {'status': 'BOOKED'},
                      ),
                      if (admin)
                        'Employees': () => openResource(
                          Resource.employeeAccess,
                          'Employee access',
                        )
                      else
                        'Following up': () => openResource(
                          Resource.customers,
                          'Follow-up records',
                          query: {'status': 'FOLLOWING_UP'},
                        ),
                      if (app.isOffline) ...{
                        'Bookings': () => Navigator.push<void>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => InsightsPage(
                              controller: app,
                              mode: InsightMode.reports,
                            ),
                          ),
                        ),
                        'Enquiries': () => Navigator.push<void>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => InsightsPage(
                              controller: app,
                              mode: InsightMode.reports,
                            ),
                          ),
                        ),
                        'Collected': () => Navigator.push<void>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => InsightsPage(
                              controller: app,
                              mode: InsightMode.totalData,
                            ),
                          ),
                        ),
                      },
                    }),
                    if (secondaryLoading)
                      const Padding(
                        padding: EdgeInsets.only(top: Brand.compact),
                        child: LinearProgressIndicator(minHeight: 2),
                      ),
                    if (secondaryError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: Brand.compact),
                        child: Text(
                          'Some secondary activity is unavailable: $secondaryError',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
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
                        onTap: () => Navigator.push<void>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => RecordDetailPage(
                              controller: app,
                              resource: Resource.customers,
                              record: record,
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: Brand.gap),
                    Wrap(
                      spacing: Brand.compact,
                      runSpacing: Brand.compact,
                      children: [
                        if (admin || app.user!.role == Role.employee)
                          OutlinedButton.icon(
                            onPressed: () => Navigator.push<void>(
                              context,
                              MaterialPageRoute(
                                builder: (_) => InsightsPage(
                                  controller: app,
                                  mode: InsightMode.reports,
                                ),
                              ),
                            ),
                            icon: const Icon(Icons.bar_chart_outlined),
                            label: const Text('Reports'),
                          ),
                        OutlinedButton.icon(
                          onPressed: () => Navigator.push<void>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => InsightsPage(
                                controller: app,
                                mode: InsightMode.totalData,
                              ),
                            ),
                          ),
                          icon: const Icon(Icons.dataset_outlined),
                          label: const Text('Total data'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => Navigator.push<void>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => InsightsPage(
                                controller: app,
                                mode: InsightMode.tracking,
                              ),
                            ),
                          ),
                          icon: const Icon(Icons.track_changes_outlined),
                          label: const Text('Tracking'),
                        ),
                      ],
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
                    ], actions: {
                      'Portfolio value': () => openResource(
                        Resource.plots,
                        'All plots',
                      ),
                      'Available value': () => openResource(
                        Resource.plots,
                        'Available plots',
                        query: {'status': 'AVAILABLE'},
                      ),
                      'Advance value': () => openResource(
                        Resource.plots,
                        'Plots with advance',
                        query: {'status': 'ADVANCE'},
                      ),
                      'Sold value': () => openResource(
                        Resource.plots,
                        'Sold plots',
                        query: {'status': 'SOLD'},
                      ),
                    }),
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
                            onTap: () => Navigator.push<void>(
                              context,
                              MaterialPageRoute(
                                builder: (_) => RecordDetailPage(
                                  controller: app,
                                  resource: Resource.employeeAccess,
                                  record: employee,
                                ),
                              ),
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
