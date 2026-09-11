#!/usr/bin/env node
/**
 * Record a full walkthrough of the 墨汐 demo into /opt/cursor/artifacts/.
 *
 * Usage (dev server already on :5173):
 *   node scripts/record-all-animations.mjs
 *
 * Captures the page via CDP screencast (no Chrome translate/update bubbles).
 * Fallback: MOXI_CAPTURE=x11 DISPLAY=:1 node scripts/record-all-animations.mjs
 */
import { spawn } from "node:child_process";
import {
  mkdirSync,
  writeFileSync,
  readFileSync,
  existsSync,
  rmSync,
  renameSync,
} from "node:fs";
import { setTimeout as sleep } from "node:timers/promises";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const __dirname = dirname(fileURLToPath(import.meta.url));
const DISPLAY = process.env.DISPLAY || ":1";
const PORT = Number(process.env.MOXI_CDP_PORT || 9333);
const BASE = process.env.MOXI_URL || "http://localhost:5173";
const OUT_DIR = process.env.MOXI_OUT || "/opt/cursor/artifacts";
const PROFILE = process.env.MOXI_PROFILE || "/tmp/moxi-record-profile";
const CHROME = process.env.CHROME_PATH || "google-chrome";
const CAPTURE = process.env.MOXI_CAPTURE || "x11";
const VIEW_W = 1680;
const VIEW_H = 1000;

const PANGRAM = "啊衣乌诶哦，妈妈来了，风过竹林，我问你哦。";
const POEM = "月色入庭，风过竹梢。纸鹤还在，我也还在。";
const ENGLISH = "Hello. I can lip-sync in English too.";
const EXPRESSIONS = ["平静", "浅笑", "开怀", "讶异", "低眉", "含羞", "眨眼", "困倦"];
const VISEMES = ["A", "E", "I", "O", "U", "WQ", "M", "F", "L", "S"];

const log = (...args) => console.log(new Date().toISOString(), ...args);

