# VenturePlus Flutter demo

A Flutter/Dart mobile app based on the existing VenturePlus website, with separate Admin, Employee, Customer and Agent experiences. The interface uses the original logo and the light sage, walnut and amber system in [DESIGN.md](DESIGN.md). The app lives in `mobile/`; it is not a WebView.

The final Android debug APK was built from `lib/main.dart`, and all 52 Flutter unit/widget tests pass. Eleven native Android cases passed: three connected authentication cases, three airplane-mode offline cases, one force-stop/relaunch persistence case, three additional workflows and one tablet check. The inquiry case used Flutter's test text-input binding; physical input-method composition and the earlier driver-teardown limitation remain documented in the [delivery report](docs/DELIVERY-REPORT.md). Native camera/gallery/document-provider interactions and iOS/Xcode execution remain unverified.

The local APK is [artifacts/ventureplus-demo-debug.apk](artifacts/ventureplus-demo-debug.apk) (206,150,998 bytes). It installed successfully on the Android emulator. It is a debug demonstration build and is excluded from Git. Its SHA-256 is `0835CB79AC9DCD4B36C540E5F28AB81801BB3A01F321998518BC4937511801D4`. See [artifact installation details](artifacts/README.md) and the [delivery report](docs/DELIVERY-REPORT.md) for the five native screenshots, completed local checks and remaining verification limits.

## Modes and roles

**Connected** uses the configured backend, cookie/CSRF authentication and `/auth/me` identity. Successful API writes are server writes. Client-side controls do not repair the deployed server's audited authorization gaps: the [local backend patch](backend-patches/README.md) must be reviewed, deployed and reverified before connected ownership acceptance can be claimed.

**Offline Demo** uses fictional local data, displays a persistent mode banner and saves changes only on this device. It never silently replaces failed connected requests with sample data and has no synchronization queue. Offline passwords are unavailable; demo OTP is explicitly a local demonstration.

| Role | Modules |
| --- | --- |
| Admin | Dashboard; inventory; ventures, plot details and layout editor; image/layout uploads; leads and reports; customer records/accounts; employee access, assignments and status; tracking; directories; favorites/inquiries; profile/password/logout. |
| Employee | Dashboard; assigned inventory; permitted plot/lead updates; own customer records; customer provisioning; tracking; authorized directories; favorites/inquiries; profile/password/logout. |
| Customer | Home; My properties; own records and tracking; favorites and inquiries; profile/password/logout. |
| Agent | Separate source-verified role with broad inventory/lead/customer reads and tracking writes; favorites/inquiries; profile/password/logout. No Employee-only mutations. Offline Agent is available; no connected Agent credentials were supplied. |

Unsupported source actions were not invented: there is no generic document store, inquiry management endpoint, independent location CRUD, venture deletion, plot create/delete, payment or push integration. The backend currently stores venture photo and layout in the same field.

## Run on Android

Use Flutter 3.47.8 / Dart 3.13.7 or a compatible SDK, an Android SDK/JDK and a running emulator or attached device. On this workstation the helper detects the Flutter installation under `Downloads/flutter/flutter/` and project-local tools under `.local/`. These SDK downloads are not source deliverables.

From the repository root in PowerShell:

```powershell
Push-Location mobile
flutter pub get
Pop-Location
.\scripts\mobile.ps1 -Action run -Device emulator-5554
```

If Flutter is not on PATH, supply its executable to the helper:

```powershell
.\scripts\mobile.ps1 -Action run -FlutterPath "$env:USERPROFILE\Downloads\flutter\flutter\bin\flutter.bat" -Device emulator-5554
```

The default API is `https://ventureplus123.vercel.app/api`. Use `-ApiBaseUrl 'https://your-authorized-test-host/api'` for another backend. For Android emulator host networking, `10.0.2.2` refers to the Windows host; `localhost` refers to the emulator. Use a reachable HTTPS development endpoint unless an explicitly scoped debug cleartext policy is configured. A physical device needs a reachable host address; no developer LAN address is hardcoded.

```powershell
.\scripts\mobile.ps1 -Action build
.\scripts\mobile.ps1 -Action analyze
.\scripts\mobile.ps1 -Action test
.\scripts\mobile.ps1 -Action offline-test -Device emulator-5554
.\scripts\mobile.ps1 -Action restart-test -Device emulator-5554
.\scripts\mobile.ps1 -Action workflow-test -Device emulator-5554
.\scripts\mobile.ps1 -Action tablet-test -Device emulator-5554
```

`restart-test` expects the prior offline integration flow to have created its fictional record. Integration actions use `--keep-app-running` so Flutter Driver does not uninstall the app and erase that fixture between runs. The native test environment is an Android API 36 x86_64 Pixel 7 emulator using Windows Hypervisor Platform (WHPX). The explicitly networked authentication suite is `-Action live-auth-test`; it sends the configured supplied demo pairs to the configured API and was authorized for this task. It performs authentication/session checks, not live business mutations.

The helper enables the isolated demo-prefill configuration for demonstration builds. Prefill buttons only fill fields; **Sign in** performs authentication. Normal release builds disable prefills unless `ENABLE_DEMO_PREFILLS=true` is deliberately supplied. No Agent prefill is invented.

## Demo walkthrough

1. Open **Offline Demo**, then **Explore as Admin**, **Employee**, **Customer** or **Agent**. The banner identifies fictional local data.
2. Use the four role-specific bottom destinations. The profile icon opens additional authorized screens.
3. Try a local customer-record edit or favorite. Feedback states local-only persistence.
4. Use **Log out / switch account** in the profile menu to return to login and choose another role.
5. For an authorized connected demonstration, select one of the three prefill buttons, then explicitly press **Sign in**. The server identity determines the role.

## Backend setup and evidence

The existing backend remains a separate repository. The ignored local reference checkout is pinned to `3c24df131699c71fac4e500f0e1c531eeab519d2`. Apply/review the exported changes using [backend-patches/README.md](backend-patches/README.md); its tests can run without MySQL. The isolated MySQL runner creates only a fresh local fixture database and is documented separately in the delivery report.

After configuring the backend's environment for an authorized local/test database, its normal commands are:

```powershell
Set-Location reference-web
npm ci
npm run prisma:generate
npm run dev -w server
```

The source server loads its local `.env`; set the required MySQL URL, JWT secret and CORS/cookie settings from its `.env.example`. Do not point setup or test scripts at production. No migration or seed is part of the launch command above. `npm run dev` starts the source web frontend and backend together.

On the verified Windows host, reproducing the existing web build/tests requires the new private SWC cache created for this task:

```powershell
$env:SWC_NATIVE_BINDING_CACHE = 'C:\VenturePlus-SWC-01a1875c'
npm run build
npm test
```

Run those commands from `reference-web/`. The default cache rejected its existing broad Windows ACL; a new cache owned by the current user was created instead of changing existing permissions. This host-specific cache is the only newly created cache outside the workspace and is not a source deliverable. Other hosts should use a suitable private cache when the default is rejected.

Further documentation: [requirements/audit checkpoint](GUIDELINES.md), [source audit](docs/SOURCE-AUDIT.md), [data contract](docs/DATA-CONTRACT.md), [backend repairs](docs/BACKEND-REPAIRS.md), and [delivery status and exact manifest](docs/DELIVERY-REPORT.md). Nothing has been pushed or deployed by this implementation task.
