# VenturePlus Flutter App — Functional Guidelines

**Status:** Requirements baseline for a demo app. This is not a claim that every live screen or endpoint has already been interactively verified.  
**Website:** https://ventureplus123.vercel.app/  
**Repository:** https://github.com/VenkataVyshnaviMondi/ventureplus123

## Verified audit checkpoint — 29 October 2026

Implementation destination: `shajithagrandhe-ctrl/ventureplus-final-app`. Reference
source pinned to `3c24df131699c71fac4e500f0e1c531eeab519d2`. The complete
screen/action/API/field/validation/ownership matrix, source line references, state
requirements and test cases are in [docs/SOURCE-AUDIT.md](docs/SOURCE-AUDIT.md).
The corrections below take precedence over the initial inventory later in this file.

| Capability | Admin | Employee | Agent | Customer | Evidence |
|---|---|---|---|---|---|
| Locations / ventures / plots | All | Assigned inventory | Read | Own lead-linked plots | VERIFIED-SOURCE: inventory services |
| Venture creation / layout / image uploads / coordinates | Yes | No | No | No | VERIFIED-SOURCE: venture and plot routes |
| Plot status/details; lead create/update/delete | Yes | Yes, assignment checks need repair | No | No | VERIFIED-SOURCE: plot/lead routes |
| Customer records | All, CRUD | Own records; write ownership gaps | Read | Own only; matching needs repair | VERIFIED-SOURCE: customer service |
| Tracking | Read/write | Read/write, scope checks need repair | Read/write | Own, read-only | VERIFIED-SOURCE: tracking routes/service |
| Staff access and assignments | Manage | No | No | No | VERIFIED-SOURCE: employee-access routes |
| Customer provisioning | Yes | Yes | No | No | VERIFIED-SOURCE: auth routes |
| Favorites | Own | Own | Own | Own; plot visibility gap | VERIFIED-SOURCE: favorite service |
| Inquiries | Submit | Submit | Submit | Submit | VERIFIED-SOURCE: POST only, no management endpoint |
| Identity / password / logout | Own | Own | Own | Own | VERIFIED-SOURCE: auth routes |

Authentication verification: the exact three supplied demo pairs each returned
HTTP 200 from login and HTTP 200 from `/auth/me`, with ADMIN, EMPLOYEE and CUSTOMER
respectively. VERIFIED-LIVE, after explicit user approval in this chat. No Agent
credentials were supplied or tested. The Admin dashboard and navigation were
observed in the browser. Other role screens and business mutations are not yet
live-audited; a successful login does not verify them.

Binding discrepancies:
- Login JSON contains no token: native clients must manage access/CSRF cookies,
  bootstrap CSRF before login and refresh identity from `/auth/me`.
- Agent is active in the backend but rejected by the existing web login's role
  picker. Preserve Agent as distinct; do not grant employee mutation permissions.
- Customer catalogue is **My Properties**, not public inventory. Sign-in remains
  required. Never copy employee sidebar links that point to admin-only endpoints.
- Separate photo/layout persistence is not supported: both uploads currently
  overwrite `layoutImage`. Separate storage needs a compatible backend change.
- No generic document store, inquiry management, standalone location CRUD,
  venture delete, or plot create/delete API was found. Do not invent these actions.
- Connected tracking must never use the web's simulated coordinates/random motion;
  reports must not copy hardcoded interaction counts or conversion probabilities.
- Customer/employee ownership and realtime payload isolation have source-proven
  defects. Connected security acceptance remains blocked until repaired and tested.

Tool baseline: Flutter 3.47.8 / Dart 3.13.7 found and initialized. No Android SDK or
device is available. Backend TypeScript build passes; four existing migration
conversion tests pass. Existing web build/tests are blocked by SWC native cache
permissions. Root dependency audit reports 15 findings (4 critical, 3 high,
7 moderate, 1 low); separate gateway install reports 8 findings. No database
migration, seeding, credential change, push, deployment or live business mutation
has been performed.

## 1. Product goal

Build a native-feeling Flutter/Dart mobile application for Android first and iOS second, based on the existing VenturePlus / EstateHub real-estate website. Preserve the website's identity and business workflows while redesigning desktop-oriented interactions for mobile. Do not use a WebView as the app.

The app is a demonstration project, but its architecture must distinguish:
- **Connected mode:** authenticated requests to the existing backend; supported changes persist in the backend and are visible to other authorized users.
- **Offline demo mode:** explicitly labelled local sample data and local-only actions that work without internet.
- **Pending sync:** any offline changes that could be synchronized later must be visibly marked as pending. Never imply an offline change was saved to the server.

Do not implement payments or push notifications. English only; light mode only.

## 2. Evidence and confidence rules

