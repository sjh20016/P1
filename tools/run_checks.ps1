param([switch]$Stress, [switch]$Rnd)
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$engine = Join-Path $repo '.tools\godot\Godot_v4.7.2-stable_win64_console.exe'
$project = Join-Path $repo 'project'
$logs = Join-Path $repo 'build'
$version = & $engine --version
if ($version -notmatch '^4\.7\.2\.stable') { throw "Godot 4.7.2 Stable required, found $version" }
& $engine --headless --path $project --editor --import --quit *> (Join-Path $logs 'check-import.log')
if ($LASTEXITCODE -ne 0 -or (Select-String -LiteralPath (Join-Path $logs 'check-import.log') -Pattern 'SCRIPT ERROR|^ERROR:')) {
    Get-Content -LiteralPath (Join-Path $logs 'check-import.log') -Tail 40
    throw 'Godot import failed'
}
$tests = @('movement','grapple','destruction','sweep','vfx','lifecycle','full_world','ink_marks')
if ($Rnd) { $tests += @('rnd_targeting','rnd_movement','rnd_impact_recovery','rnd_course') }
if ($Stress) { $tests += 'integration' }
foreach ($test in $tests) {
    $log = Join-Path $logs "check-$test.log"
    & $engine --headless --path $project --script "res://scripts/debug/test_$test.gd" *> $log
    $code = $LASTEXITCODE
    $errors = Select-String -LiteralPath $log -Pattern '^FAIL|SCRIPT ERROR|^ERROR:|WARNING:.*leak'
    if ($code -ne 0 -or $errors) {
        Get-Content -LiteralPath $log -Tail 40
        throw "Test failed: $test ($code)"
    }
    Select-String -LiteralPath $log -Pattern 'RESULT|METRICS' | ForEach-Object { $_.Line }
}
Write-Output 'ALL CHECKS PASSED'
