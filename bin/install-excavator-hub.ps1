#Requires -Version 7.0
[CmdletBinding()]
param(
    [ValidateRange(1, 5)]
    [int] $MaxAttempts = 3,
    [ValidateRange(0, 300)]
    [int] $RetryDelaySeconds = 10
)

$ErrorActionPreference = 'Stop'
# Inspect native exit codes ourselves so a failed attempt can be retried.
$PSNativeCommandUseErrorActionPreference = $false

for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
    Write-Host "Installing Excavator dependency hub (attempt $attempt/$MaxAttempts)..."
    # Scoop can call exit; isolate it so it cannot terminate the retry loop.
    # Scoop repairs/purges incomplete installations before the next install.
    & pwsh -NoProfile -NonInteractive -Command {
        scoop install hub --global
        exit $LASTEXITCODE
    }
    $installExitCode = $LASTEXITCODE
    if ($installExitCode -eq 0) {
        & pwsh -NoProfile -NonInteractive -Command {
            $ErrorActionPreference = 'Stop'
            $PSNativeCommandUseErrorActionPreference = $false
            # Match auto-pr.ps1's preflight and verify hub actually executes.
            $hubPath = scoop which hub
            if ($LASTEXITCODE -ne 0 -or -not $hubPath) { exit 1 }
            hub --version
            exit $LASTEXITCODE
        }
        if ($LASTEXITCODE -eq 0) { return }
    }

    if ($attempt -lt $MaxAttempts) {
        Write-Warning "hub is not ready; retrying in $RetryDelaySeconds seconds."
        Start-Sleep -Seconds $RetryDelaySeconds
    }
}

throw "Failed to install a working Scoop hub dependency after $MaxAttempts attempts."
