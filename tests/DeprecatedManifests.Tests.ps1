BeforeAll {
    $root = Join-Path $PSScriptRoot '..'
    $archive = Join-Path $root 'deprecated'
    $readme = Get-Content (Join-Path $root 'README.md') -Raw -Encoding UTF8
    if (-not $env:SCOOP_HOME) { throw 'SCOOP_HOME must point to the Scoop source used by bucket tests.' }
    Add-Type -Path (Join-Path $env:SCOOP_HOME 'supporting/validator/bin/Scoop.Validator.dll')
    $schemaPath = (Join-Path $env:SCOOP_HOME 'schema.json') -replace '\\', '/'
    $validator = New-Object Scoop.Validator($schemaPath, $true)
}

Describe 'Unavailable upstreams are deprecated rather than silently exempted from checks' {
    It '<Name> is archived outside the active bucket and remains schema-valid' -TestCases @(
        @{ Name = 'pidkey' }
        @{ Name = 'ztasker' }
    ) {
        param($Name)
        Test-Path (Join-Path $root "bucket/$Name.json") | Should -BeFalse
        $path = Join-Path $archive "$Name.json"
        Test-Path $path | Should -BeTrue
        $validator.Validate($path) | Should -BeTrue -Because $validator.ErrorsAsString
        $validator.Errors.Count | Should -Be 0
        $manifest = Get-Content $path -Raw -Encoding UTF8 | ConvertFrom-Json
        $manifest.checkver | Should -BeNullOrEmpty
        $manifest.autoupdate | Should -BeNullOrEmpty
        $notes = $manifest.notes -join "`n"
        $notes | Should -Match 'Deprecated on 2026-11-09'
        $notes | Should -Match '404'
        $notes | Should -Match 'reference only'
        $notes | Should -Match 'not a supported installation source'
        $notes | Should -Match 'Existing installations.*not removed'
        [regex]::IsMatch($readme, "(?i)scoop install (?:vi/)?$Name\b") | Should -BeFalse -Because 'deprecated apps must not be advertised as installable'
        $readme | Should -Match '(?i)deprecated'
    }

    It 'preserves the last known PidKey version, origin, hash and persisted data' {
        $manifest = Get-Content (Join-Path $archive 'pidkey.json') -Raw -Encoding UTF8 | ConvertFrom-Json
        $manifest.version | Should -Be '4.0.2'
        $manifest.homepage | Should -Be 'https://github.com/laomms/PidKeyTool'
        $manifest.url | Should -Be 'https://github.com/laomms/PidKeyTool/releases/download/4.0.2/PidKeyTool.V4.0.2.exe'
        $manifest.hash | Should -Be '466ddfe3b07c20c40e2f226e580b7651d375b4ae1f28e5cf93c2e5984950a2d1'
        $manifest.persist | Should -Be 'KeyList.db'
        ($manifest.notes -join "`n") | Should -Match 'No replacement download has been verified'
    }

    It 'preserves zTasker provenance without substituting an unverified newer package' {
        $manifest = Get-Content (Join-Path $archive 'ztasker.json') -Raw -Encoding UTF8 | ConvertFrom-Json
        $manifest.version | Should -Be '2.2.8'
        $manifest.url | Should -Be 'http://everauto.net:8080/up/zTasker_2.2.8_%E7%BB%BF%E8%89%B2%E7%89%88.7z'
        $manifest.hash | Should -Be 'd5e7d2c9e97818506cc84f58ae83aa79af02269d9709801dc598485f94f6cbfe'
        ($manifest.persist -join ',') | Should -Be 'User,Data'
        $notes = $manifest.notes -join "`n"
        $notes | Should -Match 'TLS hostname'
        $notes | Should -Match '403'
        $notes | Should -Match 'https://www\.everauto\.net/wddown\.html'
        $notes | Should -Match 'temporary URL'
        $manifest.url | Should -Not -Match 'lanzou|lanrar|wddown\.html'
    }
}