class Cdp {
  constructor(ws) {
    this.ws = ws;
    this.id = 0;
    this.pending = new Map();
    this.events = new Map();
    this.ws.addEventListener("message", (event) => {
      const msg = JSON.parse(String(event.data));
      if (msg.method && this.events.has(msg.method)) {
        this.events.get(msg.method)(msg.params);
      }
      if (msg.id == null) return;
      const job = this.pending.get(msg.id);
      if (!job) return;
      this.pending.delete(msg.id);
      if (msg.error) job.reject(new Error(`${msg.error.message || JSON.stringify(msg.error)} (${job.method})`));
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
        resolve: (value) => {
          clearTimeout(timer);
          resolve(value);
        },
        reject: (err) => {
          clearTimeout(timer);
          reject(err);
        },
      });
      this.ws.send(JSON.stringify({ id, method, params }));
    });
  }

  async evaluate(expression, timeoutMs = 30000) {
    const result = await this.send(
      "Runtime.evaluate",
      {
        expression,
        awaitPromise: true,
        returnByValue: true,
        userGesture: true,
      },
      timeoutMs,
    );
    if (result.exceptionDetails) {
      const ex = result.exceptionDetails;
      throw new Error(ex.exception?.description || ex.text || "evaluate failed");
    }
    return result.result?.value;
  }

  call(name, ...args) {
    const expr = `window.__TOUR.${name}(${args.map((v) => JSON.stringify(v)).join(", ")})`;
    const numeric = args.filter((v) => typeof v === "number");
    const longest = numeric.length ? Math.max(...numeric) : 0;
    const timeout = Math.max(30000, longest + 10000);
    return this.evaluate(expr, timeout);
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

async function waitDemo(timeout = 20000) {
  const t0 = Date.now();
  while (Date.now() - t0 < timeout) {
    try {
      const res = await fetch(`${BASE}/`);
      if (res.ok) return;
    } catch {
      /* retry */
    }
    await sleep(200);
  }
  throw new Error(`demo 未响应 ${BASE}`);
}

function writeChromeProfile() {
  if (existsSync(PROFILE)) rmSync(PROFILE, { recursive: true, force: true });
  const def = join(PROFILE, "Default");
  mkdirSync(def, { recursive: true });
  writeFileSync(join(PROFILE, "First Run"), "");
  writeFileSync(
    join(PROFILE, "Local State"),
    JSON.stringify({
      background_mode: { enabled: false },
      hardware_acceleration_mode_previous: false,
      user_experience_metrics: { reporting_enabled: false },
    }),
  );
  writeFileSync(
    join(def, "Preferences"),
    JSON.stringify({
      translate: { enabled: false },
      enable_do_not_track: true,
      intl: { accept_languages: "zh-CN,zh,en-US,en" },
      browser: {
        check_default_browser: false,
        has_seen_welcome_page: true,
        window_placement: {
          bottom: VIEW_H + 80,
          left: 80,
          maximized: false,
          right: 80 + VIEW_W,
          top: 36,
        },
      },
      profile: {
        default_content_setting_values: { notifications: 2 },
        exit_type: "Normal",
        exited_cleanly: true,
      },
      session: { restore_on_startup: 5 },
    }),
  );
}

function spawnChrome() {
  writeChromeProfile();
  const headless = CAPTURE !== "x11";
  const args = [
    "--no-sandbox",
    "--test-type",
    "--disable-dev-shm-usage",
    "--use-gl=angle",
    "--use-angle=swiftshader-webgl",
    "--password-store=basic",
    "--no-first-run",
    "--no-default-browser-check",
    `--remote-debugging-port=${PORT}`,
    "--remote-allow-origins=*",
    `--user-data-dir=${PROFILE}`,
    `--window-size=${VIEW_W},${VIEW_H}`,
    "--window-position=80,36",
    "--disable-extensions",
    "--disable-sync",
    "--disable-translate",
    "--disable-component-update",
    "--disable-background-networking",
    "--disable-client-side-phishing-detection",
    "--disable-default-apps",
    "--disable-hang-monitor",
    "--disable-popup-blocking",
    "--disable-prompt-on-repost",
    "--metrics-recording-only",
    "--safebrowsing-disable-auto-update",
    "--check-for-update-interval=31536000",
    "--disable-features=Translate,TranslateUI,ChromeWhatsNew,MediaRouter,OptimizationHints,NotificationTriggers,CalculateNativeWinOcclusion,InterestFeedContentSuggestions,RenderDocument,AutomationControlled,UpdateNotificationPromo",
    "--hide-crash-restore-bubble",
    "--disable-session-crashed-bubble",
    "--disable-infobars",
    "--autoplay-policy=no-user-gesture-required",
    "--mute-audio",
    "--hide-scrollbars",
    "--lang=zh-CN",
    "--accept-lang=zh-CN,zh,en-US,en",
    "--class=MoxiRecord",
  ];
  if (headless) {
    args.unshift("--headless=new");
    args.push(`${BASE}/?mute=1`);
  } else {
    args.push(`--app=${BASE}/?mute=1`);
  }
  log("launch chrome", headless ? "headless" : "windowed", CHROME);
  return spawn(CHROME, args, {
    env: { ...process.env, DISPLAY, LANG: "zh_CN.UTF-8", LANGUAGE: "zh_CN:zh" },
    stdio: ["ignore", "pipe", "pipe"],
  });
}

function shOut(cmd) {
  return new Promise((resolve, reject) => {
    const child = spawn("bash", ["-lc", cmd], { env: { ...process.env, DISPLAY } });
    let out = "";
    let err = "";
    child.stdout.on("data", (d) => (out += d));
    child.stderr.on("data", (d) => (err += d));
    child.on("exit", (code) => {
      if (code === 0) resolve(out.trim());
      else reject(new Error(`${cmd} failed (${code}): ${err || out}`));
    });
  });
}

async function findRecordWindow(timeout = 15000) {
  const t0 = Date.now();
  let last = "";
  while (Date.now() - t0 < timeout) {
    try {
      const ids = (await shOut("xdotool search --class MoxiRecord || true")).split(/\s+/).filter(Boolean);
      const named = (await shOut("xdotool search --name MOXI_RECORD_TOUR || true")).split(/\s+/).filter(Boolean);
      const all = [...new Set([...named, ...ids])];
      for (const id of all) {
        const info = await shOut(`xwininfo -id ${id}`);
        const x = Number((info.match(/Absolute upper-left X:\s+(-?\d+)/) || [])[1]);
        const y = Number((info.match(/Absolute upper-left Y:\s+(-?\d+)/) || [])[1]);
        const w = Number((info.match(/Width:\s+(\d+)/) || [])[1]);
        const h = Number((info.match(/Height:\s+(\d+)/) || [])[1]);
        const mapped = /Map State:\s+IsViewable/.test(info);
        if (mapped && w >= 800 && h >= 600) {
          await shOut(`xdotool windowraise ${id} windowactivate ${id} || true`);
          return { id, x, y, w, h };
        }
        last = `id=${id} ${w}x${h} mapped=${mapped}`;
      }
    } catch (err) {
      last = err instanceof Error ? err.message : String(err);
    }
    await sleep(250);
  }
  throw new Error(`找不到录屏窗口：${last}`);
}

function even(n) {
  return n % 2 === 0 ? n : n - 1;
}

function startFfmpeg(geom, dest) {
  const w = even(geom.w);
  const h = even(geom.h);
  const args = [
    "-y",
    "-loglevel",
    "info",
    "-f",
    "x11grab",
    "-draw_mouse",
    "0",
    "-framerate",
    "30",
    "-video_size",
    `${w}x${h}`,
    "-i",
    `${DISPLAY}+${Math.max(0, geom.x)},${Math.max(0, geom.y)}`,
    "-c:v",
    "libx264",
    "-preset",
    "veryfast",
    "-crf",
    "17",
    "-pix_fmt",
    "yuv420p",
    "-g",
    "60",
    "-movflags",
    "+faststart",
    dest,
  ];
  log("ffmpeg", args.join(" "));
  const child = spawn("ffmpeg", args, { stdio: ["pipe", "pipe", "pipe"] });
  child.errText = "";
  child.stderr.on("data", (d) => {
    child.errText += d.toString();
    if (child.errText.length > 8000) child.errText = child.errText.slice(-4000);
  });
  return child;
}

function stopFfmpeg(child) {
  return new Promise((resolve) => {
    if (!child || child.killed) return resolve();
    const timer = setTimeout(() => child.kill("SIGKILL"), 4000);
    child.on("exit", () => {
      clearTimeout(timer);
      resolve();
    });
    child.kill("SIGINT");
  });
}

function probe(path) {
  return shOut(`ffprobe -v error -show_entries format=duration,size -show_entries stream=codec_name,width,height,nb_frames -of json ${JSON.stringify(path)}`);
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
      const buf = Buffer.from(params.data, "base64");
      const t = Number(params.metadata?.timestamp || Date.now() / 1000);
      this.frames.push({ file, t, buf });
      writeFileSync(file, buf);
    });
    await this.cdp.send("Page.startScreencast", {
      format: "jpeg",
      quality: 90,
      maxWidth: VIEW_W,
      maxHeight: VIEW_H,
      everyNthFrame: 1,
    });
    this.started = true;
    log("screencast started");
  }

  async stop() {
    if (!this.started) return;
    await this.cdp.send("Page.stopScreencast").catch(() => {});
    this.started = false;
    log("screencast frames", this.frames.length);
  }

  async encode(dest) {
    if (this.frames.length < 30) throw new Error(`screencast 帧太少：${this.frames.length}`);
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
    await shOut(
      `ffmpeg -y -f concat -safe 0 -i ${JSON.stringify(list)} -vsync vfr -c:v libx264 -preset fast -crf 17 -pix_fmt yuv420p -movflags +faststart ${JSON.stringify(dest)}`,
    );
  }
}

