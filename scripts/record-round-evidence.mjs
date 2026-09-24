#!/usr/bin/env node
/**
 * Round evidence: bust A/O, full hold=A, hop/bow vs idle, short reel.
 *   npm run dev
 *   node scripts/record-round-evidence.mjs
 */
import { spawn } from "node:child_process";
import { mkdirSync, writeFileSync, existsSync, rmSync } from "node:fs";
import { setTimeout as sleep } from "node:timers/promises";
import { join } from "node:path";
import { spawnSync } from "node:child_process";

const PORT = Number(process.env.MOXI_CDP_PORT || 9361);
const BASE = process.env.MOXI_URL || "http://localhost:5173";
const OUT_DIR = process.env.MOXI_OUT || "/opt/cursor/artifacts";
const PROFILE = process.env.MOXI_PROFILE || "/tmp/moxi-round-evidence-profile";
const CHROME = process.env.CHROME_PATH || "google-chrome";
const VIEW_W = 1440;
const VIEW_H = 900;

const log = (...args) => console.log(new Date().toISOString(), ...args);

class Cdp {
  constructor(ws) {
    this.ws = ws;
    this.id = 0;
    this.pending = new Map();
    this.events = new Map();
    this.ws.addEventListener("message", (event) => {
      const msg = JSON.parse(String(event.data));
      if (msg.method && this.events.has(msg.method)) this.events.get(msg.method)(msg.params);
      if (msg.id == null) return;
      const job = this.pending.get(msg.id);
      if (!job) return;
      this.pending.delete(msg.id);
      if (msg.error) job.reject(new Error(`${msg.error.message} (${job.method})`));
      else job.resolve(msg.result);
    });
  }
  on(method, fn) {
    this.events.set(method, fn);
  }
  send(method, params = {}, timeoutMs = 20000) {
    const id = ++this.id;
    return new Promise((resolve, reject) => {
      const timer = setTimeout(() => {
        this.pending.delete(id);
        reject(new Error(`CDP timeout ${timeoutMs}ms: ${method}`));
      }, timeoutMs);
      this.pending.set(id, {
        method,
        resolve: (v) => {
          clearTimeout(timer);
          resolve(v);
        },
        reject: (e) => {
          clearTimeout(timer);
          reject(e);
        },
      });
      this.ws.send(JSON.stringify({ id, method, params }));
    });
  }
  async evaluate(expression, timeoutMs = 30000) {
    const result = await this.send(
      "Runtime.evaluate",
      { expression, awaitPromise: true, returnByValue: true, userGesture: true },
      timeoutMs,
    );
    if (result.exceptionDetails) {
      const ex = result.exceptionDetails;
      throw new Error(ex.exception?.description || ex.text || "evaluate failed");
    }
    return result.result?.value;
  }
}

async function waitHttpJson(url, timeout = 20000) {
  const t0 = Date.now();
  let last = "";
  while (Date.now() - t0 < timeout) {
    try {
      const res = await fetch(url);
      if (res.ok) return await res.json();
      last = `HTTP ${res.status}`;
    } catch (err) {
      last = err instanceof Error ? err.message : String(err);
    }
    await sleep(150);
  }
  throw new Error(`等待 ${url} 失败：${last}`);
}

function spawnChrome() {
  if (existsSync(PROFILE)) rmSync(PROFILE, { recursive: true, force: true });
  mkdirSync(join(PROFILE, "Default"), { recursive: true });
  const args = [
    "--headless=new",
    "--no-sandbox",
    "--disable-dev-shm-usage",
    "--use-gl=angle",
    "--use-angle=swiftshader-webgl",
    "--hide-scrollbars",
    "--mute-audio",
    `--remote-debugging-port=${PORT}`,
    "--remote-allow-origins=*",
    `--user-data-dir=${PROFILE}`,
    `--window-size=${VIEW_W},${VIEW_H}`,
    "--autoplay-policy=no-user-gesture-required",
    `${BASE}/?mute=1&view=bust`,
  ];
  return spawn(CHROME, args, { stdio: ["ignore", "pipe", "pipe"] });
}

