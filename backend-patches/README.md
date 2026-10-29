# Local backend repair patch

`ventureplus-authorization.patch` contains the reviewed local backend changes and their regression tests. It targets source revision `3c24df131699c71fac4e500f0e1c531eeab519d2` in the existing VenturePlus web/backend repository. The Flutter repository does not own or deploy that backend.

The source copy under `reference-web/` is ignored by the Flutter repository. This patch preserves its changes as a deliverable. No source commit, push, production migration, repository seed or deployment was performed. A fresh local synthetic MySQL database was created for the separate integration suite.

In a clean checkout of the matching source revision, review and apply:

```powershell
git apply --check C:\path\to\ventureplus-authorization.patch
git apply C:\path\to\ventureplus-authorization.patch
node node_modules/typescript/bin/tsc -p server/tsconfig.json
node --test server/tests/authorization.test.cjs server/tests/mongo-mysql-record.test.mjs
```

The build requires the repository's installed dependencies and generated Prisma client. Use its existing installation/generation instructions if missing. The new authorization test suite injects persistence before loading the app, binds only to loopback, disables Redis and uses synthetic identities. It does not create a Prisma client or connect to MySQL. Run the separate database integration suite against an explicitly approved isolated MySQL instance before deployment; these tests are not a substitute.

The separate real-MySQL suite passed 9/9 locally. On Windows, with the official MySQL ZIP extracted under `.local/mysql/mysql-8.4.13-winx64`, reproduce it from the Flutter workspace with:

```powershell
.\backend-patches\run-isolated-mysql.ps1
```

Use `-MySqlHome C:\path\to\mysql` for another extracted location. The runner refuses occupied port 3309, initializes a new datadir, creates a unique `ventureplus_test_*` database, applies the existing Prisma schema only there and runs `server/tests/mysql-authorization.test.cjs` using real persistence. It stops only its own server afterward. The test module rejects arbitrary hosts, ports, database names and nonempty fixture databases. This does not operate on the deployed backend. The fixture uses a local-only empty-password root account inside the disposable server; never use this setup for a shared or production database.

To regenerate from the current local source edits, run `node backend-patches/export-local-patch.mjs` from the Flutter workspace. The exporter checks the baseline, reverse-checks the result, and checks forward application to a disposable archive of the clean baseline without staging or committing source files.

See `docs/BACKEND-REPAIRS.md` for exact behavior, evidence and remaining limitations.
