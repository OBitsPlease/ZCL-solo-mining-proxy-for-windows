const express = require('express');
const { createProxyMiddleware } = require('http-proxy-middleware');
const path = require('path');
const fs = require('fs');
const { exec } = require('child_process');
const fetch = require('node-fetch');
const { Pool } = require('pg');

const app = express();
const PORT = 8080;
const MININGCORE_API = 'http://127.0.0.1:4000';
const POOL_CONFIG_PATH = path.join(__dirname, '..', 'build', 'zclassic_solo_pool.json');

// Load install paths written by installer (falls back gracefully when not present)
let ZCL_CLI = 'C:\\Users\\tourj\\OneDrive\\Documents\\MINING MINING MINING\\WALLETS\\ZCLASSIC\\zclassic-2-1-1-60-windows-gui-x86_64\\zclassic-2-1-1-60-windows-gui-x86_64\\zclassic-cli.exe';
let VTC_CLI = 'C:\\Users\\tourj\\OneDrive\\Documents\\MINING MINING MINING\\WALLETS\\VERTCOIN\\daemon\\vertcoin-cli.exe';
try {
    const installPaths = JSON.parse(fs.readFileSync(path.join(__dirname, '..', 'paths.json'), 'utf8'));
    if (installPaths.zclCli) ZCL_CLI = installPaths.zclCli;
    if (installPaths.vtcCli) VTC_CLI = installPaths.vtcCli;
} catch (_) {}

// Per-pool config: maps poolId → { cliPath, cliBalanceCmd, coinGeckoId, symbol }
const POOL_META = {
    'zcl_solo1': {
        cli:         () => ZCL_CLI,
        balanceCmd:  (cli) => `"${cli}" getbalance`,
        parseBalance:(out) => parseFloat(out.trim()),
        coinGeckoId: 'zclassic',
        symbol:      'ZCL',
        name:        'ZClassic',
        color:       '#f7931a',
        hashUnit:    'Sol/s',
        hashrateMultiplier: 8192,   // Equihash 192,7: solutions * 8192
        blockReward:        0.390625, // ZCL block reward
        logo:        'zclassic-zcl-logo.png'
    },
    'vtc_solo1': {
        cli:         () => VTC_CLI,
        balanceCmd:  (cli) => `"${cli}" -rpcport=15889 -rpcuser=vtcuser -rpcpassword=vtcpass getbalance`,
        parseBalance:(out) => parseFloat(out.trim()),
        coinGeckoId: 'vertcoin',
        symbol:      'VTC',
        name:        'Vertcoin',
        color:       '#1b8a3e',
        hashUnit:    'H/s',
        hashrateMultiplier: 4294967296,  // Verthash: difficulty * 2^32
        blockReward:        6.25,         // VTC block reward (halved Dec 8 2025)
        logo:        'vertcoin-vtc-logo.png'
    }
};

const db = new Pool({
    host: '127.0.0.1',
    port: 5432,
    database: 'miningcore',
    user: 'miningcore',
    password: 'password'
});

app.use(express.json());

// Proxy all /api calls to MiningCore
app.use('/api', createProxyMiddleware({
    target: MININGCORE_API,
    changeOrigin: true,
    on: {
        error: (err, req, res) => {
            res.status(502).json({ error: 'MiningCore API unreachable', detail: err.message });
        }
    }
}));

// Admin: read current pool config minimumPayment
app.get('/dashboard/config', (req, res) => {
    try {
        const cfg = JSON.parse(fs.readFileSync(POOL_CONFIG_PATH, 'utf8'));
        const pool = cfg.pools && cfg.pools[0];
        res.json({
            minimumPayment: pool?.paymentProcessing?.minimumPayment ?? null,
            poolAddress: pool?.address ?? null,
            poolId: pool?.id ?? null
        });
    } catch (e) {
        res.status(500).json({ error: e.message });
    }
});

// Helper: determine if request is from localhost
function isLocalRequest(req) {
    const ip = req.ip || req.connection.remoteAddress || '';
    return ip === '127.0.0.1' || ip === '::1' || ip === '::ffff:127.0.0.1';
}

// Admin: update minimumPayment in pool config — localhost only
app.post('/dashboard/config/minimumPayment', (req, res) => {
    if (!isLocalRequest(req)) {
        return res.status(403).json({ error: 'Global payout threshold can only be changed from the pool machine (local access).' });
    }
    try {
        const { value } = req.body;
        const num = parseFloat(value);
        if (isNaN(num) || num < 0) return res.status(400).json({ error: 'Invalid value' });

        const raw = fs.readFileSync(POOL_CONFIG_PATH, 'utf8');
        const cfg = JSON.parse(raw);
        if (cfg.pools && cfg.pools[0] && cfg.pools[0].paymentProcessing) {
            cfg.pools[0].paymentProcessing.minimumPayment = num;
        }
        fs.writeFileSync(POOL_CONFIG_PATH, JSON.stringify(cfg, null, 4), 'utf8');
        res.json({ success: true, minimumPayment: num });
    } catch (e) {
        res.status(500).json({ error: e.message });
    }
});

