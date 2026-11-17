$ErrorActionPreference = 'Stop'
$projectDirectory = $PSScriptRoot
$engine = Get-Command 'Godot*_win64.exe','godot.exe','godot4.exe' -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $engine) {
    Write-Host 'Godot 4 is required. Import project.godot in the Godot Project Manager and press F5, or add Godot to PATH.'
    exit 1
}
$env:APPDATA = Join-Path $projectDirectory '.runtime'
$env:LOCALAPPDATA = Join-Path $env:APPDATA 'local'
$env:TEMP = Join-Path $env:APPDATA 'temp'
$env:TMP = $env:TEMP
New-Item -ItemType Directory -Force -Path $env:APPDATA,$env:LOCALAPPDATA,$env:TEMP | Out-Null
& $engine.Source --headless --path $projectDirectory --editor --import --quit
& $engine.Source --path $projectDirectory
