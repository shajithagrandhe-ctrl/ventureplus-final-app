# VenturePlus delivery report

Finishing snapshot: 30 October 2026. The current Flutter unit/widget suite passes **72/72**, the analyzer is clean and formatting checks 42 files without changes. The signed demonstration release passes APK v2 signature verification, installation and launch on a fresh emulator; the installed APK checksum exactly matches the artifact. **Both native release workflow cases passed in 105.8 seconds**, covering camera/gallery/file uploads, gallery cancellation, hardware-key customer filtering and CSV/calendar saved-byte readback. The local backend passes 36 server, 2 client, 3 gateway and 14 real-MySQL tests after the final registration/reset race fix; its patch passes clean-baseline apply/reverse checks. Eleven native integration cases, the old debug APK and five screenshots remain separate historical evidence from 29 October. No production migration or backend deployment has occurred.

## Built and scoped

The implementation is a native Flutter/Dart app in `mobile/`, with Android and iOS project scaffolding, the original Venture Plus logo, centralized light-theme tokens, reusable loading/error/empty states, role-aware bottom navigation and a secondary profile menu. It preserves the source hierarchy Location → Venture → Plot. Forms, layout editing, favorites, inquiries, customer/lead records, tracking, staff access and exports use a shared repository boundary.

| Role | Implemented mobile surfaces and actions | Evidence limits |
| --- | --- | --- |
| Admin | Overview metrics, inventory hierarchy, new venture form, plot details/status, layout geometry/regions, layout/photo selection and upload, lead create/edit/delete, customer-record CRUD, customer provisioning, staff create/edit/assign/freeze/reactivate and demo OTP, employee/admin/customer/agent directories, tracking, favorites/inquiries, profile/password/logout. | Source-backed contract and local automated coverage. Native auth verified. Live business writes and cross-user business persistence have not been exercised on the deployed service. |
| Employee | Overview, assigned inventory, plot updates, scoped leads, own customer records, customer accounts/provisioning, tracking updates, authorized directories, favorites/inquiries and profile controls. Admin layout/upload/access actions are not granted. | Native auth verified; local ownership tests pass. Deployed assignment/ownership enforcement depends on the backend patch. |
| Customer | Home, signed-in My properties, linked plot details, own records/tracking, favorites, inquiry submission and profile controls. | Native auth verified; local isolation and form/navigation coverage. Live private-data isolation remains a deployment gate. |
| Agent | Distinct Overview, inventory, lead/customer reads, tracking writes, favorites/inquiries and profile controls. | **VERIFIED-SOURCE** active role with meaningful permissions, implemented separately. No Agent credentials were supplied or tested live. Offline fictional Agent is implemented. |

Shared workflows include explicit login prefills, server-identity routing, logout/account switching, safe session expiry, pull-to-refresh, validated forms, confirmation for destructive actions, CSV export and follow-up calendar export, and supported single-file upload selection through camera/gallery/files. Native provider evidence is qualified below. OTP remains the source's demo flow; it is not a claim of real SMS/email delivery.

No generic document storage, inquiry-management dashboard/API, standalone location CRUD, venture delete, plot create/delete, payments or push notifications were invented. Customer browsing is My properties, not a public unfiltered catalogue. Tracking does not fabricate random positions or hardcoded performance metrics.

## Connected and offline behavior

Connected mode uses the real API, cookies/CSRF and a fresh `/auth/me` identity. Native cookies use secure storage scoped to the configured API base; passwords and connected response data are not stored in ordinary preferences. Unsafe writes are not automatically replayed. When the server confirms a business write but cookie persistence fails, the app preserves the confirmed success and shows a session-storage warning. A successful password change clears the local session and returns to sign-in; new login attempts are blocked until old-session cleanup finishes, and cleanup failure does not invite repeating the successful password mutation.

Offline Demo is a separate repository with fictional records, explicit local role entry and persistent local edits. Its banner says changes stay on the device. It performs no backend writes and cannot silently take over after a connected error. There is no pending-sync queue. Offline password changes are unavailable. Role/ownership rules are also checked locally, but local checks do not prove deployed server security.

