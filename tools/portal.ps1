param([string]$Engine = $env:GODOT_EXE, [switch]$Check, [switch]$Tour)
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
    $arguments = @('--path',$project,'--script','res://scripts/debug/playtest_portal001.gd')
    $log = Join-Path $logs 'portal-tour.log'
    if ($Check) {
        $arguments = @('--headless','--path',$project,'--fixed-fps','120','--script','res://scripts/debug/test_portal001.gd')
        $log = Join-Path $logs 'portal-tests.log'
    }
    & $Engine @arguments *> $log
    if ($LASTEXITCODE -ne 0 -or (Select-String -LiteralPath $log -Pattern '^FAIL|SCRIPT ERROR|^ERROR:|WARNING:.*leak')) { throw "Portal validation failed. Read $log" }
    Select-String -LiteralPath $log -Pattern '^RESULT' | ForEach-Object { $_.Line }
} else {
    & $Engine --path $project 'res://scenes/portal/Portal_Playground.tscn'
}