// Per-miner threshold — requires the worker's IP to have recent shares for that address
app.post('/dashboard/miner-threshold', async (req, res) => {
    try {
        const { address, ip, paymentThreshold } = req.body;
        if (!address || !ip || paymentThreshold === undefined) {
            return res.status(400).json({ error: 'address, ip, and paymentThreshold are required' });
        }
        const thresh = parseFloat(paymentThreshold);
        if (isNaN(thresh) || thresh < 0) return res.status(400).json({ error: 'Invalid threshold value' });

        // Verify this IP has submitted shares for this miner address within the last 24 hours
        const check = await db.query(
            `SELECT COUNT(*) AS cnt FROM shares
             WHERE miner = $1 AND ipaddress = $2
               AND created > NOW() - INTERVAL '24 hours'`,
            [address, ip]
        );
        if (parseInt(check.rows[0].cnt, 10) === 0) {
            return res.status(403).json({ error: 'IP not recognized: no recent shares found for this address from that IP.' });
        }

        // Forward to MiningCore admin API
        const r = await fetch(`${MININGCORE_API}/admin/pools/${req.body.poolId || 'zcl_solo1'}/miners/${address}/settings`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ paymentThreshold: thresh })
        });
        const data = await r.json();
        res.json({ success: true, paymentThreshold: data.paymentThreshold ?? thresh });
    } catch (e) {
        res.status(500).json({ error: e.message });
    }
});

// Serve static dashboard
app.use(express.static(path.join(__dirname, 'public')));

// ─── BLOCK WORKER CACHE ────────────────────────────────────────────────────
// MiningCore deletes shares after each payout cycle, making retroactive worker
// lookup impossible. We capture worker info the moment a new block appears,
// before shares are wiped, and persist it in our own table.

async function ensureBlockWorkerCache() {
    await db.query(`
        CREATE TABLE IF NOT EXISTS block_worker_cache (
            poolid      TEXT NOT NULL,
            blockheight BIGINT NOT NULL,
            worker      TEXT NOT NULL,
            captured_at TIMESTAMPTZ DEFAULT NOW(),
            PRIMARY KEY (poolid, blockheight)
        )
    `);
}
ensureBlockWorkerCache().catch(e => console.error('[block_worker_cache] setup error:', e.message));

async function captureNewBlockWorkers() {
    try {
        const poolId = 'zcl_solo1';
        // Get all blocks we don't yet have a worker for
        const missing = await db.query(`
            SELECT b.blockheight
            FROM blocks b
            LEFT JOIN block_worker_cache c ON c.poolid = b.poolid AND c.blockheight = b.blockheight
            WHERE b.poolid = $1 AND c.blockheight IS NULL
        `, [poolId]);
        if (!missing.rows.length) return;

        const heights = missing.rows.map(r => parseInt(r.blockheight, 10));
        // Look up most common worker per block height from shares (may still exist briefly)
        const shares = await db.query(`
            SELECT blockheight, worker, COUNT(*) cnt
            FROM shares
            WHERE poolid = $1 AND blockheight = ANY($2::bigint[])
            GROUP BY blockheight, worker
            ORDER BY blockheight, cnt DESC
        `, [poolId, heights]);

        const map = {};
        shares.rows.forEach(r => { if (!map[r.blockheight]) map[r.blockheight] = r.worker; });

        // For heights where we still have shares, insert into cache
        for (const [height, worker] of Object.entries(map)) {
            await db.query(`
                INSERT INTO block_worker_cache (poolid, blockheight, worker)
                VALUES ($1, $2, $3)
                ON CONFLICT (poolid, blockheight) DO NOTHING
            `, [poolId, parseInt(height, 10), worker]);
            console.log(`[block_worker_cache] Captured: block ${height} → ${worker}`);
        }
    } catch (e) {
        // Silently skip — will retry on next interval
    }
}

// Run immediately + every 20 seconds to catch blocks before shares are deleted
captureNewBlockWorkers();
setInterval(captureNewBlockWorkers, 20000);

