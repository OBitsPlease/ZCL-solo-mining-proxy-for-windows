# ============================================================
#  BitsPleaseYT Solo Pool v2.0.0 Launcher
# ============================================================

$Host.UI.RawUI.WindowTitle = "BitsPleaseYT Solo Pool v2.0.0"
$ZCL_DIR   = "C:\Users\tourj\OneDrive\Documents\MINING MINING MINING\WALLETS\ZCLASSIC\zclassic-2-1-1-60-windows-gui-x86_64\zclassic-2-1-1-60-windows-gui-x86_64"
$ZCL_CONF  = "$env:APPDATA\ZClassic\zclassic.conf"
$MC_DIR    = "C:\Users\tourj\mining core\build"
$MC_CONFIG = "$MC_DIR\zclassic_solo_pool.json"
$PSQL_BIN  = "C:\PostgreSQL\15\bin"
$env:PATH  = "$PSQL_BIN;$env:PATH"

function Write-Step($msg) {
    Write-Host ""
    Write-Host ">>> $msg" -ForegroundColor Cyan
}

function Write-OK($msg) {
    Write-Host "    [OK] $msg" -ForegroundColor Green
}

function Write-Fail($msg) {
    Write-Host "    [!!] $msg" -ForegroundColor Red
}

function Stop-WithError($msg) {
    Write-Fail $msg
    Write-Host ""
    Write-Host "Press any key to exit..." -ForegroundColor Yellow
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit 1
}

# ---- Step 1: PostgreSQL ----------------------------------------
Write-Step "Checking PostgreSQL service..."
$pg = Get-Service -Name "postgresql-15" -ErrorAction SilentlyContinue
if ($null -eq $pg) {
    Stop-WithError "PostgreSQL service 'postgresql-15' not found. Please reinstall PostgreSQL."
}
if ($pg.Status -ne "Running") {
    Write-Host "    Starting PostgreSQL..." -ForegroundColor Yellow
    Start-Service "postgresql-15" -ErrorAction Stop
    Start-Sleep -Seconds 3
}
$pg = Get-Service -Name "postgresql-15"
if ($pg.Status -eq "Running") {
    Write-OK "PostgreSQL is running."
} else {
    Stop-WithError "Failed to start PostgreSQL."
}

