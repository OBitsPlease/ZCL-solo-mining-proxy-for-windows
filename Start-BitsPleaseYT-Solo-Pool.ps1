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

$paths     = Get-Content "C:\Users\tourj\mining core\paths.json" | ConvertFrom-Json
$VTC_CLI   = $paths.vtcCli
$VTC_DIR   = Split-Path $VTC_CLI
$VTC_CONF  = "$env:APPDATA\Vertcoin\vertcoin.conf"

function Write-Step($msg) {
    Write-Host ""
    Write-Host ">>> $msg" -ForegroundColor Cyan
}
function Write-OK($msg)   { Write-Host "    [OK] $msg" -ForegroundColor Green }
function Write-Fail($msg) { Write-Host "    [!!] $msg" -ForegroundColor Red }
function Stop-WithError($msg) {
    Write-Fail $msg
    Write-Host ""
    Write-Host "Press any key to exit..." -ForegroundColor Yellow
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit 1
}

# ---- Coin Selection Popup ----------------------------------------
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$bgImagePath = "C:\Users\tourj\mining core\installer\coin-select-bg.png"

$form = New-Object System.Windows.Forms.Form
$form.Text = "BitsPleaseYT Solo Pool v2.0.0"
$form.Size = New-Object System.Drawing.Size(720, 460)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false
$form.MinimizeBox = $false

# Background image stretched to full form
if (Test-Path $bgImagePath) {
    $bgImage = [System.Drawing.Image]::FromFile($bgImagePath)
    $form.Add_Paint({
        param($s, $e)
        $e.Graphics.DrawImage($bgImage, 0, 0, $s.ClientSize.Width, $s.ClientSize.Height)
    })
} else {
    $bgImage = $null
    $form.BackColor = [System.Drawing.Color]::FromArgb(20, 20, 35)
}

# Slim dark bottom bar — full width, ~110px at bottom
$bar = New-Object System.Windows.Forms.Panel
$bar.Size = New-Object System.Drawing.Size(704, 110)
$bar.Location = New-Object System.Drawing.Point(0, 325)
$bar.BackColor = [System.Drawing.Color]::FromArgb(210, 10, 10, 30)
$form.Controls.Add($bar)

# Gold top border line on bar
$bar.Add_Paint({
    param($s, $e)
    $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(200, 160, 60), 2)
    $e.Graphics.DrawLine($pen, 0, 0, $s.Width, 0)
    $pen.Dispose()
})

$lbl = New-Object System.Windows.Forms.Label
$lbl.Text = "Select coins to start:"
$lbl.ForeColor = [System.Drawing.Color]::FromArgb(220, 180, 60)
$lbl.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$lbl.Location = New-Object System.Drawing.Point(18, 12)
$lbl.BackColor = [System.Drawing.Color]::Transparent
$lbl.AutoSize = $true
$bar.Controls.Add($lbl)

$chkZCL = New-Object System.Windows.Forms.CheckBox
$chkZCL.Text = "ZClassic (ZCL)  — port 3032"
$chkZCL.ForeColor = [System.Drawing.Color]::White
$chkZCL.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$chkZCL.Location = New-Object System.Drawing.Point(18, 42)
$chkZCL.Size = New-Object System.Drawing.Size(240, 26)
$chkZCL.BackColor = [System.Drawing.Color]::Transparent
$chkZCL.Checked = $true
$bar.Controls.Add($chkZCL)

$chkVTC = New-Object System.Windows.Forms.CheckBox
$chkVTC.Text = "Vertcoin (VTC)  — port 3052"
$chkVTC.ForeColor = [System.Drawing.Color]::White
$chkVTC.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$chkVTC.Location = New-Object System.Drawing.Point(270, 42)
$chkVTC.Size = New-Object System.Drawing.Size(240, 26)
$chkVTC.BackColor = [System.Drawing.Color]::Transparent
$chkVTC.Checked = $true
$bar.Controls.Add($chkVTC)

$btnStart = New-Object System.Windows.Forms.Button
$btnStart.Text = "▶  Start Pool"
$btnStart.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$btnStart.Location = New-Object System.Drawing.Point(560, 34)
$btnStart.Size = New-Object System.Drawing.Size(130, 38)
$btnStart.BackColor = [System.Drawing.Color]::FromArgb(0, 140, 60)
$btnStart.ForeColor = [System.Drawing.Color]::White
$btnStart.FlatStyle = "Flat"
$btnStart.DialogResult = [System.Windows.Forms.DialogResult]::OK
$bar.Controls.Add($btnStart)
$form.AcceptButton = $btnStart

$result = $form.ShowDialog()
if ($bgImage) { $bgImage.Dispose() }
if ($result -ne [System.Windows.Forms.DialogResult]::OK) { exit 0 }

