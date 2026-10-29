# VenturePlus source audit

Audit date: 29 October 2026 (Asia/Calcutta). Reference source: `reference-web/`, upstream `VenkataVyshnaviMondi/ventureplus123`, commit `3c24df131699c71fac4e500f0e1c531eeab519d2`.

Every source finding below is **VERIFIED-SOURCE**, not a runtime success claim. Authenticated live screens, working supplied accounts, connected persistence, cross-session visibility, ownership denial tests and upload behavior are **BLOCKED / not verified by this source audit**. The primary implementation agent records any separate live results. No database operations, seed scripts, remote mutations or backend changes were performed for this audit. Source references are relative to `reference-web/`.

## Findings that control the mobile implementation

1. Customer catalogue means **My Properties**: locations, ventures and plots are limited to plots whose leads contain the customer's exact email. It is not a general marketplace. `server/src/services/location.service.ts:17`, `venture.service.ts:16`, `plot.service.ts:20`; `client/src/pages/Dashboard.tsx:40`.
2. **AGENT is an active backend role**, with a schema enum, seeded agent profile, agent directory membership and explicit tracking-write permission. It differs from EMPLOYEE: Agent cannot mutate leads/customer records/plots, provision customer accounts or access staff lists. It can read currently unscoped inventory/leads/records/tracking and post tracking. `database/schema.prisma:13`, `server/src/scripts/seed.mjs:77`, `server/src/services/agent.service.ts:3`, `server/src/routes/tracking.routes.ts:23`. These are source capabilities; no Agent account was authenticated.
3. The website login cannot successfully retain an Agent session: its three-tab role check rejects any server role outside ADMIN/EMPLOYEE/CUSTOMER. Preserve server-derived AGENT in Flutter without inventing an Agent prefill account. `client/src/pages/BackendThreeLogins.tsx:133`.
4. Employee and Agent sidebars advertise New Venture and Layout Editor, but their APIs are ADMIN-only. Flutter must obey the API restriction. `client/src/components/SimpleAppSidebar.tsx:37`, `client/src/pages/Dashboard.tsx:38`, `server/src/routes/ventures.routes.ts:41`, `plots.routes.ts:52`.
5. The backend has material ownership weaknesses, listed below. The mobile UI cannot repair them. Connected ownership acceptance must remain incomplete until compatible fixes and tests exist.
6. Layout and property photo uploads currently overwrite the **same** `Venture.layoutImage` field. There is no distinct persistent `photoUrl` column. Do not promise that both images survive two uploads. `server/src/services/venture.service.ts:102`, `venture.service.ts:116`, `database/schema.prisma:118`.
7. Some existing web presentation is fabricated: tracking generates random movement when tracking data is absent, and reports assign fixed conversion probability and interactions. Do not copy these behaviors into connected mode. `client/src/pages/CustomerLiveTracking.tsx:189`, `CustomerLiveTracking.tsx:224`, `ReportsPage.tsx:58`.

## Authentication and common response contract

