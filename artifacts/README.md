# Android demo artifact

The final local demo is `ventureplus-demo-debug.apk`, built on 29 October 2026 from the normal `mobile/lib/main.dart` entry point. It is a universal **debug** APK with the requested demo login prefills enabled and the API set to `https://ventureplus123.vercel.app/api`.

- File size: 206,150,998 bytes (about 196.6 MiB).
- SHA-256: `0835CB79AC9DCD4B36C540E5F28AB81801BB3A01F321998518BC4937511801D4`.
- Built with Flutter 3.47.8 / Dart 3.13.7 using `./scripts/mobile.ps1 -Action build`.
- Tested environment: Android API 36 x86_64 emulator; minimum Android API 24.

The APK is ignored by Git. This local file is not a published release or a production-signed build. Rebuilding can produce a different checksum. To install on an attached Android device or emulator:

```powershell
adb install -r artifacts/ventureplus-demo-debug.apk
```

Open **Offline Demo** to explore fictional Admin, Employee, Customer and Agent sessions. Local edits remain on the device. For connected access, the prefill buttons only populate the fields; **Sign in** sends credentials to the configured API and the server determines the role.

See [the delivery report](../docs/DELIVERY-REPORT.md) for the test results, live-backend deployment gate and remaining native/iOS checks.
