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
    It 'keeps the actual Behinder asset filename instead of assuming it equals its release tag' {
        $manifest = Read-Manifest 'behinder'
        $asset = 'https://github.com/rebeyond/Behinder/releases/download/Behinder_v4.0.7/Behinder_v4.07.zip'
        $match = [regex]::Match($asset, $manifest.checkver.regex)
        $match.Success | Should -BeTrue
        $match.Result($manifest.checkver.replace) | Should -Be '4.0.7'
        $manifest.autoupdate.url.Replace('$matchUrl', $match.Groups['url'].Value) | Should -Be $asset
        [regex]::IsMatch('https://github.com/rebeyond/Behinder/releases/download/Behinder_v4.1%E3%80%90t00ls%E4%B8%93%E7%89%88%E3%80%91/Behinder_v4.1.t00ls.zip', $manifest.checkver.regex) | Should -BeFalse
    }

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

    It 'does not pretend the W3Cschool cloud-drive page exposes an update feed' {
        $manifest = Read-Manifest 'w3cschool'
        $manifest.checkver | Should -BeNullOrEmpty
        $manifest.autoupdate | Should -BeNullOrEmpty
        $manifest.notes | Should -Match '2\.3\.0'
        $manifest.hash | Should -Be 'caf37da1cb5aa1f472fec4d093392141e14715d8a0285fcc4717f9ff76c1cc02'
    }
}

Describe 'Upstream asset renames' {
    It 'keeps BlueTeamTools on the current release asset name' {
        $manifest = Read-Manifest 'blueteamtools'
        $manifest.autoupdate.url.Replace('$version', '5.11') | Should -Be 'https://github.com/abc123info/BlueTeamTools/releases/download/v5.11/BlueTeamToolsV5.11.zip'
        $manifest.url | Should -Be $manifest.autoupdate.url.Replace('$version', $manifest.version)
    }

    It 'extracts the renamed frpc-desktop NSIS payload instead of the old app-64.7z' {
        $manifest = Read-Manifest 'frpc-desktop'
        $manifest.autoupdate.architecture.'64bit'.url.Replace('$version', '2.0.0') | Should -Be 'https://github.com/luckjiawei/frpc-desktop/releases/download/v2.0.0/Frpc-Desktop_2.0.0_x64-setup.exe#/dl.7z'
        $preInstall = ($manifest.architecture.'64bit'.pre_install -join "`n")
        $preInstall | Should -Not -Match 'app-64\.7z'
        $preInstall | Should -Match 'frpc-desktop\.exe'
        $manifest.shortcuts[0][0] | Should -Be 'Frpc-Desktop.exe'
    }
}

Describe 'BlueTeamTools launcher' {
    It 'publishes the renamed jar from the 5.11 archive through the launcher' {
        $manifest = Read-Manifest 'blueteamtools'
        $preInstall = ($manifest.pre_install -join "`n")
        # 上游 5.11 的 zip 里只有 BlueTeamToolsV<版本>.jar，旧写法引用的 BlueTeam_ABC_123.jar 已不存在
        $preInstall | Should -Match 'BlueTeamToolsV\$version\.jar'
        $preInstall | Should -Not -Match 'BlueTeam_ABC_123\.jar'
    }
}
