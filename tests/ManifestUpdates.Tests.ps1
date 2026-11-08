BeforeAll {
    $bucket = Join-Path $PSScriptRoot '../bucket'
    function Read-Manifest([string] $Name) {
        Get-Content (Join-Path $bucket "$Name.json") -Raw -Encoding UTF8 | ConvertFrom-Json
    }
    function Get-CheckedVersion($Manifest, [string] $Page) {
        $match = [regex]::Match($Page, $Manifest.checkver.regex)
        $match.Success | Should -BeTrue
        if ($Manifest.checkver.replace) { return $match.Result($Manifest.checkver.replace) }
        if ($match.Groups['version'].Success) { return $match.Groups['version'].Value }
        return $match.Groups[1].Value
    }
}

Describe 'Official download page regressions' {
    It 'reads the full EmEditor patch version from the official update metadata' {
        $manifest = Read-Manifest 'emeditor'
        $manifest.checkver.url | Should -Be 'https://download.emeditor.com/emeditor64.appinstaller'
        Get-CheckedVersion $manifest '<MainPackage Version="26.4.2.0" Uri="https://download.emeditor.com/emed64_26.4.2.msix" />' | Should -Be '26.4.2'
        $manifest.autoupdate.architecture.'64bit'.url.Replace('$version', '26.4.2') | Should -Be 'https://download.emeditor.com/emed64_26.4.2_portable.zip'
        $manifest.autoupdate.architecture.'32bit' | Should -BeNullOrEmpty
    }

    It 'finds PixPin on its dedicated download page with the Windows filename' {
        $manifest = Read-Manifest 'pixpin'
        $manifest.checkver.url | Should -Be 'https://pixpin.cn/download/'
        Get-CheckedVersion $manifest '<a href="https://down.pixpin.cn/PixPin_win_3.6.6.0.zip">Windows portable</a>' | Should -Be '3.6.6.0'
        $manifest.autoupdate.architecture.'64bit'.url.Replace('$version', '3.6.6.0') | Should -Be 'https://down.pixpin.cn/PixPin_win_3.6.6.0.zip'
        $manifest.innosetup | Should -BeNullOrEmpty
    }

    It 'uses the VeryCapture download host published on the official page' {
        $manifest = Read-Manifest 'verycapture'
        Get-CheckedVersion $manifest '<a href="https://ppocr.com/download/verycapture2.2.0.zip">Download</a>' | Should -Be '2.2.0'
        $manifest.autoupdate.url.Replace('$version', '2.2.0') | Should -Be 'https://ppocr.com/download/verycapture2.2.0.zip'
        $manifest.extract_dir | Should -BeNullOrEmpty
    }

    It 'uses the zTasker portable archive rather than the obsolete port 8080 path' {
        $manifest = Read-Manifest 'ztasker'
        $filename = 'zTasker_2.3.14_%E7%BB%BF%E8%89%B2%E7%89%88_%E4%B8%8D%E8%A6%81%E6%94%BEC%E7%9B%98.7z'
        Get-CheckedVersion $manifest $filename | Should -Be '2.3.14'
        Get-CheckedVersion $manifest ([uri]::UnescapeDataString($filename)) | Should -Be '2.3.14'
        $manifest.autoupdate.url.Replace('$version', '2.3.14') | Should -Be "https://www.everauto.net/down/$filename"
    }

    It 'does not pretend the W3Cschool cloud-drive page exposes an update feed' {
        $manifest = Read-Manifest 'w3cschool'
        $manifest.checkver | Should -BeNullOrEmpty
        $manifest.autoupdate | Should -BeNullOrEmpty
        $manifest.notes | Should -Match '2\.3\.0'
        $manifest.hash | Should -Be 'caf37da1cb5aa1f472fec4d093392141e14715d8a0285fcc4717f9ff76c1cc02'
    }
}
