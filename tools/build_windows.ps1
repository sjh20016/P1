param([string]$Version = '0.07')
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$expectedVersion = @{ '0.04'='0.0.4'; '0.05'='0.0.5'; '0.06'='0.0.6'; '0.07'='0.0.7' }[$Version]
$versionLine = Select-String -LiteralPath (Join-Path $repo 'project\project.godot') -Pattern '^config/version="([^"]+)"'
if (-not $expectedVersion -or $versionLine.Matches[0].Groups[1].Value -ne $expectedVersion) {
    throw "Requested release $Version does not match project.godot. Use the matching source snapshot."
}
$engine = Join-Path $repo '.tools\godot\Godot_v4.7.2-stable_win64_console.exe'
$engineVersion = & $engine --version
if ($engineVersion -notmatch '^4\.7\.2\.stable') { throw "Godot 4.7.2 Stable required, found $engineVersion" }
$output = Join-Path $repo "build\RAVAGE-$Version-Windows"
New-Item -ItemType Directory -Force -Path $output | Out-Null
$importLog = Join-Path $repo "build\import-$Version.log"
$exportLog = Join-Path $repo "build\export-$Version.log"
& $engine --headless --path (Join-Path $repo 'project') --editor --import --quit *> $importLog
if ($LASTEXITCODE -ne 0 -or (Select-String -LiteralPath $importLog -Pattern 'SCRIPT ERROR|^ERROR:')) {
    Get-Content -LiteralPath $importLog -Tail 60
    throw 'Godot pre-export import failed'
}
& $engine --headless --path (Join-Path $repo 'project') --export-release 'Windows Desktop' (Join-Path $output 'RAVAGE.exe') *> $exportLog
if ($LASTEXITCODE -ne 0 -or (Select-String -LiteralPath $exportLog -Pattern 'SCRIPT ERROR|^ERROR:')) {
    Get-Content -LiteralPath $exportLog -Tail 60
    throw 'Godot export failed'
}
Copy-Item -LiteralPath (Join-Path $repo 'README.md') -Destination (Join-Path $output 'README.zh-CN.md')
Copy-Item -LiteralPath (Join-Path $repo 'docs\THIRD_PARTY.md') -Destination $output
Copy-Item -LiteralPath (Join-Path $repo 'docs\GODOT_LICENSE.txt') -Destination $output
Copy-Item -LiteralPath (Join-Path $repo 'docs\GODOT_COPYRIGHT.txt') -Destination $output
Copy-Item -LiteralPath (Join-Path $repo 'docs\FONT_OFL.txt') -Destination $output
$guide = Join-Path $output 'docs'
New-Item -ItemType Directory -Force -Path $guide | Out-Null
foreach ($name in @('VALIDATION.md','VALIDATION-0.01.md','VALIDATION-0.02.md','VALIDATION-0.03.md','ART_DIRECTION.zh-CN.md','RELEASE_NOTES.zh-CN.md')) {
    Copy-Item -LiteralPath (Join-Path $repo "docs\$name") -Destination $guide
}
$rnd = Join-Path $guide 'rnd003'
New-Item -ItemType Directory -Force -Path $rnd | Out-Null
Copy-Item -Path (Join-Path $repo 'docs\rnd003\*.md') -Destination $rnd
$evidence = Join-Path $repo 'docs\rnd003\evidence'
if (Test-Path -LiteralPath $evidence) { Copy-Item -LiteralPath $evidence -Destination $rnd -Recurse -Force }
$rnd004 = Join-Path $guide 'rnd004'
New-Item -ItemType Directory -Force -Path $rnd004 | Out-Null
Copy-Item -Path (Join-Path $repo 'docs\rnd004\*.md') -Destination $rnd004
$evidence004 = Join-Path $repo 'docs\rnd004\evidence'
if (Test-Path -LiteralPath $evidence004) { Copy-Item -LiteralPath $evidence004 -Destination $rnd004 -Recurse -Force }
Write-Output "BUILD: $output"
foreach ($iteration in @('rnd005','rnd006','rnd007')) {
    $source = Join-Path $repo "docs\$iteration"
    if (Test-Path -LiteralPath $source) { Copy-Item -LiteralPath $source -Destination $guide -Recurse -Force }
}