# ---- Step 2: ZClassic Daemon -----------------------------------
Write-Step "Checking ZClassic daemon (zclassicd)..."
$zclProc = Get-Process -Name "zclassicd" -ErrorAction SilentlyContinue
if ($null -eq $zclProc) {
    Write-Host "    Starting zclassicd (this may take a moment)..." -ForegroundColor Yellow
    Start-Process -FilePath "$ZCL_DIR\zclassicd.exe" -ArgumentList "-conf=`"$ZCL_CONF`"" -WindowStyle Minimized
    Write-Host "    Waiting for RPC to become available..." -ForegroundColor Yellow
    $ready = $false
    for ($i = 0; $i -lt 60; $i++) {
        Start-Sleep -Seconds 2
        $result = & "$ZCL_DIR\zclassic-cli.exe" getinfo 2>&1
        if ($result -notmatch "error|refused|loading") {
            $ready = $true
            break
        }
    }
    if (-not $ready) {
        Stop-WithError "zclassicd did not respond in time. It may still be starting - try again in a minute."
    }
} else {
    Write-Host "    zclassicd already running (PID $($zclProc.Id)), checking sync..." -ForegroundColor Yellow
}

# Show block count
$info = & "$ZCL_DIR\zclassic-cli.exe" getinfo 2>&1
$blockMatch = [regex]::Match($info, '"blocks"\s*:\s*(\d+)')
if ($blockMatch.Success) {
    Write-OK "zclassicd running. Block height: $($blockMatch.Groups[1].Value)"
} else {
    Write-OK "zclassicd running."
}

# Ensure pool address is imported so gettransaction works (prevents false orphans)
$poolCfg = Get-Content "$MC_CONFIG" | ConvertFrom-Json
$poolAddr = $poolCfg.pools[0].address
$importResult = & "$ZCL_DIR\zclassic-cli.exe" importaddress $poolAddr "" false 2>&1
Write-OK "Pool address imported into wallet (prevents false orphans)."

# ---- Step 3: Launch MiningCore ---------------------------------
Write-Step "Starting MiningCore BitsPleaseYT Solo Pool..."
Write-Host "    Pool will listen for miners on port 3032" -ForegroundColor Yellow
Write-Host "    Config: $MC_CONFIG" -ForegroundColor DarkGray
Write-Host ""

# Start dashboard in background
Write-Step "Starting Pool Dashboard..."
$dashboardDir = "C:\Users\tourj\mining core\dashboard"
$dashProc = Start-Process -FilePath "node" -ArgumentList "server.js" -WorkingDirectory $dashboardDir -PassThru -WindowStyle Hidden
Start-Sleep -Milliseconds 1500
Write-OK "Dashboard running at http://localhost:8080"
Write-Host "    Opening dashboard in browser..." -ForegroundColor DarkGray
Start-Process "http://localhost:8080"

# Start Cloudflare Tunnel for remote dashboard access
Write-Step "Starting Cloudflare remote access tunnel..."
$cfProc = $null
$cloudflaredPath = Get-Command cloudflared -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source
if (-not $cloudflaredPath) {
    # Try common install locations
    @("$env:ProgramFiles\Cloudflare\cloudflared\cloudflared.exe",
      "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\Cloudflare.cloudflared_*\cloudflared.exe") |
        ForEach-Object { if (-not $cloudflaredPath) { $f = Get-Item $_ -ErrorAction SilentlyContinue | Select-Object -First 1; if ($f) { $cloudflaredPath = $f.FullName } } }
}
if ($cloudflaredPath) {
    $cfLogFile = "C:\Users\tourj\mining core\build\logs\cloudflare-tunnel.log"
    # Clear stale log so we don't pick up the URL from a previous session
    if (Test-Path $cfLogFile) { Clear-Content $cfLogFile }
    $cfProc = Start-Process -FilePath $cloudflaredPath `
        -ArgumentList "tunnel --url http://localhost:8080 --no-autoupdate" `
        -PassThru -WindowStyle Hidden -RedirectStandardError $cfLogFile
    Start-Sleep -Seconds 4
    # Parse the tunnel URL from the log
    $tunnelUrl = $null
    for ($i = 0; $i -lt 10; $i++) {
        Start-Sleep -Seconds 2
        if (Test-Path $cfLogFile) {
            $logContent = Get-Content $cfLogFile -Raw -ErrorAction SilentlyContinue
            $match = [regex]::Match($logContent, 'https://[a-z0-9\-]+\.trycloudflare\.com')
            if ($match.Success) { $tunnelUrl = $match.Value; break }
        }
    }
    if ($tunnelUrl) {
        Write-OK "Remote dashboard URL: $tunnelUrl"
        Write-Host "    Share this link to view your dashboard from anywhere!" -ForegroundColor Cyan
        # Write URL to a file and open it so user can save/share it
        $urlFile = "C:\Users\tourj\mining core\build\logs\tunnel-url.txt"
        @"
BitsPleaseYT Mining Pool - Remote Dashboard URL
================================================
$tunnelUrl

Open this link in any browser to view your dashboard remotely.
Generated: $(Get-Date)
"@ | Set-Content $urlFile
        Start-Process "notepad.exe" -ArgumentList $urlFile
    } else {
        Write-Host "    Tunnel started (URL not parsed yet — check logs\cloudflare-tunnel.log)" -ForegroundColor Yellow
    }
} else {
    Write-Host "    cloudflared not found — remote access skipped. Run: winget install Cloudflare.cloudflared" -ForegroundColor Yellow
}

# Start false-orphan recovery monitor in background
$monitorArgs = @(
    "-NonInteractive", "-WindowStyle", "Hidden",
    "-File", "C:\Users\tourj\mining core\Watch-BlockOrphans.ps1",
    "-ZclDir", "`"$ZCL_DIR`"",
    "-PsqlBin", "`"$PSQL_BIN`""
)
$monProc = Start-Process -FilePath "pwsh" -ArgumentList $monitorArgs -PassThru -WindowStyle Hidden
Write-OK "Block orphan recovery monitor running (PID $($monProc.Id))."

Write-Host ""
Write-Host "============================================================" -ForegroundColor Magenta
Write-Host "  MiningCore is starting - point your miner to:" -ForegroundColor White
Write-Host "  stratum+tcp://127.0.0.1:3032" -ForegroundColor Green
Write-Host "  Worker: your ZCL address" -ForegroundColor White
Write-Host "  Dashboard: http://localhost:8080" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Magenta
Write-Host ""

Set-Location $MC_DIR

# Filter output: show accepted shares, blocks found, errors/warnings; hide dashboard API spam
& "$MC_DIR\Miningcore.exe" -c "$MC_CONFIG" 2>&1 | ForEach-Object {
    $line = $_

    # Skip dashboard/metrics API noise
    if ($line -match '/api/|/metrics|/notifications|GET |POST |HEAD ') { return }

    # Color-code by content
    if ($line -match '\[W\]|\[E\]|Error|error|reject|Reject|invalid|Invalid|bad share|duplicate') {
        Write-Host $line -ForegroundColor Red
    } elseif ($line -match 'block accepted|Daemon accepted block|BLOCK FOUND') {
        Write-Host $line -ForegroundColor Yellow -BackgroundColor DarkGreen
    } elseif ($line -match 'Submitting block|IsBlockCandidate') {
        Write-Host $line -ForegroundColor Yellow
    } elseif ($line -match 'Share accepted') {
        Write-Host $line -ForegroundColor Green
    } elseif ($line -match 'Pool Online|Job Manager Online|Broadcasting job|Detected new block|Authorized worker') {
        Write-Host $line -ForegroundColor Cyan
    } else {
        Write-Host $line
    }
}

# Stop dashboard, tunnel and monitor when pool exits
if ($dashProc -and -not $dashProc.HasExited) { Stop-Process -Id $dashProc.Id -ErrorAction SilentlyContinue }
if ($cfProc   -and -not $cfProc.HasExited)   { Stop-Process -Id $cfProc.Id   -ErrorAction SilentlyContinue }
if ($monProc  -and -not $monProc.HasExited)  { Stop-Process -Id $monProc.Id  -ErrorAction SilentlyContinue }

# Keep window open if pool exits
Write-Host ""
Write-Host "MiningCore has stopped." -ForegroundColor Yellow
Write-Host "Press any key to close..." -ForegroundColor DarkGray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

