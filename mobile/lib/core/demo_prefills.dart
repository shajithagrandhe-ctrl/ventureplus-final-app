import 'package:flutter/foundation.dart';

import 'models.dart';

class DemoCredentials {
  const DemoCredentials(this.email, this.password);
  final String email, password;
}

abstract final class DemoPrefills {
  static const enabled = bool.fromEnvironment(
    'ENABLE_DEMO_PREFILLS',
    defaultValue: !kReleaseMode,
  );

  static DemoCredentials? forRole(Role role) {
    if (!enabled) return null;
    return switch (role) {
      Role.admin => const DemoCredentials(
        'your-email@example.com',
        'Dealatecorp1234',
      ),
      Role.employee => const DemoCredentials(
        'employee.demo@estatehub.com',
        'EmployeeDemo123!',
      ),
      Role.customer => const DemoCredentials(
        'customer.demo@estatehub.com',
        'CustomerDemo123!',
      ),
      Role.agent => null,
    };
  }
}
