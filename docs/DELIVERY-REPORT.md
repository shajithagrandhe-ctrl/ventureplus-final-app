# VenturePlus delivery report

Delivery snapshot: 29 October 2026. The final 52-test Flutter suite, 11 native Android cases, normal Android debug build/install, analyzer, formatting, whitespace, tablet visual review and isolated MySQL validation have passed. The five native screenshots and exact source manifest are included below. The backend deployment gate and platform limits remain explicit; this is not a production-readiness claim. These results supersede early environment limitations recorded in the original audit checkpoint.

## Built and scoped

The implementation is a native Flutter/Dart app in `mobile/`, with Android and iOS project scaffolding, the original Venture Plus logo, centralized light-theme tokens, reusable loading/error/empty states, role-aware bottom navigation and a secondary profile menu. It preserves the source hierarchy Location → Venture → Plot. Forms, layout editing, favorites, inquiries, customer/lead records, tracking, staff access and exports use a shared repository boundary.

| Role | Implemented mobile surfaces and actions | Evidence limits |
| --- | --- | --- |
| Admin | Overview metrics, inventory hierarchy, new venture form, plot details/status, layout geometry/regions, layout/photo selection and upload, lead create/edit/delete, customer-record CRUD, customer provisioning, staff create/edit/assign/freeze/reactivate and demo OTP, employee/admin/customer/agent directories, tracking, favorites/inquiries, profile/password/logout. | Source-backed contract and local automated coverage. Native auth verified. Live business writes and cross-user business persistence have not been exercised on the deployed service. |
| Employee | Overview, assigned inventory, plot updates, scoped leads, own customer records, customer accounts/provisioning, tracking updates, authorized directories, favorites/inquiries and profile controls. Admin layout/upload/access actions are not granted. | Native auth verified; local ownership tests pass. Deployed assignment/ownership enforcement depends on the backend patch. |
| Customer | Home, signed-in My properties, linked plot details, own records/tracking, favorites, inquiry submission and profile controls. | Native auth verified; local isolation and form/navigation coverage. Live private-data isolation remains a deployment gate. |
| Agent | Distinct Overview, inventory, lead/customer reads, tracking writes, favorites/inquiries and profile controls. | **VERIFIED-SOURCE** active role with meaningful permissions, implemented separately. No Agent credentials were supplied or tested live. Offline fictional Agent is implemented. |

Shared workflows include explicit login prefills, server-identity routing, logout/account switching, safe session expiry, pull-to-refresh, validated forms, confirmation for destructive actions, CSV export and follow-up calendar export, and supported single-file upload selection through camera/gallery/files. Native picker behavior still needs the checks noted below. OTP remains the source's demo flow; it is not a claim of real SMS/email delivery.

No generic document storage, inquiry-management dashboard/API, standalone location CRUD, venture delete, plot create/delete, payments or push notifications were invented. Customer browsing is My properties, not a public unfiltered catalogue. Tracking does not fabricate random positions or hardcoded performance metrics.

## Connected and offline behavior

Connected mode uses the real API, cookies/CSRF and a fresh `/auth/me` identity. Native cookies use secure storage scoped to the configured API base; passwords and connected response data are not stored in ordinary preferences. Unsafe writes are not automatically replayed. Client requests only report success after the server succeeds.

Offline Demo is a separate repository with fictional records, explicit local role entry and persistent local edits. Its banner says changes stay on the device. It performs no backend writes and cannot silently take over after a connected error. There is no pending-sync queue. Offline password changes are unavailable. Role/ownership rules are also checked locally, but local checks do not prove deployed server security.

The three supplied demo credential pairs were tested after explicit user authorization. Login and `/auth/me` returned 200 for ADMIN, EMPLOYEE and CUSTOMER. The Admin web dashboard/navigation was observed. Native Android integration now also verifies all three roles' identity, secure-session restoration and logout. Credentials are not repeated in this report; the isolated prefill configuration retains the requested values and remains demo-only.

## Verification evidence