The three supplied demo credential pairs were tested after explicit user authorization at the earlier checkpoint. Login and `/auth/me` returned 200 for ADMIN, EMPLOYEE and CUSTOMER. The Admin web dashboard/navigation was observed. The historical native Android integration verifies all three roles' identity, secure-session restoration and logout. Credentials are not repeated in this report; the isolated prefill configuration retains the requested values and remains demo-only.

Photo recovery retains the original account, API, mode, venture and photo/layout intent. Recovered selection review survives a further app restart and returning with Back, and requires an explicit upload action. Mismatched sessions, missing files, picker failures and files over 4 MiB lead to safe reselection. Unit/widget tests cover these paths; they do not establish native Android process-death behavior by themselves. Calendar export now escapes CR, LF and CRLF correctly. Offline provisioning validates the raw password length with the source minimums (6 for Employee, 8 for Customer), discards those fictional values and does not create an offline password sign-in mechanism.

## Verification evidence

| Check | Exact command / scope | Result at this snapshot |
| --- | --- | --- |
| Flutter dependency resolution | `flutter pub get` from `mobile/` | Completed during setup. |
| Flutter formatting/analyzer | `dart format --output=none --set-exit-if-changed lib test integration_test test_driver`; `scripts/mobile.ps1 -Action analyze` | **PASS**: 42 files, 0 formatting changes; current analyzer reports no issues (`.local/flutter-analyze-final.log`). |
| Flutter unit/widget suite | `scripts/mobile.ps1 -Action test` | **72/72 passed** in the current full run (`.local/flutter-tests-final.log`), including session cleanup, cookie-storage failure, photo recovery, export and provisioning validation regressions. |
| Inquiry widget regression | Targeted full inquiry flow in `mobile/test/workflow_forms_test.dart` | **PASS**, including validation, visible success feedback and local persistence. This does not verify physical Android input-method composition. |
| Historical Android debug APK | `scripts/mobile.ps1 -Action build` | **PASS, 29 October**: normal `lib/main.dart` debug build, 83.1 seconds (`.local/android-final-build.log`). Copied to `artifacts/ventureplus-demo-debug.apk`; historical checksum below. |
| Historical debug APK installation | `adb install -r artifacts/ventureplus-demo-debug.apk` | **PASS, 29 October** on `emulator-5554`. This does not verify the new signed release. |
| Signed Android release | `scripts/mobile.ps1 -Action demo-release`; `apksigner verify`; [packaging instructions](ANDROID-RELEASE.md) | **PASS**: final 42.1-second build from `lib/main.dart`; APK v2 signature verifies. Installation and launch passed on fresh `emulator-5556`; the installed `base.apk` SHA-256 exactly matches the artifact. Non-debuggable, minimum API 24, target API 36; ARM64, ARMv7 and x86_64. |
| Android connected auth | `scripts/mobile.ps1 -Action live-auth-test -Device emulator-5554` | **3 role cases passed**: Admin, Employee, Customer; framework reports +4 including tearDownAll. Each tests `/me` identity, secure restoration and logout. |
| Android airplane-mode offline flow | `scripts/mobile.ps1 -Action offline-test -Device emulator-5554` with airplane mode on and Wi-Fi/data disabled | **3/3 passed** in a completed run after the screenshot lifecycle fix. A later keep-app-running rerun passed the three cases but hit a VM Service disconnect during driver teardown; that rerun is not counted as a clean command pass. |
| Android process restart | `scripts/mobile.ps1 -Action restart-test -Device emulator-5554` after offline fixture creation | **1/1 passed** after actual process force-stop and relaunch: Employee session and the newly created fictional record persisted (`.local/native-restart-tests.log`). |
| Additional Android workflows | `scripts/mobile.ps1 -Action workflow-test -Device emulator-5554` | **3/3 cases passed** (`.local/native-workflow-tests.log`; framework +4 includes tearDownAll). Inquiry uses Flutter's test text-input binding after the earlier Android input-method interference; physical composition remains unverified. |
| Android tablet/responsive integration | `scripts/mobile.ps1 -Action tablet-test -Device emulator-5554` | **1/1 passed** (`.local/native-tablet-tests.log`; framework +2 includes tearDownAll). |
| Android screenshots/visual checks | Five phone/tablet PNGs listed below | **CAPTURED**; both tablet screenshots passed visual review with no clipping, overlap or readability blockers. Widget checks cover 360/1024 widths, large text and reduced motion, not every native interaction. |
| Native camera/gallery/file workflows | Android UI Automator on the debug emulator | **PASS**: camera, gallery and file selection with local uploads. These results precede the fresh signed-release run. |
| Native exports and hardware-key search | `nativeExportsAndKeyboard` UI Automator case on the debug emulator | **1/1 PASS**, 25.787 seconds (`.local/native-uiautomator.log`): CSV/calendar export readback and hardware-key search. Search accessibility now targets the field instead of the whole list. This does not verify input-method composition across languages. |
| Signed-release native workflows | `scripts/native-release-test.ps1`; independent conditional `:nativeqa` UI Automator test host; actual non-debuggable APK on fresh `emulator-5556` | **2/2 PASS**, 105.8 seconds: `nativePickers` and `nativeExportsAndKeyboard`. Verifies camera/gallery/file selection and local uploads, gallery cancellation, hardware-key customer filtering and CSV/ICS saved-byte readback. [Retained result](evidence/android-release-native-results.txt); original `.local/native-release-uiautomator.log`. |
| Release screenshots/visual review | Four release screenshots below | **CAPTURED**. Keyboard/search and saved-calendar screenshots visually reviewed with no issues found. This is bounded visual evidence, not coverage of every screen or input method. |
| Backend TypeScript | `node node_modules/typescript/bin/tsc -p server/tsconfig.json` from reference source | **PASS**. |
| Backend isolated regressions | Root `npm test` from `reference-web/` | **PASS**: 36 server, 2 client and 3 gateway HTTP tests, including the registration/reset race regression. A bounded independent review found no actionable issue; see the [backend report](../backend-patches/FINISHING-REPORT.md). |
| Real MySQL persistence/authorization | `backend-patches/run-isolated-mysql.ps1` | **14/14 PASS** against fresh MySQL 8.4.13 fixture `ventureplus_test_20261030_084707_465017b6` on loopback port 3309, including both migrations and session revocation. No production connection. |
| Exported backend patch | `node backend-patches/export-local-patch.mjs` | **PASS**: final 560,138-byte patch verified by clean-baseline apply and reverse checks. Includes the final registration/reset fix, AuthSession migration, tests, dependency locks and limited web compatibility fixes. |
| Existing source web + backend build | `npm run build` from `reference-web/` | **PASS**: Vite 6.4.5 and backend TypeScript; final recorded Vite build 39.93 seconds (`backend-patches/verification/build.txt`). Approximately 689 kB minified application chunk advisory remains. |
| Existing source web checks | `npm test`; `npm run typecheck -w client` | **PASS**: 2 limited client tests and client typecheck. This is not full browser workflow coverage. |
| Existing source web lint | `npm run lint -w client` | **FAIL: 66 errors, 30 warnings** remain (`backend-patches/verification/client-lint.txt`). Five narrow web compatibility/type repairs were made; lint rules were not disabled. |
| Backend/gateway lint | `npm run lint:backend` | **PASS**: zero errors and warnings with the added ESLint flat configuration. |
| Dependency audits | Workspace, standalone server, standalone client and gateway `npm audit` | **PASS**: all four report **0 known vulnerabilities**; before/after audit JSON is retained under `backend-patches/`. |
| Whitespace | Scoped `git diff --check`, excluding the exported unified patch | **PASS** for source and documentation. The patch's context-line spaces are checked through clean-baseline apply/reverse verification. |

