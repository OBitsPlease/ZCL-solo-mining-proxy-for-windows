# ============================================================
#  ZClassic Solo Pool - Phase 2 Setup (Run after blockchain sync)
#  Shows GUI form to collect user settings, installs dependencies
# ============================================================

# Self-elevate to admin if needed
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process pwsh -Verb RunAs -ArgumentList "-ExecutionPolicy Bypass -File `"$PSCommandPath`""
    exit
}

$INSTALL_DIR = $PSScriptRoot
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ---- Helper to generate a random password ----
function New-RandomPassword {
    $chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789!@#$'
    -join (1..16 | ForEach-Object { $chars[(Get-Random -Max $chars.Length)] })
}

# ---- Build the input form ----
$form = New-Object System.Windows.Forms.Form
$form.Text           = "BitsPleaseYT Solo Pools v2.0.0 - Complete Setup"
$form.Size           = New-Object System.Drawing.Size(620, 660)
$form.StartPosition  = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox    = $false
$form.BackColor      = [System.Drawing.Color]::FromArgb(24, 24, 32)
$form.ForeColor      = [System.Drawing.Color]::White

# ---- Splash/banner image at top ----
$splashPath = "$INSTALL_DIR\splash.png"
if (Test-Path $splashPath) {
    $picBox = New-Object System.Windows.Forms.PictureBox
    $picBox.Location  = New-Object System.Drawing.Point(0, 0)
    $picBox.Size      = New-Object System.Drawing.Size(620, 160)
    $picBox.SizeMode  = "Zoom"
    $picBox.BackColor = [System.Drawing.Color]::FromArgb(24, 24, 32)
    $picBox.Image     = [System.Drawing.Image]::FromFile($splashPath)
    $form.Controls.Add($picBox)
}

$yBase = 170

function Add-Label($text, $x, $y, $w=560, $bold=$false, $size=10) {
    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text      = $text
    $lbl.Location  = New-Object System.Drawing.Point($x, $y)
    $lbl.Size      = New-Object System.Drawing.Size($w, 22)
    $lbl.ForeColor = [System.Drawing.Color]::FromArgb(200, 200, 220)
    $style = if ($bold) { [System.Drawing.FontStyle]::Bold } else { [System.Drawing.FontStyle]::Regular }
    $lbl.Font      = New-Object System.Drawing.Font("Segoe UI", $size, $style)
    $form.Controls.Add($lbl)
    return $lbl
}

function Add-TextBox($default, $x, $y, $w=560) {
    $tb = New-Object System.Windows.Forms.TextBox
    $tb.Text       = $default
    $tb.Location   = New-Object System.Drawing.Point($x, $y)
    $tb.Size       = New-Object System.Drawing.Size($w, 26)
    $tb.BackColor  = [System.Drawing.Color]::FromArgb(40, 40, 55)
    $tb.ForeColor  = [System.Drawing.Color]::White
    $tb.Font       = New-Object System.Drawing.Font("Consolas", 10)
    $tb.BorderStyle = "FixedSingle"
    $form.Controls.Add($tb)
    return $tb
}

Add-Label "Complete ZClassic Solo Pool Setup" 28 $yBase 560 $true 13 | Out-Null
Add-Label "Fill in your ZCL wallet details below, then click Complete Setup." 28 ($yBase+30) 560 | Out-Null

$y = $yBase + 70
Add-Label "Your ZCL Transparent Address (t1...)" 28 $y | Out-Null
$tbAddr = Add-TextBox "" 28 ($y+24)

$y += 68
Add-Label "Your ZCL z-Address (optional, zs1...)" 28 $y | Out-Null
$tbZAddr = Add-TextBox "" 28 ($y+24)

$y += 68
Add-Label "ZCL Daemon RPC Username" 28 $y | Out-Null
$tbRpcUser = Add-TextBox "zclrpc" 28 ($y+24) 260

Add-Label "RPC Password  (or leave for auto-generated)" 308 $y | Out-Null
$rpcDefault = New-RandomPassword
$tbRpcPass = Add-TextBox $rpcDefault 308 ($y+24) 280

$y += 68
Add-Label "Note: 2% dev fee to t1Kj7QD3sr4zExos5M9vHYz5di8T5H5Vqtb is included." 28 $y 560 $false 9 | Out-Null
Add-Label "You keep 98% of every block reward. Fee pays only when blocks are found." 28 ($y+16) 560 $false 9 | Out-Null

# ---- Progress log box ----
$y += 52
Add-Label "Setup Log:" 28 $y | Out-Null
$logBox = New-Object System.Windows.Forms.TextBox
$logBox.Location   = New-Object System.Drawing.Point(28, ($y+22))
$logBox.Size       = New-Object System.Drawing.Size(560, 120)
$logBox.Multiline  = $true
$logBox.ScrollBars = "Vertical"
$logBox.ReadOnly   = $true
$logBox.BackColor  = [System.Drawing.Color]::FromArgb(10, 10, 20)
$logBox.ForeColor  = [System.Drawing.Color]::FromArgb(80, 220, 80)
$logBox.Font       = New-Object System.Drawing.Font("Consolas", 9)
$form.Controls.Add($logBox)

function Write-Log($msg) {
    $logBox.AppendText("$msg`r`n")
    $logBox.ScrollToCaret()
    [System.Windows.Forms.Application]::DoEvents()
}

# ---- Buttons ----
$btnOK = New-Object System.Windows.Forms.Button
$btnOK.Text      = "  Complete Setup  "
$btnOK.Location  = New-Object System.Drawing.Point(28, 590)
$btnOK.Size      = New-Object System.Drawing.Size(160, 36)
$btnOK.BackColor = [System.Drawing.Color]::FromArgb(34, 139, 34)
$btnOK.ForeColor = [System.Drawing.Color]::White
$btnOK.Font      = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$btnOK.FlatStyle = "Flat"
$form.Controls.Add($btnOK)

$btnCancel = New-Object System.Windows.Forms.Button
$btnCancel.Text      = "Cancel"
$btnCancel.Location  = New-Object System.Drawing.Point(200, 590)
$btnCancel.Size      = New-Object System.Drawing.Size(90, 36)
$btnCancel.BackColor = [System.Drawing.Color]::FromArgb(80, 30, 30)
$btnCancel.ForeColor = [System.Drawing.Color]::White
$btnCancel.FlatStyle = "Flat"
$form.Controls.Add($btnCancel)
$btnCancel.Add_Click({ $form.Close() })

# ---- Main setup logic triggered by OK button ----
$btnOK.Add_Click({
    $btnOK.Enabled = $false
    $btnCancel.Enabled = $false

    $addr   = $tbAddr.Text.Trim()
    $zAddr  = $tbZAddr.Text.Trim()
    $rpcUsr = if ($tbRpcUser.Text.Trim()) { $tbRpcUser.Text.Trim() } else { "zclrpc" }
    $rpcPwd = if ($tbRpcPass.Text.Trim()) { $tbRpcPass.Text.Trim() } else { (New-RandomPassword) }

    # Validate t-address
    if ($addr -and ($addr.Length -ne 35 -or -not $addr.StartsWith("t1"))) {
        [System.Windows.Forms.MessageBox]::Show(
            "ZCL transparent addresses are 35 characters starting with 't1'. Please check your address.",
            "Invalid Address", "OK", "Warning")
        $btnOK.Enabled = $true; $btnCancel.Enabled = $true; return
    }

    Write-Log "Starting Phase 2 setup..."

    # ---- 1. Node.js ----
    Write-Log "Checking Node.js..."
    if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
        Write-Log "  Installing Node.js LTS via winget..."
        winget install --id OpenJS.NodeJS.LTS --silent --accept-package-agreements --accept-source-agreements 2>&1 | Out-Null
        $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH","Machine") + ";" +
                    [System.Environment]::GetEnvironmentVariable("PATH","User")
    }
    Write-Log "  Node.js: $(& node --version 2>&1)"

    # ---- 2. PostgreSQL ----
    Write-Log "Checking PostgreSQL..."
    $pgSvc = Get-Service -Name "postgresql*" -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $pgSvc) {
        Write-Log "  Installing PostgreSQL 16..."
        winget install --id PostgreSQL.PostgreSQL.16 --silent --accept-package-agreements --accept-source-agreements `
            --override "--mode unattended --unattendedmodeui none --superpassword miningcore123 --serverport 5432" 2>&1 | Out-Null
        Start-Sleep 15
        $pgSvc = Get-Service -Name "postgresql*" -ErrorAction SilentlyContinue | Select-Object -First 1
    }
    if ($pgSvc -and $pgSvc.Status -ne "Running") {
        Start-Service $pgSvc.Name -ErrorAction SilentlyContinue; Start-Sleep 5
        $pgSvc = Get-Service -Name $pgSvc.Name
    }
    Write-Log "  PostgreSQL: $($pgSvc.Name) [$($pgSvc.Status)]"

    # ---- Find psql ----
    $PSQL_BIN = ""
    @("$env:ProgramFiles\PostgreSQL\16\bin","$env:ProgramFiles\PostgreSQL\15\bin",
      "C:\PostgreSQL\16\bin","C:\PostgreSQL\15\bin") |
        ForEach-Object { if (-not $PSQL_BIN -and (Test-Path "$_\psql.exe")) { $PSQL_BIN = $_ } }
    if (-not $PSQL_BIN) {
        $f = Get-ChildItem "C:\Program Files\PostgreSQL","C:\PostgreSQL" -Recurse -Filter "psql.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($f) { $PSQL_BIN = $f.DirectoryName }
    }

    if ($PSQL_BIN) {
        Write-Log "  psql found: $PSQL_BIN"
        $env:PATH = "$PSQL_BIN;$env:PATH"
        $env:PGPASSWORD = "miningcore123"

        # Create role + database
        Write-Log "  Setting up database..."
        @"
DO `$`$ BEGIN
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'miningcore') THEN
    CREATE ROLE miningcore WITH LOGIN PASSWORD 'password';
  END IF;