### Repository-documented facts
The public repository README documents:
- Frontend: Vite + React + TypeScript, shadcn/ui and Tailwind.
- Backend: Node.js + Express + TypeScript, Zod validation, JWT/cookie authentication, Multer uploads.
- Database: Prisma + MySQL.
- Realtime: SSE by default, optional WebSocket.
- Roles: `ADMIN`, `EMPLOYEE`, `AGENT`, `CUSTOMER`.
- Main domain: `Location → Venture → Plot`, plus `Lead`, `CustomerRecord`, `Favorite`, `Inquiry`, and `TrackingUpdate`.
- Features include venture/plot inventory, plot layout coordinates, venture layout/photo uploads, leads and customer records, favorites, inquiries, tracking updates, stats, employee access management and role-based access.
- API routes are documented in the README, including auth, inventory, leads/customer records, favorites, agents, stats, tracking, employee access and uploads.

The live website is a client-rendered app; a static page fetch did not expose its authenticated screens. Therefore, Codex MUST inspect the repository and run the website locally where feasible before declaring the screen-by-screen audit complete.

### Required evidence labels in Codex's audit
Every finding must be labelled one of:
- `VERIFIED-LIVE`: directly observed in the running website with a role-specific test session.
- `VERIFIED-SOURCE`: supported by current source code, route, API, schema, or test.
- `INFERRED`: plausible but not yet proven; do not implement as a confirmed business rule without checking.
- `BLOCKED`: cannot be verified due to credentials, unavailable service, or environment limitation.

Do not claim a feature works solely because a route, button, or endpoint exists.

## 3. Role model and role discovery

The app must support the three requested primary roles:
- Admin
- Employee
- Customer

The repository also defines an `AGENT` role. Include a separate Agent experience **if and only if** the source and/or live website confirms it is an active role with meaningful distinct permissions or workflows. If Agent permissions substantially overlap Employee, it may share UI components but must retain its actual authorization rules. Do not silently relabel Agent as Employee. If evidence is insufficient, document the uncertainty and implement only a clearly isolated role adapter after audit.

### Permission principles
- Enforce authorization on the backend for every protected read and mutation.
- The Flutter UI must also hide or disable unavailable actions, but client-side visibility is not security.
- Default-deny unknown roles and unknown permissions.
- Never trust a role sent by the client; derive it from the authenticated server session/token.
- A user must not access another user's private records by changing an ID in a request.
- After login, call the backend identity endpoint (documented as `GET /api/auth/me`) and route by the server-returned role.
- Logout must clear app session state and local credentials/tokens.
- Account switching must be easy for demo presentations.

## 4. Login and demo entry

The website has a single login page with role-specific demo buttons. The mobile app must reproduce this pattern with three prominent buttons:
- **Sign in as Admin**
- **Sign in as Employee**
- **Sign in as Customer**

Each button prefills the email and password fields; the user still explicitly presses **Sign in** unless the live website proves a different interaction. Prefilling must not be represented as authentication success.

User-provided prefill values:
- Admin email: `your-email@example.com`
- Admin password: `Dealatecorp1234`
- Employee email: `employee.demo@estatehub.com`
- Employee password: `EmployeeDemo123!`
- Customer email: `customer.demo@estatehub.com`
- Customer password: `CustomerDemo123!`

Important: these are user-specified UI prefill values, not verified working credentials. The admin email looks like a placeholder. Codex must test the values against the configured demo backend and report the result. Do not silently replace them with unrelated seeded credentials. For offline demo, provide an explicit local-only sign-in path that is visibly labelled **Offline Demo** and uses non-sensitive fictional sample data. Do not pretend a local session is a server-authenticated session.

The app must be able to enter offline demo mode without internet. If the device is offline, clearly explain that connected login is unavailable and offer offline demo entry. Local demo mode must not access or mutate live backend records.

## 5. Feature inventory to audit and map

Codex must inspect the current website routes/components, API routers, Prisma schema, seed scripts, and authorization middleware. Build a role-by-role matrix containing:
- Screen/section and route
- Intended role(s)
- View/create/update/delete actions
- Fields and validations
- API endpoint(s) and payload/response shapes
- Data ownership/visibility rules
- Loading, empty, error, and offline states
- Evidence label
- Test cases

The following is the initial repository-documented inventory, not a substitute for that audit.

### 5.1 Shared or role-dependent property discovery
Audit and map:
- Locations and ventures list/detail.
- Plot inventory list/detail.
- Search, sorting, filtering and pagination if supported by the website.
- Venture images, layout images, plot coordinate/map layout.
- Availability/status display.
- Property/plot details and contact/inquiry entry points.
- Favorites, add/remove favorite.
- Customer inquiry submission.
- Related/shared information available to both Employee and Customer, only where source permissions confirm it.

