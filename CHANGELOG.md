# BitsPleaseYT Solo Pool — Version 3.0.0 Changelog
## Changes from v2.0.0 to v3.0.0

1. Added coin selection popup on launch — checkboxes let you choose which coins (ZCL, VTC) to start before anything opens
2. Added background splash image to the coin selection popup with dark overlay for readability
3. Renamed desktop shortcut from "ZClassic Solo Pool" to "BitsPlease Solo Pool"
4. Updated desktop icon to mining pickaxe image
5. Renamed main launcher script from Start-ZCL-Solo-Pool.ps1 to Start-BitsPleaseYT-Solo-Pool.ps1
6. Renamed ZCL orphan monitor from Watch-BlockOrphans.ps1 to Watch-ZCL-BlockOrphans.ps1
7. Added VTC orphan monitor (Watch-VTC-BlockOrphans.ps1) — runs automatically when VTC is selected
8. Each orphan monitor now saves a log file to build/logs/ (zcl-orphan-monitor.log, vtc-orphan-monitor.log)
9. Orphan monitors are now gated per coin — only starts the monitor for coins you selected at launch
10. Fixed dashboard: block reward column was always labeled ZCL, now shows correct coin symbol (ZCL or VTC)
11. Fixed dashboard: Min. Payment label and Payments Amount column now update when switching pool tabs
12. Fixed VTC port label in startup output (was showing 3033, corrected to 3052)
13. Routed ZCL dev fee to pool owner's own mining address instead of a placeholder address
14. Removed hardcoded VTC RPC credentials from dashboard server.js — now reads from vertcoin.conf at runtime
15. Updated installer shortcut and uninstall icon to use mining.ico
16. Installer Complete-Install.ps1 now creates shortcut named "BitsPlease Solo Pool" with mining icon
