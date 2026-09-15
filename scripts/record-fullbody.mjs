#!/usr/bin/env node
/**
 * Full-body evidence: screenshots + a short idle/speak reel.
 *   npm run dev
 *   node scripts/record-fullbody.mjs
 */
import { spawn } from "node:child_process";
import {
  mkdirSync,
  writeFileSync,
  existsSync,
  rmSync,
} from "node:fs";
import { setTimeout as sleep } from "node:timers/promises";
import { join } from "node:path";

const PORT = Number(process.env.MOXI_CDP_PORT || 9351);
const BASE = process.env.MOXI_URL || "http://localhost:5173";
const OUT_DIR = process.env.MOXI_OUT || "/opt/cursor/artifacts";
const PROFILE = process.env.MOXI_PROFILE || "/tmp/moxi-fullbody-profile";
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
    `${BASE}/?mute=1&view=full`,
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
      quality: 86,
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
    if (this.frames.length < 20) throw new Error(`screencast 帧太少：${this.frames.length}`);
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
    const { spawnSync } = await import("node:child_process");
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

async function main() {
  mkdirSync(OUT_DIR, { recursive: true });
  const chrome = spawnChrome();
  chrome.stderr.on("data", (d) => {
    const text = d.toString();
    if (/ERROR|FATAL|DevTools listening/.test(text)) log("chrome", text.trim().slice(0, 180));
  });
  let ws;
  const frameDir = "/tmp/moxi-fullbody-screencast";
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

    await cdp.evaluate(`window.__MOXI.setView("full")`);
    await cdp.evaluate(`window.__MOXI.setExpression("neutral")`);
    await cdp.evaluate(`window.__MOXI.setWind(1.15)`);
    await sleep(900);
    await screenshot(cdp, "moxi-fullbody.png");

    await cdp.evaluate(`window.__MOXI.holdViseme("A")`);
    await sleep(400);
    await screenshot(cdp, "moxi-fullbody-speak.png");
    await cdp.evaluate(`window.__MOXI.holdViseme(null)`);

    await cdp.evaluate(`window.__MOXI.setView("bust")`);
    await sleep(500);
    await screenshot(cdp, "moxi-bust.png");

    await cdp.evaluate(`window.__MOXI.setView("full")`);
    await cdp.evaluate(`window.__MOXI.setExpression("smile")`);
    await sleep(400);
    await screenshot(cdp, "moxi-fullbody-smile.png");
    await cdp.evaluate(`window.__MOXI.setExpression("neutral")`);

    const reel = new Screencast(cdp, frameDir);
    await reel.start();
    await cdp.evaluate(`window.__MOXI.setWind(1.3)`);
    await sleep(2800);
    await cdp.evaluate(`window.__MOXI.holdViseme("A")`);
    await sleep(900);
    await cdp.evaluate(`window.__MOXI.holdViseme("O")`);
    await sleep(700);
    await cdp.evaluate(`window.__MOXI.holdViseme("I")`);
    await sleep(700);
    await cdp.evaluate(`window.__MOXI.holdViseme(null)`);
    await cdp.evaluate(`window.__MOXI.speak("月色入庭，风过竹梢。纸鹤还在，我也还在。")`);
    await sleep(5200);
    await cdp.evaluate(`window.__MOXI.holdViseme(null)`);
    await sleep(800);
    await reel.stop();
    await reel.encode(join(OUT_DIR, "moxi-fullbody-idle-speak.mp4"));
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