// Endpoint: get worker name for a list of block heights
app.post('/dashboard/block-workers', async (req, res) => {
    try {
        const { poolId, heights } = req.body;
        if (!heights || !heights.length) return res.json({});

        // First check our persistent cache (survives share deletion)
        const cached = await db.query(`
            SELECT blockheight, worker FROM block_worker_cache
            WHERE poolid = $1 AND blockheight = ANY($2::bigint[])
        `, [poolId, heights]);

        const map = {};
        cached.rows.forEach(r => { map[r.blockheight] = r.worker; });

        // For any heights not yet in cache, fall back to live shares table
        const uncached = heights.filter(h => !map[h]);
        if (uncached.length) {
            const live = await db.query(`
                SELECT blockheight, worker, COUNT(*) cnt
                FROM shares
                WHERE poolid = $1 AND blockheight = ANY($2::bigint[])
                GROUP BY blockheight, worker
                ORDER BY blockheight, cnt DESC
            `, [poolId, uncached]);
            live.rows.forEach(r => { if (!map[r.blockheight]) map[r.blockheight] = r.worker; });
        }

        res.json(map);
    } catch (e) {
        res.json({});
    }
});
// Endpoint: truly active workers from shares table (last 10 min)
// Hashrate estimated from difficulty sum: sol/s ≈ sum(difficulty)*65536 / window_seconds
app.get('/dashboard/active-workers', async (req, res) => {
    try {
        const poolId  = req.query.poolId || 'zcl_solo1';
        const window  = parseInt(req.query.window || '600', 10); // seconds, default 10 min
        const multiplier = (POOL_META[poolId] || {}).hashrateMultiplier || 8192;
        const r = await db.query(`
            SELECT
                miner, worker,
                COUNT(*)                            AS share_count,
                SUM(difficulty)                     AS diff_sum,
                MAX(created)                        AS last_share,
                EXTRACT(EPOCH FROM (NOW() - MIN(created))) AS elapsed_sec,
                (array_agg(useragent ORDER BY created DESC))[1] AS useragent,
                (array_agg(difficulty ORDER BY created DESC))[1] AS current_diff
            FROM shares
            WHERE poolid = $1
              AND created > NOW() - ($2 || ' seconds')::INTERVAL
            GROUP BY miner, worker
            ORDER BY last_share DESC
        `, [poolId, window]);

        const workers = r.rows.map(w => {
            const elapsed = Math.max(parseFloat(w.elapsed_sec) || window, 1);
            // Per-algorithm hashrate formula: diff_sum * multiplier / elapsed
            const hashrate = Math.round((parseFloat(w.diff_sum) * multiplier) / Math.min(elapsed, window));
            // Clean up useragent: strip trailing version noise, truncate
            const ua = (w.useragent || '').replace(/\s+\(.*\)$/, '').trim().slice(0, 30) || '—';
            const diff = parseFloat(w.current_diff) || 0;
            return {
                miner:       w.miner,
                worker:      w.worker,
                hashrate,
                shareCount:  parseInt(w.share_count, 10),
                lastShare:   w.last_share,
                software:    ua,
                diff:        diff
            };
        });

        const totalHashrate = workers.reduce((s, w) => s + w.hashrate, 0);
        res.json({ workers, totalHashrate });
    } catch (e) {
        res.json({ workers: [], totalHashrate: 0, error: e.message });
    }
});
// Endpoint: pool balance — sum of unpaid confirmed/pending block rewards
app.get('/dashboard/pool-balance', async (req, res) => {
    try {
        const poolId = req.query.poolId || 'zcl_solo1';
        const r = await db.query(
            "SELECT COALESCE(SUM(reward),0) AS total FROM blocks WHERE poolid=$1 AND status IN ('pending','confirmed')",
            [poolId]
        );
        const balance = parseFloat(r.rows[0].total);
        res.json({ balance });
    } catch (e) {
        res.json({ balance: 0 });
    }
});
// Endpoint: pending/immature block rewards (maturing but not yet payable)
app.get('/dashboard/pending-rewards', async (req, res) => {
    try {
        const poolId = req.query.poolId || 'zcl_solo1';
        const defaultReward = (POOL_META[poolId] || {}).blockReward || 0;
        const r = await db.query(
            `SELECT blockheight, reward, confirmationprogress
             FROM blocks WHERE poolid=$1 AND status IN ('pending','created')
             ORDER BY blockheight DESC`,
            [poolId]
        );
        // Use actual reward if populated, otherwise fall back to known block reward
        const blocks = r.rows.map(b => ({
            ...b,
            reward: parseFloat(b.reward) > 0 ? parseFloat(b.reward) : defaultReward
        }));
        const total = blocks.reduce((s, b) => s + b.reward, 0);
        res.json({ total, count: blocks.length, blocks });
    } catch (e) {
        res.json({ total: 0, count: 0, blocks: [] });
    }
});

