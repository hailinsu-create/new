/**
 * Capture distinct 墨汐 expression crops from the Live2D stage for PNG fallbacks.
 * Writes 192x192 circular faces into drawable-xxhdpi.
 */
import http from "http";
import fs from "fs";
import path from "path";
import { chromium } from "playwright-core";

const ROOT = "/workspace/android/app/src/main/assets/live2d";
const OUT_DIR = "/workspace/android/app/src/main/res/drawable-xxhdpi";
const PORT = 8766;

const MIME = {
  ".html": "text/html",
  ".js": "application/javascript",
  ".json": "application/json",
  ".png": "image/png",
  ".moc3": "application/octet-stream",
  ".wasm": "application/wasm",
};

const SHOTS = [
  { mood: "IDLE", file: "companion_avatar_idle.png", talk: false },
  { mood: "TALK", file: "companion_avatar_talk.png", talk: true },
  { mood: "HAPPY", file: "companion_avatar_happy.png", talk: false },
  { mood: "SURPRISE", file: "companion_avatar_surprise.png", talk: false },
];

function serve(req, res) {
  let urlPath = decodeURIComponent(req.url.split("?")[0]);
  if (urlPath === "/") urlPath = "/index.html";
  if (urlPath.startsWith("/assets/live2d/")) {
    urlPath = urlPath.slice("/assets/live2d".length);
  }
  const file = path.join(ROOT, urlPath);
  if (!file.startsWith(ROOT) || !fs.existsSync(file) || fs.statSync(file).isDirectory()) {
    res.writeHead(404);
    res.end("not found " + urlPath);
    return;
  }
  const ext = path.extname(file).toLowerCase();
  res.writeHead(200, {
    "Content-Type": MIME[ext] || "application/octet-stream",
    "Cache-Control": "no-store",
  });
  fs.createReadStream(file).pipe(res);
}

async function main() {
  fs.mkdirSync(OUT_DIR, { recursive: true });
  const server = http.createServer(serve);
  await new Promise((r) => server.listen(PORT, "127.0.0.1", r));

  const browser = await chromium.launch({
    executablePath: "/usr/bin/google-chrome-stable",
    headless: true,
    args: [
      "--use-gl=angle",
      "--use-angle=swiftshader-webgl",
      "--enable-webgl",
      "--ignore-gpu-blocklist",
      "--enable-unsafe-swiftshader",
    ],
  });
  const page = await browser.newPage({
    viewport: { width: 240, height: 240 },
    deviceScaleFactor: 2,
  });
  await page.goto(`http://127.0.0.1:${PORT}/assets/live2d/index.html`, {
    waitUntil: "domcontentloaded",
    timeout: 30000,
  });
  const ready = await page
    .waitForFunction(() => !!(window.__pangchuangReady || (window.PangchuangLive2D && PangchuangLive2D.isReady && PangchuangLive2D.isReady())), {
      timeout: 45000,
    })
    .then(() => true)
    .catch(() => false);
  if (!ready) {
    console.error("Live2D not ready; skip harvest");
    await browser.close();
    server.close();
    process.exit(2);
  }

  const tmp = "/tmp/pangchuang-fallbacks";
  fs.mkdirSync(tmp, { recursive: true });
  for (const shot of SHOTS) {
    await page.evaluate(({ mood, talk }) => {
      const api = window.PangchuangLive2D;
      if (!api) return;
      if (talk) api.speak(2400, mood);
      else {
        api.idle();
        api.setMood(mood);
      }
    }, shot);
    if (shot.talk) {
      await page.waitForFunction(() => {
        const api = window.PangchuangLive2D;
        const v = api && api.paramMouth && api.paramMouth();
        return v != null && v > 0.7;
      }, { timeout: 2500 }).catch(() => {});
    } else {
      await page.waitForTimeout(500);
    }
    const raw = path.join(tmp, shot.file);
    await page.screenshot({ path: raw, omitBackground: true });
    console.log("shot", shot.mood, raw);
  }

  await browser.close();
  server.close();
  console.log("harvested to", tmp);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