async function connectCdp() {
  const list = await waitHttpJson(`http://127.0.0.1:${PORT}/json/list`);
  const page =
    list.find((t) => t.type === "page" && /5173/.test(t.url || "")) ||
    list.find((t) => t.type === "page" && t.webSocketDebuggerUrl);
  if (!page?.webSocketDebuggerUrl) {
    throw new Error(`CDP 无 page 目标: ${JSON.stringify(list).slice(0, 400)}`);
  }
  log("cdp target", page.url, page.title);
  const ws = new globalThis.WebSocket(page.webSocketDebuggerUrl);
  await new Promise((resolve, reject) => {
    ws.addEventListener("open", resolve);
    ws.addEventListener("error", () => reject(new Error("CDP websocket 失败")));
  });
  const cdp = new Cdp(ws);
  await cdp.send("Runtime.enable");
  await cdp.send("Page.enable");
  await cdp.send("Page.bringToFront").catch(() => {});
  await cdp.send("Emulation.setLocaleOverride", { locale: "zh-CN" }).catch(() => {});
  await cdp
    .send("Emulation.setDeviceMetricsOverride", {
      width: VIEW_W,
      height: VIEW_H,
      deviceScaleFactor: 1,
      mobile: false,
    })
    .catch(() => {});
  if (!/5173/.test(page.url || "")) {
    await cdp.send("Page.navigate", { url: `${BASE}/?mute=1` });
  }
  await waitPageReady(cdp);
  return { cdp, ws };
}

