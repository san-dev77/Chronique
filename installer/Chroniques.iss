; Installeur Windows de Chroniques — Inno Setup 6
;
; Compilation :
;   iscc installer\Chroniques.iss
; ou, plus simplement :
;   powershell -ExecutionPolicy Bypass -File installer\build_installer.ps1
;
; Produit : installer\out\ChroniquesSetup-<version>.exe

#define AppName        "Chroniques"
#define AppVersion     "1.1.0"
#define AppPublisher   "Chroniques"
#define AppExeName     "Chroniques.exe"
#define BuildDir       "..\build\windows\x64\runner\Release"

[Setup]
; AppId identifie l'application pour les mises a jour et la desinstallation.
; Ne jamais le changer entre deux versions, sinon Windows installera l'app en
; double au lieu de la mettre a jour.
AppId={{7A3F1C2E-9B84-4D5A-A1E6-2C8F5D3B7E90}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher={#AppPublisher}
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
OutputDir=out
OutputBaseFilename=ChroniquesSetup-{#AppVersion}
SetupIconFile=..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#AppExeName}
Compression=lzma2/max
SolidCompression=yes

; --- Habillage -------------------------------------------------------------
; Inno n'accepte que des bitmaps : le bandeau, la vignette et les images de
; l'animation sont peints par installer\assets\make_wizard_art.py.
WizardStyle=modern
WizardSizePercent=120
; En style moderne, Inno masque la page d'accueil par defaut. C'est pourtant
; elle qui porte le bandeau : on la rallume.
DisableWelcomePage=no
WizardImageFile=assets\banner.bmp,assets\banner@2x.bmp
WizardSmallImageFile=assets\small.bmp,assets\small@2x.bmp
WizardImageStretch=yes
; Installation par utilisateur : pas de demande de droits administrateur.
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0

[Languages]
Name: "french"; MessagesFile: "compiler:Languages\French.isl"

[Tasks]
Name: "desktopicon"; Description: "Créer un raccourci sur le Bureau"; \
  GroupDescription: "Raccourcis :"; Flags: checkedonce

[Files]
; Les images de l'animation du bandeau. `dontcopy` : elles ne sont pas
; installees, seulement extraites en memoire temporaire le temps de
; l'assistant.
Source: "assets\anim*.bmp"; Flags: dontcopy
; L'executable
Source: "{#BuildDir}\{#AppExeName}"; DestDir: "{app}"; Flags: ignoreversion
; Les DLL des greffons et le moteur Flutter
Source: "{#BuildDir}\*.dll"; DestDir: "{app}"; Flags: ignoreversion
; Les ressources : app.so, flutter_assets, icudtl.dat
Source: "{#BuildDir}\data\*"; DestDir: "{app}\data"; \
  Flags: ignoreversion recursesubdirs createallsubdirs
; Les .lib et .exp sont des artefacts de compilation : ils ne servent qu'a
; l'edition de liens et n'ont rien a faire dans une installation.

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\{#AppExeName}"
Name: "{group}\Désinstaller {#AppName}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExeName}"; \
  Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExeName}"; \
  Description: "Lancer {#AppName}"; \
  Flags: nowait postinstall skipifsilent

[UninstallDelete]
; Les fichiers ecrits par l'application a l'execution ne sont pas suivis par
; l'installeur : on nettoie le dossier pour ne pas laisser de coquille vide.
Type: filesandordirs; Name: "{app}\data"

[Code]
// --- Animation du bandeau ---------------------------------------------
//
// Inno ne sait pas animer une image : on remplace le bitmap du bandeau a
// intervalle regulier, par une minuterie Windows. Dix-huit images suffisent
// a faire deriver les etincelles et passer un voile de lumiere ; au-dela,
// l'installeur grossit pour un gain que l'oeil ne voit pas.

const
  ANIM_FRAMES = 18;
  ANIM_TICK = 70;

var
  AnimFrame: Integer;
  AnimTimer: UINT_PTR;

function SetTimer(hWnd: HWND; nIDEvent: UINT_PTR; uElapse: UINT;
  lpTimerFunc: LongWord): UINT_PTR;
  external 'SetTimer@user32.dll stdcall';

function KillTimer(hWnd: HWND; nIDEvent: UINT_PTR): BOOL;
  external 'KillTimer@user32.dll stdcall';

function FramePath(Index: Integer): String;
begin
  Result := ExpandConstant('{tmp}\anim') + Format('%.2d', [Index]) + '.bmp';
end;

procedure AnimTick(H: HWND; Msg: UINT; Event: UINT_PTR; Time: DWORD);
var
  Path: String;
begin
  AnimFrame := (AnimFrame + 1) mod ANIM_FRAMES;
  Path := FramePath(AnimFrame);
  if not FileExists(Path) then
    Exit;
  // Les deux bandeaux : celui de l'accueil et celui de la derniere page.
  WizardForm.WizardBitmapImage.Bitmap.LoadFromFile(Path);
  WizardForm.WizardBitmapImage2.Bitmap.LoadFromFile(Path);
end;

procedure InitializeWizard;
var
  I: Integer;
begin
  for I := 0 to ANIM_FRAMES - 1 do
    ExtractTemporaryFile('anim' + Format('%.2d', [I]) + '.bmp');

  AnimFrame := 0;
  AnimTimer := SetTimer(0, 0, ANIM_TICK, CreateCallback(@AnimTick));

  // Le titre d'accueil, repris a la couleur de l'application.
  WizardForm.WelcomeLabel1.Font.Size := 15;
  WizardForm.WelcomeLabel1.Font.Style := [fsBold];
  WizardForm.WelcomeLabel1.Font.Color := $8F3A1F;
  WizardForm.WelcomeLabel2.Font.Size := 9;
end;

procedure DeinitializeSetup;
begin
  if AnimTimer <> 0 then
    KillTimer(0, AnimTimer);
end;

// Les donnees de l'utilisateur (base Hive et photos) vivent dans
// %APPDATA%\com.example\note_keeper. On propose de les conserver plutot que
// de les supprimer sans prevenir : ce sont ses chroniques.
procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  DataDir: String;
begin
  if CurUninstallStep = usPostUninstall then
  begin
    DataDir := ExpandConstant('{userappdata}\com.example\note_keeper');
    if DirExists(DataDir) then
    begin
      if MsgBox('Supprimer également vos chroniques enregistrées sur cet ordinateur ?' + #13#10 + #13#10 +
                'Choisissez « Non » pour les conserver — elles seront retrouvées si vous réinstallez ' +
                'l''application.',
                mbConfirmation, MB_YESNO or MB_DEFBUTTON2) = IDYES then
      begin
        DelTree(DataDir, True, True, True);
      end;
    end;
  end;
end;
