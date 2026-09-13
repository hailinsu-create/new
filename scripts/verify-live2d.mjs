/**
 * Headless verification of Live2D boot (mirrors Android AssetLoader HTTP host).
 * Exits 0 only when ready, canvas painted, crop inset, mouth clean, lip-sync strong.
 */
import http from 'http';
import fs from 'fs';
import path from 'path';
import { spawnSync } from 'child_process';
import { chromium } from 'playwright-core';

const ROOT = '/workspace/android/app/src/main/assets/live2d';
const OUT = '/opt/cursor/artifacts';
const TMP = '/tmp/pangchuang-live2d';
const PORT = 8765;

fs.mkdirSync(OUT, { recursive: true });
fs.mkdirSync(TMP, { recursive: true });

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

function analyzePngs(idlePath, speakPath) {
  const py = `
from PIL import Image
import json, sys

idle = Image.open(${JSON.stringify(idlePath)}).convert("RGBA")
speak = Image.open(${JSON.stringify(speakPath)}).convert("RGBA")
w, h = idle.size
BG = (255, 136, 170)

def is_bg(p, tol=48):
    r,g,b,a = p
    if a < 16:
        return True
    return abs(r-BG[0])+abs(g-BG[1])+abs(b-BG[2]) < tol

def corner_bg_frac(im, box=28):
    pix = im.load()
    hits = tot = 0
    regions = [(0,0,box,box), (w-box,0,w,box), (0,h-box,box,h), (w-box,h-box,w,h)]
    for x0,y0,x1,y1 in regions:
        for y in range(y0,y1):
            for x in range(x0,x1):
                tot += 1
                if is_bg(pix[x,y]):
                    hits += 1
    return hits / tot if tot else 0

def edge_mid_bg(im, band=10, span=40):
    pix = im.load()
    cx, cy = w//2, h//2
    samples = []
    # top / bottom / left / right midpoints
    for x in range(cx-span, cx+span):
        samples.append(is_bg(pix[x, 2]))
        samples.append(is_bg(pix[x, h-3]))
    for y in range(cy-span, cy+span):
        samples.append(is_bg(pix[2, y]))
        samples.append(is_bg(pix[w-3, y]))
    return sum(1 for s in samples if s) / len(samples)

def char_frac(im):
    pix = im.load()
    n = 0
    for y in range(0, h, 2):
        for x in range(0, w, 2):
            if not is_bg(pix[x,y]):
                n += 1
    return n / ((w//2)*(h//2))

def is_skin(p):
    r,g,b,a = p
    return a > 200 and r > 170 and 130 < g < 215 and r > g + 12 and g >= b - 8

def bbox(im):
    pix = im.load()
    xs, ys = [], []
    for y in range(int(h*0.28), int(h*0.70)):
        for x in range(int(w*0.22), int(w*0.78)):
            if is_skin(pix[x,y]):
                xs.append(x); ys.append(y)
    if not xs:
        return None
    return min(xs), min(ys), max(xs), max(ys)

def mouth_roi(im):
    b = bbox(im)
    if not b:
        return (int(w*0.38), int(h*0.50), int(w*0.62), int(h*0.66))
    x0,y0,x1,y1 = b
    bw, bh = max(8, x1-x0), max(8, y1-y0)
    # Lower face only: skip eyes/hair and the collar.
    return (x0+int(bw*0.18), y0+int(bh*0.58), x0+int(bw*0.82), y0+int(bh*0.95))

def skin_neighbors(pix, x, y):
    n = 0
    for dy in (-2,-1,0,1,2):
        for dx in (-2,-1,0,1,2):
            if dx == 0 and dy == 0:
                continue
            xx, yy = x+dx, y+dy
            if 0 <= xx < w and 0 <= yy < h and is_skin(pix[xx,yy]):
                n += 1
    return n

def black_blob(im):
    x0,y0,x1,y1 = mouth_roi(im)
    pix = im.load()
    dark = 0
    redish = 0
    tot = 0
    for y in range(y0, y1):
        for x in range(x0, x1):
            r,g,b,a = pix[x,y]
            tot += 1
            if a < 32 or is_bg((r,g,b,a)):
                continue
            lum = r+g+b
            # Stain on the face: near-black AND surrounded by skin (not hair/collar).
            if r <= 24 and g <= 22 and b <= 22 and lum < 55 and skin_neighbors(pix, x, y) >= 6:
                dark += 1
            if r > 140 and g < 130 and b < 130 and r > g + 20:
                redish += 1
    return {"dark": dark, "redish": redish, "tot": tot, "roi": [x0,y0,x1,y1]}

out = {
  "size": [w, h],
  "idleCornerBg": corner_bg_frac(idle),
  "speakCornerBg": corner_bg_frac(speak),
  "idleEdgeMidBg": edge_mid_bg(idle),
  "idleCharFrac": char_frac(idle),
  "idleBbox": bbox(idle),
  "idleBlack": black_blob(idle),
  "speakBlack": black_blob(speak),
}
print(json.dumps(out))
`;
  const res = spawnSync('python3', ['-c', py], { encoding: 'utf8' });
  if (res.status !== 0) {
    throw new Error('pixel analysis failed: ' + (res.stderr || res.stdout));
  }
  return JSON.parse(res.stdout);
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

  await page.evaluate(() => { document.body.style.background = '#ff88aa'; });
  await page.waitForTimeout(400);

  const pixels = await page.evaluate(() => {
    const c = document.querySelector('canvas');
    if (!c) return { hasCanvas: false };
    const info = { hasCanvas: true, w: c.width, h: c.height, model: null };
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

  const crop = await page.evaluate(() => {
    try { return PangchuangLive2D.getOverlayCrop ? PangchuangLive2D.getOverlayCrop() : null; }
    catch (e) { return { err: String(e) }; }
  });

  await page.evaluate(() => { if (window.PangchuangLive2D) PangchuangLive2D.idle(); });
  await page.waitForTimeout(280);
  const idleMouth = await page.evaluate(() => ({
    mouthOpen: PangchuangLive2D.mouthOpen ? PangchuangLive2D.mouthOpen() : null,
    paramMouth: PangchuangLive2D.paramMouth ? PangchuangLive2D.paramMouth() : null,
  }));
  const idlePng = path.join(OUT, 'live2d-face-idle.png');
  const idleTmp = path.join(TMP, 'idle.png');
  await page.screenshot({ path: idlePng, omitBackground: false });
  fs.copyFileSync(idlePng, idleTmp);
  await page.screenshot({ path: path.join(OUT, 'live2d-verify.png'), omitBackground: false });

  const motion = await page.evaluate(async () => {
    if (!window.PangchuangLive2D) return { error: 'no api' };
    const beforeBlink = PangchuangLive2D.paramEyeL ? PangchuangLive2D.paramEyeL() : null;
    if (PangchuangLive2D.forceBlink) PangchuangLive2D.forceBlink();
    await new Promise((r) => setTimeout(r, 40));
    const duringBlink = PangchuangLive2D.paramEyeL ? PangchuangLive2D.paramEyeL() : null;
    await new Promise((r) => setTimeout(r, 220));
    const afterBlink = PangchuangLive2D.paramEyeL ? PangchuangLive2D.paramEyeL() : null;
    if (PangchuangLive2D.setMood) PangchuangLive2D.setMood('THINK');
    await new Promise((r) => setTimeout(r, 80));
    const thinkAngle = PangchuangLive2D.paramAngleY ? PangchuangLive2D.paramAngleY() : null;
    if (PangchuangLive2D.setMood) PangchuangLive2D.setMood('IDLE');
    return { beforeBlink, duringBlink, afterBlink, thinkAngle };
  });

  await page.evaluate(() => PangchuangLive2D.speak(2800, 'TALK'));
  let mouth = { samples: [] };
  for (let i = 0; i < 24; i++) {
    await page.waitForTimeout(50);
    const s = await page.evaluate(() => ({
      mouthOpen: PangchuangLive2D.mouthOpen ? PangchuangLive2D.mouthOpen() : null,
      paramMouth: PangchuangLive2D.paramMouth ? PangchuangLive2D.paramMouth() : null,
      paramForm: PangchuangLive2D.paramMouthForm ? PangchuangLive2D.paramMouthForm() : null,
    }));
    mouth.samples.push(s);
    if (Number(s.paramMouth) > 0.8) {
      mouth = { ...mouth, ...s };
      break;
    }
  }
  const peak = mouth.samples.reduce((m, s) => Math.max(m, Number(s.paramMouth) || 0), 0);
  const peakOpen = mouth.samples.reduce((m, s) => Math.max(m, Number(s.mouthOpen) || 0), 0);
  mouth.peakParam = peak;
  mouth.peakOpen = peakOpen;
  mouth.idleParam = idleMouth.paramMouth;
  mouth.delta = peak - Number(idleMouth.paramMouth || 0);
  if (mouth.paramMouth == null) {
    const last = mouth.samples[mouth.samples.length - 1] || {};
    mouth.paramMouth = last.paramMouth;
    mouth.mouthOpen = last.mouthOpen;
  }

  const speakPng = path.join(OUT, 'live2d-face-speak.png');
  const speakTmp = path.join(TMP, 'speak.png');
  await page.screenshot({ path: speakPng, omitBackground: false });
  fs.copyFileSync(speakPng, speakTmp);

  let vision = null;
  try {
    vision = analyzePngs(idlePng, speakPng);
  } catch (e) {
    vision = { error: String(e) };
  }

  const payload = { result, pixels, mouth, idleMouth, motion, crop, vision, logs: logs.slice(-120) };
  fs.writeFileSync(path.join(OUT, 'live2d-verify.json'), JSON.stringify(payload, null, 2));
  await browser.close();
  server.close();
  console.log(JSON.stringify({ result, pixels, mouth, idleMouth, motion, crop, vision }, null, 2));

  if (!result.ok) {
    console.error('FAIL logs:\n' + logs.slice(-60).join('\n'));
    process.exit(1);
  }
  const painted = (pixels.glHits || 0) > 3 || (pixels.centerPx && pixels.centerPx[3] > 8);
  if (!pixels.hasCanvas || !painted) {
    console.error('FAIL: ready but no painted pixels', pixels);
    process.exit(2);
  }
  const duringBlink = Number(motion && motion.duringBlink);
  if (!(duringBlink < 0.4)) {
    console.error('FAIL: ParamEyeLOpen did not close on forceBlink', motion);
    process.exit(5);
  }
  const thinkAngle = Number(motion && motion.thinkAngle);
  if (!(thinkAngle < -2)) {
    console.error('FAIL: THINK mood did not lower ParamAngleY', motion);
    process.exit(6);
  }

  // (c) speak mouth significantly larger than idle.
  // Justify: this model only toggles a mouth_open sprite (no jaw deform).
  // Closed idle is ~0. Open viseme snaps to >=0.88. Require delta 0.55 so a
  // timid 0.28+sine that sits around 0.6 cannot pass as "stronger matching".
  const idleParam = Number(idleMouth.paramMouth);
  if (!(idleParam <= 0.12)) {
    console.error('FAIL: idle ParamMouthOpenY should be fully closed', idleMouth);
    process.exit(7);
  }
  if (!(peak > 0.75)) {
    console.error('FAIL: speak ParamMouthOpenY peak too low (want >0.75)', mouth);
    process.exit(4);
  }
  if (!(mouth.delta >= 0.55)) {
    console.error('FAIL: speak-idle mouth delta too small (want >=0.55)', mouth);
    process.exit(4);
  }

  if (vision && !vision.error) {
    // (a) face+hair inside the round window: square corners/edges are background
    // so a 96dp circle does not slice through bangs. Character still fills the
    // center (not a tiny full-body doll): charFrac between 0.28 and 0.88.
    if (!(vision.idleCornerBg >= 0.55)) {
      console.error('FAIL: crop still fills the corners; hair/effects will clip', vision);
      process.exit(8);
    }
    if (!(vision.idleEdgeMidBg >= 0.35)) {
      console.error('FAIL: frame mid-edges still character; crop too tight', vision);
      process.exit(8);
    }
    if (!(vision.idleCharFrac >= 0.28 && vision.idleCharFrac <= 0.88)) {
      console.error('FAIL: character scale out of bust range', vision);
      process.exit(8);
    }
    // (b) no large black blob beside the mouth. Thin lip ink is brown, not
    // rgb<22. A premultiplied halo or leftover cavity is dozens of near-black
    // pixels in the mouth ROI; allow a few compression specks.
    if (vision.idleBlack.dark > 35) {
      console.error('FAIL: idle black blob near mouth', vision.idleBlack);
      process.exit(9);
    }
    if (vision.speakBlack.dark > 45) {
      console.error('FAIL: speak black blob near mouth', vision.speakBlack);
      process.exit(9);
    }
    if (!(vision.speakBlack.redish > vision.idleBlack.redish + 8)) {
      console.error('FAIL: speak mouth interior not more visible than idle', vision);
      process.exit(4);
    }
  } else {
    console.error('FAIL: pixel analysis missing', vision);
    process.exit(10);
  }

  console.log('PASS');
}

main().catch((e) => { console.error(e); process.exit(3); });