async function waitPageReady(cdp, timeout = 25000) {
  const t0 = Date.now();
  let last = "";
  while (Date.now() - t0 < timeout) {
    try {
      const snap = await cdp.evaluate(`({
        ready: document.readyState,
        href: location.href,
        hasApi: Boolean(window.__MOXI),
        apiReady: Boolean(window.__MOXI && window.__MOXI.ready)
      })`);
      last = JSON.stringify(snap);
      if (snap?.href && /5173/.test(snap.href) && snap.ready === "complete" && snap.hasApi) {
        log("page ready", last);
        return snap;
      }
    } catch (err) {
      last = err instanceof Error ? err.message : String(err);
      if (!/context was destroyed|Cannot find context|Execution context/i.test(last)) {
        log("page wait", last);
      }
    }
    await sleep(200);
  }
  throw new Error(`页面未就绪：${last}`);
}

async function injectTour(cdp) {
  const src = readFileSync(join(__dirname, "moxi-animation-tour.js"), "utf8");
  let last = "";
  for (let i = 0; i < 10; i += 1) {
    try {
      await cdp.evaluate(`${src}\ntrue`);
      const setup = await cdp.call("setup");
      log("tour ready", JSON.stringify(setup));
      return setup;
    } catch (err) {
      last = err instanceof Error ? err.message : String(err);
      log("inject retry", i, last);
      await sleep(400);
      await waitPageReady(cdp).catch(() => {});
    }
  }
  throw new Error(`注入巡演失败：${last}`);
}