- API mount is `/api`: `server/src/app.ts:115`, `server/src/routes/index.ts:23`.
- `GET /auth/csrf` returns `{success:true,data:{token},message}` and sets the CSRF cookie. In production every unsafe HTTP method, including login and logout, requires the CSRF cookie plus matching `X-CSRF-Token`. `server/src/utils/csrf.ts:17`, `csrf.ts:23`.
- `POST /auth/login`: `{email: valid email, password: string min 6, adminCode?:string}`. Returns `{success:true,data:{user},message}` and sets HttpOnly access cookie plus a refreshed CSRF cookie. **No bearer token is returned in JSON**. A native client needs a cookie jar and must retain/rotate both cookies. `server/src/routes/auth.routes.ts:10`, `server/src/controllers/auth.controller.ts:27`.
- `GET /auth/me`: authenticated `{success:true,data:{user},message}`. User fields include id, email, displayName, fullName, role, department, position, adminCode, employeeId, phoneNumber, address, createdAt, lastLogin and selected employeeProfile status fields. Native routing must use this identity and default-deny unknown roles. `server/src/controllers/auth.controller.ts:96`, `server/src/services/user.service.ts:4`.
- Auth middleware accepts `Authorization: Bearer ...` or the configured access cookie; verifies JWT and populates `req.user`. It does not recheck current user status/role in the database. `server/src/middleware/auth.ts:9`.
- `POST /auth/logout`: clears cookies, returns `{success:true,message}`. It does not invalidate an already issued JWT. `server/src/controllers/auth.controller.ts:86`.
- `POST /auth/change-password`: all signed-in roles; `{currentPassword:min6,newPassword:min8}`. Verifies current password and updates hash. `server/src/routes/auth.routes.ts:44`, `server/src/services/auth.service.ts:86`.
- Employee FROZEN/date-of-relieving restrictions are checked on login. Existing JWTs are not revoked by freezing. Admin code is optional and checked only when supplied. `server/src/services/auth.service.ts:110`.
- `POST /auth/register` is public employee-only registration: email, password min8, displayName/fullName min2, role EMPLOYEE, optional department/position/employeeId/phoneNumber/address. Customer and admin self-registration are not supported. This endpoint is not a reason to silently create demo accounts. `server/src/routes/auth.routes.ts:16`.
- Successful resources use `{success:true,data:<resource or array>,message}`; lists of plots/leads/customer records also return `pagination:{total,page,pageSize,pageCount}`. Page size defaults to 20 and caps at 100; callers requesting 200 or 1000 do not receive all rows. `server/src/utils/pagination.ts:1`.
- Authentication failure is 401; role denial 403; missing resources generally 404; schema errors 400 with field errors; other database errors 400 and unhandled errors 500. Frozen login is currently mapped to 500 by the login controller. `server/src/middleware/errorHandler.ts:8`, `server/src/controllers/auth.controller.ts:41`.

## Screen and role matrix

All rows: VERIFIED-SOURCE. A=ADMIN, E=EMPLOYEE, G=AGENT, C=CUSTOMER. “All” means authenticated, except the public authentication entry and explicitly public inquiry endpoint. These describe implemented source behavior; insecure access is documented separately and is not endorsed as intended policy.