async function waitReady(cdp) {
  const t0 = Date.now();
  let last = "";
  while (Date.now() - t0 < 25000) {
    try {
      const snap = await cdp.evaluate(`({
        ready: document.readyState,
        api: Boolean(window.__MOXI && window.__MOXI.ready),
        view: window.__MOXI && window.__MOXI.getView && window.__MOXI.getView(),
        href: location.href
      })`);
      last = JSON.stringify(snap);
      if (snap?.api && snap.ready === "complete") return snap;
    } catch (err) {
      last = err instanceof Error ? err.message : String(err);
    }
    await sleep(200);
  }
  throw new Error(`页面未就绪：${last}`);
}

async function screenshot(cdp, name) {
  const shot = await cdp.send("Page.captureScreenshot", { format: "png", fromSurface: true });
  const dest = join(OUT_DIR, name);
  writeFileSync(dest, Buffer.from(shot.data, "base64"));
  log("wrote", dest);
  return dest;
}

class Screencast {
  constructor(cdp, dir) {
    this.cdp = cdp;
    this.dir = dir;
    this.frames = [];
    this.started = false;
  }
  async start() {
    mkdirSync(this.dir, { recursive: true });
    this.cdp.on("Page.screencastFrame", (params) => {
      this.cdp.send("Page.screencastFrameAck", { sessionId: params.sessionId }).catch(() => {});
      const n = this.frames.length;
      const file = join(this.dir, `f${String(n).padStart(5, "0")}.jpg`);
      writeFileSync(file, Buffer.from(params.data, "base64"));
      const t = Number(params.metadata?.timestamp || Date.now() / 1000);
      this.frames.push({ file, t });
    });
    await this.cdp.send("Page.startScreencast", {
      format: "jpeg",
      quality: 84,
      maxWidth: VIEW_W,
      maxHeight: VIEW_H,
      everyNthFrame: 1,
    });
    this.started = true;
  }
  async stop() {
    if (!this.started) return;
    await this.cdp.send("Page.stopScreencast").catch(() => {});
    this.started = false;
    log("screencast frames", this.frames.length);
  }
  async encode(dest) {
    if (this.frames.length < 12) throw new Error(`screencast 帧太少：${this.frames.length}`);
    const list = join(this.dir, "concat.txt");
    const lines = [];
    for (let i = 0; i < this.frames.length; i += 1) {
      const cur = this.frames[i];
      const next = this.frames[i + 1];
      const dur = next ? Math.min(0.2, Math.max(0.02, next.t - cur.t)) : 0.04;
      lines.push(`file '${cur.file}'`);
      lines.push(`duration ${dur.toFixed(4)}`);
    }
    lines.push(`file '${this.frames.at(-1).file}'`);
    writeFileSync(list, `${lines.join("\n")}\n`);
    const r = spawnSync(
      "ffmpeg",
      [
        "-y",
        "-f",
        "concat",
        "-safe",
        "0",
        "-i",
        list,
        "-vsync",
        "vfr",
        "-vf",
        "scale=trunc(iw/2)*2:trunc(ih/2)*2",
        "-c:v",
        "libx264",
        "-preset",
        "fast",
        "-crf",
        "18",
        "-pix_fmt",
        "yuv420p",
        "-movflags",
        "+faststart",
        dest,
      ],
      { encoding: "utf8" },
    );
    if (r.status !== 0) throw new Error(r.stderr.slice(-800));
  }
}

function crop(src, dest, box) {
  const r = spawnSync(
    "ffmpeg",
    ["-y", "-i", src, "-vf", `crop=${box.w}:${box.h}:${box.x}:${box.y}`, dest],
    { encoding: "utf8" },
  );
  if (r.status !== 0) throw new Error(r.stderr.slice(-400));
}