The backend tests cover authorization, validation, upload restrictions, logging, gateway forwarding and HTTP/SSE/WebSocket session behavior. The server suite injects synthetic persistence and never creates a Prisma connection. The separate real MySQL suite passed 14/14, verifying persisted ownership, independent-session visibility, binary assets, login session storage, copied-token rejection after logout, all-session revocation after password change, administrator reset, nullable profile JSON, successful registration and reset-before-registration-session issuance. The race test forces that ordering without claiming every overlapping lock schedule. See the [backend finishing report](../backend-patches/FINISHING-REPORT.md) and retained verification files for exact scope.

Historical native application cases total **11 passed** on 29 October: 3 connected authentication + 3 offline + 1 process restart + 3 workflows + 1 tablet. The Android integration and screenshot rows above refer to that checkpoint, not a complete rerun of the finishing changes. Framework teardown counters are excluded. The input-method and transient teardown qualifications below remain part of this evidence.

## Local APK and screenshot evidence

The historical 29 October normal-entry-point debug APK remains locally at [artifacts/ventureplus-demo-debug.apk](../artifacts/ventureplus-demo-debug.apk): **206,150,998 bytes**, SHA-256 **0835CB79AC9DCD4B36C540E5F28AB81801BB3A01F321998518BC4937511801D4**. Installation succeeded on the emulator. It predates the finishing changes and is not a signed release or store submission. The binary is ignored by Git; [artifact documentation and installation instructions](../artifacts/README.md) are tracked separately.

