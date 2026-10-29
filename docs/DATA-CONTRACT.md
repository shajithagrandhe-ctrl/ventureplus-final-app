# Mobile data interface

Import `package:ventureplus/core/app_controller.dart` for the public barrel (models, permissions, repositories and controller).

`await AppController.create()` constructs platform persistence and transport. Call `await controller.restore()` before displaying a session. Controller extends ChangeNotifier. Public state: `user` (UserIdentity?), `mode` (SessionMode?), `busy`, `error` (String?), `repository` (VentureRepository?). Methods: `login(email,password)`, `enterOffline(Role)`, `logout()`, `clearError()` return Future<bool> for actions (clearError void); methods catch operational errors and report false. `isOffline` is derived from mode. Failed connected login never creates an offline session. Call `login` only after explicit Sign in.

Roles: `Role.admin/employee/customer/agent`; each has `label` and `wireName`. SessionMode: `connected/offlineDemo`. UserIdentity: `id,email,displayName,fullName,role`; `fromJson` rejects unknown roles. `DemoPrefills.enabled` is false in release unless ENABLE_DEMO_PREFILLS=true. `DemoPrefills.forRole(Role)` returns `DemoCredentials?` (email/password), never an Agent credential.

Resource enum: `locations, ventures, plots, leads, customers, tracking, favorites, employees, admins, customerAccounts, agents, employeeAccess`. `customers` maps to `/total-data`; `customerAccounts` to `/customers`; `employeeAccess` to `/employee-access/employees`. Use `Permissions.canRead(role,resource)` and `canCreate/canUpdate/canDelete` for controls. Unknown server roles are rejected, not mapped to a default.

VentureRepository methods:

- `list(Resource, {Map<String,dynamic> query = const {}}) -> Future<List<JsonMap>>`; exhausts server pagination where present.
- `detail(Resource, String id) -> Future<JsonMap>` (only source-supported detail endpoints).
- `stats() -> Future<JsonMap>`.
- `create(Resource, JsonMap values)`, `update(Resource,String id,JsonMap values)` -> Future<JsonMap>.
- `remove(Resource,String id) -> Future<void>`; favorites uses plot ID.
- `setEmployeeStatus(String id,String status)`, `updatePlotCoordinates(String id,JsonMap values)`, `updatePlotCoordinatesBatch(List<JsonMap>)`, `updateRegions(String ventureId,JsonMap regions)` where regions contains roads and parks arrays.
- `uploadVenture(String id,List<int> bytes,String filename,{required bool layout,required String contentType,void Function(int,int)? onProgress}) -> Future<JsonMap>`; 4 MiB limit, role and accepted MIME checks; field layout/photo.
- `provisionCustomer(JsonMap values)`, `requestOtp(String type,String target)`, `verifyOtp(String requestId,String otp)`, `submitInquiry(JsonMap values)`, `changePassword(String current,String next)`.
- `assetUrl(String? path) -> String?`; relative server asset paths resolve to configured API origin. Offline demo returns no remote asset URLs.

`JsonMap` aliases Map<String,dynamic>. Domain DTOs `LocationData,VentureData,PlotData,LeadData,CustomerData,TrackingData` parse response maps for typed consumers and expose their original `json` as needed. Generic maps preserve optional source fields needed by the forms.

Use `AppFailure.message` in UI. `AppFailure.statusCode` can distinguish 401/403. Connected repository errors do not return synthetic records or fake success. Cookie state lives in native secure storage; ordinary preferences contain only selected mode and fictional offline JSON. Connected calls bootstrap CSRF and preserve server-issued cookies; identity comes from `/auth/me`.

Offline data is fictional and local-only, persisted independently of cookie state. Switching roles retains that role's demo changes. No backend calls are made by OfflineRepository. Local operations use the same resource shape and permissions; writes say saved locally. No sync queue exists.

Offline employee plots and leads are restricted to assigned ventures/locations; customer records and tracking are restricted to owned records. Frozen employees cannot start an offline employee session. Customer properties and leads match the signed-in fictional email exactly. Lead creation establishes customer-record linkage; editable notes never grant customer access. Favorites cannot expose an inaccessible plot. Offline profiles do not store passwords, and a password-change attempt returns an explicit error. These local boundaries do not establish the security of a deployed backend.

Offline role selection restores the persisted identity by its stable demo ID. A stored role mismatch is rejected. Employee emails are immutable to protect legacy record-owner labels; unchanged email is accepted on profile saves. The compatible backend patch enforces the same restriction.

Native transport serializes CSRF token rotation together with each write and never retries a mutation automatically. The server's success envelope is required. Its access cookie is persisted in secure storage under an API-base-specific key; passwords and connected response data are never persisted in ordinary preferences. Browser preview uses the browser's cookie handling instead. The session identity is published only after `/auth/me` succeeds.

Foundation verification: `flutter test test/core_data_test.dart test/core_transport_test.dart` exercises mode isolation, failed authentication and expiry, role permissions and ownership, JSON round trips, restart persistence, atomic local rollback, OTP reuse, upload persistence, pagination, native cookie headers, CSRF rotation and rejected-write behavior. No live credentials or server mutations are submitted by these tests.

Security limits: client guards cannot fix audited backend ownership gaps. See SOURCE-AUDIT.md. API-supported favorites/inquiries/agent directory are not claims of observed web screens. Customer catalogue remains lead-linked My Properties. Source has no separate saved photo/layout columns; current connected uploads both replace layoutImage.
