# Android demo APK

The current local deliverable is `ventureplus-demo-release.apk`, built on 30 October 2026 from the normal `mobile/lib/main.dart` entry point. This is an optimized, privately signed demonstration APK with the requested demo credential-prefill buttons enabled and API `https://ventureplus123.vercel.app/api`.

- File size: 57,496,126 bytes (54.83 MiB).
- SHA-256: `DEA8EC66BCD74BA14EBC738371ADD90B84748C555EA848048637F669D263D80D`.
- APK v2 signature verified; certificate SHA-256: `47e5ea429fc233fe989404727ff80b890830fb855e28e754479f27c5dac38c5c`.
- Package: `com.ventureplus.ventureplus`, version 1.0.0 (1), minimum Android 7 / API 24, target API 36.
- CPU support: arm64-v8a, armeabi-v7a and x86_64. The release is not debuggable.
- Built with Flutter 3.47.8 / Dart 3.13.7 using `scripts/mobile.ps1 -Action demo-release`.

The APK is ignored by Git. Installation and launch passed on a new Android API 36 emulator. Its installed hash matched this artifact, and both native workflow cases passed in 105.8 seconds; see the [delivery report](../docs/DELIVERY-REPORT.md). To install on an Android device with Android platform tools:

```powershell
adb install artifacts/ventureplus-demo-release.apk
```

An existing debug build has a different certificate and cannot be upgraded in place. Preserve needed local demo data before removing it; uninstalling deletes its data. A new installation or separate test device avoids that conflict.

Open **Offline Demo** to explore fictional Admin, Employee, Customer and Agent sessions. Local edits stay on the device. Connected prefill buttons only fill fields; pressing **Sign in** sends credentials to the configured API, and the server determines the role. The backend repair patch has not been deployed; signing the APK does not certify live backend readiness.

The earlier `ventureplus-demo-debug.apk` is retained as a historical artifact (206,150,998 bytes; SHA-256 `0835CB79AC9DCD4B36C540E5F28AB81801BB3A01F321998518BC4937511801D4`). Use the release APK above for the current demonstration.

Retain a secure owner-controlled backup of the entire private `.local/signing/` directory. It is excluded from Git and APKs; losing its key prevents future APK updates. See [Android signing and release instructions](../docs/ANDROID-RELEASE.md).
