BeforeAll {
    . (Join-Path $PSScriptRoot '../bin/initialize-excavator.ps1')

    function New-TestScoop {
        $bin = Join-Path $env:SCOOP_HOME 'bin'
        New-Item $bin -ItemType Directory -Force | Out-Null
        Set-Content (Join-Path $bin 'scoop.ps1') '# Mock only; never execute.'
    }

    function New-TestHub {
        $current = Join-Path $env:SCOOP_GLOBAL 'apps/hub/current'
        New-Item (Join-Path $current 'bin') -ItemType Directory -Force | Out-Null
        Set-Content (Join-Path $current 'manifest.json') '{"version":"2.14.2"}'
        Set-Content (Join-Path $current 'install.json') '{"architecture":"64bit"}'
        Set-Content (Join-Path $current 'bin/hub.exe') 'Not an executable; mocked process only.'
    }
}

Describe 'Excavator dependency setup (no real installs or network)' {
    BeforeEach {
        $script:originalEnvironment = @{}
        foreach ($name in @('GITHUB_ACTIONS', 'GITHUB_PATH', 'RUNNER_TEMP', 'USERPROFILE', 'SystemDrive', 'SCOOP', 'SCOOP_HOME', 'SCOOP_GLOBAL', 'PATH')) {
            $script:originalEnvironment[$name] = [Environment]::GetEnvironmentVariable($name)
        }
        $caseRoot = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $env:GITHUB_ACTIONS = 'true'
        $env:USERPROFILE = Join-Path $caseRoot 'user'
        $env:SystemDrive = Join-Path $caseRoot 'system'
        $env:RUNNER_TEMP = Join-Path $caseRoot 'temp'
        $env:GITHUB_PATH = Join-Path $caseRoot 'github-path'
        New-Item $env:USERPROFILE, $env:SystemDrive, $env:RUNNER_TEMP -ItemType Directory -Force | Out-Null
        Set-Content $env:GITHUB_PATH ''
        $env:SCOOP = Join-Path $env:USERPROFILE 'SCOOP'
        $env:SCOOP_HOME = Join-Path $env:SCOOP 'apps/scoop/current'
        $env:SCOOP_GLOBAL = Join-Path $env:SystemDrive 'SCOOP'
        $script:setupState = @{ Installs = 0; Downloads = 0; InstallerRuns = 0 }

        Mock Start-Sleep {}
        Mock Invoke-RestMethod { throw 'Unexpected network access.' }
        Mock Invoke-WebRequest {
            $script:setupState.Downloads++
            Set-Content $OutFile '# Mock installer; never execute.'
        }
        # This is the only process boundary. Unknown commands must not escape to the host.
        Mock Invoke-SetupProcess {
            if ($FilePath -eq (Join-Path $env:RUNNER_TEMP 'initialize-excavator-install.ps1')) {
                $script:setupState.InstallerRuns++
                New-TestScoop
                return [pscustomobject]@{ ExitCode = 0; Output = 'Scoop installed' }
            }
            switch ($ArgumentList[0]) {
                'config' { return [pscustomobject]@{ ExitCode = 0; Output = '' } }
                'install' {
                    $script:setupState.Installs++
                    New-TestHub
                    return [pscustomobject]@{ ExitCode = 0; Output = 'hub installed' }
                }
                'which' { return [pscustomobject]@{ ExitCode = 0; Output = (Join-Path $env:SCOOP_GLOBAL 'apps/hub/current/bin/hub.exe') } }
                '--version' { return [pscustomobject]@{ ExitCode = 0; Output = "git version 2.0`nhub version 2.14.2" } }
                default { throw "Unexpected process: $FilePath $ArgumentList" }
            }
        }
    }

    AfterEach {
        foreach ($name in $script:originalEnvironment.Keys) {
            [Environment]::SetEnvironmentVariable($name, $script:originalEnvironment[$name])
        }
    }

    It 'refuses a local invocation before any setup side effect' {
        $env:GITHUB_ACTIONS = $null
        $env:SCOOP = 'do-not-touch'
        { Initialize-Excavator } | Should -Throw '*GitHub Actions*'
        $env:SCOOP | Should -Be 'do-not-touch'
        Should -Invoke Invoke-SetupProcess -Times 0 -Exactly
        Should -Invoke Invoke-WebRequest -Times 0 -Exactly
    }

    It 'requires a real GitHub path command file' {
        $env:GITHUB_PATH = Join-Path $TestDrive 'absent'
        { Initialize-Excavator } | Should -Throw '*GITHUB_PATH*'
        Should -Invoke Invoke-SetupProcess -Times 0 -Exactly
        Should -Invoke Invoke-WebRequest -Times 0 -Exactly
    }

    It 'requires the runner temporary directory' {
        $env:RUNNER_TEMP = $null
        { Initialize-Excavator } | Should -Throw '*RUNNER_TEMP*'
        Should -Invoke Invoke-SetupProcess -Times 0 -Exactly
        Should -Invoke Invoke-WebRequest -Times 0 -Exactly
    }

    It 'uses upstream-compatible roots and publishes both shim paths' {
        $env:SCOOP = Join-Path $TestDrive 'wrong-root'
        $env:SCOOP_HOME = Join-Path $TestDrive 'wrong-home'
        $env:SCOOP_GLOBAL = Join-Path $TestDrive 'wrong-global'
        Initialize-Excavator
        $env:SCOOP | Should -Be (Join-Path $env:USERPROFILE 'SCOOP')
        $env:SCOOP_HOME | Should -Be (Join-Path $env:SCOOP 'apps/scoop/current')
        $env:SCOOP_GLOBAL | Should -Be (Join-Path $env:SystemDrive 'SCOOP')
        $paths = @(Get-Content $env:GITHUB_PATH)
        $paths | Should -Contain (Join-Path $env:SCOOP 'shims')
        $paths | Should -Contain (Join-Path $env:SCOOP_GLOBAL 'shims')
        $env:PATH.Split(';') | Should -Contain (Join-Path $env:SCOOP_GLOBAL 'shims')
        $script:setupState.InstallerRuns | Should -Be 1
        $script:setupState.Installs | Should -Be 1
    }

    It 'retries an installer HTTP failure but executes the installer only once' {
        Mock Invoke-WebRequest {
            $script:setupState.Downloads++
            if ($script:setupState.Downloads -eq 1) { throw 'HTTP 504' }
            Set-Content $OutFile '# Mock installer'
        }
        Initialize-Excavator
        $script:setupState.Downloads | Should -Be 2
        $script:setupState.InstallerRuns | Should -Be 1
        Should -Invoke Start-Sleep -Times 1 -Exactly
    }

    It 'fails after exactly three installer download errors without executing it' {
        Mock Invoke-WebRequest { throw 'HTTP 504' }
        { Initialize-Excavator } | Should -Throw '*download*3*'
        Should -Invoke Invoke-WebRequest -Times 3 -Exactly
        Should -Invoke Invoke-SetupProcess -Times 0 -Exactly
        Should -Invoke Start-Sleep -Times 2 -Exactly
        Get-Content $env:GITHUB_PATH -Raw | Should -Not -Match 'shims'
    }

    It 'does not rerun a failed Scoop installer' {
        Mock Invoke-SetupProcess {
            $script:setupState.InstallerRuns++
            [pscustomobject]@{ ExitCode = 1; Output = 'Installer failed' }
        } -ParameterFilter { $FilePath -eq (Join-Path $env:RUNNER_TEMP 'initialize-excavator-install.ps1') }
        { Initialize-Excavator } | Should -Throw '*Scoop installer*'
        $script:setupState.InstallerRuns | Should -Be 1
        $script:setupState.Installs | Should -Be 0
    }

    It 'rejects an installer exit zero when Scoop was not created' {
        Mock Invoke-SetupProcess {
            [pscustomobject]@{ ExitCode = 0; Output = 'False success' }
        } -ParameterFilter { $FilePath -eq (Join-Path $env:RUNNER_TEMP 'initialize-excavator-install.ps1') }
        { Initialize-Excavator } | Should -Throw '*Scoop*missing*'
        $script:setupState.Installs | Should -Be 0
    }

    It 'does not overwrite an incomplete existing Scoop installation' {
        New-Item $env:SCOOP -ItemType Directory -Force | Out-Null
        Set-Content (Join-Path $env:SCOOP 'existing-data') 'keep'
        { Initialize-Excavator } | Should -Throw '*incomplete*'
        Should -Invoke Invoke-WebRequest -Times 0 -Exactly
        Get-Content (Join-Path $env:SCOOP 'existing-data') | Should -Be 'keep'
    }

    It 'skips downloading Scoop and reinstalling a verified existing hub' {
        New-TestScoop
        New-TestHub
        Initialize-Excavator
        Should -Invoke Invoke-WebRequest -Times 0 -Exactly
        $script:setupState.Installs | Should -Be 0
        Should -Invoke Invoke-SetupProcess -Times 1 -Exactly -ParameterFilter { $ArgumentList[0] -eq 'which' }
        Should -Invoke Invoke-SetupProcess -Times 1 -Exactly -ParameterFilter { $ArgumentList[0] -eq '--version' }
    }

    It 'retries a transient hub exit one and lets Scoop handle its partial install' {
        New-TestScoop
        Mock Invoke-SetupProcess {
            $script:setupState.Installs++
            $partial = Join-Path $env:SCOOP_GLOBAL 'apps/hub/2.14.2'
            if ($script:setupState.Installs -eq 1) {
                New-Item $partial -ItemType Directory -Force | Out-Null
                return [pscustomobject]@{ ExitCode = 1; Output = 'HTTP 504' }
            }
            Test-Path $partial | Should -BeTrue
            New-TestHub
            [pscustomobject]@{ ExitCode = 0; Output = 'Scoop repaired partial install' }
        } -ParameterFilter { $ArgumentList[0] -eq 'install' }
        Initialize-Excavator
        $script:setupState.Installs | Should -Be 2
        Should -Invoke Start-Sleep -Times 1 -Exactly
    }

    It 'retries a hub process exception and succeeds on the next attempt' {
        New-TestScoop
        Mock Invoke-SetupProcess {
            $script:setupState.Installs++
            if ($script:setupState.Installs -eq 1) { throw 'Transient child process failure' }
            New-TestHub
            [pscustomobject]@{ ExitCode = 0; Output = '' }
        } -ParameterFilter { $ArgumentList[0] -eq 'install' }
        Initialize-Excavator
        $script:setupState.Installs | Should -Be 2
    }

    It 'fails after three hub errors and never publishes readiness' {
        New-TestScoop
        Mock Invoke-SetupProcess {
            [pscustomobject]@{ ExitCode = 1; Output = 'Previous installation could not be repaired' }
        } -ParameterFilter { $ArgumentList[0] -eq 'install' }
        { Initialize-Excavator } | Should -Throw '*hub*3*'
        Should -Invoke Invoke-SetupProcess -Times 3 -Exactly -ParameterFilter { $ArgumentList[0] -eq 'install' }
        Should -Invoke Start-Sleep -Times 2 -Exactly
        Get-Content $env:GITHUB_PATH -Raw | Should -Not -Match 'shims'
    }

    It 'does not treat a failed install as success even if later health checks would pass' {
        New-TestScoop
        Mock Invoke-SetupProcess {
            New-TestHub
            [pscustomobject]@{ ExitCode = 1; Output = 'Failed after creating files' }
        } -ParameterFilter { $ArgumentList[0] -eq 'install' }
        { Initialize-Excavator } | Should -Throw '*hub*3*'
        Should -Invoke Invoke-SetupProcess -Times 0 -Exactly -ParameterFilter { $ArgumentList[0] -eq '--version' }
    }

    It 'rejects exit zero without a usable installed hub' {
        New-TestScoop
        Mock Invoke-SetupProcess {
            [pscustomobject]@{ ExitCode = 0; Output = 'Misleading success' }
        } -ParameterFilter { $ArgumentList[0] -eq 'install' }
        { Initialize-Excavator } | Should -Throw '*hub*3*'
        Should -Invoke Invoke-SetupProcess -Times 3 -Exactly -ParameterFilter { $ArgumentList[0] -eq 'install' }
    }

    It 'rejects a broken scoop which result' {
        New-TestScoop
        Mock Invoke-SetupProcess {
            [pscustomobject]@{ ExitCode = 2; Output = 'Broken shim' }
        } -ParameterFilter { $ArgumentList[0] -eq 'which' }
        { Initialize-Excavator } | Should -Throw '*hub*3*'
        Should -Invoke Invoke-SetupProcess -Times 0 -Exactly -ParameterFilter { $ArgumentList[0] -eq '--version' }
    }

    It 'rejects an unrelated hub binary found earlier on PATH' {
        New-TestScoop
        Mock Invoke-SetupProcess {
            [pscustomobject]@{ ExitCode = 0; Output = (Join-Path $TestDrive 'other/hub.exe') }
        } -ParameterFilter { $ArgumentList[0] -eq 'which' }
        { Initialize-Excavator } | Should -Throw '*hub*3*'
    }

    It 'rejects a broken hub executable despite install and which exit zero' {
        New-TestScoop
        Mock Invoke-SetupProcess {
            [pscustomobject]@{ ExitCode = 1; Output = 'Cannot execute binary' }
        } -ParameterFilter { $ArgumentList[0] -eq '--version' }
        { Initialize-Excavator } | Should -Throw '*hub*3*'
    }

    It 'rejects version output that does not identify hub' {
        New-TestScoop
        Mock Invoke-SetupProcess {
            [pscustomobject]@{ ExitCode = 0; Output = 'git version 2.0' }
        } -ParameterFilter { $ArgumentList[0] -eq '--version' }
        { Initialize-Excavator } | Should -Throw '*hub*3*'
    }

    It 'keeps hash verification enabled and limits retries to dependency preparation' {
        New-TestScoop
        Initialize-Excavator
        Should -Invoke Invoke-SetupProcess -Times 1 -Exactly -ParameterFilter {
            $ArgumentList[0] -eq 'install' -and $ArgumentList[1] -eq 'hub' -and
            $ArgumentList -contains '-g' -and $ArgumentList -contains '--no-update-scoop' -and
            $ArgumentList -notcontains '-s' -and $ArgumentList -notcontains '--skip-hash-check'
        }
        Should -Invoke Invoke-SetupProcess -Times 0 -Exactly -ParameterFilter {
            $FilePath -match 'action\.ps1|auto-pr\.ps1|git(\.exe)?$' -or $ArgumentList -contains 'push'
        }
    }
}
