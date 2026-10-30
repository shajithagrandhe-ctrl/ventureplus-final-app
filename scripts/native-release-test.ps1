param([ValidateSet('emulator-5556')][string]$Device = 'emulator-5556')
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$env:JAVA_HOME = Join-Path $projectRoot '.local/java/jdk-21.0.13.0.2+1'
$env:ANDROID_HOME = Join-Path $projectRoot '.local/android-sdk'
$env:GRADLE_USER_HOME = Join-Path $projectRoot '.local/gradle'
$adb = Join-Path $env:ANDROID_HOME 'platform-tools/adb.exe'
$avdName = & $adb -s $Device emu avd name
if ($avdName -notcontains 'VenturePlus_Release_API36') { throw 'Only the separate project release emulator is permitted.' }
if ((& $adb -s $Device shell getprop sys.boot_completed).Trim() -ne '1') { throw 'Release emulator is still starting.' }
# A separate test host uses UIAutomator to operate the exact installed release APK.
# It avoids depending on classes removed or renamed by the app's release shrinker.
Push-Location (Join-Path $projectRoot 'mobile/android')
try {
    & .\gradlew.bat :nativeqa:assembleDebug :nativeqa:assembleDebugAndroidTest -PventureplusNativeQa=true --console=plain *> (Join-Path $projectRoot '.local/release-instrumentation-build.log')
    if ($LASTEXITCODE -ne 0) { throw 'Native QA build failed; inspect .local/release-instrumentation-build.log.' }
} finally { Pop-Location }
foreach ($apk in @('artifacts/ventureplus-demo-release.apk', 'mobile/build/nativeqa/outputs/apk/debug/nativeqa-debug.apk', 'mobile/build/nativeqa/outputs/apk/androidTest/debug/nativeqa-debug-androidTest.apk')) {
    & $adb -s $Device install -r (Join-Path $projectRoot $apk)
    if ($LASTEXITCODE -ne 0) { throw "Installation failed: $apk" }
}
$testLog = Join-Path $projectRoot '.local/native-release-uiautomator.log'
& $adb -s $Device shell am instrument -w -r -e ventureplusTestDevice local-demo-emulator -e class com.ventureplus.ventureplus.NativeWorkflowTest com.ventureplus.nativeqa.test/androidx.test.runner.AndroidJUnitRunner *> $testLog
New-Item -ItemType Directory -Path (Join-Path $projectRoot '.local/release-uiautomator-evidence') -Force | Out-Null
& $adb -s $Device pull /sdcard/Android/data/com.ventureplus.nativeqa/files/native-evidence (Join-Path $projectRoot '.local/release-uiautomator-evidence')
Get-Content -LiteralPath $testLog -Tail 30
if (-not (Select-String -LiteralPath $testLog -Pattern 'OK \(2 tests\)' -Quiet)) { throw 'Release native workflow assertions failed.' }