The current signed demonstration release is [artifacts/ventureplus-demo-release.apk](../artifacts/ventureplus-demo-release.apk): **57,496,126 bytes**, SHA-256 **DEA8EC66BCD74BA14EBC738371ADD90B84748C555EA848048637F669D263D80D**. The normal `lib/main.dart` build uses the default API and the requested demo prefills. `apksigner` verifies its APK v2 signature; the certificate subject is `CN=VenturePlus Android, O=VenturePlus` and certificate SHA-256 is `47e5ea429fc233fe989404727ff80b890830fb855e28e754479f27c5dac38c5c`. The APK is non-debuggable and includes `arm64-v8a`, `armeabi-v7a` and `x86_64`, with minimum API 24 and target API 36. Installation and launch passed on fresh `VenturePlus_Release_API36` / `emulator-5556`. The pulled installed `base.apk` SHA-256 exactly matches this artifact, and both native cases passed against that installed build.

The private signing identity was created with owner approval. Release configuration requires a private key and does not fall back to the shared Android debug certificate. `-Action release` disables demo prefills; `-Action demo-release` enables the explicitly requested demo values. Private key material is ignored under `.local/signing/`; see [Android release packaging](ANDROID-RELEASE.md) for owner-controlled backup and reproducible commands. No store submission was performed.

| Screenshot | Captured surface |
| --- | --- |
| [android-admin-overview.png](evidence/android-admin-overview.png) | Admin overview on the Android phone emulator |
| [android-employee-overview.png](evidence/android-employee-overview.png) | Employee overview on the Android phone emulator |
| [android-customer-favorites.png](evidence/android-customer-favorites.png) | Customer favorites on the Android phone emulator |
| [android-tablet-overview.png](evidence/android-tablet-overview.png) | Tablet-width overview |
| [android-tablet-inventory.png](evidence/android-tablet-inventory.png) | Historical tablet-width inventory |
| [android-release-gallery-picker.png](evidence/android-release-gallery-picker.png) | Signed release using the native gallery picker |
| [android-release-camera-preview.png](evidence/android-release-camera-preview.png) | Signed release using the native camera preview |
| [android-release-native-keyboard.png](evidence/android-release-native-keyboard.png) | Signed release customer filtering with hardware-key input |
| [android-release-calendar-saved.png](evidence/android-release-calendar-saved.png) | Signed release calendar export saved through the native provider |

The five historical PNGs and four current release PNGs are retained under `docs/evidence/`, together with the [two-case native release result](evidence/android-release-native-results.txt). Both historical tablet screenshots passed visual review with no clipping, overlap or readability blockers. The current keyboard/search and saved-calendar screenshots were also reviewed with no issues found. The native cases validate saved CSV/ICS bytes as well as UI completion. Their independent `:nativeqa` test host is included only with `-PventureplusNativeQa=true`; it adds no test library or debug flag to the production APK. These bounded checks do not establish every native interaction or input method.

