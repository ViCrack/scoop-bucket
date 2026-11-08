#Requires -Version 7.0
# Offline regression tests: never install or uninstall anything on this machine.
$ErrorActionPreference = 'Stop'
$installer = Join-Path $PSScriptRoot 'install-excavator-hub.ps1'

function Test-HubRetry {
    param(
        [string] $Name,
        [int[]] $ExitCodes,
        [int] $ExpectedInstalls,
        [int] $ExpectedChecks,
        [switch] $ShouldFail
    )

    $state = @{ Calls = 0; Installs = 0; Checks = 0; Sleeps = 0 }
    # Intercept only the child-process boundary; exercise the real retry script.
    function pwsh {
        param([switch] $NoProfile, [switch] $NonInteractive, [scriptblock] $Command)
        if (-not $NoProfile -or -not $NonInteractive) { throw 'Unsafe child process options.' }
        if ($Command.ToString().Contains('scoop install hub --global')) {
            $state.Installs++
        } elseif ($Command.ToString().Contains('scoop which hub')) {
            $state.Checks++
        } else {
            throw 'Unexpected child process.'
        }
        if ($state.Calls -ge $ExitCodes.Count) { throw 'Too many child processes.' }
        $global:LASTEXITCODE = $ExitCodes[$state.Calls++]
    }
    function Start-Sleep {
        param([int] $Seconds)
        if ($Seconds -ne 0) { throw 'Tests must not sleep.' }
        $state.Sleeps++
    }

    $failure = $null
    try {
        & $installer -MaxAttempts 3 -RetryDelaySeconds 0
    } catch {
        $failure = $_
    }
    if ($ShouldFail) {
        if (-not $failure -or $failure.ToString() -notlike '*after 3 attempts*') {
            throw "${Name}: expected an explicit exhausted-retries failure, got $failure"
        }
    } elseif ($failure) {
        throw $failure
    }
    if ($state.Installs -ne $ExpectedInstalls -or $state.Checks -ne $ExpectedChecks -or
        $state.Calls -ne $ExitCodes.Count -or $state.Sleeps -ne ($ExpectedInstalls - 1)) {
        throw "${Name}: unexpected retry counts: $($state | ConvertTo-Json -Compress)"
    }
    Write-Host "PASS: $Name"
}

Test-HubRetry 'first attempt succeeds' @(0, 0) 1 1
Test-HubRetry 'transient download failure then success' @(1, 0, 0) 2 1
Test-HubRetry 'two failures then success' @(1, 1, 0, 0) 3 1
Test-HubRetry 'installation succeeds but hub is unusable' @(0, 1, 0, 0) 2 2
Test-HubRetry 'permanent download failure stays fatal' @(1, 1, 1) 3 0 -ShouldFail
Test-HubRetry 'broken shim stays fatal' @(0, 1, 0, 1, 0, 1) 3 3 -ShouldFail

# Run the actual verification child block with fake scoop/hub commands, in a real
# subprocess, so exit handling and the shim/version gates are tested as well.
$tokens = $null
$parseErrors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($installer, [ref] $tokens, [ref] $parseErrors)
if ($parseErrors.Count) { throw ($parseErrors | Out-String) }
$verification = $ast.Find({
    param($node)
    $node -is [System.Management.Automation.Language.ScriptBlockExpressionAst] -and
        $node.Extent.Text.Contains('scoop which hub')
}, $true)
if (-not $verification) { throw 'Missing Scoop shim verification.' }

function Test-HubVerification {
    param([string] $Name, [string] $Setup, [int] $ExpectedExitCode)
    & (Join-Path $PSHOME 'pwsh.exe') -NoProfile -NonInteractive -Command "$Setup; & $($verification.Extent.Text)"
    if ($LASTEXITCODE -ne $ExpectedExitCode) { throw "${Name}: unexpected exit code $LASTEXITCODE" }
    Write-Host "PASS: $Name"
}

Test-HubVerification 'missing shim fails before hub execution' @'
function scoop { $global:LASTEXITCODE = 0 }
function hub { exit 99 }
'@ 1
Test-HubVerification 'failed shim resolution is rejected' @'
function scoop { $global:LASTEXITCODE = 1; 'hub.exe' }
function hub { exit 99 }
'@ 1
Test-HubVerification 'broken executable is rejected' @'
function scoop { $global:LASTEXITCODE = 0; 'hub.exe' }
function hub { $global:LASTEXITCODE = 7 }
'@ 7
Test-HubVerification 'working shim and executable succeed' @'
function scoop { $global:LASTEXITCODE = 0; 'hub.exe' }
function hub { $global:LASTEXITCODE = 0 }
'@ 0

Write-Host 'All 10 Excavator hub regression tests passed.'
