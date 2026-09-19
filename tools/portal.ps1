param([string]$Engine = $env:GODOT_EXE, [switch]$Check, [switch]$Tour, [switch]$Classic)
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
if (-not $Engine) {
    $candidates = @(
        (Join-Path $repo '.tools\godot\Godot_v4.7.2-stable_win64_console.exe'),
        'D:\worldxxxxx\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe'
    )
    $Engine = $candidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
}
if (-not $Engine -or -not (Test-Path -LiteralPath $Engine)) { throw 'Set GODOT_EXE or use -Engine with a Godot 4.7 executable.' }
$project = Join-Path $repo 'project'
$logs = Join-Path $repo 'build'
New-Item -ItemType Directory -Force $logs | Out-Null
Write-Output ('Engine: ' + (& $Engine --version))
if ($Check -or $Tour) {
    & $Engine --headless --path $project --editor --import --quit *> (Join-Path $logs 'portal-import.log')
    if ($LASTEXITCODE -ne 0 -or (Select-String -LiteralPath (Join-Path $logs 'portal-import.log') -Pattern 'SCRIPT ERROR|^ERROR:')) { throw 'Import failed. Read build/portal-import.log.' }
    $runs = @(@{ Script = 'test_portal_magic'; Log = 'portal-magic-tour'; Headless = $false })
    if ($Classic) { $runs = @(@{ Script = 'playtest_portal001'; Log = 'portal-tour'; Headless = $false }) }
    if ($Check) {
        $runs = @(
            @{ Script = 'test_portal001'; Log = 'portal-tests'; Headless = $true },
            @{ Script = 'test_portal_magic'; Log = 'portal-magic-tests'; Headless = $true }
        )
    }
    foreach ($run in $runs) {
        $arguments = @('--path',$project,'--quit-after','16000','--script',('res://scripts/debug/' + $run.Script + '.gd'))
        if ($run.Headless) { $arguments += @('--headless','--fixed-fps','120') }
        $log = Join-Path $logs ($run.Log + '.log')
        & $Engine @arguments *> $log
        $result = Select-String -LiteralPath $log -Pattern '^RESULT'
        if ($LASTEXITCODE -ne 0 -or -not $result -or (Select-String -LiteralPath $log -Pattern '^FAIL|SCRIPT ERROR|^ERROR:|WARNING:.*leak')) { throw "Portal validation failed or incomplete. Read $log" }
        $result | ForEach-Object { $_.Line }
    }
} else {
    & $Engine --path $project 'res://scenes/portal/Portal_Playground.tscn'
}
