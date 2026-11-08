#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.2.0' }

if (!$env:SCOOP_HOME) { $env:SCOOP_HOME = Resolve-Path (scoop prefix scoop) }
$testPaths = @("$PSScriptRoot/../Bucket.Tests.ps1")
$testPaths += @(Get-ChildItem "$PSScriptRoot/../tests" -Filter '*.Tests.ps1' -File | Select-Object -ExpandProperty FullName)
$result = Invoke-Pester -Path $testPaths -PassThru
# 即使未运行任何测试，发现阶段或容器错误也必须使 CI 失败。
if ($result.Result -ne 'Passed') { exit 1 }
exit 0
