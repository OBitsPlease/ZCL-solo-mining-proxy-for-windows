# ============================================================
#  ZClassic Solo Pool Launcher  (portable - uses $PSScriptRoot)
# ============================================================

$Host.UI.RawUI.WindowTitle = "ZClassic Solo Pool"

$INSTALL_DIR = $PSScriptRoot
$ZCL_DIR     = "$INSTALL_DIR\zcl"
$ZCL_CONF    = "$env:APPDATA\ZClassic\zclassic.conf"
$MC_DIR      = "$INSTALL_DIR\miningcore"
$MC_CONFIG   = "$INSTALL_DIR\config\zclassic_solo_pool.json"
$dashboardDir = "$INSTALL_DIR\dashboard"

# Find PSQL bin from paths.json or common locations
$PSQL_BIN = ""
$pathsJson = "$INSTALL_DIR\paths.json"
if (Test-Path $pathsJson) {
    try {
        $p = Get-Content $pathsJson | ConvertFrom-Json
        if ($p.psqlBin -and (Test-Path "$($p.psqlBin)\psql.exe")) { $PSQL_BIN = $p.psqlBin }
    } catch {}
}
if (-not $PSQL_BIN) {
    @(
        "$env:ProgramFiles\PostgreSQL\16\bin",
        "$env:ProgramFiles\PostgreSQL\15\bin",
        "C:\PostgreSQL\16\bin",
        "C:\PostgreSQL\15\bin"
    ) | ForEach-Object { if (-not $PSQL_BIN -and (Test-Path "$_\psql.exe")) { $PSQL_BIN = $_ } }
}
if ($PSQL_BIN) { $env:PATH = "$PSQL_BIN;$env:PATH" }

function Write-Step($msg) { Write-Host ""; Write-Host ">>> $msg" -ForegroundColor Cyan }
function Write-OK($msg)   { Write-Host "    [OK] $msg" -ForegroundColor Green }
function Write-Fail($msg) { Write-Host "    [!!] $msg" -ForegroundColor Red }
function Stop-WithError($msg) {
    Write-Fail $msg
    Write-Host ""; Write-Host "Press any key to exit..." -ForegroundColor Yellow
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit 1
}

# ---- Step 1: PostgreSQL ----------------------------------------
Write-Step "Checking PostgreSQL service..."
$pgService = Get-Service -Name "postgresql*" -ErrorAction SilentlyContinue | Select-Object -First 1
if ($null -eq $pgService) {
    Stop-WithError "PostgreSQL service not found. Please run the installer again or install PostgreSQL manually."
}
if ($pgService.Status -ne "Running") {
    Write-Host "    Starting PostgreSQL..." -ForegroundColor Yellow
    Start-Service $pgService.Name -ErrorAction Stop
    Start-Sleep -Seconds 3
}
$pgService = Get-Service -Name $pgService.Name
if ($pgService.Status -eq "Running") {
    Write-OK "PostgreSQL is running ($($pgService.Name))."
} else {
    Stop-WithError "Failed to start PostgreSQL."
}

# ---- Step 2: ZClassic Daemon -----------------------------------
Write-Step "Checking ZClassic daemon (zclassicd)..."

# Create ZClassic appdata dir and conf if missing
New-Item -ItemType Directory -Force "$env:APPDATA\ZClassic" | Out-Null
if (-not (Test-Path $ZCL_CONF)) {
    $confTemplate = "$INSTALL_DIR\config\zclassic.conf.template"
    if (Test-Path $confTemplate) {
        Copy-Item $confTemplate $ZCL_CONF
        Write-Host "    Created zclassic.conf from template." -ForegroundColor Yellow
    }
}

