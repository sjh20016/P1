$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$engine = Join-Path $repo '.tools\godot\Godot_v4.7.2-stable_win64_console.exe'
$version = & $engine --version
if ($version -notmatch '^4\.7\.2\.stable') { throw "Godot 4.7.2 Stable required, found $version" }
$output = Join-Path $repo 'build\RAVAGE-0.03-Windows'
New-Item -ItemType Directory -Force -Path $output | Out-Null
& $engine --headless --path (Join-Path $repo 'project') --editor --import --quit
if ($LASTEXITCODE -ne 0) { throw 'Godot pre-export import failed' }
& $engine --headless --path (Join-Path $repo 'project') --export-release 'Windows Desktop' (Join-Path $output 'RAVAGE.exe')
if ($LASTEXITCODE -ne 0) { throw 'Godot export failed' }
Copy-Item -LiteralPath (Join-Path $repo 'README.md') -Destination (Join-Path $output 'README.zh-CN.md')
Copy-Item -LiteralPath (Join-Path $repo 'docs\THIRD_PARTY.md') -Destination $output
Copy-Item -LiteralPath (Join-Path $repo 'docs\GODOT_LICENSE.txt') -Destination $output
Copy-Item -LiteralPath (Join-Path $repo 'docs\GODOT_COPYRIGHT.txt') -Destination $output
$guide = Join-Path $output 'docs'
New-Item -ItemType Directory -Force -Path $guide | Out-Null
foreach ($name in @('VALIDATION.md','VALIDATION-0.01.md','VALIDATION-0.02.md','ART_DIRECTION.zh-CN.md','RELEASE_NOTES.zh-CN.md')) {
    Copy-Item -LiteralPath (Join-Path $repo "docs\$name") -Destination $guide
}
$rnd = Join-Path $guide 'rnd003'
New-Item -ItemType Directory -Force -Path $rnd | Out-Null
Copy-Item -Path (Join-Path $repo 'docs\rnd003\*.md') -Destination $rnd
$evidence = Join-Path $repo 'docs\rnd003\evidence'
if (Test-Path -LiteralPath $evidence) { Copy-Item -LiteralPath $evidence -Destination $rnd -Recurse -Force }
Write-Output "BUILD: $output"
