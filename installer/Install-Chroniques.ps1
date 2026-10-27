<#
    Installeur de Chroniques — sans dependance.

    Fait ce qu'un installeur fait, sans outil supplementaire :
      - copie l'application dans %LOCALAPPDATA%\Programs\Chroniques
      - cree un raccourci sur le Bureau et dans le menu Demarrer
      - inscrit l'application dans « Applications et fonctionnalites »
      - depose un desinstalleur

    Usage :
        powershell -ExecutionPolicy Bypass -File installer\Install-Chroniques.ps1

    Options :
        -NoDesktopShortcut   n'ajoute pas le raccourci sur le Bureau
        -Uninstall           desinstalle
#>

param(
    [switch]$NoDesktopShortcut,
    [switch]$Uninstall
)

$ErrorActionPreference = 'Stop'

$AppName    = 'Chroniques'
$AppVersion = '1.0.0'
$ExeName    = 'Chroniques.exe'
$RegKey     = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\Chroniques'

$InstallDir = Join-Path $env:LOCALAPPDATA "Programs\$AppName"
$Desktop    = [Environment]::GetFolderPath('Desktop')
$StartMenu  = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs'

function Say($text, $color = 'White') { Write-Host $text -ForegroundColor $color }

function Stop-App {
    $p = Get-Process -Name 'Chroniques' -ErrorAction SilentlyContinue
    if ($p) {
        Say "Fermeture de $AppName…" DarkGray
        $p | Stop-Process -Force
        Start-Sleep -Milliseconds 800
    }
}

function New-Shortcut($Path, $Target, $IconPath, $Description) {
    $shell = New-Object -ComObject WScript.Shell
    $lnk = $shell.CreateShortcut($Path)
    $lnk.TargetPath       = $Target
    # Le repertoire de travail doit etre celui de l'exe : l'application y
    # cherche son dossier data\ (flutter_assets, icudtl.dat, app.so).
    $lnk.WorkingDirectory = Split-Path -Parent $Target
    $lnk.IconLocation     = $IconPath
    $lnk.Description      = $Description
    $lnk.Save()
}

# =========================================================== desinstallation
if ($Uninstall) {
    Say "Désinstallation de $AppName…" White
    Stop-App

    foreach ($lnk in @(
            (Join-Path $Desktop   "$AppName.lnk"),
            (Join-Path $StartMenu "$AppName.lnk"))) {
        if (Test-Path $lnk) { Remove-Item $lnk -Force; Say "  raccourci retiré" DarkGray }
    }

    if (Test-Path $InstallDir) {
        Remove-Item $InstallDir -Recurse -Force
        Say "  fichiers supprimés" DarkGray
    }
    if (Test-Path $RegKey) {
        Remove-Item $RegKey -Recurse -Force
        Say "  entrée « Applications et fonctionnalités » retirée" DarkGray
    }

    # Les chroniques de l'utilisateur ne sont pas touchees sans son accord.
    $dataDir = Join-Path $env:APPDATA 'com.example\note_keeper'
    if (Test-Path $dataDir) {
        Say ""
        Say "Vos chroniques sont conservées ici :" Yellow
        Say "    $dataDir" Yellow
        Say "Supprimez ce dossier vous-même si vous ne voulez rien garder." DarkGray
    }

    Say ""
    Say "$AppName a été désinstallé." Green
    exit 0
}

# ============================================================= installation
$root = Split-Path -Parent $PSScriptRoot
$source = Join-Path $root 'build\windows\x64\runner\Release'

if (-not (Test-Path (Join-Path $source $ExeName))) {
    Say "Application introuvable dans :" Red
    Say "    $source" Red
    Say ""
    Say "Compilez-la d'abord :" White
    Say "    flutter build windows --release" Cyan
    exit 1
}

Say "Installation de $AppName $AppVersion" White
Say ""

Stop-App

# --- copie -----------------------------------------------------------------
if (Test-Path $InstallDir) {
    Say "Mise à jour de l'installation existante…" DarkGray
    Remove-Item $InstallDir -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null

# Les .lib et .exp sont des artefacts d'edition de liens : inutiles ici.
Get-ChildItem $source -File |
    Where-Object { $_.Extension -notin @('.lib', '.exp', '.pdb') } |
    Copy-Item -Destination $InstallDir

Copy-Item (Join-Path $source 'data') $InstallDir -Recurse -Force

$size = (Get-ChildItem $InstallDir -Recurse -File | Measure-Object Length -Sum).Sum
Say "  $([math]::Round($size / 1MB, 1)) Mo copiés dans $InstallDir" DarkGray

# --- icone -----------------------------------------------------------------
$icoSource = Join-Path $root 'windows\runner\resources\app_icon.ico'
$icoTarget = Join-Path $InstallDir 'app_icon.ico'
if (Test-Path $icoSource) { Copy-Item $icoSource $icoTarget -Force }
$iconRef = if (Test-Path $icoTarget) { $icoTarget } else { Join-Path $InstallDir $ExeName }

# --- raccourcis ------------------------------------------------------------
$target = Join-Path $InstallDir $ExeName

New-Shortcut (Join-Path $StartMenu "$AppName.lnk") $target $iconRef 'Vos souvenirs ont une mémoire'
Say "  raccourci ajouté au menu Démarrer" DarkGray

if (-not $NoDesktopShortcut) {
    New-Shortcut (Join-Path $Desktop "$AppName.lnk") $target $iconRef 'Vos souvenirs ont une mémoire'
    Say "  raccourci ajouté sur le Bureau" DarkGray
}

# --- inscription dans Applications et fonctionnalites -----------------------
$uninstaller = Join-Path $InstallDir 'Uninstall-Chroniques.ps1'
Copy-Item $PSCommandPath $uninstaller -Force

New-Item -Path $RegKey -Force | Out-Null
Set-ItemProperty $RegKey 'DisplayName'     $AppName
Set-ItemProperty $RegKey 'DisplayVersion'  $AppVersion
Set-ItemProperty $RegKey 'Publisher'       $AppName
Set-ItemProperty $RegKey 'DisplayIcon'     $iconRef
Set-ItemProperty $RegKey 'InstallLocation' $InstallDir
Set-ItemProperty $RegKey 'NoModify'        1 -Type DWord
Set-ItemProperty $RegKey 'NoRepair'        1 -Type DWord
Set-ItemProperty $RegKey 'EstimatedSize'   ([int]($size / 1KB)) -Type DWord
Set-ItemProperty $RegKey 'UninstallString' `
    "powershell.exe -ExecutionPolicy Bypass -File `"$uninstaller`" -Uninstall"
Say "  inscrit dans « Applications et fonctionnalités »" DarkGray

Say ""
Say "$AppName est installé." Green
Say "Un raccourci vous attend sur le Bureau." Green
Say ""
Say "Pour désinstaller :" DarkGray
Say "    powershell -ExecutionPolicy Bypass -File `"$uninstaller`" -Uninstall" DarkGray
