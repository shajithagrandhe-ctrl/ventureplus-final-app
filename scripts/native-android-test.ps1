param([ValidateSet('emulator-5554')][string]$Device = 'emulator-5554', [ValidateSet('', 'nativePickers', 'nativeExportsAndKeyboard')][string]$TestMethod = '')
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$env:JAVA_HOME = Join-Path $projectRoot '.local/java/jdk-21.0.13.0.2+1'
$env:ANDROID_HOME = Join-Path $projectRoot '.local/android-sdk'
$env:GRADLE_USER_HOME = Join-Path $projectRoot '.local/gradle'
$adb = Join-Path $env:ANDROID_HOME 'platform-tools/adb.exe'
$avdName = & $adb -s $Device emu avd name
if ($avdName -notcontains 'VenturePlus_API36') { throw 'Only the project debug emulator is permitted.' }
$hardware = (& $adb -s $Device shell getprop ro.hardware).Trim()
if ($hardware -notin @('ranchu', 'goldfish')) { throw 'Only the project test emulator is permitted.' }
Push-Location (Join-Path $projectRoot 'mobile/android')
try {
    & .\gradlew.bat :app:assembleDebugAndroidTest --offline --console=plain *> (Join-Path $projectRoot '.local/native-instrumentation-build.log')
    if ($LASTEXITCODE -ne 0) { throw 'Native test APK build failed. See .local/native-instrumentation-build.log.' }
} finally { Pop-Location }
& $adb -s $Device install -r (Join-Path $projectRoot 'mobile/build/app/outputs/apk/androidTest/debug/app-debug-androidTest.apk')
if ($LASTEXITCODE -ne 0) { throw 'Native test APK installation failed.' }
$taskLog = Join-Path $projectRoot '.local/native-uiautomator.log'
$taskClass = 'com.ventureplus.ventureplus.NativeWorkflowTest'
if ($TestMethod) { $taskClass += '#' + $TestMethod }
& $adb -s $Device shell am instrument -w -r -e ventureplusTestDevice local-demo-emulator -e class $taskClass com.ventureplus.ventureplus.test/androidx.test.runner.AndroidJUnitRunner *> $taskLog
& $adb -s $Device pull /sdcard/Android/data/com.ventureplus.ventureplus/files/native-evidence (Join-Path $projectRoot '.local/uiautomator-evidence')
Get-Content -LiteralPath $taskLog -Tail 30
if (-not (Select-String -LiteralPath $taskLog -Pattern 'OK \([0-9]+ tests?\)' -Quiet)) { throw 'Native workflow assertions failed. See .local/native-uiautomator.log.' }
