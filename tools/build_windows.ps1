$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$engine = Join-Path $repo '.tools\godot\Godot_v4.7.2-stable_win64_console.exe'
$version = & $engine --version
if ($version -notmatch '^4\.7\.2\.stable') { throw "Godot 4.7.2 Stable required, found $version" }
$output = Join-Path $repo 'build\RAVAGE-0.01-Windows'
New-Item -ItemType Directory -Force -Path $output | Out-Null
& $engine --headless --path (Join-Path $repo 'project') --export-release 'Windows Desktop' (Join-Path $output 'RAVAGE.exe')
if ($LASTEXITCODE -ne 0) { throw 'Godot export failed' }
Copy-Item -LiteralPath (Join-Path $repo 'README.md') -Destination (Join-Path $output 'README.zh-CN.md')
Copy-Item -LiteralPath (Join-Path $repo 'docs\THIRD_PARTY.md') -Destination $output
Copy-Item -LiteralPath (Join-Path $repo 'docs\GODOT_LICENSE.txt') -Destination $output
Copy-Item -LiteralPath (Join-Path $repo 'docs\GODOT_COPYRIGHT.txt') -Destination $output
Write-Output "BUILD: $output"