# Validate at least one coin selected
if (-not $chkZCL.Checked -and -not $chkVTC.Checked) {
    [System.Windows.Forms.MessageBox]::Show("Please select at least one coin.", "No Coin Selected",
        [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
    exit 0
}

$START_ZCL = $chkZCL.Checked
$START_VTC = $chkVTC.Checked

# Build a temporary pool config with only selected pools
$fullCfg = Get-Content $MC_CONFIG | ConvertFrom-Json
$selectedPools = @()
if ($START_ZCL) { $selectedPools += $fullCfg.pools | Where-Object { $_.id -eq "zcl_solo1" } }
if ($START_VTC) { $selectedPools += $fullCfg.pools | Where-Object { $_.id -eq "vtc_solo1" } }
$fullCfg.pools = $selectedPools
$MC_CONFIG_ACTIVE = "$MC_DIR\active_pool.json"
$fullCfg | ConvertTo-Json -Depth 20 | Set-Content $MC_CONFIG_ACTIVE -Encoding UTF8

Write-Host "Starting with coins: $(($selectedPools | Select-Object -ExpandProperty id) -join ', ')" -ForegroundColor Cyan

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
if ($START_ZCL) {
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
$poolAddr = ($poolCfg.pools | Where-Object { $_.id -eq "zcl_solo1" }).address
$importResult = & "$ZCL_DIR\zclassic-cli.exe" importaddress $poolAddr "" false 2>&1
Write-OK "Pool address imported into wallet (prevents false orphans)."
} # end ZCL block

# ---- Step 2b: Vertcoin Daemon ----------------------------------
if ($START_VTC) {
Write-Step "Checking Vertcoin daemon (vertcoind)..."
$vtcProc = Get-Process -Name "vertcoind" -ErrorAction SilentlyContinue
if ($null -eq $vtcProc) {
    Write-Host "    Starting vertcoind..." -ForegroundColor Yellow
    $vtcDaemon = Join-Path $VTC_DIR "vertcoind.exe"
    Start-Process -FilePath $vtcDaemon -ArgumentList "-conf=`"$VTC_CONF`"" -WindowStyle Minimized
    Write-Host "    Waiting for Vertcoin RPC to become available..." -ForegroundColor Yellow
    $ready = $false
    for ($i = 0; $i -lt 60; $i++) {
        Start-Sleep -Seconds 2
        $result = & $VTC_CLI getblockcount 2>&1
        if ($result -match '^\d+$') { $ready = $true; break }
    }
    if (-not $ready) {
        Stop-WithError "vertcoind did not respond in time. It may still be starting - try again in a minute."
    }
} else {
    Write-Host "    vertcoind already running (PID $($vtcProc.Id))." -ForegroundColor Yellow
}
$vtcBlocks = & $VTC_CLI getblockcount 2>&1
Write-OK "vertcoind running. Block height: $vtcBlocks"
} # end VTC block

# ---- Step 3: Launch MiningCore ---------------------------------
Write-Step "Starting MiningCore BitsPleaseYT Solo Pool..."
$activePorts = @()
if ($START_ZCL) { $activePorts += "ZCL port 3032" }
if ($START_VTC) { $activePorts += "VTC port 3052" }
Write-Host "    Pool listening on: $($activePorts -join ' | ')" -ForegroundColor Yellow
Write-Host "    Config: $MC_CONFIG_ACTIVE" -ForegroundColor DarkGray
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

# Start false-orphan recovery monitor(s) in background
if ($START_ZCL) {
    $monitorArgs = @(
        "-NonInteractive", "-WindowStyle", "Hidden",
        "-File", "C:\Users\tourj\mining core\Watch-ZCL-BlockOrphans.ps1",
        "-ZclDir", "`"$ZCL_DIR`"",
        "-PsqlBin", "`"$PSQL_BIN`""
    )
    $monProc = Start-Process -FilePath "pwsh" -ArgumentList $monitorArgs -PassThru -WindowStyle Hidden
    Write-OK "ZCL orphan recovery monitor running (PID $($monProc.Id))."
}

if ($START_VTC) {
    $vtcMonitorArgs = @(
        "-NonInteractive", "-WindowStyle", "Hidden",
        "-File", "C:\Users\tourj\mining core\Watch-VTC-BlockOrphans.ps1",
        "-VtcCli", "`"$VTC_CLI`"",
        "-PsqlBin", "`"$PSQL_BIN`""
    )
    $vtcMonProc = Start-Process -FilePath "pwsh" -ArgumentList $vtcMonitorArgs -PassThru -WindowStyle Hidden
    Write-OK "VTC orphan recovery monitor running (PID $($vtcMonProc.Id))."
}

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
& "$MC_DIR\Miningcore.exe" -c "$MC_CONFIG_ACTIVE" 2>&1 | ForEach-Object {
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

# Stop dashboard, tunnel and monitors when pool exits
if ($dashProc   -and -not $dashProc.HasExited)   { Stop-Process -Id $dashProc.Id   -ErrorAction SilentlyContinue }
if ($cfProc     -and -not $cfProc.HasExited)     { Stop-Process -Id $cfProc.Id     -ErrorAction SilentlyContinue }
if ($monProc    -and -not $monProc.HasExited)    { Stop-Process -Id $monProc.Id    -ErrorAction SilentlyContinue }
if ($vtcMonProc -and -not $vtcMonProc.HasExited) { Stop-Process -Id $vtcMonProc.Id -ErrorAction SilentlyContinue }

# Keep window open if pool exits
Write-Host ""
Write-Host "MiningCore has stopped." -ForegroundColor Yellow
Write-Host "Press any key to close..." -ForegroundColor DarkGray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

