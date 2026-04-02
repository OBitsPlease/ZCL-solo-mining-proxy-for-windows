# ============================================================
#  Vertcoin Pool - Automatic False-Orphan Recovery Monitor
#  Runs in background, checks every 3 minutes
# ============================================================

param(
    [string]$VtcCli,
    [string]$PsqlBin,
    [string]$DbUser     = "miningcore",
    [string]$DbPassword = "password",
    [string]$DbName     = "miningcore",
    [string]$PoolId     = "vtc_solo1",
    [int]   $IntervalSeconds = 180
)

$env:PATH = "$PsqlBin;$env:PATH"
$env:PGPASSWORD = $DbPassword

$LogDir  = "C:\Users\tourj\mining core\build\logs"
$LogFile = "$LogDir\vtc-orphan-monitor.log"
New-Item -ItemType Directory -Force $LogDir | Out-Null

function Write-Monitor($msg, $color = "DarkGray") {
    $ts = Get-Date -Format "HH:mm:ss"
    Write-Host "[$ts] [VTC-BlockMonitor] $msg" -ForegroundColor $color
}

function Write-Log($msg) {
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "[$ts] $msg" | Add-Content -Path $LogFile
}

function Invoke-Psql($sql) {
    return $sql | & "$PsqlBin\psql.exe" -U $DbUser -d $DbName -t -A 2>&1
}

Write-Monitor "Started. Checking for false orphans every $IntervalSeconds seconds." "Cyan"
Write-Log "Monitor started. Pool: $PoolId"

while ($true) {
    Start-Sleep -Seconds $IntervalSeconds

    try {
        # Find all orphaned blocks for this pool
        $orphans = Invoke-Psql "SELECT id,blockheight,hash FROM blocks WHERE poolid='$PoolId' AND status='orphaned';"

        if (-not $orphans -or $orphans -match "^$" -or $orphans.Count -eq 0) {
            continue
        }

        foreach ($row in $orphans) {
            $row = $row.Trim()
            if ([string]::IsNullOrWhiteSpace($row)) { continue }

            $parts = $row -split '\|'
            if ($parts.Count -lt 3) { continue }

            $id          = $parts[0].Trim()
            $blockHeight = $parts[1].Trim()
            $storedHash  = $parts[2].Trim()

            # Ask the VTC daemon for the actual block hash at this height
            $chainHash = & $VtcCli getblockhash $blockHeight 2>&1

            if ($LASTEXITCODE -ne 0 -or $chainHash -match "error") {
                Write-Monitor "Could not getblockhash for block $blockHeight (daemon error)" "Yellow"
                Write-Log "ERROR: Could not getblockhash for block $blockHeight"
                continue
            }

            $chainHash = $chainHash.Trim()

            if ($chainHash -ieq $storedHash) {
                # Block IS on the main chain — false orphan, reset to pending
                Invoke-Psql "UPDATE blocks SET status='pending', confirmationprogress=0 WHERE id=$id;" | Out-Null
                Write-Monitor "RECOVERED block $blockHeight — hash matched chain, reset to pending." "Green"
                Write-Log "RECOVERED: Block $blockHeight (id=$id) was false orphan — reset to pending. Hash: $storedHash"
            } else {
                Write-Monitor "Block $blockHeight is a true orphan (chain hash $($chainHash.Substring(0,12))… != stored $($storedHash.Substring(0,12))…)" "Yellow"
                Write-Log "ORPHAN: Block $blockHeight (id=$id) confirmed true orphan. Chain: $chainHash | Stored: $storedHash"
            }
        }
    } catch {
        Write-Monitor "Monitor error: $_" "Red"
        Write-Log "ERROR: $_"
    }
}
