<#
    Construit Chroniques puis fabrique l'installeur Windows.

    Usage :
        powershell -ExecutionPolicy Bypass -File installer\build_installer.ps1

    Options :
        -SkipBuild   reutilise la compilation existante
#>

param(
    [switch]$SkipBuild
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot

function Say($text, $color = 'White') { Write-Host $text -ForegroundColor $color }

# --- 1. Inno Setup est-il disponible ? -------------------------------------
$iscc = $null
foreach ($candidate in @(
        "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
        "${env:ProgramFiles}\Inno Setup 6\ISCC.exe",
        # winget installe par defaut pour l utilisateur seul : sans ce
        # chemin, le script declarait Inno Setup introuvable alors qu il
        # venait d etre installe.
        "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe")) {
    if (Test-Path $candidate) { $iscc = $candidate; break }
}
if (-not $iscc) {
    $cmd = Get-Command ISCC.exe -ErrorAction SilentlyContinue
    if ($cmd) { $iscc = $cmd.Source }
}

if (-not $iscc) {
    Say "Inno Setup est introuvable." Yellow
    Say ""
    Say "Installez-le une fois, puis relancez ce script :" White
    Say "    winget install --id JRSoftware.InnoSetup --accept-source-agreements" Cyan
    Say ""
    Say "Sans lui, vous pouvez utiliser l'installeur PowerShell :" White
    Say "    powershell -ExecutionPolicy Bypass -File installer\Install-Chroniques.ps1" Cyan
    exit 1
}
Say "Inno Setup : $iscc" DarkGray

# --- 2. L'application doit etre fermee --------------------------------------
$running = Get-Process -Name 'Chroniques' -ErrorAction SilentlyContinue
if ($running) {
    Say "Chroniques est ouvert — fermeture (sinon la compilation ne peut pas ecrire)." Yellow
    $running | Stop-Process -Force
    Start-Sleep -Milliseconds 800
}

# --- 3. Compilation ---------------------------------------------------------
if (-not $SkipBuild) {
    Say "Compilation en mode release…" White
    Push-Location $root
    try {
        & flutter build windows --release
        if ($LASTEXITCODE -ne 0) { throw "La compilation Flutter a échoué." }
    } finally {
        Pop-Location
    }
} else {
    Say "Compilation ignorée (-SkipBuild)." DarkGray
}

$releaseDir = Join-Path $root 'build\windows\x64\runner\Release'
$exe = Join-Path $releaseDir 'Chroniques.exe'
if (-not (Test-Path $exe)) {
    throw "Chroniques.exe est introuvable dans $releaseDir. Lancez d'abord une compilation."
}

# --- 4. Fabrication de l'installeur ----------------------------------------
$outDir = Join-Path $PSScriptRoot 'out'
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

Say "Fabrication de l'installeur…" White
& $iscc (Join-Path $PSScriptRoot 'Chroniques.iss')
if ($LASTEXITCODE -ne 0) { throw "Inno Setup a échoué." }

$setup = Get-ChildItem $outDir -Filter 'ChroniquesSetup-*.exe' |
         Sort-Object LastWriteTime -Descending |
         Select-Object -First 1

Say ""
Say "Installeur prêt :" Green
Say "    $($setup.FullName)" Green
Say "    $([math]::Round($setup.Length / 1MB, 1)) Mo" DarkGray
