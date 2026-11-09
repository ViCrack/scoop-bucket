Describe 'Pester runner contract' {
    BeforeAll {
        $scriptText = Get-Content "$PSScriptRoot/../bin/test.ps1" -Raw -Encoding UTF8
        $tokens = $null
        $errors = $null
        $ast = [Management.Automation.Language.Parser]::ParseInput($scriptText, [ref] $tokens, [ref] $errors)
    }

    It 'requires the same Pester major version as current Scoop tests' {
        $requirement = $ast.ScriptRequirements.RequiredModules | Where-Object Name -eq 'Pester'
        $requirement.Version | Should -BeGreaterOrEqual ([version] '5.2.0')
        $requirement.MaximumVersion | Should -BeNullOrEmpty
    }

    It 'does not recursively discover cached dependency tests' {
        $scriptText | Should -Match 'Bucket\.Tests\.ps1'
        $scriptText | Should -Match 'Get-ChildItem.*tests.*-Filter'
        $scriptText | Should -Not -Match 'Invoke-Pester\s+"\$PSScriptRoot/\.\."'
    }

    It 'fails on discovery errors even when FailedCount would be zero' {
        $scriptText | Should -Match '\$result\.Result -ne ''Passed'''
        $scriptText | Should -Not -Match 'exit \$result\.FailedCount'
    }
}
