#!/usr/bin/env node
/**
 * Body-action after reel (nod/bow/hop/step/cloth/speech afterglow).
 *   npm run dev
 *   node scripts/record-actions-100.mjs
 */
import { spawn } from "node:child_process";
import {
  mkdirSync,
  writeFileSync,
  existsSync,
  rmSync,
  renameSync,
} from "node:fs";
import { setTimeout as sleep } from "node:timers/promises";
import { join } from "node:path";

const DISPLAY = process.env.DISPLAY || ":1";
const PORT = Number(process.env.MOXI_CDP_PORT || 9347);
const BASE = process.env.MOXI_URL || "http://localhost:5173";
const OUT_DIR = process.env.MOXI_OUT || "/opt/cursor/artifacts";
const PROFILE = process.env.MOXI_PROFILE || "/tmp/moxi-actions-100-profile";
const CHROME = process.env.CHROME_PATH || "google-chrome";
const VIEW_W = 1440;
const VIEW_H = 900;
const OUT = join(OUT_DIR, "moxi-actions-100-after.mp4");
const RAW = join(OUT_DIR, "moxi-actions-100-after.raw.mp4");

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

async function waitDemo() {
  const t0 = Date.now();
  while (Date.now() - t0 < 25000) {
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

function writeChromeProfile() {
  if (existsSync(PROFILE)) rmSync(PROFILE, { recursive: true, force: true });
  const def = join(PROFILE, "Default");
  mkdirSync(def, { recursive: true });
  writeFileSync(join(PROFILE, "First Run"), "");
  writeFileSync(
    join(PROFILE, "Local State"),
    JSON.stringify({
      background_mode: { enabled: false },
      user_experience_metrics: { reporting_enabled: false },
    }),
  );
  writeFileSync(
    join(def, "Preferences"),
    JSON.stringify({
      translate: { enabled: false },
      enable_do_not_track: true,
      intl: { accept_languages: "zh-CN,zh,en-US,en" },
      browser: { check_default_browser: false, has_seen_welcome_page: true },
      profile: {
        default_content_setting_values: { notifications: 2 },
        exit_type: "Normal",
        exited_cleanly: true,
      },
    }),
  );
}

function spawnChrome() {
  writeChromeProfile();
  const args = [
    "--no-sandbox",
    "--test-type",
    "--disable-dev-shm-usage",
    "--use-gl=angle",
    "--use-angle=swiftshader-webgl",
    `--remote-debugging-port=${PORT}`,
    "--remote-allow-origins=*",
    `--user-data-dir=${PROFILE}`,
    `--window-size=${VIEW_W},${VIEW_H}`,
    "--window-position=64,32",
    "--disable-extensions",
    "--disable-sync",
    "--disable-translate",
    "--disable-component-update",
    "--disable-background-networking",
    "--disable-features=Translate,TranslateUI,TranslateRanker,LanguageDetection,ChromeWhatsNew,MediaRouter,AutomationControlled,UpdateNotificationPromo",
    "--hide-crash-restore-bubble",
    "--disable-infobars",
    "--disable-session-crashed-bubble",
    "--no-first-run",
    "--no-default-browser-check",
    "--autoplay-policy=no-user-gesture-required",
    "--mute-audio",
    "--hide-scrollbars",
    "--lang=zh-CN",
    "--class=MoxiActions100",
    `--app=${BASE}/?mute=1`,
  ];
  return spawn(CHROME, args, {
    env: { ...process.env, DISPLAY, LANG: "zh_CN.UTF-8" },
    stdio: ["ignore", "pipe", "pipe"],
  });
}

async function findWindow(timeout = 18000) {
  const t0 = Date.now();
  let last = "";
  while (Date.now() - t0 < timeout) {
    try {
      const ids = (await shOut("xdotool search --class MoxiActions100 || true")).split(/\s+/).filter(Boolean);
      for (const id of ids) {
        const info = await shOut(`xwininfo -id ${id}`);
        const x = Number((info.match(/Absolute upper-left X:\s+(-?\d+)/) || [])[1]);
        const y = Number((info.match(/Absolute upper-left Y:\s+(-?\d+)/) || [])[1]);
        const w = Number((info.match(/Width:\s+(\d+)/) || [])[1]);
        const h = Number((info.match(/Height:\s+(\d+)/) || [])[1]);
        const mapped = /Map State:\s+IsViewable/.test(info);
        if (mapped && w >= 700 && h >= 500) return { id, x, y, w, h };
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
  const child = spawn(
    "ffmpeg",
    [
      "-y",
      "-loglevel",
      "error",
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
      "18",
      "-pix_fmt",
      "yuv420p",
      "-movflags",
      "+faststart",
      dest,
    ],
    { stdio: ["pipe", "pipe", "pipe"] },
  );
  child.errText = "";
  child.stderr.on("data", (d) => {
    child.errText += d.toString();
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

async function waitPage(cdp) {
  const t0 = Date.now();
  let last = "";
  while (Date.now() - t0 < 25000) {
    try {
      const snap = await cdp.evaluate(`({
        ready: document.readyState,
        href: location.href,
        api: Boolean(window.__MOXI && window.__MOXI.ready)
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

async function shot(cdp, name) {
  const result = await cdp.send("Page.captureScreenshot", { format: "png", fromSurface: true });
  const dest = join(OUT_DIR, "moxi-action-rounds", `${name}.png`);
  mkdirSync(join(OUT_DIR, "moxi-action-rounds"), { recursive: true });
  writeFileSync(dest, Buffer.from(result.data, "base64"));
  log("shot", dest);
}

async function hud(cdp, title, sub) {
  await cdp.evaluate(`(() => {
    let el = document.getElementById("moxi-blink-hud");
    if (!el) {
      el = document.createElement("div");
      el.id = "moxi-blink-hud";
      el.style.cssText = "position:fixed;left:50%;top:16px;transform:translateX(-50%);z-index:2147483000;pointer-events:none;padding:8px 18px 10px;background:rgba(12,16,14,.78);border:1px solid rgba(201,163,106,.5);color:#f4e6d0;font:13px/1.4 sans-serif;letter-spacing:.04em;text-align:center;";
      document.body.appendChild(el);
    }
    el.innerHTML = "<div style='color:#c9a36a;font-size:10px;letter-spacing:.38em'>墨汐 · 身段 100 轮 after</div><div style='margin-top:4px;font-size:16px'>${title}</div><div style='margin-top:2px;opacity:.8;font-size:12px'>${sub}</div>";
    return true;
  })()`);
}

async function runReel(cdp) {
  await cdp.evaluate(`(() => {
    const canvas = document.getElementById("avatar");
    if (!canvas) return;
    const r = canvas.getBoundingClientRect();
    const fire = (x, y) => canvas.dispatchEvent(new PointerEvent("pointermove", { clientX: x, clientY: y, bubbles: true }));
    window.__gaze = { fire, r };
    fire(r.left + r.width * 0.5, r.top + r.height * 0.42);
    return true;
  })()`);

  const play = async (id) => {
    await cdp.evaluate(`window.__MOXI.playAction(${JSON.stringify(id)})`);
  };

  await hud(cdp, "全身静立", "重心呼吸 · 裙摆 · 萤火涟漪");
  await cdp.evaluate(`window.__MOXI.setView("full")`);
  await cdp.evaluate(`window.__MOXI.setWind(1)`);
  await cdp.evaluate(`window.__MOXI.setExpression("neutral")`);
  await sleep(3200);

  await hud(cdp, "点头", "颔首带发丝");
  await play("nod");
  await sleep(500);
  await shot(cdp, "after-nod");
  await sleep(1300);

  await hud(cdp, "侧身", "头颈让开 · 披肩翻转");
  await play("sideTurn");
  await sleep(2000);

  await hud(cdp, "微鞠躬", "头颈+躯干 · 裙摆轻送");
  await play("bow");
  await sleep(700);
  await shot(cdp, "after-bow");
  await sleep(1500);

  await hud(cdp, "重心大转移", "髋左右换脚");
  await play("weightShift");
  await sleep(2000);

  await hud(cdp, "踮脚", "脚尖离地 · 视线微抬");
  await play("tiptoe");
  await sleep(1800);

  await hud(cdp, "手势", "披肩/肩线暗示抬手");
  await play("gesture");
  await sleep(2000);

  await hud(cdp, "原地踏步", "换脚循环 · 下摆滞后");
  await play("step");
  await sleep(2400);

  await hud(cdp, "欲走", "重量先偏 · 目光略垂");
  await play("walkPrep");
  await sleep(1800);

  await hud(cdp, "害羞低头", "含羞头颈+腮红");
  await cdp.evaluate(`window.__MOXI.setExpression("shy")`);
  await sleep(2200);

  await hud(cdp, "讶异后仰", "胸口让开 · 一点离地");
  await cdp.evaluate(`window.__MOXI.setExpression("surprise")`);
  await sleep(2000);

  await hud(cdp, "开心轻跳", "落地裙弧 · 脚钉住");
  await cdp.evaluate(`window.__MOXI.setExpression("laugh")`);
  await play("hop");
  await sleep(450);
  await shot(cdp, "after-hop");
  await sleep(1550);

  await hud(cdp, "叹气沉肩", "双肩落下 · 呼吸加深");
  await cdp.evaluate(`window.__MOXI.setExpression("sad")`);
  await sleep(2200);

  await hud(cdp, "开口肩动", "viseme 抬肩 · 说完鞠躬");
  await cdp.evaluate(`window.__MOXI.setExpression("neutral")`);
  await cdp.evaluate(`window.__MOXI.setWind(1)`);
  await cdp.evaluate(`window.__MOXI.speak("月色入庭，风过竹梢。纸鹤还在，我也还在。")`);
  await sleep(7500);

  await hud(cdp, "台词余韵", "鞠躬 · 垂视 · 嘴角未收");
  await sleep(2800);

  await hud(cdp, "hold=A 对齐抽查", "全身口型封面仍贴在唇上");
  await cdp.evaluate(`window.__MOXI.holdViseme("A")`);
  await sleep(800);
  await shot(cdp, "after-full-hold-A");
  await sleep(1400);
  await cdp.evaluate(`window.__MOXI.holdViseme(null)`);

  await hud(cdp, "拖拽视线", "眼先于头 · 披肩跟随");
  await cdp.evaluate(`(() => {
    const { fire, r } = window.__gaze;
    const t0 = performance.now();
    const step = () => {
      const t = (performance.now() - t0) / 1000;
      fire(r.left + r.width * (0.5 + 0.22 * Math.sin(t * 0.9)), r.top + r.height * (0.38 + 0.08 * Math.sin(t * 0.7)));
      if (t < 4.2) requestAnimationFrame(step);
    };
    step();
  })()`);
  await sleep(4500);

  await hud(cdp, "强风布料", "裙弧 · 流苏碰撞 · 软墙");
  await cdp.evaluate(`window.__MOXI.setWind(1.85)`);
  await play("weightShift");
  await sleep(2800);

  await hud(cdp, "回到庭中", "呼吸光 · 灯笼 · 闲置身段");
  await cdp.evaluate(`window.__MOXI.setWind(1)`);
  await cdp.evaluate(`window.__MOXI.setExpression("neutral")`);
  await cdp.evaluate(`(() => {
    const { fire, r } = window.__gaze;
    fire(r.left + r.width * 0.5, r.top + r.height * 0.42);
  })()`);
  await sleep(4000);
}

async function main() {
  mkdirSync(OUT_DIR, { recursive: true });
  await waitDemo();
  const chrome = spawnChrome();
  chrome.stderr.on("data", (d) => {
    const text = d.toString();
    if (/ERROR|FATAL|DevTools listening/.test(text)) log("chrome", text.trim().slice(0, 200));
  });
  let ffmpeg;
  let ws;
  try {
    await waitHttpJson(`http://127.0.0.1:${PORT}/json/version`, 25000);
    const list = await waitHttpJson(`http://127.0.0.1:${PORT}/json/list`);
    const page = list.find((t) => t.type === "page" && t.webSocketDebuggerUrl);
    if (!page) throw new Error("no cdp page");
    ws = new globalThis.WebSocket(page.webSocketDebuggerUrl);
    await new Promise((resolve, reject) => {
      ws.addEventListener("open", resolve);
      ws.addEventListener("error", () => reject(new Error("cdp ws fail")));
    });
    const cdp = new Cdp(ws);
    await cdp.send("Runtime.enable");
    await cdp.send("Page.enable");
    if (!/5173/.test(page.url || "")) await cdp.send("Page.navigate", { url: `${BASE}/?mute=1` });
    await waitPage(cdp);
    const geom = await findWindow();
    await shOut(
      `xdotool windowmove ${geom.id} 64 32 windowsize ${geom.id} ${VIEW_W} ${VIEW_H} windowraise ${geom.id} windowactivate ${geom.id} || true`,
    );
    const geom2 = await findWindow();
    log("window", geom2);
    if (existsSync(RAW)) rmSync(RAW);
    ffmpeg = startFfmpeg(geom2, RAW);
    await sleep(350);
    await runReel(cdp);
  } finally {
    await stopFfmpeg(ffmpeg);
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
  if (!existsSync(RAW)) throw new Error("未写出录屏");
  try {
    await shOut(`ffmpeg -y -i ${JSON.stringify(RAW)} -c copy -movflags +faststart ${JSON.stringify(OUT)}`);
    rmSync(RAW, { force: true });
  } catch {
    renameSync(RAW, OUT);
  }
  const probe = await shOut(
    `ffprobe -v error -show_entries format=duration,size -show_entries stream=width,height,codec_name -of json ${JSON.stringify(OUT)}`,
  );
  log("wrote", OUT, probe);
  console.log(probe);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