function sideBySide(a, b, dest, labelA, labelB) {
  const r = spawnSync(
    "ffmpeg",
    [
      "-y",
      "-i",
      a,
      "-i",
      b,
      "-filter_complex",
      `[0:v]drawtext=text='${labelA}':x=16:y=16:fontsize=28:fontcolor=white:shadowx=1:shadowy=1[a];[1:v]drawtext=text='${labelB}':x=16:y=16:fontsize=28:fontcolor=white:shadowx=1:shadowy=1[b];[a][b]hstack=inputs=2`,
      dest,
    ],
    { encoding: "utf8" },
  );
  if (r.status !== 0) {
    const r2 = spawnSync("ffmpeg", ["-y", "-i", a, "-i", b, "-filter_complex", "hstack=inputs=2", dest], {
      encoding: "utf8",
    });
    if (r2.status !== 0) throw new Error(r2.stderr.slice(-400));
  }
}

async function main() {
  mkdirSync(OUT_DIR, { recursive: true });
  const chrome = spawnChrome();
  chrome.stderr.on("data", (d) => {
    const text = d.toString();
    if (/ERROR|FATAL|DevTools listening/.test(text)) log("chrome", text.trim().slice(0, 180));
  });
  let ws;
  const frameDir = "/tmp/moxi-round-screencast";
  if (existsSync(frameDir)) rmSync(frameDir, { recursive: true, force: true });
  try {
    await waitHttpJson(`http://127.0.0.1:${PORT}/json/version`, 25000);
    const list = await waitHttpJson(`http://127.0.0.1:${PORT}/json/list`);
    const page = list.find((t) => t.type === "page" && t.webSocketDebuggerUrl);
    if (!page) throw new Error("no cdp page");
    ws = new globalThis.WebSocket(page.webSocketDebuggerUrl);
    await new Promise((resolve, reject) => {
      ws.addEventListener("open", resolve);
      ws.addEventListener("error", () => reject(new Error("cdp ws")));
    });
    const cdp = new Cdp(ws);
    await cdp.send("Page.enable");
    await cdp.send("Runtime.enable");
    await waitReady(cdp);
    log("ready", await cdp.evaluate(`window.__MOXI.getState()`));

    await cdp.evaluate(`window.__MOXI.setView("bust")`);
    await cdp.evaluate(`window.__MOXI.setExpression("neutral")`);
    await cdp.evaluate(`window.__MOXI.holdViseme(null)`);
    await sleep(700);
    await screenshot(cdp, "round-bust-idle.png");

    await cdp.evaluate(`window.__MOXI.holdViseme("A")`);
    await sleep(450);
    await screenshot(cdp, "round-bust-hold-A.png");

    await cdp.evaluate(`window.__MOXI.holdViseme("O")`);
    await sleep(450);
    await screenshot(cdp, "round-bust-hold-O.png");

    await cdp.evaluate(`window.__MOXI.holdViseme("U")`);
    await sleep(350);
    await screenshot(cdp, "round-bust-hold-U.png");

    await cdp.evaluate(`window.__MOXI.holdViseme("M")`);
    await sleep(350);
    await screenshot(cdp, "round-bust-hold-M.png");
    await cdp.evaluate(`window.__MOXI.holdViseme(null)`);

    await cdp.evaluate(`window.__MOXI.setView("full")`);
    await cdp.evaluate(`window.__MOXI.setExpression("neutral")`);
    await sleep(700);
    await screenshot(cdp, "round-full-idle.png");

    await cdp.evaluate(`window.__MOXI.holdViseme("A")`);
    await sleep(450);
    await screenshot(cdp, "round-full-hold-A.png");
    await cdp.evaluate(`window.__MOXI.holdViseme("O")`);
    await sleep(400);
    await screenshot(cdp, "round-full-hold-O.png");
    await cdp.evaluate(`window.__MOXI.holdViseme(null)`);

    await cdp.evaluate(`window.__MOXI.playAction("hop")`);
    await sleep(320);
    await screenshot(cdp, "round-full-hop.png");
    await sleep(900);

    await cdp.evaluate(`window.__MOXI.playAction("bow")`);
    await sleep(580);
    await screenshot(cdp, "round-full-bow.png");
    await sleep(900);

    await cdp.evaluate(`window.__MOXI.playAction("step")`);
    await sleep(420);
    await screenshot(cdp, "round-full-step.png");
    await sleep(400);

    const reel = new Screencast(cdp, frameDir);
    await reel.start();
    await cdp.evaluate(`window.__MOXI.setView("bust")`);
    await sleep(400);
    for (const id of ["A", "O", "U", "M", "E", "I"]) {
      await cdp.evaluate(`window.__MOXI.holdViseme("${id}")`);
      await sleep(420);
    }
    await cdp.evaluate(`window.__MOXI.holdViseme(null)`);
    await cdp.evaluate(`window.__MOXI.setView("full")`);
    await sleep(350);
    await cdp.evaluate(`window.__MOXI.holdViseme("A")`);
    await sleep(500);
    await cdp.evaluate(`window.__MOXI.holdViseme(null)`);
    await cdp.evaluate(`window.__MOXI.playAction("hop")`);
    await sleep(900);
    await cdp.evaluate(`window.__MOXI.playAction("bow")`);
    await sleep(1400);
    await cdp.evaluate(`window.__MOXI.speak("月色入庭，风过竹梢。")`);
    await sleep(4200);
    await reel.stop();
    await reel.encode(join(OUT_DIR, "round-viseme-action.mp4"));

    const faceBust = { x: 430, y: 40, w: 520, h: 520 };
    const faceFull = { x: 520, y: 20, w: 400, h: 520 };
    crop(join(OUT_DIR, "round-bust-hold-A.png"), join(OUT_DIR, "round-crop-bust-A.png"), faceBust);
    crop(join(OUT_DIR, "round-bust-hold-O.png"), join(OUT_DIR, "round-crop-bust-O.png"), faceBust);
    crop(join(OUT_DIR, "round-bust-idle.png"), join(OUT_DIR, "round-crop-bust-idle.png"), faceBust);
    crop(join(OUT_DIR, "round-full-hold-A.png"), join(OUT_DIR, "round-crop-full-A.png"), faceFull);
    crop(join(OUT_DIR, "round-full-idle.png"), join(OUT_DIR, "round-crop-full-idle.png"), faceFull);
    crop(join(OUT_DIR, "round-full-hop.png"), join(OUT_DIR, "round-crop-hop.png"), { x: 480, y: 0, w: 480, h: 700 });
    crop(join(OUT_DIR, "round-full-bow.png"), join(OUT_DIR, "round-crop-bow.png"), { x: 480, y: 0, w: 480, h: 700 });
    crop(join(OUT_DIR, "round-full-idle.png"), join(OUT_DIR, "round-crop-fullbody-idle.png"), {
      x: 480,
      y: 0,
      w: 480,
      h: 700,
    });

    sideBySide(
      join(OUT_DIR, "round-crop-bust-A.png"),
      join(OUT_DIR, "round-crop-bust-O.png"),
      join(OUT_DIR, "round-compare-bust-AO.png"),
      "A",
      "O",
    );
    sideBySide(
      join(OUT_DIR, "round-crop-fullbody-idle.png"),
      join(OUT_DIR, "round-crop-hop.png"),
      join(OUT_DIR, "round-compare-hop.png"),
      "idle",
      "hop",
    );
    sideBySide(
      join(OUT_DIR, "round-crop-fullbody-idle.png"),
      join(OUT_DIR, "round-crop-bow.png"),
      join(OUT_DIR, "round-compare-bow.png"),
      "idle",
      "bow",
    );

    log("done");
  } finally {
    try {
      ws?.close();
    } catch {
      /* ignore */
    }
    chrome.kill("SIGTERM");
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
