# VenturePlus mobile

This directory contains the native Flutter app for Admin, Employee, Customer and Agent. See the [root README](../README.md) for role modules, connected/offline behavior, Android setup and demo steps, and the [delivery report](../docs/DELIVERY-REPORT.md) for exact test evidence and remaining platform/security limits.

Use Flutter 3.47.8 / Dart 3.13.7 or a compatible SDK. From this directory:

~~~powershell
flutter pub get
..\scripts\mobile.ps1 -Action run -Device emulator-5554
..\scripts\mobile.ps1 -Action analyze
..\scripts\mobile.ps1 -Action test
..\scripts\mobile.ps1 -Action build
~~~

Pass -FlutterPath if Flutter is not on PATH or in the helper's default installation, and -ApiBaseUrl for an authorized test backend. The default API is https://ventureplus123.vercel.app/api.

Choose **Offline Demo** at login for fictional local data and all four roles. Connected prefill buttons only fill the form; **Sign in** verifies server identity. Changes made offline never sync automatically. The [backend patch](../backend-patches/README.md) remains a separate undeployed deliverable, so live ownership acceptance is not implied by local UI tests.

The current Flutter unit/widget suite passes **72/72** and the analyzer reports no issues. Finishing changes recover interrupted photo selections for the original account/API/mode and venture, retain review after restart or Back, enforce a 4 MiB file limit, preserve confirmed API success when cookie storage fails, and return to sign-in after a successful password change. Calendar escaping and offline provisioning password validation are also covered.

The historical 29 October normal-entry-point debug APK remains locally at [../artifacts/ventureplus-demo-debug.apk](../artifacts/ventureplus-demo-debug.apk). It installed on the emulator and is ignored by Git, but predates the finishing changes. Eleven native Android cases passed at that earlier checkpoint on an API 36 x86_64 Pixel 7 emulator with WHPX, including tablet-width coverage; these cases have not been rerun as a complete suite for the finishing changes. See [artifact installation details](../artifacts/README.md) and the delivery report for the historical checksum, screenshots and input-method/teardown qualifications.

The current signed demonstration APK is [../artifacts/ventureplus-demo-release.apk](../artifacts/ventureplus-demo-release.apk) (**57,496,126 bytes**; SHA-256 `DEA8EC66BCD74BA14EBC738371ADD90B84748C555EA848048637F669D263D80D`). The owner-approved private key signs the non-debuggable build, and APK v2 signature verification passes. Installation and launch passed on fresh `emulator-5556`; the installed APK checksum exactly matches this artifact. This build uses `lib/main.dart`, the default API and the requested demo prefills. Use `-Action release` for an optimized build without prefills, or `-Action demo-release` for the demo variant, following [Android release packaging](../docs/ANDROID-RELEASE.md).

The actual non-debuggable signed APK passed **2/2 native cases in 105.8 seconds** on the fresh `VenturePlus_Release_API36` emulator: camera/gallery/file selection and local uploads, gallery cancellation, hardware-key customer filtering, and CSV/calendar saved-byte readback. An independent, conditionally included `:nativeqa` test host operates the installed app through UI Automator; no test libraries or debug flag were added to the production APK. See the [retained result](../docs/evidence/android-release-native-results.txt) and [delivery report](../docs/DELIVERY-REPORT.md) for screenshots. Hardware-key coverage does not establish physical input-method composition across languages; the historical inquiry integration case uses Flutter's test text-input binding. iOS/Xcode execution and signing remain unverified. The local backend migration and code remain undeployed; see the [deployment packet](../backend-patches/DEPLOYMENT-PACKET.md).
