# Local backend authorization repairs

Status: implemented locally against source revision `3c24df131699c71fac4e500f0e1c531eeab519d2`, with TypeScript compilation, mocked-persistence route tests and isolated real-MySQL integration tests passing. These fixes are **not deployed** and do not establish that the live service enforces the same boundaries. No application schema source changes, repository seed scripts, production migrations, live database writes, real credential changes, source commits or pushes were performed. A new synthetic test database was created locally for integration validation.

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
| Frozen employees retain working tokens | Every protected HTTP request rechecks the user, current role/email and employee freeze/relieving date. Deleted users and inactive employees are denied. SSE and WebSocket connections repeat the check before each event and every 25 seconds when idle. |
| Full PII reaches non-admin event subscribers | Employee, Agent and Customer events retain event name, event ID and timestamp with an empty payload. Clients refetch through scoped APIs. Admins retain existing event details for administrative notices. Both SSE and WebSocket use the same filter. |
| Cache retains old scoped responses | Customer and Employee responses bypass the existing short-lived response cache so assignment/ownership changes apply to the next protected read. |
| Customer dashboard exposes global totals | Customer counts use accessible plots, own leads and exact record ownership; employee count is zero. |
| Employee editor accepts other-role targets | Employee edit/status handlers require the target role to be EMPLOYEE. User update also includes the role in the mutation predicate. Email changes explicitly return 400 because legacy record ownership uses that address; case-equivalent submissions are accepted without changing the stored address. Unparsable date strings produce 400. |
| Unbounded or invalid updates | Tracking latitude is limited to -90..90 and longitude to -180..180. Region payloads require roads/parks polygon arrays, 3..500 normalized points per region and at most 200 regions per collection. Lead update status is constrained to the existing enum. Invalid pagination numbers fall back safely and page size remains capped. |
| Upload MIME spoofing / generic size failures | Persisted uploads check PNG/JPEG/WebP/PDF signatures or the SVG root marker against their supported MIME type. Multipart oversize errors return 413 at the existing 4 MiB limit; malformed upload errors return 400. SVG assets served by the database asset endpoint receive a restrictive CSP sandbox. |

ADMIN broad permissions are preserved. AGENT retains its source-backed broad read and tracking-write permissions. This patch does not give AGENT any Employee-only writes.

## Validation performed

Run from `reference-web/` on 2026-10-29:

```text
node node_modules/typescript/bin/tsc -p server/tsconfig.json
node --test server/tests/authorization.test.cjs server/tests/mongo-mysql-record.test.mjs
git diff --check
```

TypeScript compilation passed. The test run passed **28/28**: 24 new authorization/validation tests and 4 existing Mongo-to-MySQL record-conversion tests. The new suite covers successful mutations, anonymous and wrong-role rejection, cross-owner/assignment denial, shared-plot nested lead filtering, exact customer ownership, free-text ownership injection/transfer/erase denial with successful legitimate edits, trusted lead email linkage, coherent pagination, assignment removal, ambiguous aliases, scoped statistics, favorite access removal, frozen/current-role session checks, employee target-role and email-immutability checks, coordinate/region/status/date validation, upload type/size rejection, SVG response headers, and actual loopback SSE/WebSocket filtering and session closure. The exported patch passed both reverse application against the modified source and forward application checks against a disposable archive of the clean source revision.

The Windows sandbox initially rejected loopback connections with EACCES. The same test command passed after a scoped execution approval allowed its temporary local HTTP/WebSocket server. The test module injects an in-memory persistence adapter before app import, never constructs a Prisma client, disables Redis, and uses only synthetic test identities and a local test signing key. Unexpected persistence operations fail instead of falling through to a database.

The adapter checks the service's generated query contracts and endpoint behavior. It does not itself validate MySQL behavior. A separate **9/9 passing integration suite** now covers real MySQL relation filters, transactional lead/customer creation, scoped mutations, independent-session and independent-client persistence, notes ownership, frozen accounts, employee email immutability, asset bytes and retained-favorite revocation. It used fresh local database `ventureplus_test_20261029_175933_3a4558cd` on MySQL 8.4.13 bound only to `127.0.0.1:3309`. The database and datadir contain only synthetic fixtures; no existing database or repository seed was used. The runner shut down its own process afterward. This still does not establish exhaustive concurrency/race isolation or deployed behavior.

Reproduce from the Flutter workspace with `./backend-patches/run-isolated-mysql.ps1`, supplying `-MySqlHome` if the extracted MySQL ZIP is elsewhere. The runner refuses an occupied test port, initializes a fresh datadir, creates a unique test database, runs Prisma schema creation only there, compiles the backend and runs `node --test server/tests/mysql-authorization.test.cjs`. It uses the official MySQL 8.4.13 Windows archive (published MD5 `7b94489d5524dea9b27097068bea25a8` matched), no Windows service and no production credentials. The first attempted run exposed a local root-hostname-resolution issue; the corrected runner passed from a new datadir and includes cleanup even after a failed shutdown request.

## Remaining limits and migration work

- Customer ownership remains encoded in legacy notes, and staff ownership in text aliases. Durable user foreign keys are the proper long-term repair. Exact matching intentionally hides ambiguous/malformed legacy records. Administrators may need to reconcile them. Renaming a staff email/name can require reconciling old owner text. The candidate query for customer ownership also scales less well than an indexed foreign key.
- Assignment checks and separate create/upsert operations use the current authorization snapshot; a transactionally enforced relation model is still needed for strict concurrent reassignment guarantees.
- Logout/password changes still do not revoke a copied JWT. The new database check rejects frozen/relieved/deleted identities and follows role changes; it is not a general session-revocation system.
- Venture photo and layout still share `layoutImage`. Separate persistence requires a reviewed schema change and migration. No field or migration was invented here.
- Asset URLs remain public under the existing policy. SVG is sandboxed on the database asset route, but assets are not authorization-protected documents. Signature checks are not full file parsing, malware scanning or SVG sanitization. Already cached or legacy static assets are outside this change.
- Admin event details remain intentionally complete; non-admin streams reveal event types/timing only. Existing clients must refetch authorized data instead of relying on non-admin event payloads.
- The live backend has not received this patch. Connected mobile ownership acceptance remains pending deployment approval and verification against the patched service.
