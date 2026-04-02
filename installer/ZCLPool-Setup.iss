; ============================================================
;  BitsPleaseYT Solo Pool v3.0.0 - Inno Setup Installer Script
;  Created by BitsPlease YT
;  Two-phase install:
;    Phase 1: Extract all files + install ZCL daemon/wallet
;    Phase 2: User clicks desktop icon after blockchain syncs
; ============================================================

#define MyAppName      "BitsPleaseYT Solo Pools"
#define MyAppVersion   "3.0.0"
#define MyAppPublisher "BitsPlease YT"
#define MyAppURL       "https://github.com/BitsPleaseYT/solo-pools"
#define SrcRoot        ".."
#define ZclBin         "zcl-bin"

[Setup]
AppId={{F3A2B1C4-7E6D-4A9F-8B3C-2D1E5F7A9B0C}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
DefaultDirName={autopf64}\BitsPleaseYT-SoloPools
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=no
OutputDir={#SrcRoot}\installer-output
OutputBaseFilename=BitsPleaseYT-SoloPools-Setup-{#MyAppVersion}
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=classic
WizardImageFile=splash.png
WizardImageStretch=yes
WizardSmallImageFile=splash.png
PrivilegesRequired=admin
PrivilegesRequiredOverridesAllowed=dialog
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0.17763
UninstallDisplayIcon={app}\mining.ico

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Create &desktop shortcut"; GroupDescription: "Additional icons:"

[Files]
; ---- ZClassic daemon binaries ----
Source: "{#ZclBin}\zclassicd.exe";    DestDir: "{app}\zcl"; Flags: ignoreversion
Source: "{#ZclBin}\zclassic-cli.exe"; DestDir: "{app}\zcl"; Flags: ignoreversion
Source: "{#ZclBin}\zclwallet.exe";    DestDir: "{app}\zcl"; Flags: ignoreversion

; ---- MiningCore (self-contained .NET 8 win-x64 publish) ----
Source: "{#SrcRoot}\src\Miningcore\bin\Release\net8.0\win-x64\*"; \
    DestDir: "{app}\miningcore"; Flags: recursesubdirs createallsubdirs ignoreversion

; ---- Dashboard (node_modules installed in Phase 2) ----
Source: "{#SrcRoot}\dashboard\server.js";         DestDir: "{app}\dashboard"; Flags: ignoreversion
Source: "{#SrcRoot}\dashboard\package.json";      DestDir: "{app}\dashboard"; Flags: ignoreversion
Source: "{#SrcRoot}\dashboard\package-lock.json"; DestDir: "{app}\dashboard"; Flags: ignoreversion skipifsourcedoesntexist
Source: "{#SrcRoot}\dashboard\public\*";          DestDir: "{app}\dashboard\public"; \
    Flags: recursesubdirs createallsubdirs ignoreversion

; ---- Launcher, monitor, phase-2 setup scripts ----
Source: "Start-BitsPleaseYT-Solo-Pool.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SrcRoot}\Watch-ZCL-BlockOrphans.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SrcRoot}\Watch-VTC-BlockOrphans.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "Complete-Install.ps1";         DestDir: "{app}"; Flags: ignoreversion

; ---- Config templates ----
Source: "zclassic_solo_pool_template.json"; DestDir: "{app}\config"; \
    DestName: "zclassic_solo_pool.json"; Flags: onlyifdoesntexist
Source: "zclassic.conf.template";           DestDir: "{app}\config"; Flags: ignoreversion

; ---- Database schema ----
Source: "{#SrcRoot}\src\Miningcore\Persistence\Postgres\Scripts\createdb.sql"; \
    DestDir: "{app}\sql"; Flags: ignoreversion
Source: "{#SrcRoot}\src\Miningcore\Persistence\Postgres\Scripts\createdb_postgresql_11_appendix.sql"; \
    DestDir: "{app}\sql"; Flags: ignoreversion

; ---- Splash image (used by Complete-Install.ps1 GUI) ----
Source: "splash.png"; DestDir: "{app}"; Flags: ignoreversion

; ---- Desktop icon ----
Source: "mining.ico"; DestDir: "{app}"; Flags: ignoreversion

; ---- Help file ----
Source: "CONFIGURE-ME.txt"; DestDir: "{app}"; Flags: ignoreversion

; ---- BMP splash for pre-wizard splash form ----
Source: "splash.bmp"; DestDir: "{tmp}"; Flags: deleteafterinstall

[Dirs]
Name: "{app}\logs"
Name: "{app}\config"

[Icons]
; Start menu
Name: "{group}\ZCL Wallet (Sync Blockchain Here First)"; \
    Filename: "{app}\zcl\zclwallet.exe"; WorkingDir: "{app}\zcl"
Name: "{group}\Finish ZCL Pool Setup (After Blockchain Syncs)"; \
    Filename: "pwsh.exe"; \
    Parameters: "-ExecutionPolicy Bypass -File ""{app}\Complete-Install.ps1"""; \
    WorkingDir: "{app}"; IconFilename: "{app}\mining.ico"
Name: "{group}\Configuration Guide"; \
    Filename: "{app}\CONFIGURE-ME.txt"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; \
    Filename: "{uninstallexe}"

; Desktop - Phase 1: "Finish Setup" icon (BitsPlease Solo Pool icon added by Complete-Install.ps1)
Name: "{commondesktop}\Finish ZCL Pool Setup"; \
    Filename: "pwsh.exe"; \
    Parameters: "-ExecutionPolicy Bypass -File ""{app}\Complete-Install.ps1"""; \
    WorkingDir: "{app}"; \
    IconFilename: "{app}\mining.ico"; \
    Comment: "Run this after the ZClassic blockchain finishes syncing"; \
    Tasks: desktopicon

[Run]
; Phase 1: Launch ZCL Wallet so blockchain starts syncing immediately
Filename: "{app}\zcl\zclwallet.exe"; \
    Description: "Open ZCL Wallet (let the blockchain sync before clicking Finish Setup)"; \
    Flags: postinstall shellexec nowait unchecked

[Code]
// Pre-wizard splash screen (shown before the wizard appears)
procedure ShowSplashScreen;
var
  SplashForm  : TForm;
  SplashImage : TBitmapImage;
  BmpFile     : String;
begin
  BmpFile := ExpandConstant('{tmp}\splash.bmp');
  if not FileExists(BmpFile) then Exit;

  SplashForm              := TForm.Create(nil);
  SplashForm.BorderStyle  := bsNone;
  SplashForm.Width        := 700;
  SplashForm.Height       := 393;
  SplashForm.Position     := poScreenCenter;
  SplashForm.Color        := $00120D1A;

  SplashImage             := TBitmapImage.Create(SplashForm);
  SplashImage.AutoSize    := False;
  SplashImage.Stretch     := True;
  SplashImage.Left        := 0;
  SplashImage.Top         := 0;
  SplashImage.Width       := 700;
  SplashImage.Height      := 393;
  SplashImage.Parent      := SplashForm;
  SplashImage.Bitmap.LoadFromFile(BmpFile);

  SplashForm.Show;
  SplashForm.BringToFront;
  SplashForm.Update;
  Sleep(3000);
  SplashForm.Close;
  SplashForm.Free;
end;

function InitializeSetup(): Boolean;
begin
  // Extract BMP to temp then show splash before wizard appears
  ExtractTemporaryFile('splash.bmp');
  ShowSplashScreen;
  Result := True;
end;

function NextButtonClick(CurPageID: Integer): Boolean;
begin
  Result := True;
end;
