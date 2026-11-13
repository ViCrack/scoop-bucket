# 显式 checkver.url 请求是匿名的，共享 runner IP 上很容易被 GitHub 限流（HTTP 403）。
# 打 api.github.com 的清单必须写成 checkver.github，checkver 才会带上 token。
BeforeAll {
    $bucket = Join-Path $PSScriptRoot '../bucket'

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

    It 'reads release lists with an explicit jsonpath instead of the /latest default' {
        # GitHub API 模式默认 jsonpath 是 $.tag_name，只对 /releases/latest 这种单对象响应有效；
        # /releases 返回数组，必须在清单里显式写 jsonpath，否则提取不到版本。
        $offenders = Get-ChildItem -Path $bucket -Filter '*.json' -File | ForEach-Object {
            try { $manifest = Get-Content $_.FullName -Raw -Encoding UTF8 | ConvertFrom-Json } catch { return }
            $checkver = $manifest.checkver
            if ($checkver -isnot [PSCustomObject]) { return }
            $github = $checkver.github
            if (-not $github -or $github -notlike '*api.github.com*') { return }
            if ($github -like '*/releases/latest' -or $github -like '*/releases/latest*') { return }
            if ($checkver.script) { return }
            if (-not ($checkver.jsonpath -or $checkver.jp)) { $_.Name }
        }
        $offenders | Should -BeNullOrEmpty
    }
}