Require sign-in before the property catalogue, as requested. Do not expose protected property data to unauthenticated users just because an endpoint is reachable.

### 5.2 Admin
The mobile app must include the complete admin dashboard and every admin capability confirmed in the existing site, including auditing:
- Dashboard metrics/statistics.
- Locations, ventures and plots management.
- Plot layout coordinate management.
- Venture layout and photo upload/update.
- Leads pipeline and customer records.
- Employee access management, including account status and OTP-based flows if currently used.
- Viewing employees, admins and customers where authorized.
- Tracking updates and records.
- Inquiry management if supported by current UI/API.
- Any other admin-only screen discovered in the actual website.

Do not invent metrics, statuses, or admin controls. Use actual API response fields and existing business rules.

### 5.3 Employee
Map all actual employee permissions and screens. The repository documents leads/customer records, inventory APIs, tracking, inquiries, and employee-related authentication, but these do not prove that every employee can use every endpoint.
- Employee dashboard and assigned/available work, if present.
- Leads and customer records within permitted scope.
- Venture/plot browsing and details.
- Inquiry and tracking workflows where permitted.
- Customer contact or profile views where permitted.
- File/image/document upload or viewing where supported.
- Any existing restrictions on create/update/delete operations.

### 5.4 Agent
Only include after checking current role implementation and permission middleware:
- Agent profile and assigned leads.
- Agent-specific customer/plot workflows.
- Tracking or updates.
- Any agent-only dashboard/actions.
Record exactly how Agent differs from Employee and Customer. If no usable Agent demo account exists, create local sample Agent data for offline demo and report connected-login limitations; do not invent a working online account.

### 5.5 Customer
Map actual customer screens and actions:
- Customer dashboard/home.
- Venture/plot catalogue and details after sign-in.
- Favorites.
- Inquiries.
- Customer's own records and tracking updates, if supported.
- Upload/view documents or images where supported.
- Contact actions, if present.
- Profile and password actions.
Customer data must be scoped to the authenticated customer. Never expose other customers' records.

## 6. Existing backend and API audit

The repository README documents these API groups; verify each in source before use:
- Auth: `/api/auth/login`, `/api/auth/me`, `/api/auth/logout`, `/api/auth/change-password`, `/api/auth/customers`, `/api/auth/csrf`.
- Inventory: `/api/locations`, `/api/ventures`, `/api/plots`, plot coordinate endpoints, plot leads.
- Leads/customer records: `/api/leads`, `/api/total-data`.
- Engagement: `/api/favorites`, `/api/agents`, `/api/stats`, `/api/tracking`.
- Staff access: `/api/employees`, `/api/admins`, `/api/customers`, `/api/employee-access/...`.
- Uploads: venture layout and photo endpoints; asset retrieval under `/uploads/assets/:id`.
- Realtime: authenticated SSE `/api/stream`; optional WebSocket depending on configuration.

For every endpoint the app needs:
1. Confirm it exists in the current source.
2. Record method, URL, auth requirements, role middleware, schema validation, response shape and errors.
3. Verify the route works with an integration test or a reproducible manual request.
4. Prefer adding a compatible endpoint over changing an existing contract.
5. Keep existing web functionality backward-compatible.
6. Add backend tests for any permission or API change.
7. Never place database credentials, JWT secrets, or privileged server secrets in the Flutter app.

Use a platform-aware API base URL configuration. `localhost` on an Android emulator refers to the emulator, not the Windows host; configure the emulator host address correctly. Do not hardcode a single developer's LAN IP. Document setup for Android emulator and physical device.

## 7. Offline demo and persistence contract

Implement an explicit data-source boundary, e.g. repository interfaces with connected API and local demo implementations.

Offline mode must:
- Start without internet.
- Use seeded, fictional sample data.
- Support login-as-role demo selection and navigation for every implemented role.
- Persist local demo edits across app restarts where practical.
- Clearly display an **Offline Demo** indicator.
- Never report a local-only change as synced or saved to the server.
- Never fall back to demo data invisibly after a live API error; explain the failure and offer an explicit switch to offline demo.
- Keep offline demo data separate from authenticated live data.

Connected mode must:
- Use the existing API and real server identity.
- Persist successful mutations on the server.
- Refresh or invalidate local cache after mutations.
- Display sync status when relevant.
- Avoid automatic replay of unsafe/conflicting changes. If an offline write queue is implemented, add conflict handling, idempotency and visible retry/discard controls; otherwise keep offline changes local-only.

## 8. Uploads and mobile capabilities

Support camera capture, gallery selection, multiple image selection and document attachment only for workflows the website already supports or where a necessary mobile equivalent is explicitly approved. Respect backend file size limits and accepted MIME types. Show upload progress, retry, cancel where feasible, and clear failure states. Do not add push notifications or payment integration in this demo.