| Website surface / route | Roles / actions for mobile | API and scope | Evidence |
|---|---|---|---|
| Login `/auth`, `/backend-auth` | All intended roles; exact three requested prefills remain prefill-only; explicit separate Offline Demo | CSRF, login, me, logout above | `client/src/App.tsx:36`; `BackendThreeLogins.tsx:133`; auth routes |
| Overview `/` | All; navigate inventory and role-appropriate work, display real available/advance/sold counts | GET stats and recent total-data. Stats scopes E; currently returns global totals to C/G | `client/src/pages/Dashboard.tsx:13`; `server/src/services/stats.service.ts:4` |
| Locations `/ventures` | A/G all; E assigned; C lead-linked | GET locations summaries, GET locations/:id | `client/src/pages/VentureLocations.tsx:8`; `server/src/services/location.service.ts:4` |
| Ventures `/ventures/:locationId` | Same; browse photo, counts, venture | GET locations/:id or ventures?locationId; layout-edit shortcut must be A-only | `client/src/pages/VenturesList.tsx:11`; `server/src/services/venture.service.ts:4` |
| Plots `/ventures/:locationId/:ventureId` | Read role-scoped layout/grid/details; A/E update plot status/details and create leads; G/C read only | GET venture/:id, GET plots, GET plots/:id, GET plots/:plotId/leads; PUT plots/:id | `client/src/pages/PlotGrid.tsx:192`; `PlotGrid.tsx:430`; `client/src/components/PlotDetailDialog.tsx:26`; plot routes |
| New Venture `/new-venture` | A only: create venture and generated plots, upload photo/layout, open editor | POST ventures then POST ventures/:id/photo or /layout | `client/src/pages/NewVenture.tsx:35`; `server/src/routes/ventures.routes.ts:31` |
| Layout Editor `/layout-editor` | A only: select venture, upload layout, rectangle/polygon plot coordinates, road/park regions, edit plot details; source includes image rectangle detection | PUT plots/:id/coords, PUT plots/coords, PUT ventures/:id/regions, PUT plots/:id | `client/src/components/VentureLayoutEditor.tsx:194`, `:345`, `:369`, `:407`, `:499`; plot/venture routes |
| Reports `/reports` | Read leads: A/E/G all currently, C own email. A/E create/update/delete; G read only | GET leads (paginate all pages); POST/PUT/DELETE leads | `client/src/pages/ReportsPage.tsx:94`; `server/src/routes/leads.routes.ts:33` |
| Track Customers `/track-customers` | A/E record create/edit; owner assignment A, E owner overwritten with identity. Staff can provision customer credentials. G can currently read records, no mutations. C own records only | GET/POST/PUT/DELETE total-data; GET employees A/E; POST auth/customers A/E | `client/src/pages/TrackCustomers.tsx:89`, `:100`, `:191`, `:237`; customer/auth routes |
| Track Customers local actions | Staff filter/search, call phone, download CSV and calendar follow-up (local export, not server calendar sync) | No new server endpoints; derived from authorized records | `client/src/pages/TrackCustomers.tsx:298`, `:313`, `:382` |
| Total Data `/total-data` | A/E add records; A owner reassignment. G/C must not receive edit controls merely because page lacks guard | GET/POST/PUT total-data, GET employees | `client/src/pages/TotalDataForm.tsx:17`, `:61`, `:92`, `:326` |
| Live Tracking `/live-tracking` | All read scope; A/E/G can post updates per API, C cannot. Source UI displays tracking, not an evidenced update form | GET total-data + GET tracking; POST tracking is API-supported | `client/src/pages/CustomerLiveTracking.tsx:170`; `server/src/routes/tracking.routes.ts:22` |
| Admin `/admin` | A only: dashboard, locations, ventures, customers, employees, performance, units | GET stats, locations, ventures, total-data, employees, leads | `client/src/components/AdminPanel.tsx:40`, `:301` |
| Employee Access `/employee-access` | A only: employee create/edit/freeze/reactivate, assignments, demo OTP request/verify | All employee-access routes | `client/src/pages/EmployeeAccess.tsx:66`, `:102`, `:122`, `:128`, `:280` |
| Profile/sidebar | All: display server identity, change own password, logout/account switching | auth/me, auth/change-password, auth/logout | `client/src/components/SimpleAppSidebar.tsx:75` |
| Favorites | All API-supported for own user; no routed web screen/call site found beyond API wrapper | GET/POST/DELETE favorites; customer plot-access gap must be fixed | `client/src/services/api.ts:560`; favorite routes/service |
| Inquiries | Public API submission supported; mobile can require login; no inquiry list/update/admin management endpoint exists | POST inquiries only | `server/src/routes/inquiries.routes.ts:9`; `client/src/services/api.ts:571` |
| Agent directory/profile | All API-supported; returns agents and employees, no routed web screen/call site found beyond wrapper | GET agents, GET agents/:id | `server/src/services/agent.service.ts:3`; `client/src/services/api.ts:566` |
| Payment `/payment`, available/sold pages | Payment excluded by explicit brief; sold-out feedback can be retained. Do not invent payment persistence | No payment API registered | `client/src/App.tsx:38`, `:52`; `server/src/routes/index.ts:23` |

Admin analytics are derivations of real objects: portfolio value = sum(area × pricePerSqYard), sold/advance/available values by status, occupancy = (sold+advance)/plots, conversion = sold/plots, customer budgets, employee owner-name-based performance. Label incomplete/paginated data; do not copy the web's first-100-row assumption. `client/src/components/AdminPanel.tsx:57`, `:117`, `:191`.

## Resource payloads and validations

