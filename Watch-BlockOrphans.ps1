# ============================================================
#  ZClassic Pool - Automatic False-Orphan Recovery Monitor
#  Runs in background, checks every 3 minutes
# ============================================================

param(
    [string]$ZclDir,
    [string]$PsqlBin,
    [string]$DbUser     = "miningcore",
    [string]$DbPassword = "password",
    [string]$DbName     = "miningcore",
    [string]$PoolId     = "zcl_solo1",
    [int]   $IntervalSeconds = 180
)

$env:PATH = "$PsqlBin;$env:PATH"
$env:PGPASSWORD = $DbPassword

function Write-Monitor($msg, $color = "DarkGray") {
    $ts = Get-Date -Format "HH:mm:ss"
    Write-Host "[$ts] [BlockMonitor] $msg" -ForegroundColor $color
}

function Invoke-Psql($sql) {
    return $sql | & "$PsqlBin\psql.exe" -U $DbUser -d $DbName -t -A 2>&1
}

Write-Monitor "Started. Checking for false orphans every $IntervalSeconds seconds." "Cyan"

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

            # Ask the ZCL daemon for the actual block hash at this height
            $chainHash = & "$ZclDir\zclassic-cli.exe" getblockhash $blockHeight 2>&1

            if ($LASTEXITCODE -ne 0 -or $chainHash -match "error") {
                Write-Monitor "Could not getblockhash for block $blockHeight (daemon error)" "Yellow"
                continue
            }

            $chainHash = $chainHash.Trim()

            if ($chainHash -ieq $storedHash) {
                # Block IS on the main chain — false orphan, reset to pending
                Invoke-Psql "UPDATE blocks SET status='pending', confirmationprogress=0 WHERE id=$id;" | Out-Null
                Write-Monitor "RECOVERED block $blockHeight — hash matched chain, reset to pending." "Green"
            } else {
                Write-Monitor "Block $blockHeight is a true orphan (chain hash $($chainHash.Substring(0,12))… != stored $($storedHash.Substring(0,12))…)" "Yellow"
            }
        }
    } catch {
        Write-Monitor "Monitor error: $_" "Red"
    }
}