The successful existing-web build/test commands require this host-specific SWC cache setting before running from `reference-web/`:

```powershell
$env:SWC_NATIVE_BINDING_CACHE = 'C:\VenturePlus-SWC-01a1875c'
npm run build
npm test
```

The default SWC cache rejected its existing broad Windows ACL. A new private cache owned by the current user was created at the path above; no existing permissions were altered. It is the only new cache outside the workspace. The cache-permission error was an environment issue, not a demonstrated application regression.

## Environment and platform limits

Development host: Windows; Flutter 3.47.8 / Dart 3.13.7. Local Android SDK, emulator, JDK and Gradle caches are under ignored `.local/` folders. The helper selects these tools without committing machine-local paths. Historical native target: Android API 36 x86_64 Pixel 7 emulator `emulator-5554`, using Windows Hypervisor Platform (WHPX); after that checkpoint it was restored to phone size 1080×2400 at density 420 with airplane mode off. The current signed release was installed, launched and verified separately on the fresh `VenturePlus_Release_API36` / `emulator-5556` target.

Native harness history is retained separately from app assertions. The complete offline run passed three cases after fixing screenshot-surface lifecycle handling. A later run using `--keep-app-running` passed those cases but lost its VM Service connection during driver teardown. The earlier restart failure was traced to Flutter Driver's default uninstall behavior in the SDK source (`drive_service.dart`), which erased the fixture. The helper now keeps the app installed. A separate force-stop/relaunch test then passed and independently verified native storage persistence; the transient offline teardown disconnect remains recorded.

The earlier additional native workflow run passed two cases, while the inquiry case was blocked by Android input-method behavior: after the test injected a longer replacement, the field controller was observed reverting to `Short` before validation, so no application write occurred. This is not recorded as a demonstrated product defect. A full inquiry widget regression was added and passed. The final native workflow run passed all three cases. Its inquiry case explicitly registers Flutter's test text-input binding; it still uses the visible form, validation, buttons, success feedback and platform-backed persistence, without directly setting an app controller or repository record. Physical input-method composition remains unverified despite that successful retry.

iOS source and permission descriptions are present. No macOS/Xcode environment was available, so iOS compilation, simulator/device execution, signing, secure-storage behavior, camera/gallery/document interactions and App Store packaging are **UNVERIFIED**. Android release verification does not establish iOS behavior.

