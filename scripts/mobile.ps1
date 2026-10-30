param(
    [ValidateSet('run', 'build', 'release', 'demo-release', 'analyze', 'test', 'offline-test', 'workflow-test', 'tablet-test', 'live-auth-test', 'restart-test')]
    [string]$Action = 'run',
    [string]$FlutterPath = '',
    [string]$Device = 'emulator-5554',
    [string]$ApiBaseUrl = 'https://ventureplus123.vercel.app/api'
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$localTools = Join-Path $projectRoot '.local'
if (-not $FlutterPath) {
    $installedFlutter = Get-Command flutter -ErrorAction SilentlyContinue
    if ($installedFlutter) { $FlutterPath = $installedFlutter.Source }
    else { $FlutterPath = Join-Path $env:USERPROFILE 'Downloads/flutter/flutter/bin/flutter.bat' }
}
if (-not (Test-Path -LiteralPath $FlutterPath)) { throw 'Pass -FlutterPath pointing to your Flutter executable.' }
$projectSdk = Join-Path $localTools 'android-sdk'
if (Test-Path -LiteralPath $projectSdk) {
    $env:ANDROID_HOME = $projectSdk
    $env:ANDROID_SDK_ROOT = $projectSdk
    $env:ANDROID_AVD_HOME = Join-Path $localTools 'avd'
    $env:GRADLE_USER_HOME = Join-Path $localTools 'gradle'
}
$projectJdk = Join-Path $localTools 'java/jdk-21.0.13.0.2+1'
if (Test-Path -LiteralPath $projectJdk) { $env:JAVA_HOME = $projectJdk }
Push-Location (Join-Path $projectRoot 'mobile')
try {
    $defines = @('--dart-define=ENABLE_DEMO_PREFILLS=true', "--dart-define=API_BASE_URL=$ApiBaseUrl")
    switch ($Action) {
        'run' { & $FlutterPath run -d $Device @defines }
        'build' { & $FlutterPath build apk --debug @defines }
        'release' { & $FlutterPath build apk --release --dart-define=ENABLE_DEMO_PREFILLS=false "--dart-define=API_BASE_URL=$ApiBaseUrl" }
        'demo-release' { & $FlutterPath build apk --release @defines }
        'analyze' { & $FlutterPath analyze }
        'test' { & $FlutterPath test }
        'offline-test' { & $FlutterPath drive -d $Device --keep-app-running --driver=test_driver/integration_test.dart --target=integration_test/demo_test.dart @defines }
        'workflow-test' { & $FlutterPath drive -d $Device --keep-app-running --driver=test_driver/integration_test.dart --target=integration_test/workflows_test.dart @defines }
        'tablet-test' { & $FlutterPath drive -d $Device --keep-app-running --driver=test_driver/integration_test.dart --target=integration_test/responsive_test.dart @defines }
        'live-auth-test' { & $FlutterPath drive -d $Device --keep-app-running --driver=test_driver/integration_test.dart --target=integration_test/demo_test.dart --dart-define=LIVE_AUTH_TESTS=true @defines }
        'restart-test' { & $FlutterPath drive -d $Device --keep-app-running --driver=test_driver/integration_test.dart --target=integration_test/restart_test.dart @defines }
    }
    $resultCode = $LASTEXITCODE
} finally { Pop-Location }
exit $resultCode