END `$`$;
"@ | & "$PSQL_BIN\psql.exe" -U postgres -d postgres 2>&1 | Out-Null

        $dbExists = "SELECT 1 FROM pg_database WHERE datname='miningcore';" |
            & "$PSQL_BIN\psql.exe" -U postgres -d postgres -t -A 2>&1
        if ($dbExists.Trim() -ne "1") {
            & "$PSQL_BIN\psql.exe" -U postgres -d postgres -c "CREATE DATABASE miningcore OWNER miningcore;" 2>&1 | Out-Null
        }
        & "$PSQL_BIN\psql.exe" -U miningcore -d miningcore -f "$INSTALL_DIR\sql\createdb.sql" 2>&1 | Out-Null
        Write-Log "  Database ready."
    } else {
        Write-Log "  WARNING: psql not found — DB setup skipped."
    }

    # ---- 2b. cloudflared (Cloudflare Tunnel for remote dashboard) ----
    Write-Log "Installing cloudflared for remote access..."
    if (-not (Get-Command cloudflared -ErrorAction SilentlyContinue)) {
        winget install --id Cloudflare.cloudflared --silent --accept-package-agreements --accept-source-agreements 2>&1 | Out-Null
    }
    Write-Log "  cloudflared: ready"

    # ---- 3. npm install ----
    Write-Log "Installing dashboard dependencies..."
    if (Get-Command node -ErrorAction SilentlyContinue) {
        Push-Location "$INSTALL_DIR\dashboard"
        npm install --silent 2>&1 | Out-Null
        Pop-Location
        Write-Log "  Dashboard npm packages installed."
    }

    # ---- 4. Write zclassic.conf ----
    Write-Log "Writing ZClassic config..."
    New-Item -ItemType Directory -Force "$env:APPDATA\ZClassic" | Out-Null
    $zclConf = "$env:APPDATA\ZClassic\zclassic.conf"
    $confContent = @"