async function runTour(cdp, mark) {
  await cdp.call("setScene", -1, "全动画能力录屏", "眨眼 · 对口型 · 表情 · 发丝");
  await sleep(2200);

  mark("idle", "闲置：自动眨眼、视线跟随、头发/流苏微动");
  await cdp.call("setScene", 0, "闲置呼吸", "自动眨眼 · 视线跟随 · 发丝流苏微动");
  await cdp.call("gazeHoldCenter", 3800);
  await cdp.call("gazeFigureEight", 7200);

  mark("talk", "说话对口型：扫过啊衣乌诶哦妈风等 viseme");
  await cdp.call("setScene", 1, "说话对口型", "仅口型 · 扫过啊衣乌诶哦妈风");
  await cdp.call("resetLook");
  await cdp.call("fillLine", PANGRAM);
  await cdp.call("speakNow");
  await cdp.call("waitSpeaking");
  await cdp.call("waitSilent");
  await sleep(400);
  await cdp.call("fillLine", POEM);
  await cdp.call("speakNow");
  await cdp.call("waitSpeaking");
  await cdp.call("waitSilent");
  await sleep(300);
  await cdp.call("fillLine", ENGLISH);
  await cdp.call("speakNow");
  await cdp.call("waitSpeaking");
  await cdp.call("waitSilent");
  await sleep(500);

  mark("faces", "全部表情：平静、浅笑、开怀、讶异、低眉、含羞、眨眼、困倦");
  await cdp.call("setScene", 2, "神情", "八种表情逐一点亮");
  await cdp.call("resetLook");
  for (const name of EXPRESSIONS) {
    await cdp.call("setScene", 2, `神情 · ${name}`, "平静 浅笑 开怀 讶异 低眉 含羞 眨眼 困倦");
    await cdp.call("clickText", name);
    await sleep(1800);
  }
  await cdp.call("clickText", "平静");
  await sleep(400);

  mark("chips", "口型芯片 hold：A E I O U WQ M F L S");
  await cdp.call("setScene", 3, "口型芯片", "逐个卡住 viseme 看嘴形");
  const labels = { A: "啊", E: "诶", I: "衣", O: "哦", U: "乌", WQ: "喔", M: "姆", F: "夫", L: "勒", S: "斯" };
  for (const id of VISEMES) {
    await cdp.call("setScene", 3, `口型 · ${id} ${labels[id]}`, "点芯片可单独卡住 viseme");
    await cdp.call("holdChip", id);
    await sleep(1300);
  }
  await cdp.call("holdChip", "S");
  await sleep(200);

  mark("wind", "风力滑杆拉高：头发二次运动");
  await cdp.call("setScene", 4, "发丝风力", "滑杆拉到最强 · 头发流苏二次运动");
  await cdp.call("setWind", 2, 1100);
  await cdp.call("gazeFigureEight", 7000);

  mark("stop", "收声 / 回到闲置");
  await cdp.call("setScene", 5, "收声回座", "开口中途收声，回到闲置");
  await cdp.call("fillLine", "你若说话，我便对上口型；你若静默，发丝也自己摇。");
  await cdp.call("speakNow");
  await cdp.call("waitSpeaking");
  await sleep(1400);
  await cdp.call("stopNow");
  await cdp.call("clickText", "平静");
  await cdp.call("setWind", 1, 700);
  await cdp.call("resetLook");
  await cdp.call("endCard");
  await cdp.call("gazeHoldCenter", 2800);

  mark("end", "结束");
  await sleep(800);
}

function writeGuide(outPath, mdPath, duration, chapters) {
  const stamps = chapters
    .map((c) => {
      const m = Math.floor(c.t / 60);
      const s = Math.floor(c.t % 60);
      const ds = Math.round((c.t % 1) * 10);
      const stamp = `${String(m).padStart(2, "0")}:${String(s).padStart(2, "0")}.${ds}`;
      return `| ${stamp} | ${c.title} |`;
    })
    .join("\n");
  const md = `# 墨汐 · 全动画能力录屏

文件：\`${outPath}\`

用任意播放器打开即可（H.264 / yuv420p mp4）。片内顶部金框会标明当前段落。

## 时间轴

| 时间 | 内容 |
| --- | --- |
${stamps}

## 各段演示了什么

1. **闲置** — 不说话时的呼吸感：自动眨眼、视线跟着指针走、刘海 / 侧发 / 腰间流苏轻微摆动。
2. **说话对口型** — 先用 viseme 全覆盖句「${PANGRAM}」，再念庭前原句与一句英文；声线模式为「仅口型」，嘴形扫过 啊衣乌诶哦 / 妈 / 风 等。
3. **全部表情** — 依次点：平静、浅笑、开怀、讶异、低眉、含羞、眨眼、困倦。
4. **口型芯片 hold** — 依次卡住 A / E / I / O / U / WQ / M / F / L / S，方便对照嘴形。
5. **风力** — 把「发丝」滑杆拉到最高，再做视线扫过，看头发与流苏的二次运动。
6. **收声 / 回闲置** — 开口说到一半点「收声」，表情回平静、风力回 1，重新进入闲置眨眼。

时长约 ${duration.toFixed(1)} 秒。重录：\`node scripts/record-all-animations.mjs\`（需 \`npm run dev\`）。
`;
  writeFileSync(mdPath, md);
}