| Check | Exact command / scope | Result at this snapshot |
| --- | --- | --- |
| Flutter dependency resolution | `flutter pub get` from `mobile/` | Completed during setup. |
| Flutter formatting/analyzer | `dart format lib test integration_test test_driver`; `scripts/mobile.ps1 -Action analyze` | **PASS**: final format check found 39 files and 0 changes; final analyzer reports no issues in 8.8 seconds (`.local/flutter-analyze-final.log`). |
| Flutter unit/widget suite | `scripts/mobile.ps1 -Action test` | **52/52 passed** in the final full rerun (`.local/flutter-tests.log`), including the added inquiry regression. |
| Inquiry widget regression | Targeted full inquiry flow in `mobile/test/workflow_forms_test.dart` | **PASS**, including validation, visible success feedback and local persistence. This does not verify physical Android input-method composition. |
| Android debug APK | `scripts/mobile.ps1 -Action build` | **PASS**: final normal `lib/main.dart` debug build, 83.1 seconds (`.local/android-final-build.log`). Copied to `artifacts/ventureplus-demo-debug.apk`; checksum below. |
| Final APK installation | `adb install -r artifacts/ventureplus-demo-debug.apk` | **PASS** on `emulator-5554`. |
| Android connected auth | `scripts/mobile.ps1 -Action live-auth-test -Device emulator-5554` | **3 role cases passed**: Admin, Employee, Customer; framework reports +4 including tearDownAll. Each tests `/me` identity, secure restoration and logout. |
| Android airplane-mode offline flow | `scripts/mobile.ps1 -Action offline-test -Device emulator-5554` with airplane mode on and Wi-Fi/data disabled | **3/3 passed** in a completed run after the screenshot lifecycle fix. A later keep-app-running rerun passed the three cases but hit a VM Service disconnect during driver teardown; that rerun is not counted as a clean command pass. |
| Android process restart | `scripts/mobile.ps1 -Action restart-test -Device emulator-5554` after offline fixture creation | **1/1 passed** after actual process force-stop and relaunch: Employee session and the newly created fictional record persisted (`.local/native-restart-tests.log`). |
| Additional Android workflows | `scripts/mobile.ps1 -Action workflow-test -Device emulator-5554` | **3/3 cases passed** (`.local/native-workflow-tests.log`; framework +4 includes tearDownAll). Inquiry uses Flutter's test text-input binding after the earlier Android input-method interference; physical composition remains unverified. |
| Android tablet/responsive integration | `scripts/mobile.ps1 -Action tablet-test -Device emulator-5554` | **1/1 passed** (`.local/native-tablet-tests.log`; framework +2 includes tearDownAll). |
| Android screenshots/visual checks | Five phone/tablet PNGs listed below | **CAPTURED**; both tablet screenshots passed visual review with no clipping, overlap or readability blockers. Widget checks cover 360/1024 widths, large text and reduced motion, not every native interaction. |
| Native platform pickers | Camera/gallery/document-provider interactions | **UNVERIFIED**. Computer-use capture could not address the emulator window outside the captured monitor; integration screenshots worked. This evidence-collection limitation is not a demonstrated product defect. Implemented picker code and upload validation do not establish platform-provider interaction. |
| Backend TypeScript | `node node_modules/typescript/bin/tsc -p server/tsconfig.json` from reference source | **PASS**. |
| Backend isolated route regressions | `node --test server/tests/authorization.test.cjs server/tests/mongo-mysql-record.test.mjs` | **28/28 passed**: 24 new HTTP/validation/SSE/WebSocket cases with injected persistence, plus 4 existing record-conversion cases. |
| Real MySQL persistence/authorization | `backend-patches/run-isolated-mysql.ps1` | **9/9 PASS** against fresh MySQL 8.4.13 database `ventureplus_test_20261029_175933_3a4558cd` on loopback port 3309. No production connection. |
| Exported backend patch | `node backend-patches/export-local-patch.mjs` | Reverse and clean-baseline apply checks passed; final exported patch includes the MySQL suite. |
| Existing source web + backend build | `npm run build` from `reference-web/` | **PASS**; Vite build and backend TypeScript completed (`.local/web-build.log`). Large-bundle advisory remains. |
| Existing source web test | `npm test` from reference source | **1/1 passed** (`.local/web-tests.log`). This is a small existing test, not full web workflow coverage. |
| Existing source web lint | `npm run lint -w client` | **FAIL: 66 errors, 30 warnings** in upstream client code (`.local/web-lint.log`). Client source was not changed. |
| Backend lint | `npm run lint -w server` | **BLOCKED/FAIL**: ESLint 9 cannot find an `eslint.config.*` file (`.local/backend-lint.log`). No lint pass is claimed. |
| Whitespace | `git diff --check` in changed source | **PASS** in the final workspace check. |