$zclProc = Get-Process -Name "zclassicd" -ErrorAction SilentlyContinue
if ($null -eq $zclProc) {
    Write-Host "    Starting zclassicd (this may take a moment)..." -ForegroundColor Yellow
    Start-Process -FilePath "$ZCL_DIR\zclassicd.exe" -ArgumentList "-conf=`"$ZCL_CONF`"" -WindowStyle Minimized
    Write-Host "    Waiting for RPC to become available..." -ForegroundColor Yellow
    $ready = $false
    for ($i = 0; $i -lt 60; $i++) {
        Start-Sleep -Seconds 2
        $result = & "$ZCL_DIR\zclassic-cli.exe" getinfo 2>&1
        if ($result -notmatch "error|refused|loading") { $ready = $true; break }
    }
    if (-not $ready) {
        Stop-WithError "zclassicd did not respond. It may still be syncing - try again in a moment."
    }
} else {
    Write-Host "    zclassicd already running (PID $($zclProc.Id))..." -ForegroundColor Yellow
}

$info = & "$ZCL_DIR\zclassic-cli.exe" getinfo 2>&1
$blockMatch = [regex]::Match($info, '"blocks"\s*:\s*(\d+)')
if ($blockMatch.Success) {
    Write-OK "zclassicd running. Block height: $($blockMatch.Groups[1].Value)"
} else {
    Write-OK "zclassicd running."
}

# Import pool address to prevent false orphans
$poolCfg    = Get-Content "$MC_CONFIG" | ConvertFrom-Json
$poolAddr   = $poolCfg.pools[0].address
$importResult = & "$ZCL_DIR\zclassic-cli.exe" importaddress $poolAddr "" false 2>&1
Write-OK "Pool address imported into wallet (prevents false orphans)."

# ---- Step 3: Dashboard -----------------------------------------
Write-Step "Starting Pool Dashboard..."
$dashProc = Start-Process -FilePath "node" -ArgumentList "server.js" `
    -WorkingDirectory $dashboardDir -PassThru -WindowStyle Hidden
Start-Sleep -Milliseconds 1500
Write-OK "Dashboard running at http://localhost:8080"
Start-Process "http://localhost:8080"

# Start Cloudflare Tunnel for remote access
Write-Step "Starting Cloudflare remote access tunnel..."
$cfProc = $null
$cloudflaredPath = Get-Command cloudflared -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source
if ($cloudflaredPath) {
    $cfLogFile = "$INSTALL_DIR\logs\cloudflare-tunnel.log"
    if (Test-Path $cfLogFile) { Clear-Content $cfLogFile }
    $cfProc = Start-Process -FilePath $cloudflaredPath `
        -ArgumentList "tunnel --url http://localhost:8080 --no-autoupdate" `
        -PassThru -WindowStyle Hidden -RedirectStandardError $cfLogFile
    Start-Sleep -Seconds 4
    $tunnelUrl = $null
    for ($i = 0; $i -lt 10; $i++) {
        Start-Sleep -Seconds 2
        if (Test-Path $cfLogFile) {
            $match = [regex]::Match((Get-Content $cfLogFile -Raw -ErrorAction SilentlyContinue), 'https://[a-z0-9\-]+\.trycloudflare\.com')
            if ($match.Success) { $tunnelUrl = $match.Value; break }
        }
    }
    if ($tunnelUrl) {
        Write-OK "Remote URL: $tunnelUrl"
        Write-Host "    Share this link to view from anywhere!" -ForegroundColor Cyan
        $urlFile = "$INSTALL_DIR\logs\tunnel-url.txt"
        @"
BitsPleaseYT Mining Pool - Remote Dashboard URL
================================================
$tunnelUrl

Open this link in any browser to view your dashboard remotely.
Generated: $(Get-Date)
"@ | Set-Content $urlFile
        Start-Process "notepad.exe" -ArgumentList $urlFile
    } else {
        Write-Host "    Tunnel started (check logs\cloudflare-tunnel.log for URL)" -ForegroundColor Yellow
    }
} else {
    Write-Host "    cloudflared not found — run: winget install Cloudflare.cloudflared" -ForegroundColor Yellow
}

# ---- Step 4: Orphan monitor ------------------------------------
$monitorArgs = @(
    "-NonInteractive", "-WindowStyle", "Hidden",
    "-File", "$INSTALL_DIR\Watch-BlockOrphans.ps1",
    "-ZclDir",  "`"$ZCL_DIR`"",
    "-PsqlBin", "`"$PSQL_BIN`""
)
$monProc = Start-Process -FilePath "pwsh" -ArgumentList $monitorArgs -PassThru -WindowStyle Hidden
Write-OK "Block orphan recovery monitor running (PID $($monProc.Id))."

# ---- Step 5: MiningCore ----------------------------------------
Write-Step "Starting MiningCore ZClassic Solo Pool..."
Write-Host "    Pool port: 3032  |  Config: $MC_CONFIG" -ForegroundColor DarkGray
Write-Host ""
Write-Host "============================================================" -ForegroundColor Magenta
Write-Host "  Point your miner to: stratum+tcp://YOUR-IP:3032" -ForegroundColor Green
Write-Host "  Worker: your ZCL t-address" -ForegroundColor White
Write-Host "  Dashboard: http://localhost:8080" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Magenta
Write-Host ""

Set-Location $MC_DIR
& "$MC_DIR\Miningcore.exe" -c "$MC_CONFIG" 2>&1 | ForEach-Object {
    $line = $_
    if ($line -match '/api/|/metrics|/notifications|GET |POST |HEAD ') { return }
    if    ($line -match '\[W\]|\[E\]|Error|error|reject|invalid') { Write-Host $line -ForegroundColor Red }
    elseif ($line -match 'block accepted|BLOCK FOUND')             { Write-Host $line -ForegroundColor Yellow -BackgroundColor DarkGreen }
    elseif ($line -match 'Submitting block|IsBlockCandidate')      { Write-Host $line -ForegroundColor Yellow }
    elseif ($line -match 'Share accepted')                         { Write-Host $line -ForegroundColor Green }
    elseif ($line -match 'Pool Online|Broadcasting job|Detected new block|Authorized') { Write-Host $line -ForegroundColor Cyan }
    else                                                           { Write-Host $line }
}

if ($dashProc -and -not $dashProc.HasExited) { Stop-Process -Id $dashProc.Id -ErrorAction SilentlyContinue }
if ($cfProc   -and -not $cfProc.HasExited)   { Stop-Process -Id $cfProc.Id   -ErrorAction SilentlyContinue }
if ($monProc  -and -not $monProc.HasExited)  { Stop-Process -Id $monProc.Id  -ErrorAction SilentlyContinue }

Write-Host ""; Write-Host "MiningCore has stopped." -ForegroundColor Yellow
Write-Host "Press any key to close..." -ForegroundColor DarkGray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