async function main() {
  mkdirSync(OUT_DIR, { recursive: true });
  await waitDemo();
  log("demo up", BASE);

  if (CAPTURE === "x11") {
    try {
      await shOut("xdotool search --name 'Google Chrome' windowminimize || true");
    } catch {
      /* ignore */
    }
  }

  const chrome = spawnChrome();
  chrome.stderr.on("data", (d) => {
    const text = d.toString();
    if (/ERROR|FATAL|DevTools listening/.test(text)) log("chrome", text.trim().slice(0, 220));
  });

  let ffmpeg;
  let ws;
  let screencast;
  const chapters = [];
  const frameDir = process.env.MOXI_FRAME_DIR || "/tmp/moxi-tour-screencast";
  const rawPath = join(OUT_DIR, "moxi-guofeng-all-animations.raw.mp4");
  const outPath = join(OUT_DIR, "moxi-guofeng-all-animations.mp4");
  const mdPath = join(OUT_DIR, "moxi-guofeng-all-animations.md");

  let recStart = Date.now();
  const mark = (id, title) => {
    const t = (Date.now() - recStart) / 1000;
    chapters.push({ id, title, t: Number(t.toFixed(2)) });
    log(`chapter ${id} @ ${t.toFixed(2)}s  ${title}`);
  };

  try {
    await waitHttpJson(`http://127.0.0.1:${PORT}/json/version`, 25000);
    const session = await connectCdp();
    ws = session.ws;
    const { cdp } = session;
    await injectTour(cdp);

    if (CAPTURE === "x11") {
      const geom = await findRecordWindow();
      try {
        await shOut(
          `xdotool windowmove ${geom.id} 80 36 windowsize ${geom.id} ${VIEW_W} ${VIEW_H} windowraise ${geom.id} windowactivate ${geom.id}`,
        );
      } catch (err) {
        log("windowmove skip", err instanceof Error ? err.message : err);
      }
      const geom2 = await findRecordWindow();
      log("window", geom2);
      if (existsSync(rawPath)) rmSync(rawPath);
      ffmpeg = startFfmpeg(geom2, rawPath);
      await sleep(400);
      recStart = Date.now();
      await runTour(cdp, mark);
    } else {
      if (existsSync(frameDir)) rmSync(frameDir, { recursive: true, force: true });
      screencast = new Screencast(cdp, frameDir);
      await screencast.start();
      await sleep(300);
      recStart = Date.now();
      await runTour(cdp, mark);
      await sleep(200);
      await screencast.stop();
    }
  } finally {
    await stopFfmpeg(ffmpeg);
    try {
      await screencast?.stop();
    } catch {
      /* ignore */
    }
    try {
      ws?.close();
    } catch {
      /* ignore */
    }
    chrome.kill("SIGTERM");
    await sleep(400);
    try {
      chrome.kill("SIGKILL");
    } catch {
      /* ignore */
    }
  }

  if (CAPTURE === "x11") {
    if (!existsSync(rawPath)) throw new Error("未写出录屏文件");
    const info = JSON.parse(await probe(rawPath));
    const duration = Number(info.format?.duration || 0);
    log("raw probe", JSON.stringify(info));
    if (duration < 50) throw new Error(`录屏过短：${duration}s`);
    try {
      await shOut(
        `ffmpeg -y -i ${JSON.stringify(rawPath)} -c copy -movflags +faststart ${JSON.stringify(outPath)}`,
      );
      rmSync(rawPath, { force: true });
    } catch (err) {
      log("faststart copy failed, keep raw", err instanceof Error ? err.message : err);
      renameSync(rawPath, outPath);
    }
    writeGuide(outPath, mdPath, duration, chapters);
    log("wrote", outPath, mdPath, `${duration.toFixed(1)}s`);
    console.log(JSON.stringify({ outPath, mdPath, duration, chapters }, null, 2));
    return;
  }

  await screencast.encode(outPath);
  rmSync(frameDir, { recursive: true, force: true });
  const info = JSON.parse(await probe(outPath));
  const duration = Number(info.format?.duration || 0);
  log("probe", JSON.stringify(info));
  if (duration < 50) throw new Error(`录屏过短：${duration}s`);
  writeGuide(outPath, mdPath, duration, chapters);
  log("wrote", outPath, mdPath, `${duration.toFixed(1)}s`);
  console.log(JSON.stringify({ outPath, mdPath, duration, chapters, frames: screencast.frames.length }, null, 2));
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
