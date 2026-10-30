param([string]$KeytoolPath = '')
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$signingDirectory = Join-Path $projectRoot '.local/signing'
if (Test-Path -LiteralPath $signingDirectory) {
    throw 'The signing directory already exists. Preserve the existing key; this script never replaces signing material.'
}
if (-not $KeytoolPath) {
    $KeytoolPath = Join-Path $projectRoot '.local/java/jdk-21.0.13.0.2+1/bin/keytool.exe'
    if (-not (Test-Path -LiteralPath $KeytoolPath)) {
        $KeytoolPath = (Get-Command keytool -ErrorAction Stop).Source
    }
}
if (-not (Test-Path -LiteralPath $KeytoolPath)) { throw 'Supply a valid -KeytoolPath.' }

# Only this newly created directory receives a private ACL; existing folders are untouched.
New-Item -ItemType Directory -Path $signingDirectory | Out-Null
$currentIdentity = [System.Security.Principal.WindowsIdentity]::GetCurrent().User
$signingAcl = [System.Security.AccessControl.DirectorySecurity]::new()
$signingAcl.SetAccessRuleProtection($true, $false)
$signingAcl.SetOwner($currentIdentity)
foreach ($identity in @($currentIdentity, [System.Security.Principal.SecurityIdentifier]::new('S-1-5-18'))) {
    $rule = [System.Security.AccessControl.FileSystemAccessRule]::new(
        $identity, 'FullControl', 'ContainerInherit,ObjectInherit', 'None', 'Allow')
    $signingAcl.AddAccessRule($rule)
}
Set-Acl -LiteralPath $signingDirectory -AclObject $signingAcl

$keyFile = Join-Path $signingDirectory 'ventureplus-release.jks'
$propertiesFile = Join-Path $signingDirectory 'key.properties'
$previousPassword = $env:VENTUREPLUS_NEW_SIGNING_PASSWORD
$randomBytes = New-Object byte[] 32
$random = [System.Security.Cryptography.RandomNumberGenerator]::Create()
try {
    $random.GetBytes($randomBytes)
    $signingPassword = [Convert]::ToBase64String($randomBytes)
    $env:VENTUREPLUS_NEW_SIGNING_PASSWORD = $signingPassword
    & $KeytoolPath -genkeypair -noprompt -keystore $keyFile -storetype JKS -keyalg RSA -keysize 3072 -validity 10000 -alias ventureplus -dname 'CN=VenturePlus Android, O=VenturePlus' -storepass:env VENTUREPLUS_NEW_SIGNING_PASSWORD -keypass:env VENTUREPLUS_NEW_SIGNING_PASSWORD
    if ($LASTEXITCODE -ne 0) { throw 'Signing-key generation failed. Inspect the new signing directory before retrying.' }
    $portablePath = $keyFile.Replace('\', '/')
    $properties = "storeFile=$portablePath`nstorePassword=$signingPassword`nkeyAlias=ventureplus`nkeyPassword=$signingPassword`n"
    [IO.File]::WriteAllText($propertiesFile, $properties, [Text.UTF8Encoding]::new($false))
    Write-Output "Created release signing material in $signingDirectory. Back up this entire private folder before distributing the APK."
} finally {
    $random.Dispose()
    [Array]::Clear($randomBytes, 0, $randomBytes.Length)
    $env:VENTUREPLUS_NEW_SIGNING_PASSWORD = $previousPassword
    $signingPassword = $null
    $properties = $null
}
