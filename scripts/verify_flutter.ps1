param([string]$FlutterSdk, [switch]$RunDemo, [switch]$RunApp)

if ($RunDemo -and $RunApp) {
    Write-Host 'Choose either -RunDemo or -RunApp.'
    exit 1
}

# Run from an ordinary Windows terminal. Results are stored locally.
$ErrorActionPreference = 'Continue'
$taskProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$taskMobilePath = Join-Path $taskProjectRoot 'mobile'
$taskLogPath = Join-Path $taskProjectRoot 'verification'
$taskFlutterCommand = $null

if ($FlutterSdk) {
    $taskFlutterCommand = Join-Path $FlutterSdk 'bin\flutter.bat'
} else {
    $taskInstalledFlutter = Get-Command flutter.bat -ErrorAction SilentlyContinue
    if ($taskInstalledFlutter) {
        $taskFlutterCommand = $taskInstalledFlutter.Source
    } elseif ($env:FLUTTER_ROOT) {
        $taskFlutterCommand = Join-Path $env:FLUTTER_ROOT 'bin\flutter.bat'
    } else {
        $taskFlutterCommand = Join-Path $env:USERPROFILE 'Documents\Codex\tools\flutter\bin\flutter.bat'
    }
}

if (-not (Test-Path -LiteralPath $taskFlutterCommand -PathType Leaf)) {
    Write-Host 'Flutter SDK not found. Run this script with -FlutterSdk C:\path\to\flutter.'
    exit 1
}
if (-not (Test-Path -LiteralPath (Join-Path $taskMobilePath 'pubspec.yaml'))) {
    Write-Host 'The mobile project must be in the mobile folder next to scripts.'
    exit 1
}

# Flutter invokes Git internally. The bundled SDK may have been installed by
# a different local account. Trust only this SDK, only in this process and
# its children; preserve any existing command-scope Git configuration.
$taskSdkRoot = (Resolve-Path (Join-Path (Split-Path $taskFlutterCommand -Parent) '..')).Path
$taskOriginalGitCount = [Environment]::GetEnvironmentVariable('GIT_CONFIG_COUNT', 'Process')
$taskGitIndex = 0
if ($taskOriginalGitCount -and
    (-not [int]::TryParse($taskOriginalGitCount, [ref]$taskGitIndex) -or $taskGitIndex -lt 0)) {
    Write-Host 'GIT_CONFIG_COUNT is invalid. No Git configuration was changed.'
    exit 1
}
$taskGitKeyName = 'GIT_CONFIG_KEY_' + $taskGitIndex
$taskGitValueName = 'GIT_CONFIG_VALUE_' + $taskGitIndex
$taskOriginalGitKey = [Environment]::GetEnvironmentVariable($taskGitKeyName, 'Process')
$taskOriginalGitValue = [Environment]::GetEnvironmentVariable($taskGitValueName, 'Process')

New-Item -ItemType Directory -Path $taskLogPath -Force | Out-Null
$taskResults = [System.Collections.Generic.List[object]]::new()
$taskChecks = @(
    @{ Name = 'sdk'; Arguments = @('--version') },
    @{ Name = 'dependencies'; Arguments = @('pub', 'get') },
    @{ Name = 'analysis'; Arguments = @('analyze') },
    @{ Name = 'tests'; Arguments = @('test') },
    @{ Name = 'web-build'; Arguments = @('build', 'web', '--dart-define=DEMO_MODE=true') }
)
$taskMode = 'verification'
$taskResultName = 'result.json'
if ($RunDemo) {
    $taskMode = 'demo'
    $taskResultName = 'demo-result.json'
    $taskChecks = @(
        @{ Name = 'demo'; Arguments = @('run', '-d', 'chrome', '--dart-define=DEMO_MODE=true') }
    )
} elseif ($RunApp) {
    $taskMode = 'app'
    $taskResultName = 'app-result.json'
    $taskChecks = @(
        @{ Name = 'app'; Arguments = @('run', '-d', 'chrome', '--dart-define=API_BASE_URL=http://127.0.0.1:8000/api/v1') }
    )
}
$taskFailed = $false
$taskLocationPushed = $false

try {
    [Environment]::SetEnvironmentVariable($taskGitKeyName, 'safe.directory', 'Process')
    [Environment]::SetEnvironmentVariable($taskGitValueName, $taskSdkRoot.Replace('\', '/'), 'Process')
    [Environment]::SetEnvironmentVariable('GIT_CONFIG_COUNT', [string]($taskGitIndex + 1), 'Process')
    Push-Location -LiteralPath $taskMobilePath
    $taskLocationPushed = $true
    foreach ($taskCheck in $taskChecks) {
        Write-Host "Checking $($taskCheck.Name)..."
        $taskStageLog = Join-Path $taskLogPath ($taskCheck.Name + '.log')
        $taskArguments = $taskCheck.Arguments
        $LASTEXITCODE = $null
        & $taskFlutterCommand @taskArguments 2>&1 |
            ForEach-Object { $_.ToString() } |
            Tee-Object -FilePath $taskStageLog
        $taskExitCode = if ($null -eq $LASTEXITCODE) { 1 } else { $LASTEXITCODE }
        $taskResults.Add([pscustomobject]@{
            check = $taskCheck.Name
            exitCode = $taskExitCode
            passed = ($taskExitCode -eq 0)
            log = $taskStageLog
        })
        if ($taskExitCode -ne 0) {
            $taskFailed = $true
            break
        }
    }
} catch {
    $taskFailed = $true
    Write-Host "Verification could not complete: $_"
} finally {
    if ($taskLocationPushed) { Pop-Location }
    [Environment]::SetEnvironmentVariable('GIT_CONFIG_COUNT', $taskOriginalGitCount, 'Process')
    [Environment]::SetEnvironmentVariable($taskGitKeyName, $taskOriginalGitKey, 'Process')
    [Environment]::SetEnvironmentVariable($taskGitValueName, $taskOriginalGitValue, 'Process')
    [pscustomobject]@{
        checkedAt = (Get-Date).ToString('o')
        mode = $taskMode
        flutter = $taskFlutterCommand
        allChecksPassed = (-not $taskFailed -and $taskResults.Count -eq $taskChecks.Count)
        results = @($taskResults.ToArray())
    } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $taskLogPath $taskResultName) -Encoding UTF8
}

Write-Host "Logs: $taskLogPath"
if ($taskFailed) {
    Write-Host 'Verification stopped at a failed check. See its log for details.'
    exit 1
}
if ($RunDemo) {
    Write-Host 'Demo stopped.'
} elseif ($RunApp) {
    Write-Host 'App stopped.'
} else {
    Write-Host 'Flutter analysis, tests and the demo web build passed.'
}
exit 0
