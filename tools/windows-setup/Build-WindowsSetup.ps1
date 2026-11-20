param(
    [Parameter(Mandatory=$true)][string]$GameZip,
    [Parameter(Mandatory=$true)][string]$Output
)

$ErrorActionPreference='Stop'
$GameZip=(Resolve-Path -LiteralPath $GameZip).Path
$Output=[IO.Path]::GetFullPath($Output)
$project=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$ico=Join-Path $project 'assets\charm-city-beatdown.ico'
$logo=Join-Path $project 'assets\logo.png'
$framework=Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319'
$compiler=Join-Path $framework 'csc.exe'
$staging=Join-Path $project ('.runtime\windows-setup-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $staging -Force | Out-Null
$uninstall=Join-Path $staging 'Uninstall.exe'
$compiled=Join-Path $staging 'CharmCityBeatdown-Setup.exe'
$core=Join-Path $PSScriptRoot 'InstallFiles.cs'
$references=@(
    '/reference:System.Windows.Forms.dll',
    '/reference:System.Drawing.dll',
    '/reference:Microsoft.CSharp.dll',
    '/reference:System.IO.Compression.dll'
)
try {
    & $compiler /nologo /target:winexe /platform:anycpu /optimize+ @references "/win32icon:$ico" "/out:$uninstall" $core (Join-Path $PSScriptRoot 'Uninstall.cs')
    if ($LASTEXITCODE -ne 0) {throw 'Uninstaller compilation failed'}
    & $compiler /nologo /target:winexe /platform:anycpu /optimize+ @references "/win32icon:$ico" "/out:$compiled" "/resource:$GameZip,Game.zip" "/resource:$logo,Logo.png" "/resource:$uninstall,Uninstall.exe" $core (Join-Path $PSScriptRoot 'Setup.cs')
    if ($LASTEXITCODE -ne 0) {throw 'Setup compilation failed'}
    [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($Output)) | Out-Null
    if (Test-Path -LiteralPath $Output) {
        [IO.File]::Replace($compiled,$Output,(Join-Path $staging 'previous.exe'))
    } else {
        [IO.File]::Move($compiled,$Output)
    }
    Get-Item -LiteralPath $Output | Select-Object FullName,Length
} finally {
    foreach ($name in 'Uninstall.exe','CharmCityBeatdown-Setup.exe','previous.exe') {
        $file=Join-Path $staging $name
        if (Test-Path -LiteralPath $file) {Remove-Item -LiteralPath $file -Force}
    }
    [IO.Directory]::Delete($staging)
}
