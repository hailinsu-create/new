/**
 * Headless verification of Live2D boot (mirrors Android AssetLoader HTTP host).
 * Exits 0 only when ready and canvas has non-clear pixels.
 */
import http from 'http';
import fs from 'fs';
import path from 'path';
import { chromium } from 'playwright-core';
import { createRequire } from 'module';
const require = createRequire(import.meta.url);

const ROOT = '/workspace/android/app/src/main/assets/live2d';
const OUT = '/opt/cursor/artifacts';
const PORT = 8765;

const MIME = {
  '.html': 'text/html',
  '.js': 'application/javascript',
  '.json': 'application/json',
  '.png': 'image/png',
  '.moc3': 'application/octet-stream',
  '.wasm': 'application/wasm',
};

function serve(req, res) {
  let urlPath = decodeURIComponent(req.url.split('?')[0]);
  if (urlPath === '/') urlPath = '/index.html';
  if (urlPath.startsWith('/assets/live2d/')) {
    urlPath = urlPath.slice('/assets/live2d'.length);
  }
  const file = path.join(ROOT, urlPath);
  if (!file.startsWith(ROOT) || !fs.existsSync(file) || fs.statSync(file).isDirectory()) {
    res.writeHead(404); res.end('not found ' + urlPath); return;
  }
  const ext = path.extname(file).toLowerCase();
  res.writeHead(200, { 'Content-Type': MIME[ext] || 'application/octet-stream', 'Cache-Control': 'no-store' });
  fs.createReadStream(file).pipe(res);
}

async function main() {
  const server = http.createServer(serve);
  await new Promise((r) => server.listen(PORT, '127.0.0.1', r));

  const browser = await chromium.launch({
    executablePath: '/usr/bin/google-chrome-stable',
    headless: true,
    args: [
      '--use-gl=angle',
      '--use-angle=swiftshader-webgl',
      '--enable-webgl',
      '--ignore-gpu-blocklist',
      '--enable-unsafe-swiftshader',
    ],
  });

  const page = await browser.newPage({
    viewport: { width: 240, height: 240 },
    deviceScaleFactor: 2,
    userAgent:
      'Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
  });

  const logs = [];
  page.on('console', (m) => logs.push(`[console.${m.type()}] ${m.text()}`));
  page.on('pageerror', (e) => logs.push(`[pageerror] ${e.message}`));

  const url = `http://127.0.0.1:${PORT}/assets/live2d/index.html`;
  await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 30000 });

  const result = await page.waitForFunction(() => {
    try {
      if (window.__pangchuangReady) return { ok: true, via: 'flag' };
      if (window.PangchuangLive2D && PangchuangLive2D.isReady && PangchuangLive2D.isReady()) {
        return { ok: true, via: 'api' };
      }
      if (window.__pangchuangError) return { ok: false, err: window.__pangchuangError };
    } catch (e) {
      return { ok: false, err: String(e) };
    }
    return null;
  }, { timeout: 45000 }).then((h) => h.jsonValue()).catch(async (e) => ({
    ok: false,
    err: 'timeout: ' + e.message,
    href: await page.url(),
    hasPIXI: await page.evaluate(() => !!window.PIXI),
    liveKeys: await page.evaluate(() => Object.getOwnPropertyNames((window.PIXI && PIXI.live2d) || {})),
    hasModel: await page.evaluate(() => !!(window.PIXI && PIXI.live2d && PIXI.live2d.Live2DModel)),
    processType: await page.evaluate(() => typeof process),
    pangError: await page.evaluate(() => window.__pangchuangError || null),
  }));

  // Sample canvas via WebGL readback OR screenshot with pink page bg for visibility.
  await page.evaluate(() => { document.body.style.background = '#ff88aa'; });
  await page.waitForTimeout(500);
  await page.screenshot({ path: path.join(OUT, 'live2d-verify.png'), omitBackground: false });

  const pixels = await page.evaluate(() => {
    const c = document.querySelector('canvas');
    if (!c) return { hasCanvas: false };
    const info = {
      hasCanvas: true,
      w: c.width,
      h: c.height,
      model: null,
    };
    try {
      const m = window.__model;
      if (m) {
        info.model = {
          x: m.x, y: m.y, w: m.width, h: m.height,
          sx: m.scale && m.scale.x, sy: m.scale && m.scale.y,
          visible: m.visible, alpha: m.alpha
        };
      }
    } catch (e) {}
    // WebGL pixel read
    try {
      const gl = c.getContext('webgl') || c.getContext('webgl2') || c.getContext('experimental-webgl');
      if (gl) {
        const px = new Uint8Array(4);
        gl.readPixels((c.width / 2) | 0, (c.height / 2) | 0, 1, 1, gl.RGBA, gl.UNSIGNED_BYTE, px);
        info.centerPx = Array.from(px);
        let hits = 0;
        for (let y = 0; y < c.height; y += 16) {
          for (let x = 0; x < c.width; x += 16) {
            gl.readPixels(x, y, 1, 1, gl.RGBA, gl.UNSIGNED_BYTE, px);
            if (px[3] > 8 && (px[0] + px[1] + px[2]) > 20) hits++;
          }
        }
        info.glHits = hits;
      }
    } catch (e) {
      info.glErr = String(e);
    }
    return info;
  });

  fs.writeFileSync(path.join(OUT, 'live2d-verify.json'), JSON.stringify({ result, pixels, logs: logs.slice(-120) }, null, 2));
  await page.screenshot({ path: path.join(OUT, 'live2d-face-idle.png'), omitBackground: false });

  const mouth = await page.evaluate(async () => {
    if (!window.PangchuangLive2D || !PangchuangLive2D.speak) return { error: 'no api' };
    PangchuangLive2D.speak(2400, 'TALK');
    await new Promise((r) => setTimeout(r, 420));
    return {
      mouthOpen: PangchuangLive2D.mouthOpen ? PangchuangLive2D.mouthOpen() : null,
      paramA: PangchuangLive2D.paramA ? PangchuangLive2D.paramA() : null,
    };
  });
  await page.waitForTimeout(80);
  await page.screenshot({ path: path.join(OUT, 'live2d-face-speak.png'), omitBackground: false });

  fs.writeFileSync(
    path.join(OUT, 'live2d-verify.json'),
    JSON.stringify({ result, pixels, mouth, logs: logs.slice(-120) }, null, 2)
  );
  await browser.close();
  server.close();
  console.log(JSON.stringify({ result, pixels, mouth }, null, 2));
  if (!result.ok) {
    console.error('FAIL logs:\n' + logs.slice(-60).join('\n'));
    process.exit(1);
  }
  const painted = (pixels.glHits || 0) > 3 || (pixels.centerPx && pixels.centerPx[3] > 8);
  if (!pixels.hasCanvas || !painted) {
    console.error('FAIL: ready but no painted pixels', pixels);
    process.exit(2);
  }
  const paramA = Number(mouth && mouth.paramA);
  if (!(paramA > 0.15)) {
    console.error('FAIL: mouth ParamA too low while speaking', mouth);
    process.exit(4);
  }
  console.log('PASS');
}

main().catch((e) => { console.error(e); process.exit(3); });
