#Requires -Version 7.0
# 公开仓库的防泄漏守卫：任何清单、脚本、工作流里都不允许出现真实凭据。
$ErrorActionPreference = 'Stop'

BeforeAll {
    $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
    $scanRoots = @('bucket', 'bin', 'tests', '.github', '.vscode') |
        ForEach-Object { Join-Path $repoRoot $_ } |
        Where-Object { Test-Path $_ }

    # 只匹配 GitHub 系 token 的固定前缀与显式凭据 URL，避免误报普通文本。
    $secretPatterns = @(
        'gho_[A-Za-z0-9]{20,}'
        'ghp_[A-Za-z0-9]{20,}'
        'github_pat_[A-Za-z0-9_]{20,}'
        'x-access-token:[^@\s]+@'
        'Authorization:\s*(?:basic|token|Bearer)\s+[A-Za-z0-9_.-]{16,}'
    )

    function Find-SecretHit {
        param([string[]] $Roots, [string[]] $Patterns)
        $hits = foreach ($root in $Roots) {
            Get-ChildItem -Path $root -Recurse -File |
                Where-Object { $_.Extension -in '.json', '.ps1', '.psm1', '.yml', '.yaml', '.md' -and $_.FullName -ne $PSCommandPath } |
                Select-String -Pattern $Patterns
        }
        return @($hits | ForEach-Object { "$($_.Path):$($_.LineNumber): $($_.Line.Trim())" })
    }
}

Describe '公开仓库不得携带凭据' {
    It '清单与脚本里没有 GitHub token 字面量、也没有带凭据的 URL 或认证头' {
        $hits = Find-SecretHit -Roots $scanRoots -Patterns $secretPatterns
        $hits | Should -BeNullOrEmpty
    }

    It 'checkver 只允许通过环境变量取 token，不允许把 token 内联进清单' {
        $manifests = Get-ChildItem -Path (Join-Path $repoRoot 'bucket') -Filter '*.json' -File
        $hits = $manifests | Select-String -Pattern 'SCOOP_GH_TOKEN\s*[:=]|"token"\s*:\s*"[^"]+' | ForEach-Object { "$($_.Path):$($_.LineNumber)" }
        $hits | Should -BeNullOrEmpty
    }
}