Official MySQL 8.4.13 Windows x64 ZIP was downloaded from the [official MySQL download page](https://dev.mysql.com/downloads/mysql/8.4.html?os=3), and the published MD5 `7b94489d5524dea9b27097068bea25a8` matched. The integration runner creates a new workspace datadir and uniquely named `ventureplus_test_*` database, binds only to `127.0.0.1:3309`, disables MySQL X, creates synthetic fixtures and stops its own process. It does not install a service, use an existing database, read production credentials or run repository seed scripts. The original 9/9 run was superseded by **14/14 passed**, including the additive session migration. The server shut down after the run. The first startup attempt exposed a local root-hostname-resolution issue; a fresh corrected run passed.

## Backend changes and deployment gates

The local patch is exported to `backend-patches/ventureplus-authorization.patch`; the source copy under `reference-web/` is ignored. The [backend finishing report](../backend-patches/FINISHING-REPORT.md) and [deployment packet](../backend-patches/DEPLOYMENT-PACKET.md) supersede the earlier backend status in [BACKEND-REPAIRS.md](BACKEND-REPAIRS.md). The patch combines assignment/ownership repairs, validation/upload restrictions, durable session revocation through `AuthSession`, gateway/logging fixes, dependency updates and limited web compatibility repairs. Only the new additive `20261029000000_auth_sessions` migration is proposed; no production schema change, backfill or seed was executed.

Connected ownership and session-revocation acceptance remain blocked until the migration and patch are reviewed, deployed to the target backend and exercised there with authorized accounts. A read-only Vercel team retry on 30 October still returned **403 after the user-approved access grant**; the in-app browser is signed out and scoped deployment access has not been established. The deployment packet defines the remaining account/project and database-baseline preflight. The local app cannot compensate for live server gaps, and local MySQL results apply only to its synthetic database and local server.

Remaining design/security limits:

- Ownership is still legacy text, not durable foreign keys. Ambiguous aliases/headers fail closed and may require admin reconciliation. Employee email changes are now rejected instead of introducing an orphan/reuse path; historical text ownership still requires a reviewed migration.
- Concurrent assignment/ownership changes need stronger transaction/relation guarantees for strict race isolation.
- The local patch revokes the presented session on logout and all user sessions on password changes or administrator resets. It stores a digest of a random JWT identifier and checks persisted revocation on protected requests and realtime sessions. These protections are **not deployed**; legacy stateless tokens require sign-in after rollout.
- Venture photo and layout still share `layoutImage`; separate persistence needs a compatible schema migration.
- Asset URLs retain the source's public policy. Byte signatures and SVG sandboxing are not malware scanning, full file parsing or protected-document authorization.
- Agent connected access and live business mutation/cross-session tests remain unverified. The native connected tests exercise authentication, not live CRUD.
- All four local dependency audits now report 0 known vulnerabilities after the repairs. The earlier 15 workspace and 8 gateway findings are preserved as historical before-update evidence. Existing full web-client lint still reports 66 errors and 30 warnings; the backend/gateway lint and client typecheck pass.

## Launch and demo commands

From the Flutter workspace root:

```powershell
.\scripts\mobile.ps1 -Action run -Device emulator-5554
.\scripts\mobile.ps1 -Action build
.\scripts\mobile.ps1 -Action analyze
.\scripts\mobile.ps1 -Action test
.\scripts\mobile.ps1 -Action offline-test -Device emulator-5554
.\scripts\mobile.ps1 -Action restart-test -Device emulator-5554
.\scripts\mobile.ps1 -Action workflow-test -Device emulator-5554
.\scripts\mobile.ps1 -Action tablet-test -Device emulator-5554
```

Supply `-FlutterPath` for another SDK executable and `-ApiBaseUrl` for an authorized backend. The default API is `https://ventureplus123.vercel.app/api`. For emulator-to-host communication use the host alias `10.0.2.2`, subject to HTTPS/debug network policy; for physical devices configure a reachable host. Do not hardcode a LAN address.

For the separately configured backend, follow [the patch instructions](../backend-patches/README.md). After installing dependencies and setting its `.env` for an approved local/test database:

```powershell
Set-Location reference-web
npm ci
npm run prisma:generate
npm run dev -w server
```

`npm run dev` starts both existing web and server workspaces. These launch commands do not seed or migrate a database. For the disposable local MySQL regression only, run `backend-patches/run-isolated-mysql.ps1` from the Flutter root.

To present all four roles, use **Offline Demo → Explore as …**. Bottom tabs show primary modules; the profile icon opens more authorized screens. Local writes stay local. **Log out / switch account** returns to login. The three connected prefill buttons only fill fields; pressing **Sign in** obtains the server identity. Agent has no invented connected demo credential.

## Checkpoints and exact file manifest

Branch: `codex/flutter-demo`. Earlier implementation checkpoints: `93915f0` (`docs: preserve Flutter demo specifications`), `7efaeec` (`docs: record verified source audit and permission discrepancies`), `8d30efc` (`feat: add verified session and persistent offline data foundation`), `d436c73` (`feat: build native role workflows and tested backend authorization repairs`) and `0d4d07f` (`test: verify Android demo and document delivery evidence`). With explicit user approval, these five commits were pushed to `shajithagrandhe-ctrl/ventureplus-final-app` on 29 October 2026; GitHub's branch head was verified against that checkpoint. The finishing changes are recorded in the signed-demo checkpoint on this branch. No merge or backend deployment was performed; APKs remain local. No live business records, production schema or live API credentials were changed.

The manifest below is the source-deliverable snapshot from tracked files plus non-ignored untracked files. `.local/`, `reference-web/`, APK binaries, build output (including `mobile/android/.kotlin/`), tool caches and ignored private configuration are excluded. The backend patch is the durable deliverable for its ignored source edits. Regenerate after finishing checks add or remove files:

```powershell
git ls-files --cached --others --exclude-standard | Where-Object { $_ -notmatch '^(\.local|reference-web)/|^mobile/android/\.kotlin/' } | Sort-Object -Unique
```

<!-- FILE-MANIFEST-START -->
Source files: 167

~~~text
.gitignore
artifacts/README.md
backend-patches/audit-after-client.json
backend-patches/audit-after-gateway.json
backend-patches/audit-after-server.json
backend-patches/audit-after-workspace.json
backend-patches/audit-before-gateway.json
backend-patches/audit-before-workspace.json
backend-patches/DEPLOYMENT-PACKET.md
backend-patches/export-local-patch.mjs
backend-patches/FINISHING-REPORT.md
backend-patches/README.md
backend-patches/run-isolated-mysql.ps1
backend-patches/ventureplus-authorization.patch
backend-patches/verification/backend-lint.txt
backend-patches/verification/build.txt
backend-patches/verification/client-lint.txt
backend-patches/verification/mysql.txt
backend-patches/verification/patch-export.txt
backend-patches/verification/server-final-tests.txt
backend-patches/verification/tests-sandbox-blocked.txt
backend-patches/verification/tests.txt
DESIGN.md
docs/ANDROID-RELEASE.md
docs/BACKEND-REPAIRS.md
docs/DATA-CONTRACT.md
docs/DELIVERY-REPORT.md
docs/evidence/android-admin-overview.png
docs/evidence/android-customer-favorites.png
docs/evidence/android-employee-overview.png
docs/evidence/android-release-calendar-saved.png
docs/evidence/android-release-camera-preview.png
docs/evidence/android-release-gallery-picker.png
docs/evidence/android-release-native-keyboard.png
docs/evidence/android-release-native-results.txt
docs/evidence/android-tablet-inventory.png
docs/evidence/android-tablet-overview.png
docs/SOURCE-AUDIT.md
GUIDELINES.md
mobile/.gitignore
mobile/.metadata
mobile/analysis_options.yaml
mobile/android/.gitignore
mobile/android/app/build.gradle.kts
mobile/android/app/src/androidTest/java/com/ventureplus/ventureplus/NativeWorkflowTest.java
mobile/android/app/src/debug/AndroidManifest.xml
mobile/android/app/src/main/AndroidManifest.xml
mobile/android/app/src/main/kotlin/com/ventureplus/ventureplus/MainActivity.kt
mobile/android/app/src/main/res/drawable-v21/launch_background.xml
mobile/android/app/src/main/res/drawable-xhdpi/ventureplus_logo.png
mobile/android/app/src/main/res/drawable/launch_background.xml
mobile/android/app/src/main/res/mipmap-hdpi/ic_launcher.png
mobile/android/app/src/main/res/mipmap-mdpi/ic_launcher.png
mobile/android/app/src/main/res/mipmap-xhdpi/ic_launcher.png
mobile/android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png
mobile/android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png
mobile/android/app/src/main/res/values-night/styles.xml
mobile/android/app/src/main/res/values-v31/styles.xml
mobile/android/app/src/main/res/values/styles.xml
mobile/android/app/src/profile/AndroidManifest.xml
mobile/android/build.gradle.kts
mobile/android/gradle.properties
mobile/android/gradle/wrapper/gradle-wrapper.properties
mobile/android/nativeqa/build.gradle.kts
mobile/android/nativeqa/src/main/AndroidManifest.xml
mobile/android/settings.gradle.kts
mobile/assets/brand/ventureplus.png
mobile/integration_test/demo_test.dart
mobile/integration_test/responsive_test.dart
mobile/integration_test/restart_test.dart
mobile/integration_test/workflows_test.dart
mobile/ios/.gitignore
mobile/ios/Flutter/AppFrameworkInfo.plist
mobile/ios/Flutter/Debug.xcconfig
mobile/ios/Flutter/Release.xcconfig
mobile/ios/Runner.xcodeproj/project.pbxproj
mobile/ios/Runner.xcodeproj/project.xcworkspace/contents.xcworkspacedata
mobile/ios/Runner.xcodeproj/project.xcworkspace/xcshareddata/IDEWorkspaceChecks.plist
mobile/ios/Runner.xcodeproj/project.xcworkspace/xcshareddata/WorkspaceSettings.xcsettings
mobile/ios/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme
mobile/ios/Runner.xcworkspace/contents.xcworkspacedata
mobile/ios/Runner.xcworkspace/xcshareddata/IDEWorkspaceChecks.plist
mobile/ios/Runner.xcworkspace/xcshareddata/WorkspaceSettings.xcsettings
mobile/ios/Runner/AppDelegate.swift
mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json
mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png
mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@1x.png
mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@2x.png
mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@3x.png
mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@1x.png
mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@2x.png
mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@3x.png
mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@1x.png
mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@2x.png
mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@3x.png
mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@2x.png
mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@3x.png
mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@1x.png
mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@2x.png
mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-83.5x83.5@2x.png
mobile/ios/Runner/Assets.xcassets/LaunchImage.imageset/Contents.json
mobile/ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage.png
mobile/ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage@2x.png
mobile/ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage@3x.png
mobile/ios/Runner/Assets.xcassets/LaunchImage.imageset/README.md
mobile/ios/Runner/Base.lproj/LaunchScreen.storyboard
mobile/ios/Runner/Base.lproj/Main.storyboard
mobile/ios/Runner/Info.plist
mobile/ios/Runner/Runner-Bridging-Header.h
mobile/ios/Runner/SceneDelegate.swift
mobile/ios/RunnerTests/RunnerTests.swift
mobile/lib/app.dart
mobile/lib/core/app_controller.dart
mobile/lib/core/demo_prefills.dart
mobile/lib/core/models.dart
mobile/lib/core/permissions.dart
mobile/lib/data/api_transport.dart
mobile/lib/data/connected_repository.dart
mobile/lib/data/demo_data.dart
mobile/lib/data/offline_repository.dart
mobile/lib/data/repository.dart
mobile/lib/data/storage.dart
mobile/lib/data/transport_adapter_web.dart
mobile/lib/data/transport_adapter.dart
mobile/lib/features/auth/login_page.dart
mobile/lib/features/dashboard/dashboard.dart
mobile/lib/features/shell/shell.dart
mobile/lib/features/workflows/employee_otp.dart
mobile/lib/features/workflows/forms.dart
mobile/lib/features/workflows/layout_canvas.dart
mobile/lib/features/workflows/layout_detection.dart
mobile/lib/features/workflows/layout_editor.dart
mobile/lib/features/workflows/layout_image.dart
mobile/lib/features/workflows/photo_recovery.dart
mobile/lib/features/workflows/picker_recovery_host.dart
mobile/lib/features/workflows/record_detail.dart
mobile/lib/features/workflows/resource_forms.dart
mobile/lib/features/workflows/venture_detail.dart
mobile/lib/features/workflows/workflow_exports.dart
mobile/lib/features/workflows/workflow_page.dart
mobile/lib/main.dart
mobile/lib/ui/components.dart
mobile/lib/ui/theme.dart
mobile/pubspec.lock
mobile/pubspec.yaml
mobile/README.md
mobile/test_driver/integration_test.dart
mobile/test/app_widget_test.dart
mobile/test/core_data_test.dart
mobile/test/core_transport_test.dart
mobile/test/session_finish_test.dart
mobile/test/workflow_forms_test.dart
mobile/test/workflow_photo_recovery_test.dart
mobile/web/favicon.png
mobile/web/icons/Icon-192.png
mobile/web/icons/Icon-512.png
mobile/web/icons/Icon-maskable-192.png
mobile/web/icons/Icon-maskable-512.png
mobile/web/index.html
mobile/web/manifest.json
PRODUCT.md
README.md
scripts/create-android-signing-key.ps1
scripts/mobile.ps1
scripts/native-android-test.ps1
scripts/native-release-test.ps1
scripts/probe-demo-auth.mjs
~~~
<!-- FILE-MANIFEST-END -->
