import 'models.dart';

abstract final class Permissions {
  static bool canRead(Role role, Resource resource) => switch (resource) {
    Resource.employeeAccess || Resource.admins => role == Role.admin,
    Resource.employees ||
    Resource.customerAccounts => role == Role.admin || role == Role.employee,
    Resource.locations ||
    Resource.ventures ||
    Resource.plots ||
    Resource.leads ||
    Resource.customers ||
    Resource.tracking ||
    Resource.favorites ||
    Resource.agents => true,
  };

  static bool canCreate(Role role, Resource resource) => switch (resource) {
    Resource.ventures || Resource.employeeAccess => role == Role.admin,
    Resource.leads ||
    Resource.customers => role == Role.admin || role == Role.employee,
    Resource.tracking =>
      role == Role.admin || role == Role.employee || role == Role.agent,
    Resource.favorites => true,
    _ => false,
  };

  static bool canUpdate(Role role, Resource resource) => switch (resource) {
    Resource.plots ||
    Resource.leads ||
    Resource.customers => role == Role.admin || role == Role.employee,
    Resource.employeeAccess => role == Role.admin,
    _ => false,
  };

  static bool canDelete(Role role, Resource resource) => switch (resource) {
    Resource.leads ||
    Resource.customers => role == Role.admin || role == Role.employee,
    Resource.favorites => true,
    _ => false,
  };

  static void require(bool allowed) {
    if (!allowed) {
      throw const AppFailure(
        'Your role cannot perform this action.',
        statusCode: 403,
      );
    }
  }
}
