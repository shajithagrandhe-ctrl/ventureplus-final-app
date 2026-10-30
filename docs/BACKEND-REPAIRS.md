# Local backend authorization repairs

Status: implemented locally against source revision `3c24df131699c71fac4e500f0e1c531eeab519d2`, with TypeScript compilation, mocked-persistence route tests and isolated real-MySQL integration tests passing. These fixes are **not deployed** and do not establish that the live service enforces the same boundaries. An additive AuthSession schema migration is included and has been applied only to fresh synthetic local test databases. No repository seed, production migration, live database write, backend credential change, source commit or push was performed. The full finishing evidence and rollout prerequisites are in [the finishing report](../backend-patches/FINISHING-REPORT.md) and [deployment packet](../backend-patches/DEPLOYMENT-PACKET.md).

The exported deliverable is `backend-patches/ventureplus-authorization.patch`; `reference-web/` is an ignored source checkout. The patch retains the endpoint paths, response envelopes, roles and event names used by the existing clients.

## Repairs

| Source audit gap | Local remedy |
| --- | --- |
| Customer plot detail includes other customers' leads | Customer plot visibility and nested lead projection both use the signed-in account's current email. Shared plots return only that customer's leads. |
| Record/tracking access uses incidental email substrings | A dedicated, exact `Email:` line identifies legacy customer ownership; suffix matches, incidental text, malformed lines and multiple ownership lines fail closed. Candidate records are filtered before pagination/counts. Final queries retain both ID and the matched notes value, preventing a later notes edit from reusing a stale candidate ID. |
| Free-text notes could become an ownership key | Total-data creation strips reserved `Email:` lines from notes. Edits preserve stored ownership headers while ignoring attempted replacement, insertion or removal in the submitted notes; updates also require the originally read notes value. Lead creation establishes the explicit validated email linkage and strips reserved headers from its free-text notes. |
| Employee direct IDs bypass assignment/ownership | Shared predicates scope plot reads/updates and lead list/create/update/delete to assigned ventures or assigned locations. Customer record reads/updates/deletes and tracking reads/writes use existing employee owner aliases. Newly created leads force the employee's own agent ID. Lead-to-record synchronization cannot overwrite an unowned employee record. |
| Ambiguous legacy employee aliases | An alias shared with another user's email/name/displayName/employeeId grants no access. Exact unique email aliases remain usable. Newly created or edited employee records prefer the employee email. Legacy ambiguous records require an admin to reconcile ownership. |
| Favorites reveal inaccessible inventory | Adding a favorite first checks the same plot visibility rule; reads filter retained favorites through current visibility. Own stale favorites can still be removed. |
| Copied JWTs survive logout or password changes | Persisted AuthSession identifiers enable single-session logout and all-session revocation on password changes/resets. Raw tokens are not stored; legacy JWTs require one-time sign-in after rollout. |
| Session creation races a password reset | Login and registration check the verified password hash while holding a user-row lock and insert the session in the same transaction. Password updates and session revocation are transactional. |
| Frozen employees retain working tokens | Every protected HTTP request rechecks the user, current role/email and employee freeze/relieving date. Deleted users and inactive employees are denied. SSE and WebSocket connections repeat the check before each event and every 25 seconds when idle. |
| Full PII reaches non-admin event subscribers | Employee, Agent and Customer events retain event name, event ID and timestamp with an empty payload. Clients refetch through scoped APIs. Admins retain existing event details for administrative notices. Both SSE and WebSocket use the same filter. |
| Cache retains old scoped responses | Customer and Employee responses bypass the existing short-lived response cache so assignment/ownership changes apply to the next protected read. |
| Customer dashboard exposes global totals | Customer counts use accessible plots, own leads and exact record ownership; employee count is zero. |
| Employee editor accepts other-role targets | Employee edit/status handlers require the target role to be EMPLOYEE. User update also includes the role in the mutation predicate. Email changes explicitly return 400 because legacy record ownership uses that address; case-equivalent submissions are accepted without changing the stored address. Unparsable date strings produce 400. |
| Unbounded or invalid updates | Tracking latitude is limited to -90..90 and longitude to -180..180. Region payloads require roads/parks polygon arrays, 3..500 normalized points per region and at most 200 regions per collection. Lead update status is constrained to the existing enum. Invalid pagination numbers fall back safely and page size remains capped. |
| Upload MIME spoofing / generic size failures | Persisted uploads check PNG/JPEG/WebP/PDF signatures or the SVG root marker against their supported MIME type. Multipart oversize errors return 413 at the existing 4 MiB limit; malformed upload errors return 400. SVG assets served by the database asset endpoint receive a restrictive CSP sandbox. |

ADMIN broad permissions are preserved. AGENT retains its source-backed broad read and tracking-write permissions. This patch does not give AGENT any Employee-only writes.

## Validation performed

The final 30 October 2026 run passes **36 server tests**, **3 gateway tests** and **2 web compatibility tests** through the root `npm test` command. Server TypeScript compilation, backend lint and client type checking pass. The production web/server build passed on 29 October. The four dependency audit snapshots each contain zero known vulnerabilities. Existing full web-client lint still reports 66 errors and 30 warnings.

The route suite uses synthetic persistence and loopback HTTP/SSE/WebSocket servers. It covers the original ownership/assignment/upload boundaries, persisted session checks, logout/password/reset revocation, and registration/reset ordering. It never falls through to a production database.

A separate **14/14 passing MySQL suite** uses real Prisma queries and independent observer connections on a fresh, loopback-only fixture. Both baseline and AuthSession SQL migrations are exercised there. The final fixture was `ventureplus_test_20261030_084707_465017b6`; the runner stopped its own MySQL process afterward. This verifies actual persistence and deterministic reset-before-issuance ordering, while exhaustive overlapping transaction scheduling remains outside the suite.

Reproduce the database checks with `backend-patches/run-isolated-mysql.ps1`. It refuses an occupied port 3309 and non-test targets, initializes a new datadir, and never seeds or migrates an existing database. The exported 560,138-byte patch passes reverse application and clean-baseline application checks. A separate bounded review found no actionable issue in the registration/session transaction changes. See [verification output and exact commands](../backend-patches/FINISHING-REPORT.md).

## Remaining limits

- Customer ownership remains encoded in legacy notes, and staff ownership in text aliases. Durable user foreign keys are the proper long-term repair. Exact matching intentionally hides ambiguous/malformed legacy records. Administrators may need to reconcile them. Renaming a staff email/name can require reconciling old owner text. The candidate query for customer ownership also scales less well than an indexed foreign key.
- Assignment checks and separate create/upsert operations use the current authorization snapshot; a transactionally enforced relation model is still needed for strict concurrent reassignment guarantees.
- AuthSession revocation applies only after its migration and code are deployed. The live backend remains unchanged. Existing sessions must sign in once after rollout.
- Venture photo and layout still share `layoutImage`. Separate persistence requires a reviewed schema change and migration. No field or migration was invented here.
- Asset URLs remain public under the existing policy. SVG is sandboxed on the database asset route, but assets are not authorization-protected documents. Signature checks are not full file parsing, malware scanning or SVG sanitization. Already cached or legacy static assets are outside this change.
- Admin event details remain intentionally complete; non-admin streams reveal event types/timing only. Existing clients must refetch authorized data instead of relying on non-admin event payloads.
- The live backend has not received this patch. Connected mobile ownership acceptance remains pending deployment approval and verification against the patched service.