The mocked backend suite includes success, anonymous rejection, wrong-role rejection, assignment/owner isolation, shared-plot nested lead filtering, exact structured-email matching, free-text ownership injection/transfer/erase denial, staff email immutability, freeze invalidation, scoped favorites/statistics, validation, upload limits/type checks and actual local SSE/WebSocket session behavior. It never creates a Prisma connection. The separate real MySQL suite passed 9/9, verifying persisted HTTP create/update/delete, visibility from another authorized session and independent Prisma client, actual relation-filter denials, binary asset persistence and access removal.

Native application cases total **11 passed**: 3 connected authentication + 3 offline + 1 process restart + 3 workflows + 1 tablet. Framework teardown counters are excluded. These totals preserve the input-method and transient teardown qualifications below.

## Local APK and screenshot evidence

The final normal-entry-point debug APK is available locally at [artifacts/ventureplus-demo-debug.apk](../artifacts/ventureplus-demo-debug.apk): **206,150,998 bytes**, SHA-256 **0835CB79AC9DCD4B36C540E5F28AB81801BB3A01F321998518BC4937511801D4**. Installation succeeded on the emulator. The binary is ignored by Git; [artifact documentation and installation instructions](../artifacts/README.md) are tracked separately. This is not a signed release or store submission.

| Screenshot | Captured surface |
| --- | --- |
| [android-admin-overview.png](evidence/android-admin-overview.png) | Admin overview on the Android phone emulator |
| [android-employee-overview.png](evidence/android-employee-overview.png) | Employee overview on the Android phone emulator |
| [android-customer-favorites.png](evidence/android-customer-favorites.png) | Customer favorites on the Android phone emulator |
| [android-tablet-overview.png](evidence/android-tablet-overview.png) | Tablet-width overview |
| [android-tablet-inventory.png](evidence/android-tablet-inventory.png) | Tablet-width inventory |

All five PNGs are present under `docs/evidence/`. Both tablet screenshots passed visual review with no clipping, overlap or readability blockers. This bounded review and the automated checks do not establish every native interaction or platform-provider behavior.

The successful existing-web build/test commands require this host-specific SWC cache setting before running from `reference-web/`:

```powershell
$env:SWC_NATIVE_BINDING_CACHE = 'C:\VenturePlus-SWC-01a1875c'
npm run build
npm test
```

The default SWC cache rejected its existing broad Windows ACL. A new private cache owned by the current user was created at the path above; no existing permissions were altered. It is the only new cache outside the workspace. The cache-permission error was an environment issue, not a demonstrated application regression.

## Environment and platform limits

Development host: Windows; Flutter 3.47.8 / Dart 3.13.7. Local Android SDK, emulator, JDK and Gradle caches are under ignored `.local/` folders. The helper selects these tools without committing machine-local paths. Native target: Android API 36 x86_64 Pixel 7 emulator, device `emulator-5554`, using Windows Hypervisor Platform (WHPX). After verification, the emulator was restored to phone size 1080×2400 at density 420, and airplane mode was confirmed off.

Native harness history is retained separately from app assertions. The complete offline run passed three cases after fixing screenshot-surface lifecycle handling. A later run using `--keep-app-running` passed those cases but lost its VM Service connection during driver teardown. The earlier restart failure was traced to Flutter Driver's default uninstall behavior in the SDK source (`drive_service.dart`), which erased the fixture. The helper now keeps the app installed. A separate force-stop/relaunch test then passed and independently verified native storage persistence; the transient offline teardown disconnect remains recorded.

The earlier additional native workflow run passed two cases, while the inquiry case was blocked by Android input-method behavior: after the test injected a longer replacement, the field controller was observed reverting to `Short` before validation, so no application write occurred. This is not recorded as a demonstrated product defect. A full inquiry widget regression was added and passed. The final native workflow run passed all three cases. Its inquiry case explicitly registers Flutter's test text-input binding; it still uses the visible form, validation, buttons, success feedback and platform-backed persistence, without directly setting an app controller or repository record. Physical input-method composition remains unverified despite that successful retry.

iOS source and permission descriptions are present. No macOS/Xcode environment was available, so iOS compilation, simulator/device execution, signing, secure-storage behavior, camera/gallery/document interactions and App Store packaging are **UNVERIFIED**. Android debug success is not an iOS result or a signed release result.