| Operation | Request | Response / rules and evidence |
|---|---|---|
| GET locations | No query | Array of `{id,name,availablePlots,ventures:[{id,name,photoUrl,plotCount,availablePlots,soldPlots}]}`; photoUrl is alias for layoutImage. Detail nests ventures/plots; C nested leads filtered. `location.service.ts:4`, `:127` |
| GET ventures | optional locationId | Venture records + location + plots. Detail includes leads (C filtered). `venture.service.ts:4`, `:60` |
| POST ventures (A) | name nonempty; locationName trimmed nonempty; plotCount integer 1..200; optional plotNumberPrefix; optional startingPlotNumber integer >=1; defaultArea and defaultPricePerSqYard positive integers | 201 venture with location/plots; upserts location name and generates AVAILABLE plots. No separate location-create endpoint. `ventures.routes.ts:31`, `venture.service.ts:123` |
| GET plots | optional ventureId, status, page, pageSize | Plot array + pagination. Plot has id, plotNumber, status, area, pricePerSqYard, ventureId, x/y/width/height/shapeData, timestamps, nested venture/location. Query status and numeric pagination are not Zod-validated. `plots.controller.ts:7`, `plot.service.ts:6` |
| PUT plots/:id (A/E) | optional status AVAILABLE/ADVANCE/SOLD; area and pricePerSqYard positive integers; plotNumber nonempty | Updated plot with venture/location/leads. No independent plot create/delete API. `plots.routes.ts:11`, `plot.service.ts:66` |
| PUT plot coordinates (A) | at least one x/y/width/height 0..1 or shapeData `{type:'polygon',points:[{x:0..1,y:0..1}, ...]}` >=3 points | Updated plot; batch `{plots:[{id,...coordinates}]}` returns array. Existence checked; batches of 50 transactions are not a single all-or-nothing transaction. `plots.routes.ts:18`, `plot.service.ts:108` |
| PUT venture regions (A) | `{regions:<JSON>}` | Updated venture; currently no shape schema/size validation. `ventures.controller.ts:74`, `venture.service.ts:109` |
| POST lead (A/E) | plotId nonempty, customerName min2, email valid, contactNumber min6, location min2, uniqueId min3, pricePerSqYard positive integer; optional plotNumber, notes, photoUrl URL, agentId | 201 Lead; agentId defaults to actor id. Transaction also creates/updates CustomerRecord, writes structured email/venture/plot/unique-id notes and marks HOT_LEAD. `leads.routes.ts:10`, `leads.controller.ts:37`, `lead.service.ts:46` |
| PUT lead (A/E) | optional notes, status string, pricePerSqYard positive integer, contactNumber, location, uniqueId | Updated Lead. Actual database enum NEW/FOLLOW_UP/QUALIFIED/WON/LOST; route accepts arbitrary string then casts, so mobile should validate enum. DELETE returns success/message. `leads.routes.ts:24`, `lead.service.ts:173`, schema:26 |
| GET leads | optional page/pageSize or plotId via `/plots/:plotId/leads` | Lead array + plot/venture + pagination; C exact email match, E/G no assignment filter. `lead.service.ts:4` |
| POST/PUT customer record (A/E) | contactName min2, contactNumber min6, location min2, budget nonempty string, recordOwner min2; optional interested boolean, status enum, leadName min2, notes | CustomerRecord; status defaults FOLLOWING_UP. interested derives from status except explicit boolean. E forces identity as owner/leadName. PUT requires full required fields; DELETE success/message. `customers.routes.ts:10`, `customer.service.ts:78`, `:124` |
| GET customer records | optional page/pageSize | Array + pagination; C notes contains email; E owner/leadName aliases from fullName/displayName/email/employeeId; A/G unrestricted. `customer.service.ts:11` |
| POST customer credentials (A/E) | email valid, password min8, displayName/fullName min2; optional phoneNumber/address | 201 `{user}` CUSTOMER identity; existing email rejected. `auth.routes.ts:35`, `auth.service.ts:59` |
| Favorites | POST `{plotId:nonempty}`; DELETE path plotId | GET favorites nested plot/venture/location; own userId enforced; unique user+plot; arbitrary plot id is not checked for catalogue visibility. `favorite.service.ts:3`, `:17`, `:26` |
| Inquiry | optional plotId/agentId/customerPhone; customerName min2; customerEmail valid; message min10 | 201 Inquiry. No list, edit or delete route; no customer attachment workflow. `inquiries.routes.ts:9` |
| Tracking | `{customerId:nonempty,latitude:number,longitude:number,status?:active/inactive/moving (case-normalized),address?:string}` | TrackingUpdate with id, customerId, coords, status, address, updatedAt, updatedBy. Upsert by customerId. Latitude/longitude bounds not validated. `tracking.routes.ts:10`, `tracking.service.ts:32` |
| Staff directories | GET employees (A/E), admins (A), customers (A/E) | User records with selected profile fields, no password hash. Agent excluded from these routes. `users.routes.ts:8`, `user.service.ts:4` |
| Employee create/update (A) | email valid; create password min6; update partial; optional displayName/fullName min2, employeeId, phone min6, department/position, address, firstName/lastName, emailVerified/phoneVerified, dateOfBirth, yearsOfExperience integer 0..80, company history, positions, roleGiven, assignedLocationIds/assignedVentureIds string arrays, joining/relieving dates, achievements, ACTIVE/FROZEN | Employee + employeeProfile + assignments. Update schema accepts email but controller does not update email. Date strings are not validated before Date conversion; target role is not checked in update/status handler. `employeeAccess.routes.ts:17`, `employeeAccess.controller.ts:124` |
| Employee status (A) | `{status:ACTIVE/FROZEN}` | EmployeeProfile; no JWT revocation. `employeeAccess.controller.ts:211` |
| Demo OTP (A) | request `{type:email/phone,target:min3}`; verify `{requestId:UUID,otp:string length4..10}` | Request returns actual OTP with requestId/expiresAt (5 minutes), not delivered SMS/email. Verify max5 attempts and one use; response type,target,verifiedAt. `otp.service.ts:7`, `:20` |
| Upload layout (A) | multipart single field `layout`; max4 MiB; MIME PDF, PNG, JPEG/JPG, SVG | Saves DB asset and updates layoutImage. Invalid MIME filtered => missing file 400. `ventures.routes.ts:13`, `ventures.controller.ts:32` |
| Upload photo (A) | multipart single field `photo`; max4 MiB; PNG/JPEG/JPG/WebP | Same DB asset mechanism and same layoutImage column. `ventures.routes.ts:22`, `ventures.controller.ts:53` |
| Asset read | GET `/uploads/assets/:id` (outside /api) | Public binary bytes, contentType stored from upload, immutable cache. No auth or ownership check. `server/src/app.ts:103` |

