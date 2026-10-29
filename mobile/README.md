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

The final normal-entry-point Android debug APK is available locally at [../artifacts/ventureplus-demo-debug.apk](../artifacts/ventureplus-demo-debug.apk), installed successfully on the emulator, and is ignored by Git. The full Flutter unit/widget suite passed 52/52 and 11 native Android cases passed on an API 36 x86_64 Pixel 7 emulator with WHPX on Windows, including tablet-width coverage. See [artifact installation details](../artifacts/README.md) and the delivery report for the APK checksum, five screenshots, completed checks, and input-method/teardown qualifications.

iOS source is included, but Xcode/iOS execution and native camera/gallery/document-provider interactions remain unverified. Physical Android input-method composition is also unverified; the inquiry integration case uses Flutter's test text-input binding while retaining its UI and persistence assertions.