app.get('/dashboard/shares-rate', async (req, res) => {
    try {
        const poolId = req.query.poolId || 'zcl_solo1';
        const r = await db.query(
            "SELECT COUNT(*) cnt FROM shares WHERE poolid=$1 AND created > NOW() - INTERVAL '10 minutes'",
            [poolId]
        );
        const count = parseInt(r.rows[0].cnt, 10);
        res.json({ sharesPerSecond: +(count / 600).toFixed(4) });
    } catch (e) {
        res.json({ sharesPerSecond: 0 });
    }
});
let priceCaches = {};
app.get('/dashboard/wallet-stats', async (req, res) => {
    try {
        const poolId = req.query.poolId || 'zcl_solo1';
        const meta = POOL_META[poolId];
        if (!meta) return res.json({ price: null, balance: null, usdValue: null });

        // Coin price from CoinGecko (cache 60s per coin)
        let price = null;
        const cache = priceCaches[poolId] || { price: null, ts: 0 };
        if (Date.now() - cache.ts < 60000 && cache.price !== null) {
            price = cache.price;
        } else {
            try {
                const r = await fetch(`https://api.coingecko.com/api/v3/simple/price?ids=${meta.coinGeckoId}&vs_currencies=usd`, { timeout: 8000 });
                const data = await r.json();
                price = data?.[meta.coinGeckoId]?.usd ?? null;
                if (price !== null) priceCaches[poolId] = { price, ts: Date.now() };
            } catch (_) {}
        }

        const cli = meta.cli();
        const balance = await new Promise((resolve) => {
            exec(meta.balanceCmd(cli), (err, stdout) => {
                if (err) return resolve(null);
                try { resolve(meta.parseBalance(stdout)); } catch (_) { resolve(null); }
            });
        });

        res.json({
            price,
            balance,
            symbol: meta.symbol,
            usdValue: (price !== null && balance !== null) ? +(price * balance).toFixed(2) : null
        });
    } catch (e) {
        res.json({ price: null, balance: null, usdValue: null, error: e.message });
    }
});

// Pool metadata endpoint — tells the dashboard about all available pools
app.get('/dashboard/pools-meta', (req, res) => {
    const result = Object.entries(POOL_META).map(([id, m]) => ({
        id, symbol: m.symbol, name: m.name, color: m.color, hashUnit: m.hashUnit, logo: m.logo
    }));
    res.json(result);
});

// Live share monitor — returns most recent N shares with worker hashrate
app.get('/dashboard/live-shares', async (req, res) => {
    try {
        const poolId = req.query.poolId || 'zcl_solo1';
        const since  = req.query.since  || new Date(Date.now() - 30000).toISOString();
        const meta   = POOL_META[poolId] || {};
        const mult   = meta.hashrateMultiplier || 8192;

        // Get new shares since cursor
        const r = await db.query(`
            SELECT created, worker, miner, difficulty
            FROM shares
            WHERE poolid = $1
              AND created > $2::timestamptz
            ORDER BY created DESC
            LIMIT 200
        `, [poolId, since]);

        if (!r.rows.length) return res.json([]);

        // Get per-worker 60s hashrate for all workers seen in this batch
        const workers = [...new Set(r.rows.map(x => x.worker))];
        const hrMap = {};
        for (const w of workers) {
            const hr = await db.query(`
                SELECT COALESCE(SUM(difficulty),0) AS diff_sum,
                       EXTRACT(EPOCH FROM (MAX(created)-MIN(created))) AS span
                FROM shares
                WHERE poolid = $1 AND worker = $2
                  AND created > NOW() - INTERVAL '60 seconds'
            `, [poolId, w]);
            const span = Math.max(parseFloat(hr.rows[0].span) || 60, 5);
            hrMap[w] = Math.round((parseFloat(hr.rows[0].diff_sum) * mult) / span);
        }

        const rows = r.rows.map(row => ({
            time:     row.created,
            worker:   row.worker || '—',
            miner:    row.miner,
            diff:     parseFloat(row.difficulty),
            valid:    true,
            error:    null,
            hashrate: hrMap[row.worker] || 0
        }));

        res.json(rows);
    } catch(e) {
        console.error('live-shares error:', e.message);
        res.json([]);
    }
});

app.get('*', (req, res) => res.sendFile(path.join(__dirname, 'public', 'index.html')));

app.listen(PORT, () => {
    console.log(`\n  ZClassic Pool Dashboard running at http://localhost:${PORT}\n`);
});