rpcuser=$rpcUsr
rpcpassword=$rpcPwd
rpcport=8023
rpcallowip=127.0.0.1
server=1
listen=1
maxconnections=16
txindex=1
"@
    $confContent | Set-Content $zclConf
    Write-Log "  zclassic.conf written."

    # ---- 5. Patch pool JSON config ----
    Write-Log "Writing pool config..."
    $cfgPath = "$INSTALL_DIR\config\zclassic_solo_pool.json"
    try {
        $cfg = Get-Content $cfgPath | ConvertFrom-Json
        if ($addr) {
            $cfg.pools[0].address = $addr
            $cfg.pools[0].rewardRecipients[0].address = $addr
        }
        $cfg.pools[0].daemons[0].user     = $rpcUsr
        $cfg.pools[0].daemons[0].password = $rpcPwd
        if ($zAddr) { $cfg.pools[0] | Add-Member -MemberType NoteProperty -Name "z-address" -Value $zAddr -Force }
        $cfg | ConvertTo-Json -Depth 10 | Set-Content $cfgPath
        Write-Log "  Pool config updated."
    } catch { Write-Log "  WARNING: Could not patch config: $_" }

    # ---- 6. Write paths.json ----
    [ordered]@{
        installDir = $INSTALL_DIR
        zclDir     = "$INSTALL_DIR\zcl"
        zclCli     = "$INSTALL_DIR\zcl\zclassic-cli.exe"
        psqlBin    = $PSQL_BIN
    } | ConvertTo-Json | Set-Content "$INSTALL_DIR\paths.json"
    Write-Log "  paths.json written."

    # ---- 7. Create "Start ZCL Solo Pool" desktop shortcut ----
    Write-Log "Creating desktop shortcuts..."
    $WShell = New-Object -ComObject WScript.Shell

    $startLink = $WShell.CreateShortcut("$env:PUBLIC\Desktop\Start ZCL Solo Pool.lnk")
    $startLink.TargetPath  = "pwsh.exe"
    $startLink.Arguments   = "-ExecutionPolicy Bypass -File `"$INSTALL_DIR\Start-ZCL-Solo-Pool.ps1`""
    $startLink.WorkingDirectory = $INSTALL_DIR
    $startLink.Description = "Start ZClassic Solo Mining Pool"
    $startLink.IconLocation = "$INSTALL_DIR\zcl\zclwallet.exe,0"
    $startLink.Save()

    # ---- 8. Remove Phase 1 "Finish Setup" shortcut ----
    @(
        "$env:PUBLIC\Desktop\Finish ZCL Pool Setup.lnk",
        "$env:USERPROFILE\Desktop\Finish ZCL Pool Setup.lnk"
    ) | ForEach-Object { Remove-Item $_ -Force -ErrorAction SilentlyContinue }

    Write-Log ""
    Write-Log "============================================"
    Write-Log "  Setup complete!"
    Write-Log "  Edit config\zclassic_solo_pool.json to"
    Write-Log "  verify your address, then click:"
    Write-Log "  'Start ZCL Solo Pool' on your Desktop."
    Write-Log "============================================"

    $btnOK.Text    = "Done - Close"
    $btnOK.Enabled = $true
    $btnOK.Add_Click({ $form.Close() })
})

[void]$form.ShowDialog()
