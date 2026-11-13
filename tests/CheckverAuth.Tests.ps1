# 显式 checkver.url 请求是匿名的，共享 runner IP 上很容易被 GitHub 限流（HTTP 403）。
# 打 api.github.com 的清单必须写成 checkver.github，checkver 才会带上 token。
BeforeAll {
    $bucket = Join-Path $PSScriptRoot '../bucket'
}

Describe 'GitHub API manifests use the authenticated checkver mode' {
    It 'no manifest reads api.github.com through checkver.url' {
        $offenders = Get-ChildItem -Path $bucket -Filter '*.json' -File | ForEach-Object {
            try { $manifest = Get-Content $_.FullName -Raw -Encoding UTF8 | ConvertFrom-Json } catch { return }
            $checkver = $manifest.checkver
            if ($checkver -isnot [PSCustomObject]) { return }
            $url = $checkver.url
            if ($url -and $url -like '*api.github.com*') { $_.Name }
        }
        $offenders | Should -BeNullOrEmpty
    }

    It 'every checkver.github value names an owner and a repository' {
        $offenders = Get-ChildItem -Path $bucket -Filter '*.json' -File | ForEach-Object {
            try { $manifest = Get-Content $_.FullName -Raw -Encoding UTF8 | ConvertFrom-Json } catch { return }
            $checkver = $manifest.checkver
            if ($checkver -isnot [PSCustomObject]) { return }
            $github = $checkver.github
            if (-not $github) { return }
            if ($github -notmatch '^https://api\.github\.com/repos/[^/]+/[^/]+/.+$' -and
                $github -notmatch '^https://(www\.)?github\.com/[^/]+/[^/]+/?$') { $_.Name }
        }
        $offenders | Should -BeNullOrEmpty
    }
}
