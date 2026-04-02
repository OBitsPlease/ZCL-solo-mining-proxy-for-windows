# BitsPleaseYT Solo Pool Version 2.0.0
### Created by [BitsPleaseYT](https://www.youtube.com/@BitsPleaseYT/shorts)

A fully automated, one-click installer for running a ZClassic (ZCL) solo mining pool on Windows.  
Built on [MiningCore](https://github.com/oliverw/miningcore) with a live web dashboard.

![Splash](https://raw.githubusercontent.com/OBitsPlease/ZCL-solo-mining-proxy-for-windows/main/splash-preview.png)

---

## ⬇️ Download

**[ZCLPool-Setup-1.0.0.exe](https://github.com/OBitsPlease/ZCL-solo-mining-proxy-for-windows/releases/download/v1.0.0/ZCLPool-Setup-1.0.0.exe)**  
Windows 10/11 x64 · ~58 MB · Includes everything

---

## 📋 Requirements

- Windows 10 or 11 (64-bit)
- Internet connection (blockchain sync takes 1–3 days on first install)
- Your ZCL wallet address (generated during setup)
- Mining hardware with Equihash 192,7 support (GPU or ASIC)

---

## 🚀 Installation — Two Phases

### Phase 1 — Run the Installer
1. Download and run `ZCLPool-Setup-1.0.0.exe`
2. The ZCL Wallet opens automatically — **let the blockchain fully sync**
3. A **"Finish ZCL Pool Setup"** shortcut appears on your Desktop

> ⏳ Blockchain sync takes 1–3 days on a new PC. You'll see "Synced" in the wallet when ready.

### Phase 2 — Complete Setup (after blockchain syncs)
1. Double-click **"Finish ZCL Pool Setup"** on your Desktop
2. Enter your ZCL addresses, RPC username, and password
3. Setup automatically installs Node.js, PostgreSQL, creates the database, and patches your config
4. The **"Start ZCL Solo Pool"** icon replaces the setup icon on your Desktop

### Starting the Pool
1. Double-click **"Start ZCL Solo Pool"**
2. Point your miner to:
   ```
   stratum+tcp://YOUR-PC-IP:3032
   Worker: your ZCL t1... address
   ```
3. Dashboard opens at **http://localhost:8080**

---

## 📊 Dashboard Features

- Live pool hashrate, network hashrate, difficulty
- Blocks found with worker names, effort, and reward
- Real-time ZCL price (USD)
- Wallet balance + USD value
- Pool balance (unpaid block rewards)
- Shares/sec, connected miners, active workers
- Auto false-orphan block recovery monitor

---

## 💰 Dev Fee

A **2% dev fee** is automatically included in every block reward.  
You receive **98%** of every block found.  
Fee address: `t1Kj7QD3sr4zExos5M9vHYz5di8T5H5Vqtb`

---

## 🔧 What's Included

| Component | Details |
|---|---|
| MiningCore | Equihash 192,7 solo pool server |
| ZClassic Daemon | `zclassicd.exe` — full node |
| ZCL Wallet | `zclwallet.exe` — GUI wallet |
| Web Dashboard | Node.js + PostgreSQL |
| Auto Orphan Monitor | Runs in background, recovers false orphans |
| PostgreSQL | Auto-installed during Phase 2 |
| Node.js | Auto-installed during Phase 2 |

---

## 🔗 Connect

| Platform | Link |
|---|---|
| 🎵 TikTok | [@BitsPleaseYT](https://www.tiktok.com/@bitspleaseyt?lang=en) |
| ▶️ YouTube | [@BitsPleaseYT](https://www.youtube.com/@BitsPleaseYT/shorts) |
| 💬 Discord | [Join the community](https://discord.gg/E8RgFphZ) |

---

## ⚠️ Disclaimer

This software is provided as-is. Solo mining involves risk — blocks may not be found for extended periods depending on your hashrate vs. network difficulty. Always verify your wallet address in the config before mining.