There is no verified generic document store, customer upload, profile edit, inquiry-management dashboard, standalone location CRUD, venture delete/update-metadata, or standalone plot create/delete route. Those must not be presented as working features merely because the baseline lists broad “management” examples.

## Backend authorization defects and required tests

These are source-proven code paths, not an assertion that a live exploit was exercised.

| Priority | Source issue | Concrete impact / required verification |
|---|---|---|
| P1 | `plot.service.ts:49` selects a C-accessible plot but includes `leads:true` | A customer sharing a plot can receive other customers' contact/unique-id/notes. Scope nested leads by identity; test two customers on same plot and denied foreign plot. |
| P1 | `customer.service.ts:19`, `tracking.service.ts:13` use notes substring matching | A customer's email appearing incidentally or as suffix of another address can grant record/tracking access. Need durable exact ownership relation or compatible exact structured-email matching with fail-closed behavior; test overlapping addresses and unrelated notes. |
| P1 | `routes/realtime.routes.ts:17`, `realtime/ws.ts:66` subscribe without per-user filtering | Full lead, record, inquiry, favorite and tracking event payloads reach every authenticated subscriber. Scope subscribers/events or emit non-sensitive invalidations and re-fetch authorized data; test C/E/G event boundaries. |
| P1 | `plot.service.ts:6`, `:66`; `lead.service.ts:4`, `:173`; `customer.service.ts:124`, `:171`; `tracking.service.ts:32` lack staff assignment/ownership checks | Employee can target arbitrary IDs outside assigned locations/ventures or owned records even though lists restrict some data. UI-only restrictions are insufficient. Preserve ADMIN scope; test unassigned employee direct GET/PUT/DELETE and foreign tracking. Agent currently has broad read/tracking permission; do not silently narrow G without documenting source-backed policy. |
| P1 | `favorite.service.ts:17` accepts arbitrary plot ID, list includes that plot | Customer can add an unowned plot then read its inventory via favorites. Require same inventory visibility predicate; test guessed foreign plot and retained favorite after access removal. |
| P1 | `middleware/auth.ts:20` only JWT-verifies; freeze affects login and selected list services | A frozen employee's existing JWT can still mutate other endpoints. Check current active status for requests and existing streams; test freeze after login. |
| P2 | `stats.service.ts:89` global fallback for C | Customer dashboard exposes global counts instead of own properties/records. Scope customer stats or omit unsupported KPI; verify no global total leakage. |
| P2 | `employeeAccess.controller.ts:124`, `:211` target user ID without EMPLOYEE check | Admin employee editor can update password/profile for another role by changing ID. Require target role; test admin/customer/agent IDs rejected through employee-specific endpoints. |
| P2 | `ventures.routes.ts:64` no region validator; tracking coords unbounded; upload MIME trusted | Add shape/coordinate bounds, robust file limits/type handling, safe SVG delivery; verify validation errors and oversized files. |
| P2 | `auth.service.ts:110`, `auth.controller.ts:86` no revocation | Password change/logout do not invalidate copied JWTs. Do not claim server-side session revocation. |
| P2 | `app.ts:103` assets public | Uploaded layouts/photos can be fetched without sign-in if URL known. Confirm intended asset-public policy before claiming protected documents. |

