#!/usr/bin/env node
//
// Tiny harness server: binds to 127.0.0.1:<port>, accepts one POST to /,
// writes the request body to <out>, then exits. CI uses this as a
// side-channel to capture JSON from validate-probe.html without scraping
// the live DOM.
//
// Usage:
//   node browser-probe-server.js --port 8787 --out report.json [--timeout 60]
//
// Exits 0 when a report is received, 2 on timeout, 3 on misuse.

'use strict';
const http = require('http');
const fs = require('fs');
const path = require('path');

function parseArgs(argv) {
    const out = { port: 8787, out: 'report.json', timeout: 60 };
    for (let i = 2; i < argv.length; i++) {
        const a = argv[i];
        if (a === '--port')         out.port    = parseInt(argv[++i], 10);
        else if (a === '--out')     out.out     = argv[++i];
        else if (a === '--timeout') out.timeout = parseInt(argv[++i], 10);
        else if (a === '-h' || a === '--help') { console.log(__filename); process.exit(0); }
        else { console.error(`unknown arg: ${a}`); process.exit(3); }
    }
    if (!Number.isFinite(out.port) || out.port <= 0 || out.port > 65535) {
        console.error(`invalid --port`); process.exit(3);
    }
    return out;
}

const args = parseArgs(process.argv);
const outPath = path.resolve(args.out);
let gotReport = false;

const server = http.createServer((req, res) => {
    // CORS preflight from fetch().
    if (req.method === 'OPTIONS') {
        res.writeHead(204, {
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': 'POST, OPTIONS',
            'Access-Control-Allow-Headers': 'Content-Type',
            'Access-Control-Max-Age': '86400',
        });
        res.end();
        return;
    }
    if (req.method !== 'POST') {
        res.writeHead(405, { 'Allow': 'POST' });
        res.end();
        return;
    }

    let chunks = [];
    req.on('data', c => chunks.push(c));
    req.on('end', () => {
        const buf = Buffer.concat(chunks);
        try {
            fs.writeFileSync(outPath, buf);
        } catch (e) {
            console.error(`write failed: ${e.message}`);
            res.writeHead(500);
            res.end();
            return;
        }
        // Reply with CORS headers so fetch() completes cleanly.
        res.writeHead(200, {
            'Access-Control-Allow-Origin': '*',
            'Content-Type': 'application/json',
        });
        res.end(JSON.stringify({ ok: true, bytes: buf.length }));
        console.log(`[harness] received ${buf.length} bytes → ${outPath}`);
        gotReport = true;
        // Close gracefully after the response flushes.
        server.close(() => process.exit(0));
    });
});

server.on('error', (e) => {
    console.error(`[harness] server error: ${e.message}`);
    process.exit(3);
});

server.listen(args.port, '127.0.0.1', () => {
    console.log(`[harness] listening on http://127.0.0.1:${args.port}/  (timeout ${args.timeout}s)`);
});

setTimeout(() => {
    if (!gotReport) {
        console.error(`[harness] timed out after ${args.timeout}s waiting for report`);
        process.exit(2);
    }
}, args.timeout * 1000).unref();
