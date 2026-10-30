# Review packet for backend migration and deployment

This is a concrete local deployment proposal, not a record of a production action. Apply the reviewed `ventureplus-authorization.patch` only to source revision `3c24df131699c71fac4e500f0e1c531eeab519d2` or rebase/review it against a newer source revision first. The patch includes all preceding authorization repairs, the AuthSession migration, dependency lockfiles and limited web compatibility fixes.

The parent task identified the Vercel project as `prj_NyQlIO65RFD37AJK97jE1ttv89tA`, team `team_8Eq10DEH1ZQg21C1YoQf1oAK`, with Node 24 and the existing client/backend/server service configuration. Scoped deployment access has not been verified successfully. Reconfirm the connected account, project, source revision and production database before requesting approval; these identifiers alone do not authorize a deployment.

## What changes in the database

Only `database/migrations/20261029000000_auth_sessions/migration.sql` is new. It creates `AuthSession` with `id CHAR(64)` as the primary key, `userId` linked to `User.id`, `createdAt`, `expiresAt`, nullable `revokedAt`, and indexes on `(userId, revokedAt)` and `expiresAt`. User deletion cascades to that user's sessions. No existing records are deleted, seeded, renamed or backfilled by this migration. The application will create session rows on successful login/registration and update revocation timestamps on logout/password changes.

Raw JWTs, passwords and password hashes are not added to this table. The `id` contains only a digest of a random JWT identifier. The existing JWT secret remains configured through the approved environment and must not be pasted into reports or command logs.

## Read-only preflight before approval

1. Verify the deployment account/project and exact patched source revision. Review the exported patch and `FINISHING-REPORT.md`.
2. Confirm Node 24 and the client/backend/server bindings. Preserve existing environment secrets and database connection configuration.
3. Through the database owner's approved connection, inspect `prisma migrate status --schema database/schema.prisma` and compare the deployed schema with the baseline. Confirm a recoverable backup and rollback owner.
4. If the production tables exist without the original Prisma migration history, stop. Review schema equivalence and a separate explicit baseline-recording proposal; do not blindly deploy the baseline or run `db push`, `migrate reset`, development migration commands or repository seeds.
5. Confirm users can tolerate one-time sign-in, and that the deployed web/mobile clients handle a successful password change by clearing their session and returning to sign-in.

## Actions to approve together after preflight

Approve the exact target and revision, a maintenance window if needed, application of the additive AuthSession migration to the identified production database, and deployment of the reviewed server/gateway/client code. The proposed database command in that approved environment is:

```powershell
npm run prisma:deploy -w server
```

Run it only after confirming the baseline migration is already recorded. Build/generate commands do not substitute for applying the SQL migration. Deploy the new code after the table exists. Preserve the existing API JSON envelopes, routes, role permissions, secrets and bindings.

Legacy JWTs have no persisted session identifier and intentionally fail authentication under the new code. Users sign in once to create a session. Logout revokes only that session; own password changes and administrator password resets revoke all sessions for the affected user. Current-role/frozen-account checks continue on protected requests and realtime connections.

Session creation for login and registration checks the original password hash while holding the user row lock. If an administrator reset wins the race after account creation but before registration's session issuance, the account remains created with the replacement credentials, registration returns 401 without an access cookie, and the user must sign in again. This ordering is covered by deterministic HTTP and real-MySQL regressions in the final local checks (36 server tests and 14 real-persistence tests).

## Post-deployment verification within the approved scope

Use approved test accounts and synthetic records only. Check health, login and `/auth/me` for supplied roles; capture two sessions for one account; verify logout invalidates the captured first token while the second works; verify a password change invalidates both old sessions and old credentials; verify the replacement password creates a new working session. Test anonymous/wrong-role/foreign-ID denial and refresh after permission changes. Verify SSE/WS subscriptions lose access after revocation and that uploads retain their expected content type/sandbox headers. Never log raw credentials or tokens.

The local real-MySQL tests prove the proposed SQL and code against a fresh fixture, not the live deployment's grants, TLS, backup, baseline history, bindings or data quality. Those remain preflight checks.

## Rollback and residual work

Keep the additive session table on rollback; it contains no business records that require restoring. Rolling back to the original stateless-auth server reintroduces the previous authorization/revocation gaps. Prefer a reviewed fix-forward or an auth maintenance window. Any credential rotation or production schema/history change requires its own explicit approval and must not be improvised as a cleanup step.

Do not present the string-based legacy ownership model, shared photo/layout field or demonstration OTP as newly repaired. Their exact limitations are recorded in `FINISHING-REPORT.md`. No customer-owner foreign-key migration or historical-ownership backfill is included in this approval packet.
