# Prepare dependencies only. Never retry Excavator itself: it can commit and push.
# Dot-sourcing defines functions for isolated tests without running setup.
function Invoke-SetupProcess {
    param([string] $FilePath, [string[]] $ArgumentList)

    # A child process contains Scoop's exit statements and exposes a real exit code.
    $file = "'" + $FilePath.Replace("'", "''") + "'"
    $arguments = (@($ArgumentList | ForEach-Object { "'" + $_.Replace("'", "''") + "'" }) -join ',')
    $command = @"
`$ErrorActionPreference = 'Stop'
`$PSNativeCommandUseErrorActionPreference = `$false
try {
    & $file @($arguments)
    if (`$null -eq `$LASTEXITCODE) { exit 0 }
    exit `$LASTEXITCODE
} catch {
    Write-Error `$_ -ErrorAction Continue
    exit 1
}
"@
    $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($command))
    $PSNativeCommandUseErrorActionPreference = $false
    $output = & (Join-Path $PSHOME 'pwsh.exe') -NoLogo -NoProfile -NonInteractive -EncodedCommand $encoded 2>&1
    $exitCode = $LASTEXITCODE
    $text = ($output | Out-String).Trim()
    if ($text) { Write-Host $text }
    return [pscustomobject]@{ ExitCode = $exitCode; Output = $text }
}

function Test-ExcavatorHub {
    param([string] $ScoopScript)

    $current = Join-Path $env:SCOOP_GLOBAL 'apps/hub/current'
    $binary = Join-Path $current 'bin/hub.exe'
    foreach ($path in @($binary, (Join-Path $current 'manifest.json'), (Join-Path $current 'install.json'))) {
        if (-not (Test-Path $path -PathType Leaf)) { return $false }
    }
    try {
        $which = Invoke-SetupProcess $ScoopScript @('which', 'hub')
        if ($which.ExitCode -ne 0 -or $which.Output.Trim() -ne $binary) { return $false }
        $version = Invoke-SetupProcess $binary @('--version')
        return $version.ExitCode -eq 0 -and $version.Output -match '(?m)^hub version \S+'
    } catch {
        Write-Warning "hub health check failed: $_"
        return $false
    }
}

function Initialize-Excavator {
    # Do not let a developer's ordinary local Scoop installation enter this path.
    if ($env:GITHUB_ACTIONS -ne 'true') { throw 'This setup is only for GitHub Actions.' }
    if (-not $env:GITHUB_PATH -or -not (Test-Path $env:GITHUB_PATH -PathType Leaf)) {
        throw 'GITHUB_PATH must be an existing runner command file.'
    }
    if (-not $env:RUNNER_TEMP -or -not (Test-Path $env:RUNNER_TEMP -PathType Container)) {
        throw 'RUNNER_TEMP must be an existing runner temporary directory.'
    }
    $ErrorActionPreference = 'Stop'

    # Match ScoopInstaller/GithubActions src/Variables.psm1; it overrides these roots.
    $env:SCOOP = Join-Path $env:USERPROFILE 'SCOOP'
    $env:SCOOP_HOME = Join-Path $env:SCOOP 'apps/scoop/current'
    $env:SCOOP_GLOBAL = Join-Path $env:SystemDrive 'SCOOP'
    $shims = @((Join-Path $env:SCOOP 'shims'), (Join-Path $env:SCOOP_GLOBAL 'shims'))
    # GITHUB_PATH affects only later steps, not this process or its children.
    $env:PATH = ($shims -join ';') + ';' + $env:PATH
    $scoopScript = Join-Path $env:SCOOP_HOME 'bin/scoop.ps1'

    if (-not (Test-Path $scoopScript -PathType Leaf)) {
        if ((Test-Path $env:SCOOP) -and (Get-ChildItem $env:SCOOP -Force | Select-Object -First 1)) {
            throw 'An incomplete Scoop installation exists; refusing to overwrite it.'
        }
        $installer = Join-Path $env:RUNNER_TEMP 'initialize-excavator-install.ps1'
        for ($attempt = 1; $attempt -le 3; $attempt++) {
            try {
                # Retry only the HTTP download, never re-execute a partially run installer.
                Invoke-WebRequest 'https://raw.githubusercontent.com/ScoopInstaller/Install/master/install.ps1' -OutFile $installer -TimeoutSec 60
                if (-not (Test-Path $installer -PathType Leaf) -or (Get-Item $installer).Length -eq 0) {
                    throw 'Installer download produced no content.'
                }
                break
            } catch {
                if ($attempt -eq 3) { throw "Scoop installer download failed after 3 attempts: $_" }
                Write-Warning "Scoop installer download attempt $attempt failed: $_"
                Start-Sleep -Seconds (10 * $attempt)
            }
        }
        $installed = Invoke-SetupProcess $installer @('-RunAsAdmin')
        if ($installed.ExitCode -ne 0) { throw "Scoop installer failed (exit $($installed.ExitCode))." }
        if (-not (Test-Path $scoopScript -PathType Leaf)) { throw 'Scoop script is missing after installation.' }
    }

    $configured = Invoke-SetupProcess $scoopScript @('config', 'USE_EXTERNAL_7ZIP', 'true')
    if ($configured.ExitCode -ne 0) { throw 'Cannot configure Scoop for the runner.' }

    $ready = Test-ExcavatorHub $scoopScript
    if (-not $ready) {
        for ($attempt = 1; $attempt -le 3; $attempt++) {
            try {
                # Current Scoop repairs/purges failed hub installs in ensure_none_failed.
                # Use its public install path, not manual cache names or directory deletion.
                $installed = Invoke-SetupProcess $scoopScript @('install', 'hub', '-g', '--no-update-scoop')
                if ($installed.ExitCode -ne 0) { throw "scoop install exited $($installed.ExitCode)." }
                if (-not (Test-ExcavatorHub $scoopScript)) { throw 'Installed hub failed its shim/binary health check.' }
                $ready = $true
                break
            } catch {
                if ($attempt -eq 3) { throw "hub preparation failed after 3 attempts: $_" }
                Write-Warning "hub preparation attempt $attempt failed: $_"
                Start-Sleep -Seconds (10 * $attempt)
            }
        }
    }
    if (-not $ready) { throw 'hub is not ready; Excavator must not run.' }
    $shims | Add-Content $env:GITHUB_PATH -Encoding utf8
}

if ($MyInvocation.InvocationName -ne '.') { Initialize-Excavator }
