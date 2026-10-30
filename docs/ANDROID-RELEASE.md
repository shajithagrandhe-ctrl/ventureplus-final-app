# Android release packaging

Release builds use a private application signing key. They fail if signing is not configured; they never fall back to Android's shared debug key. Debug builds remain available through `scripts/mobile.ps1 -Action build`.

For an existing application, retain its original signing key so Android accepts future updates. Configure a private properties file with `storeFile`, `storePassword`, `keyAlias` and `keyPassword`, following [Flutter's Android signing guide](https://docs.flutter.dev/deployment/android#sign-the-app). Set `VENTUREPLUS_SIGNING_PROPERTIES` to its absolute path, or use the ignored `mobile/android/key.properties`. Do not send private keys or passwords in chat or commit them to Git.

For a new application signing identity, the local helper creates an RSA 3072-bit key with a cryptographically random password in `.local/signing/`. It restricts the new folder to the current Windows user and SYSTEM, refuses to replace existing material, and never prints the password. Run it only after the owner approves creating the new signing identity:

```powershell
.\scripts\create-android-signing-key.ps1
```

Back up the entire private `.local/signing/` folder to an owner-controlled secure location. Losing this key prevents updates to directly installed APKs signed with it. The key and properties are ignored by Git and are not included in deliverable APKs.

Build the optimized APK without credential prefills:

```powershell
.\scripts\mobile.ps1 -Action release
```

For the explicitly requested demonstration with the three credential-prefill buttons:

```powershell
.\scripts\mobile.ps1 -Action demo-release
```

Both commands output `mobile/build/app/outputs/flutter-apk/app-release.apk`. The demonstration variant must be named distinctly when copied to `artifacts/`; it contains the requested demo values. Neither command deploys the backend or publishes to an app store.

An existing debug installation uses a different certificate and cannot be updated in place with a newly signed release. Preserve any needed local demo data before removing a debug installation; uninstalling clears its local data. Prefer a separate test emulator for release validation.

Signing and optimizing an APK do not establish backend readiness. Deployment/access and native verification results are tracked in the delivery report.

## Native release verification

The final demo APK was installed on a new `VenturePlus_Release_API36` emulator (Android API 36, x86_64). Its installed SHA-256 matched the saved artifact. Both native UIAutomator cases passed in 105.8 seconds: gallery/files/camera selection, local uploads and cancellation; hardware-key customer search, CSV export and calendar export with saved-byte readback. See [the retained result](evidence/android-release-native-results.txt).

`scripts/native-release-test.ps1` builds an independent Android test host, enabled only by the `ventureplusNativeQa` Gradle property. It operates the unchanged, non-debuggable APK through Android UIAutomator. This avoids coupling instrumentation to classes removed by release shrinking. The test host is not included in the distributed APK, and its script refuses any AVD other than the separate project release emulator on port 5556. All mutations use fictional Offline Demo data. The existing `scripts/native-android-test.ps1` targets only `VenturePlus_API36` on port 5554.

These emulator checks do not certify every physical device, keyboard composition language, iOS behavior or live backend deployment. Preserve the original key for future APK updates; a new signing key cannot update an installation signed by another key.
