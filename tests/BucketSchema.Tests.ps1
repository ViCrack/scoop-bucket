BeforeAll {
    $bucket = Join-Path $PSScriptRoot '../bucket'
    if (-not $env:SCOOP_HOME) { throw 'SCOOP_HOME must point to the Scoop source used by bucket tests.' }
    Add-Type -Path (Join-Path $env:SCOOP_HOME 'supporting/validator/bin/Scoop.Validator.dll')
    $schemaPath = (Join-Path $env:SCOOP_HOME 'schema.json') -replace '\\', '/'
    $validator = New-Object Scoop.Validator($schemaPath, $true)
}

Describe 'Previously invalid manifest schemas' {
    It '<Name> validates against the Scoop schema' -TestCases @(
        @{ Name = 'chat2db' }
        @{ Name = 'maye' }
        @{ Name = 'xterminal' }
        @{ Name = 'pyxis' }
        @{ Name = 'TscanPlus' }
        @{ Name = 'decrypttools' }
        @{ Name = 'godzilla_ekp' }
        @{ Name = 'java-memshell-generator' }
        @{ Name = 'struts2vulsscantools' }
    ) {
        param($Name)
        $validator.Validate((Join-Path $bucket "$Name.json")) | Should -BeTrue -Because $validator.ErrorsAsString
        $validator.Errors.Count | Should -Be 0
    }
}

Describe 'Launcher generation after a manifest version update' {
    It '<Name> writes the current jar name without running the application' -TestCases @(
        @{ Name = 'decrypttools'; JarTemplate = 'DecryptTools.jar'; Java = 'javaw.exe' }
        @{ Name = 'behinder'; JarTemplate = 'Behinder.jar'; Java = 'javaw.exe' }
        @{ Name = 'godzilla_ekp'; JarTemplate = 'godzilla_ekp{0}.jar'; Java = 'javaw.exe' }
        @{ Name = 'java-memshell-generator'; JarTemplate = 'jmg-all-{0}.jar'; Java = 'java.exe' }
        @{ Name = 'java-echo-generator-release'; JarTemplate = 'jEG-gui-{0}.jar'; Java = 'javaw.exe' }
        @{ Name = 'mysql-fake-server'; JarTemplate = 'fake-mysql-gui-{0}.jar'; Java = 'javaw.exe' }
        @{ Name = 'struts2vulsscantools'; JarTemplate = 'Struts2_{0}.jar'; Java = 'javaw.exe' }
    ) {
        param($Name, $JarTemplate, $Java)
        $manifest = Get-Content (Join-Path $bucket "$Name.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $manifest.autoupdate.PSObject.Properties.Name | Should -Not -Contain 'pre_install'
        foreach ($version in @($manifest.version, '99.8.7_test')) {
            $manifest.version = $version
            $dir = Join-Path $TestDrive "$Name-$version"
            $persist_dir = Join-Path $dir 'persist'
            New-Item $dir, $persist_dir -ItemType Directory -Force | Out-Null
            # Only the reviewed file-generation hook executes, never its generated BAT or JAR.
            & ([scriptblock]::Create(($manifest.pre_install -join "`n")))
            $launcher = Get-Content (Join-Path $dir "$Name.bat") -Raw
            $launcher | Should -Match ([regex]::Escape(($JarTemplate -f $version)))
            $launcher | Should -Match ([regex]::Escape($Java))
            $launcher | Should -Match '%\*'
            $launcher | Should -Not -Match '\$version|\$manifest'
        }
    }
}