## 9. Navigation and information architecture

Use one design system with role-specific navigation:
- Bottom navigation for the most important screens per role.
- Drawer or profile menu for secondary sections.
- Avoid putting every admin section in the bottom bar.
- Preserve Android back behavior and sensible deep-link/route handling.
- Show the active role and mode (Connected / Offline Demo) clearly.
- Prevent navigation to unauthorized screens even if a route is manually invoked.

Codex must derive exact navigation items from the verified website audit rather than assume a generic real-estate menu.

## 10. UX requirements

All are required:
- Button tap/press feedback and accessible interaction states.
- Branded splash/startup transition.
- Skeleton loading for lists, cards and dashboard sections.
- Subtle animated page transitions and navigation.
- Pull-to-refresh where the content is refreshable.
- Designed empty states, error states and retry actions.
- Form validation and clear success/error feedback.
- Phone-first responsive layouts, with tablet/iPad adaptation.
- Readable typography, adequate contrast, semantic labels and screen-reader support.
- Reduced-motion support and sensible animation duration limits.

No animation may delay a primary action. Avoid excessive shimmer, parallax or decorative motion. Provide a consistent loading/error/empty-state component system.

## 11. Visual brand direction

- Palette: sage green, walnut brown, amber glow.
- Apply the 60/30/10 rule as a flexible composition guideline: 60% neutral/background surfaces, 30% primary/secondary brand surfaces, 10% accent/high-attention elements. Do not apply it mechanically to every component.
- Reuse the actual Venture Plus logo from the repository/website after checking its file quality and aspect ratio.
- English only; light mode only.
- Premium, calm, trustworthy real-estate presentation; clear hierarchy; large property imagery; restrained shadows and borders.
- Define exact HEX tokens, typography scale, spacing, radii, elevation, icon style, component states and responsive breakpoints in `DESIGN.md`.

## 12. Technical architecture expectations

Codex should select and justify a maintainable Flutter architecture after inspecting installed tooling and project constraints. Prefer:
- Feature-oriented folders.
- Typed API DTOs and domain models.
- Repository/data-source boundary.
- Central auth/session state and role-aware route guards.
- Centralized API client, timeouts, error mapping and request IDs where appropriate.
- Secure storage for connected session tokens if token-based auth is used; do not assume browser cookies automatically work in Flutter.
- Local persistence for offline demo data and cache.
- Unit-testable business logic and dependency injection.
- No secrets in source control.
- No needless rewrite of the existing backend.

Do not add packages without checking compatibility, maintenance, license and need. Lock dependency versions through the project's normal Flutter dependency workflow.

## 13. Required tests and acceptance criteria

At minimum:
- Unit tests for auth/session state, role permissions, repositories, serialization and offline/connected mode boundaries.
- Widget tests for login, role-prefill buttons, validation, loading/error/empty states, role-specific navigation and key actions.
- Integration tests for login and critical workflows for each supported role.
- Backend tests for every new/changed endpoint and authorization rule.
- Verify unauthorized access returns an appropriate error; hiding the UI alone does not pass.
- Verify offline demo works in airplane mode and local edits survive restart.
- Verify connected mutations persist and are visible to another authorized session when test infrastructure permits.
- Verify upload success/failure/size limits if uploads are implemented.
- Run `flutter analyze`, `flutter test`, integration tests, and backend test/build/lint commands relevant to changed code.
- Test on an Android emulator or device. iOS implementation must remain compatible, but this Windows environment may not be able to run Xcode/iOS Simulator; report that limitation instead of claiming an iOS build was tested.
- Every visible interactive control must have a real action or be explicitly disabled with an explanation. No dead buttons, placeholder success messages, fake metrics in connected mode, or TODO-only implementations.

## 14. Checkpoints and completion reporting

Work in phases with a clean checkpoint after each phase:
1. Audit and inventory.
2. Flutter scaffold, theme and routing.
3. Login, role handling and offline demo.
4. Shared property discovery.
5. Customer workflows.
6. Employee workflows.
7. Agent workflow, only if verified as supported.
8. Admin dashboard and management.
9. Uploads and backend gaps.
10. Offline persistence, loading/error/accessibility polish.
11. Tests, security review and Android demo verification.

Continue automatically when a phase's tests pass and its checkpoint is saved. Stop for genuine blockers, destructive operations, unresolved product decisions, or any change that could break the existing website/database. Never overwrite user data or run destructive migrations without explicit approval.

At the end, report:
- Verified screens/features by role.
- Implemented features and exact routes.
- Changed files and commits/checkpoints.
- Tests run and actual pass/fail results.
- API/backend changes.
- Known gaps and blocked verifications.
- Exact commands to run the app and backend.
- How to demonstrate all roles and switch between connected/offline demo modes.
