param([string]$MySqlHome = '')
$ErrorActionPreference = 'Stop'
$workspace = Split-Path -Parent $PSScriptRoot
if (-not $MySqlHome) { $MySqlHome = Join-Path $workspace '.local/mysql/mysql-8.4.13-winx64' }
$mysqlBase = (Resolve-Path -LiteralPath $MySqlHome).Path
$mysqld = Join-Path $mysqlBase 'bin/mysqld.exe'
$mysql = Join-Path $mysqlBase 'bin/mysql.exe'
$mysqladmin = Join-Path $mysqlBase 'bin/mysqladmin.exe'
if (Get-NetTCPConnection -LocalPort 3309 -State Listen -ErrorAction SilentlyContinue) { throw 'Port 3309 is occupied; no existing server will be used.' }
$runId = (Get-Date -Format 'yyyyMMdd_HHmmss') + '_' + [Guid]::NewGuid().ToString('N').Substring(0,8)
$database = 'ventureplus_test_' + $runId
$runRoot = Join-Path $workspace ('.local/mysql-integration/' + $runId)
$dataDirectory = Join-Path $runRoot 'data'
New-Item -ItemType Directory -Path $dataDirectory | Out-Null
Write-Output "Isolated fixture run: $runId; loopback port 3309; fresh database $database"
$oldDatabaseUrl = $env:DATABASE_URL
$oldTestDatabaseUrl = $env:TEST_DATABASE_URL
$oldTestFlag = $env:RUN_LOCAL_MYSQL_TESTS
$oldNodeEnvironment = $env:NODE_ENV
$oldJwtSecret = $env:JWT_SECRET
$oldRedisUrl = $env:REALTIME_REDIS_URL
$mysqlProcess = $null
$serverReady = $false
try {
    & $mysqld --no-defaults --initialize-insecure "--basedir=$mysqlBase" "--datadir=$dataDirectory" --console 2> (Join-Path $runRoot 'initialize.log')
    if ($LASTEXITCODE -ne 0) { throw 'Fresh MySQL initialization failed; see local initialize.log.' }
    $mysqlProcess = Start-Process -FilePath $mysqld -ArgumentList @('--no-defaults', "--basedir=`"$mysqlBase`"", "--datadir=`"$dataDirectory`"", '--bind-address=127.0.0.1', '--port=3309', '--mysqlx=0', '--console') -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $runRoot 'server.stdout.log') -RedirectStandardError (Join-Path $runRoot 'server.stderr.log')
    for ($attempt = 0; $attempt -lt 120; $attempt++) {
        if ($mysqlProcess.HasExited) { throw 'The isolated MySQL process exited before readiness.' }
        & $mysqladmin --no-defaults --protocol=TCP --host=127.0.0.1 --port=3309 --user=root ping --silent 2>$null | Out-Null
        if ($LASTEXITCODE -eq 0) { $serverReady = $true; break }
        Start-Sleep -Milliseconds 500
    }
    if (-not $serverReady) { throw 'The isolated MySQL server did not become ready.' }
    & $mysql --no-defaults --protocol=TCP --host=127.0.0.1 --port=3309 --user=root --execute="CREATE DATABASE $database CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci"
    if ($LASTEXITCODE -ne 0) { throw 'Test database creation failed.' }
    $env:DATABASE_URL = "mysql://root@127.0.0.1:3309/$database"
    $env:TEST_DATABASE_URL = $env:DATABASE_URL
    $env:RUN_LOCAL_MYSQL_TESTS = '1'
    $env:NODE_ENV = 'test'
    $env:JWT_SECRET = 'isolated-mysql-test-signing-key-only'
    $env:REALTIME_REDIS_URL = ''
    Push-Location (Join-Path $workspace 'reference-web')
    try {
        & node node_modules/prisma/build/index.js db push --schema database/schema.prisma --skip-generate
        if ($LASTEXITCODE -ne 0) { throw 'Schema creation in the new test database failed.' }
        & node node_modules/typescript/bin/tsc -p server/tsconfig.json
        if ($LASTEXITCODE -ne 0) { throw 'Backend compilation failed.' }
        & node --test server/tests/mysql-authorization.test.cjs
        if ($LASTEXITCODE -ne 0) { throw 'MySQL authorization regression tests failed.' }
    } finally { Pop-Location }
    Write-Output 'Isolated MySQL integration tests passed.'
} finally {
    if ($mysqlProcess -and -not $mysqlProcess.HasExited) {
        if ($serverReady) { try { & $mysqladmin --no-defaults --protocol=TCP --host=127.0.0.1 --port=3309 --user=root shutdown 2>$null | Out-Null } catch { } }
        if (-not $mysqlProcess.WaitForExit(10000)) { Stop-Process -Id $mysqlProcess.Id -Force; $mysqlProcess.WaitForExit(10000) | Out-Null }
    }
    $env:DATABASE_URL = $oldDatabaseUrl
    $env:TEST_DATABASE_URL = $oldTestDatabaseUrl
    $env:RUN_LOCAL_MYSQL_TESTS = $oldTestFlag
    $env:NODE_ENV = $oldNodeEnvironment
    $env:JWT_SECRET = $oldJwtSecret
    $env:REALTIME_REDIS_URL = $oldRedisUrl
}
