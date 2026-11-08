BeforeAll {
    $bucket = Join-Path $PSScriptRoot '../bucket'
    function Read-GitHubManifest([string] $Name) {
        $manifest = Get-Content (Join-Path $bucket "$Name.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        # Fixture versions must not track future automatic manifest updates.
        $versions = @{
            'cyberapi' = '0.6.0'; 'mitan' = '2.0.8'; 'trilium-cn' = '0.64.1.20261106'
            'memshellparty' = '3.0.0'; 'termix' = '26.11.0'
        }
        $manifest.version = $versions[$Name]
        return $manifest
    }
    function New-ReleaseFixture([string] $Tag, [string] $Repo, [string[]] $Assets, [bool] $Prerelease = $false, [bool] $Draft = $false) {
        [pscustomobject]@{
            tag_name = $Tag; draft = $Draft; prerelease = $Prerelease
            assets = @($Assets | ForEach-Object {
                [pscustomobject]@{ name = $_; state = 'uploaded'; browser_download_url = "https://github.com/$Repo/releases/download/$Tag/$_" }
            })
        }
    }
    function Invoke-ReleaseFixture($Manifest, $Releases) {
        $json = $Manifest
        $page = ConvertTo-Json -InputObject @($Releases) -Depth 8 -Compress
        if (!$Manifest.checkver.script) { throw 'Asset-aware checkver script is required.' }
        $output = & ([scriptblock]::Create($Manifest.checkver.script -join "`n"))
        $match = [regex]::Match(($output -join "`n"), $Manifest.checkver.regex)
        if (!$match.Success) { throw 'Release selection did not match the version expression.' }
        $version = $match.Groups['version'].Value
        if ($Manifest.checkver.replace) { $version = $match.Result($Manifest.checkver.replace) }
        [pscustomobject]@{ Version = $version; Match = $match; Regex = [regex] $Manifest.checkver.regex }
    }
    function Expand-ReleaseTemplate([string] $Template, $Result) {
        $expanded = $Template.Replace('$version', $Result.Version)
        foreach ($name in $Result.Regex.GetGroupNames()) {
            $group = $Result.Match.Groups[$name]
            if ($name -match '^\d+$') { continue }
            $variable = '$match' + $name.Substring(0, 1).ToUpperInvariant() + $name.Substring(1)
            $expanded = $expanded.Replace($variable, $group.Value)
        }
        return $expanded
    }
}

Describe 'GitHub release asset regressions' {
    It 'selects the latest CyberAPI desktop ZIP, excluding empty, draft, nightly and CLI-only releases' {
        $manifest = Read-GitHubManifest 'cyberapi'
        $releases = @(
            (New-ReleaseFixture 'v0.6.1' 'vicanso/cyberapi' @()),
            (New-ReleaseFixture 'v0.8.0' 'vicanso/cyberapi' @('cyberapi-0.8.0-x86_64-pc-windows-msvc.zip') $true),
            (New-ReleaseFixture 'v0.7.0' 'vicanso/cyberapi' @('cyberapi-0.7.0-x86_64-pc-windows-msvc.zip') $false $true),
            (New-ReleaseFixture 'v0.6.2' 'vicanso/cyberapi' @('cyberapi-cli-0.6.2-x86_64-pc-windows-msvc.zip')),
            (New-ReleaseFixture 'v0.6.0' 'vicanso/cyberapi' @('cyberapi-0.6.0-x86_64-pc-windows-msvc.zip')),
            (New-ReleaseFixture 'v0.5.0' 'vicanso/cyberapi' @('cyberapi-0.5.0-x86_64-pc-windows-msvc.zip'))
        )
        $result = Invoke-ReleaseFixture $manifest $releases
        $result.Version | Should -Be '0.6.0'
        Expand-ReleaseTemplate $manifest.autoupdate.architecture.'64bit'.url $result | Should -Be $releases[4].assets[0].browser_download_url
        Expand-ReleaseTemplate $manifest.autoupdate.extract_dir $result | Should -Be 'cyberapi-0.6.0-x86_64-pc-windows-msvc'
        $manifest.shortcuts[0][0] | Should -Be 'cyberapi.exe'
    }

    It 'fails closed when CyberAPI has no compatible stable asset' {
        $manifest = Read-GitHubManifest 'cyberapi'
        { Invoke-ReleaseFixture $manifest @((New-ReleaseFixture 'v0.6.1' 'vicanso/cyberapi' @())) } | Should -Throw
    }

    It 'does not automatically downgrade CyberAPI when a newer asset disappears' {
        $manifest = Read-GitHubManifest 'cyberapi'
        $manifest.version = '0.7.0'
        { Invoke-ReleaseFixture $manifest @((New-ReleaseFixture 'v0.6.0' 'vicanso/cyberapi' @('cyberapi-0.6.0-x86_64-pc-windows-msvc.zip'))) } | Should -Throw
    }

    It 'uses the native Mitan Windows x64 asset rather than the obsolete Java launcher' {
        $manifest = Read-GitHubManifest 'mitan'
        $release = New-ReleaseFixture '2.0.8' 'kkbo8005/mitan' @('mitan_aarch64-pc-windows-msvc-setup.exe', 'mitan_x86_64-pc-windows-msvc-setup.exe')
        $result = Invoke-ReleaseFixture $manifest @($release)
        $result.Version | Should -Be '2.0.8'
        Expand-ReleaseTemplate $manifest.autoupdate.architecture.'64bit'.url $result | Should -Be ($release.assets[1].browser_download_url + '#/dl.7z')
        $manifest.shortcuts[0][0] | Should -Be 'mitan.exe'
        ($manifest.pre_install -join "`n") | Should -Not -Match 'java|jar-with-dependencies'
        $manifest.suggest.JDK | Should -BeNullOrEmpty
        $manifest.suggest.WebView2 | Should -Contain 'extras/webview2'
        $manifest.nsis | Should -BeNullOrEmpty
    }

    It 'keeps the full Trilium dated tag while selecting the new Windows 7z asset' {
        $manifest = Read-GitHubManifest 'trilium-cn'
        $release = New-ReleaseFixture 'v0.64.1_20261106' 'Nriver/trilium-translation' @('trilium-windows-x64-0.64.1-cn.7z')
        $result = Invoke-ReleaseFixture $manifest @($release)
        $result.Version | Should -Be '0.64.1.20261106'
        Expand-ReleaseTemplate $manifest.autoupdate.architecture.'64bit'.url $result | Should -Be $release.assets[0].browser_download_url
        $manifest.extract_dir | Should -Be 'trilium-windows-x64'
        $manifest.persist | Should -Be 'trilium-data'
    }

    It 'tracks a same-version Trilium translation rebuild as an update' {
        $manifest = Read-GitHubManifest 'trilium-cn'
        $release = New-ReleaseFixture 'v0.64.1_20261107' 'Nriver/trilium-translation' @('trilium-windows-x64-0.64.1-cn.7z')
        (Invoke-ReleaseFixture $manifest @($release)).Version | Should -Be '0.64.1.20261107'
    }

    It 'uses the renamed MemShellParty boot JAR in its canonical repository' {
        $manifest = Read-GitHubManifest 'memshellparty'
        $release = New-ReleaseFixture 'v3.0.0' 'MemShellParty/MemShellParty' @('memshell-party-gui-3.0.0.jar', 'memshell-party-boot-3.0.0.jar')
        $result = Invoke-ReleaseFixture $manifest @($release)
        $result.Version | Should -Be '3.0.0'
        Expand-ReleaseTemplate $manifest.autoupdate.url $result | Should -Be $release.assets[1].browser_download_url
        ($manifest.pre_install -join "`n") | Should -Match 'memshell-party-boot-\$version\.jar'
        ($manifest.pre_install -join "`n") | Should -Match '(?i)version|release'
        ($manifest.pre_install -join "`n") | Should -Match '(?i)17'
        ($manifest.pre_install -join "`n") | Should -Not -Match 'JDK_11_HOME'
    }

    It 'selects Termix app releases only after both Windows architectures are uploaded' {
        $manifest = Read-GitHubManifest 'termix'
        $both = @('termix_windows_ia32_portable.zip', 'termix_windows_x64_portable.zip')
        $releases = @(
            (New-ReleaseFixture 'sdk-v1.1.3' 'Termix-SSH/Termix' @()),
            (New-ReleaseFixture 'v26.11.2' 'Termix-SSH/Termix' $both $false $true),
            (New-ReleaseFixture 'v26.11.1-beta.1' 'Termix-SSH/Termix' $both $true),
            (New-ReleaseFixture 'v26.11.1' 'Termix-SSH/Termix' @('termix_windows_x64_portable.zip')),
            (New-ReleaseFixture 'v26.11.0' 'Termix-SSH/Termix' $both)
        )
        $result = Invoke-ReleaseFixture $manifest $releases
        $result.Version | Should -Be '26.11.0'
        Expand-ReleaseTemplate $manifest.autoupdate.architecture.'32bit'.url $result | Should -Be $releases[4].assets[0].browser_download_url
        Expand-ReleaseTemplate $manifest.autoupdate.architecture.'64bit'.url $result | Should -Be $releases[4].assets[1].browser_download_url
        $manifest.shortcuts[0][0] | Should -Be 'Termix.exe'
    }

    It 'preserves a legacy Termix release tag without inventing a renamed URL' {
        $manifest = Read-GitHubManifest 'termix'
        $manifest.version = '2.9.2'
        $release = New-ReleaseFixture 'release-2.9.2-tag' 'Termix-SSH/Termix' @('termix_windows_ia32_portable.zip', 'termix_windows_x64_portable.zip')
        $result = Invoke-ReleaseFixture $manifest @($release)
        $result.Version | Should -Be '2.9.2'
        Expand-ReleaseTemplate $manifest.autoupdate.architecture.'64bit'.url $result | Should -Be $release.assets[1].browser_download_url
    }

    It 'fails closed for Termix releases missing an advertised architecture' {
        $manifest = Read-GitHubManifest 'termix'
        { Invoke-ReleaseFixture $manifest @((New-ReleaseFixture 'v26.11.1' 'Termix-SSH/Termix' @('termix_windows_x64_portable.zip'))) } | Should -Throw
    }

    It 'runs the MemShellParty launcher only with a supported JDK and preserves its exit code' -Skip:(!$env:WINDIR) {
        $manifest = Read-GitHubManifest 'memshellparty'
        $source = Join-Path $TestDrive 'FakeJava.cs'
        $stub = Join-Path $TestDrive 'java.exe'
        @'
using System;
public static class FakeJava {
    public static int Main(string[] args) {
        if (args.Length == 1 && args[0] == "-version") {
            Console.Error.WriteLine("openjdk version \"" + Environment.GetEnvironmentVariable("FAKE_JAVA_VERSION") + "\"");
            return 0;
        }
        Console.WriteLine("LAUNCHED:" + String.Join("|", args));
        return 23;
    }
}
'@ | Set-Content -Path $source -Encoding UTF8
        $compiler = Join-Path $env:WINDIR 'Microsoft.NET/Framework64/v4.0.30319/csc.exe'
        & $compiler /nologo /target:exe "/out:$stub" $source
        $LASTEXITCODE | Should -Be 0
        $dir = Join-Path $TestDrive 'application with spaces'
        $jdk = Join-Path $TestDrive 'jdk with spaces'
        New-Item -ItemType Directory -Path $dir, "$jdk/bin" -Force | Out-Null
        Copy-Item $stub "$jdk/bin/java.exe"
        $version = '99.8.7'
        & ([scriptblock]::Create($manifest.pre_install -join "`n"))
        $names = 'JDK_25_HOME', 'JDK_21_HOME', 'JDK_19_HOME', 'JDK_17_HOME', 'JDK_11_HOME', 'JAVA_HOME', 'FAKE_JAVA_VERSION'
        $saved = @{}
        foreach ($name in $names) {
            $saved[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
            [Environment]::SetEnvironmentVariable($name, $null, 'Process')
        }
        try {
            $env:JAVA_HOME = $jdk
            $env:FAKE_JAVA_VERSION = '11.0.20'
            $output = & $env:ComSpec /d /c "`"$dir/memshellparty.bat`"" 2>&1
            $LASTEXITCODE | Should -Be 1
            ($output -join "`n") | Should -Match 'too old'
            ($output -join "`n") | Should -Not -Match 'LAUNCHED:'
            $env:JDK_17_HOME = $jdk
            $env:JDK_11_HOME = Join-Path $TestDrive 'obsolete jdk'
            $env:JAVA_HOME = $env:JDK_11_HOME
            $env:FAKE_JAVA_VERSION = '17.0.12'
            $output = & $env:ComSpec /d /c "`"$dir/memshellparty.bat`"" 2>&1
            $LASTEXITCODE | Should -Be 23
            ($output -join "`n") | Should -Match ('LAUNCHED:.*-jar\|' + [regex]::Escape("memshell-party-boot-$version.jar"))
            ($output -join "`n") | Should -Match '--add-opens=java.base/java.util=ALL-UNNAMED'
            $env:FAKE_JAVA_VERSION = 'invalid'
            $output = & $env:ComSpec /d /c "`"$dir/memshellparty.bat`"" 2>&1
            $LASTEXITCODE | Should -Be 1
            ($output -join "`n") | Should -Not -Match 'LAUNCHED:'
        } finally {
            foreach ($name in $names) { [Environment]::SetEnvironmentVariable($name, $saved[$name], 'Process') }
        }
    }
}