## Web discrepancies and UX evidence

- General route guard only checks user existence, not role; `/admin` and `/employee-access` add component guards, other privileged pages rely on backend refusal. `client/src/components/SimpleProtectedRoute.tsx:4`.
- Reports maps NEW to Available, FOLLOW_UP/QUALIFIED to Advance Paid, WON to Sold, and LOST to Converted. These labels conflate lead and plot status; use real enums in mobile. It hardcodes payment method, one interaction, and 65% conversion probability. `client/src/pages/ReportsPage.tsx:41`, `:58`.
- Tracking uses city defaults when no server update exists and randomly moves coordinates every five seconds. Mobile connected mode must show “No tracking update” instead. `client/src/pages/CustomerLiveTracking.tsx:189`, `:224`.
- Dashboard uses zero defaults while requests have no explicit error rendering. Admin analytics asks for 1000 records but backend caps at 100. Mobile must distinguish loading/error/zero and exhaust pagination before all-record totals. `client/src/pages/Dashboard.tsx:23`, `client/src/components/AdminPanel.tsx:46`, `server/src/utils/pagination.ts:1`.
- Locations/ventures have loading text, reports loading state, customer mutation toasts and validations, layout mutation error feedback. They are not evidence of the complete ten mobile UX requirements. `VentureLocations.tsx:22`, `VenturesList.tsx:20`, `ReportsPage.tsx:94`, `TrackCustomers.tsx:199`, `VentureLayoutEditor.tsx:345`.
- Mobile required state matrix applies to every resource: skeleton while loading; explicit empty explanation; actionable error/retry; permission denial; refresh; verified mutation feedback; Offline Demo persistent indicator and local-only confirmation. Auth expiry must clear connected session; connected errors must never switch to sample records.
- Favorites/inquiries/agent wrappers exist but no actual call sites outside `services/api.ts` were found. Mark these as API-supported mobile additions, not observed web screens.
- The reference seed scripts delete existing tables before seeding. **Do not run them against an existing database.** `server/src/scripts/seed.mjs:20` onward and `seed.ts:9` onward. Their accounts are not evidence of deployed credentials.

## Test plan before connected acceptance

1. Cookie/CSRF bootstrap; exact supplied login credentials; invalid login; `me` identity; all four server roles; expiry/logout; no auto-submit on prefill.
2. Anonymous denial for inventory, favorites, leads, tracking, records, stats, staff; 403 wrong-role for every mutation and employee admin route.
3. Two customer fixtures: own vs foreign plots/records/tracking; shared plot nested leads; favorite by guessed foreign ID; email suffix/incidental-notes cases; SSE/WS payload isolation.
4. Two employees with disjoint assignments: location/venture/plot reads and edits, leads/record writes, tracking writes, status frozen after login. Test all paths, not only lists.
5. G distinct role: tracking allowed as source currently defines; lead/record/plot and account writes denied; no implicit employee privilege.
6. Admin CRUD that actually exists; enums and form errors; full pagination; duplicate identifiers; partial batch failure; safe delete confirmation.
7. Admin upload success for supported types and 4 MiB boundary; denied roles; missing/wrong field; invalid type; retry; dual image field discrepancy resolved before separate-photo promise.
8. Offline app restart and airplane mode; persistence and role guards; local-only data isolation; no hidden network fallback; every visible control.
9. Existing web build/tests plus backend authorization tests after any compatible patch. This report records no passing test counts; source inspection is not execution.

## Source audit scope

Read route registration, all routes/controllers, domain services, auth/cache/error/CSRF, realtime event delivery, Prisma model/enums, source seed role entries, top-level client route/navigation/auth, dashboard/admin analytics, property controls, layout editor actions, staff/customer actions and API wrappers. The baseline migration file is present and contains the schema tables including VentureAsset; migration execution/schema drift against a deployed database was not checked. Live service credentials/environment, actual database contents and every rendered web button remain outside this source-only evidence.

