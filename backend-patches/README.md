# VenturePlus backend repair and verification patch

`ventureplus-authorization.patch` targets source revision `3c24df131699c71fac4e500f0e1c531eeab519d2` of the existing web/backend source. It contains the authorization repairs, durable session revocation and additive SQL migration, patched dependency lockfiles, backend ESLint configuration, regression tests and narrow web type-check fixes. The Flutter repository does not deploy that backend automatically.

The local source copy in `reference-web/` is ignored. This exported patch preserves its changes as a deliverable. No backend source commit/push, production migration, repository seed or deployment was performed. Only fresh local synthetic MySQL databases were created for verification.

## Apply and verify locally

Use Node 24. In a clean checkout of the matching source revision:

```powershell
git apply --check C:\path\to\ventureplus-authorization.patch
git apply C:\path\to\ventureplus-authorization.patch
npm ci
npm ci --prefix backend
npm run lint:backend
npm run typecheck -w client
npm test
npm run build
```

On this Windows host, set the existing private SWC cache before web build/test commands:

```powershell
$env:SWC_NATIVE_BINDING_CACHE='C:\VenturePlus-SWC-01a1875c'
```

That path is specific to this machine. Other machines should use their normal safe SWC cache. It does not belong in the deployed application configuration.

The root test command runs 2 client tests, 36 server tests without a database, and 3 gateway HTTP tests. Server tests inject synthetic persistence before loading the app; they bind only to loopback and do not connect to MySQL. The real-persistence suite is separate. Backend lint and client type checking pass; existing full client lint still reports 66 errors and 30 warnings. The production build passes with its existing large-chunk warning. The final registration regression ensures that an administrator password reset committed before session issuance prevents stale credentials from creating a session.

## Separate isolated MySQL suite

With the official MySQL 8.4.13 Windows ZIP extracted under `.local/mysql/mysql-8.4.13-winx64`, run this from the Flutter workspace:

```powershell
.\backend-patches\run-isolated-mysql.ps1
```

Use `-MySqlHome C:\path\to\mysql` for another extracted location. The runner refuses an occupied port 3309, initializes a fresh datadir, creates a unique `ventureplus_test_*` database, applies both SQL migrations only there and runs `server/tests/mysql-authorization.test.cjs` with real Prisma persistence. It stops only its own server. The tests reject arbitrary hosts, ports, database names and preexisting fixture users/inventory. The final run passed 14/14. The disposable loopback-only server uses an empty-password local root; never use this configuration for shared or production databases.

MySQL provenance: [official MySQL 8.4 downloads](https://dev.mysql.com/downloads/mysql/8.4.html?os=3), Windows 8.4.13 ZIP, official MD5 `7b94489d5524dea9b27097068bea25a8` verified when downloaded.

## Review before any rollout

The AuthSession migration changes session persistence. Existing stateless JWTs require one-time sign-in after deployment; password changes require sign-in again. Do not deploy the new authentication code before the table exists. Review `DEPLOYMENT-PACKET.md` for the exact additive migration, production-baseline preflight and actions requiring approval. No production schema operation is authorized by running these local tests.

`FINISHING-REPORT.md` records the exact remedies, evidence and residual limitations. `verification/` contains build/test output. The four `audit-after-*.json` files each report zero known npm vulnerabilities as checked on 30 October 2026. Audit results are a registry snapshot, not a claim that every security issue is absent.

To regenerate the complete allowlisted patch from the local source edits, run:

```powershell
node backend-patches/export-local-patch.mjs
```

The exporter verifies the source baseline, reverse-checks the result and forward-checks it against a disposable clean archive. It does not stage, commit, push or deploy source files. Its allowlist includes server/database repairs, the gateway, package manifests/lockfiles and the limited client compatibility changes.