Official MySQL 8.4.13 Windows x64 ZIP was downloaded from the [official MySQL download page](https://dev.mysql.com/downloads/mysql/8.4.html?os=3), and the published MD5 `7b94489d5524dea9b27097068bea25a8` matched. The integration runner creates a new workspace datadir and uniquely named `ventureplus_test_*` database, binds only to `127.0.0.1:3309`, disables MySQL X, creates synthetic fixtures and stops its own process. It does not install a service, use an existing database, read production credentials or run repository seed scripts. Final result: **9/9 passed**. The server shut down after the run. The first startup attempt exposed a local root-hostname-resolution issue; a fresh corrected run passed.

## Backend changes and deployment gates

The reviewed patch is exported to `backend-patches/ventureplus-authorization.patch`; the source copy under `reference-web/` is ignored. See [BACKEND-REPAIRS.md](BACKEND-REPAIRS.md) for exact remedies and residual constraints. Main changes: shared assignment/record access predicates, customer nested lead filtering, exact legacy ownership, protected free-text ownership headers, scoped favorites/statistics/tracking, current user/frozen-session checks, non-admin realtime invalidations, employee target-role/email checks, bounded regions/coordinates and upload signature/size/SVG handling.

Connected ownership acceptance is blocked until the patch is reviewed and deployed to the target backend and exercised there with authorized accounts. The local app cannot compensate for the live source's identified gaps. The local MySQL suite verifies only its synthetic database and local server when it passes.

Remaining design/security limits:

- Ownership is still legacy text, not durable foreign keys. Ambiguous aliases/headers fail closed and may require admin reconciliation. Employee email changes are now rejected instead of introducing an orphan/reuse path; historical text ownership still requires a reviewed migration.
- Concurrent assignment/ownership changes need stronger transaction/relation guarantees for strict race isolation.
- Password changes and logout do not revoke copied JWTs server-side. Frozen/relieved/deleted users and current roles are rechecked by the patch.
- Venture photo and layout still share `layoutImage`; separate persistence needs a compatible schema migration.
- Asset URLs retain the source's public policy. Byte signatures and SVG sandboxing are not malware scanning, full file parsing or protected-document authorization.
- Agent connected access and live business mutation/cross-session tests remain unverified. The native connected tests exercise authentication, not live CRUD.
- Existing dependency/lint findings remain: the reference root dependency audit reported **15 findings: 4 critical, 3 high, 7 moderate, 1 low**; the separate gateway install reported **8 findings**. These are recorded audit findings, not a new clean audit or fixes. Production deployment requires dependency triage and rerunning the relevant audits.

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

Local branch: `codex/flutter-demo`. Saved implementation checkpoints: `93915f0` (`docs: preserve Flutter demo specifications`), `7efaeec` (`docs: record verified source audit and permission discrepancies`), `8d30efc` (`feat: add verified session and persistent offline data foundation`) and `d436c73` (`feat: build native role workflows and tested backend authorization repairs`). Identify the final verification checkpoint with `git log -1 --oneline`; its own hash is not embedded recursively in this report. Nothing has been pushed, merged or deployed. No live business records, production schema or credentials were changed.

The manifest below is the final source-deliverable snapshot from tracked files plus non-ignored untracked files, including the five native screenshots and artifact README. `.local/`, `reference-web/`, the APK binary, build output, tool caches and ignored private configuration are excluded. The backend patch is the durable deliverable for its ignored source edits. Regenerate for any later changes:

```powershell
git ls-files --cached --others --exclude-standard | Where-Object { $_ -notmatch '^(\.local|reference-web)/' } | Sort-Object -Unique
```

<!-- FILE-MANIFEST-START -->
Source files: 135

~~~text
.gitignore
artifacts/README.md
backend-patches/export-local-patch.mjs
backend-patches/README.md
backend-patches/run-isolated-mysql.ps1
backend-patches/ventureplus-authorization.patch
DESIGN.md
docs/BACKEND-REPAIRS.md
docs/DATA-CONTRACT.md
docs/DELIVERY-REPORT.md
docs/evidence/android-admin-overview.png
docs/evidence/android-customer-favorites.png
docs/evidence/android-employee-overview.png
docs/evidence/android-tablet-inventory.png
docs/evidence/android-tablet-overview.png
docs/SOURCE-AUDIT.md
GUIDELINES.md
mobile/.gitignore
mobile/.metadata
mobile/analysis_options.yaml
mobile/android/.gitignore
mobile/android/app/build.gradle.kts
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
mobile/test/workflow_forms_test.dart
mobile/web/favicon.png
mobile/web/icons/Icon-192.png
mobile/web/icons/Icon-512.png
mobile/web/icons/Icon-maskable-192.png
mobile/web/icons/Icon-maskable-512.png
mobile/web/index.html
mobile/web/manifest.json
PRODUCT.md
README.md
scripts/mobile.ps1
scripts/probe-demo-auth.mjs
~~~
<!-- FILE-MANIFEST-END -->
