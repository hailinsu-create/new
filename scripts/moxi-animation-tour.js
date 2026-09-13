/**
 * Injected into the 墨汐 demo. Exposes window.__TOUR for the recorder.
 * Does not change product behavior unless the recorder evaluates it.
 */
(() => {
  const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

  function ease(t) {
    return t < 0.5 ? 2 * t * t : 1 - (2 - 2 * t) ** 2 / 2;
  }

  function $(sel) {
    const node = document.querySelector(sel);
    if (!node) throw new Error(`缺少元素 ${sel}`);
    return node;
  }

  function buttonByText(text) {
    const node = [...document.querySelectorAll("button")].find(
      (el) => el.textContent.replace(/\s+/g, "") === text.replace(/\s+/g, ""),
    );
    if (!node) throw new Error(`缺少按钮「${text}」`);
    return node;
  }

  function chipById(id) {
    const node = [...document.querySelectorAll("button.chip")].find((el) => {
      const label = el.textContent.trim();
      return label === id || label.startsWith(`${id} `);
    });
    if (!node) throw new Error(`缺少口型芯片 ${id}`);
    return node;
  }

  function ensureHud() {
    let hud = document.getElementById("moxi-tour-hud");
    if (hud) return hud;
    hud = document.createElement("div");
    hud.id = "moxi-tour-hud";
    hud.innerHTML = `
      <div class="tour-card">
        <div class="tour-kicker" id="tour-kicker">墨汐 · 庭前对口</div>
        <div class="tour-title" id="tour-title">全动画能力</div>
        <div class="tour-sub" id="tour-sub">正在入座…</div>
      </div>
      <div class="tour-progress" id="tour-progress"></div>
    `;
    const style = document.createElement("style");
    style.textContent = `
      #moxi-tour-hud {
        position: fixed;
        left: 50%;
        top: 18px;
        transform: translateX(-50%);
        z-index: 2147483000;
        pointer-events: none;
        display: flex;
        flex-direction: column;
        align-items: center;
        gap: 8px;
        font-family: "Noto Sans SC", "WenQuanYi Micro Hei", sans-serif;
      }
      #moxi-tour-hud .tour-card {
        min-width: 280px;
        max-width: min(560px, 70vw);
        text-align: center;
        padding: 10px 22px 12px;
        background: linear-gradient(180deg, rgba(18, 24, 22, 0.78), rgba(10, 14, 12, 0.88));
        border: 1px solid rgba(201, 163, 106, 0.45);
        box-shadow: 0 12px 40px rgba(0, 0, 0, 0.4);
        backdrop-filter: blur(12px);
      }
      #moxi-tour-hud .tour-kicker {
        font-size: 10px;
        letter-spacing: 0.42em;
        color: #c9a36a;
      }
      #moxi-tour-hud .tour-title {
        margin-top: 4px;
        font-family: "Ma Shan Zheng", "Noto Sans SC", serif;
        font-size: 30px;
        letter-spacing: 0.18em;
        color: #e4d3b3;
        line-height: 1.15;
      }
      #moxi-tour-hud .tour-sub {
        margin-top: 6px;
        font-size: 13px;
        letter-spacing: 0.18em;
        color: #9bb7b0;
      }
      #moxi-tour-hud .tour-progress {
        display: flex;
        gap: 6px;
      }
      #moxi-tour-hud .dot {
        width: 7px;
        height: 7px;
        border-radius: 50%;
        border: 1px solid rgba(201, 163, 106, 0.55);
        background: transparent;
      }
      #moxi-tour-hud .dot.is-on {
        background: #c44536;
        border-color: #c44536;
      }
      #moxi-tour-cursor {
        position: fixed;
        left: 0;
        top: 0;
        width: 22px;
        height: 22px;
        margin-left: -3px;
        margin-top: -3px;
        pointer-events: none;
        z-index: 2147483646;
        filter: drop-shadow(0 2px 4px rgba(0, 0, 0, 0.55));
      }
      #moxi-tour-cursor i {
        display: block;
        width: 0;
        height: 0;
        border-style: solid;
        border-width: 0 11px 20px 11px;
        border-color: transparent transparent #f3dd9a transparent;
        transform: rotate(-28deg);
        transform-origin: 50% 80%;
      }
      #moxi-tour-cursor.is-down i {
        transform: rotate(-28deg) scale(0.82);
      }
    `;
    document.head.append(style);
    document.body.append(hud);
    const cursor = document.createElement("div");
    cursor.id = "moxi-tour-cursor";
    cursor.innerHTML = "<i></i>";
    document.body.append(cursor);
    return hud;
  }

  const CHAPTERS = ["闲置", "对口型", "表情", "口型", "风力", "收声"];

  function setProgress(index) {
    const row = document.getElementById("tour-progress");
    if (!row) return;
    row.replaceChildren(
      ...CHAPTERS.map((_, i) => {
        const dot = document.createElement("span");
        dot.className = i === index ? "dot is-on" : "dot";
        return dot;
      }),
    );
  }

  let cursorX = 900;
  let cursorY = 420;

  function placeCursor(x, y) {
    cursorX = x;
    cursorY = y;
    const cursor = document.getElementById("moxi-tour-cursor");
    if (cursor) cursor.style.transform = `translate(${x}px, ${y}px)`;
  }

  function dispatchLook(x, y) {
    const canvas = document.querySelector("#avatar");
    if (!canvas) return;
    const rect = canvas.getBoundingClientRect();
    const inside =
      x >= rect.left && x <= rect.right && y >= rect.top && y <= rect.bottom;
    if (!inside) {
      canvas.dispatchEvent(new PointerEvent("pointerleave", { bubbles: true }));
      return;
    }
    canvas.dispatchEvent(
      new PointerEvent("pointermove", {
        bubbles: true,
        clientX: x,
        clientY: y,
        pointerId: 1,
        pointerType: "mouse",
      }),
    );
  }

  async function moveTo(x, y, ms = 500) {
    const x0 = cursorX;
    const y0 = cursorY;
    if (ms <= 0) {
      placeCursor(x, y);
      dispatchLook(x, y);
      return;
    }
    const t0 = performance.now();
    while (true) {
      const t = Math.min(1, (performance.now() - t0) / ms);
      const k = ease(t);
      const nx = x0 + (x - x0) * k;
      const ny = y0 + (y - y0) * k;
      placeCursor(nx, ny);
      dispatchLook(nx, ny);
      if (t >= 1) break;
      await sleep(16);
    }
  }

  async function moveToEl(el, ms = 480) {
    el.scrollIntoView({ block: "nearest", inline: "nearest" });
    const r = el.getBoundingClientRect();
    await moveTo(r.left + r.width * 0.55, r.top + r.height * 0.55, ms);
  }

  async function clickEl(el) {
    await moveToEl(el);
    const cursor = document.getElementById("moxi-tour-cursor");
    cursor?.classList.add("is-down");
    await sleep(90);
    el.click();
    await sleep(80);
    cursor?.classList.remove("is-down");
  }

  async function waitReady(timeout = 25000) {
    const t0 = Date.now();
    while (Date.now() - t0 < timeout) {
      if (window.__MOXI?.ready) {
        try {
          await Promise.race([document.fonts.ready, sleep(2500)]);
        } catch {
          /* ignore */
        }
        return true;
      }
      await sleep(80);
    }
    throw new Error("墨汐未入座（__MOXI.ready 超时）");
  }

  window.__TOUR = {
    async setup() {
      document.title = "MOXI_RECORD_TOUR";
      ensureHud();
      await waitReady();
      const mode = document.querySelector("#voice-mode");
      if (mode) mode.value = "silent";
      const canvas = $("#avatar");
      const r = canvas.getBoundingClientRect();
      placeCursor(r.left + r.width * 0.52, r.top + r.height * 0.4);
      setProgress(-1);
      document.getElementById("tour-kicker").textContent = "墨汐 · 庭前对口";
      document.getElementById("tour-title").textContent = "全动画能力录屏";
      document.getElementById("tour-sub").textContent = "眨眼 · 对口型 · 表情 · 发丝";
      return {
        ready: true,
        canvas: { width: canvas.width, height: canvas.height, ...r.toJSON?.() },
        state: window.__MOXI.getState(),
      };
    },

    setScene(index, title, sub) {
      ensureHud();
      setProgress(index);
      document.getElementById("tour-title").textContent = title;
      document.getElementById("tour-sub").textContent = sub;
      return { title, sub };
    },

    async resetLook() {
      const canvas = document.querySelector("#avatar");
      canvas?.dispatchEvent(new PointerEvent("pointerleave", { bubbles: true }));
      await sleep(200);
    },

    async gazeFigureEight(ms) {
      const canvas = $("#avatar");
      const r = canvas.getBoundingClientRect();
      const cx = r.left + r.width * 0.48;
      const cy = r.top + r.height * 0.36;
      const t0 = performance.now();
      while (performance.now() - t0 < ms) {
        const t = (performance.now() - t0) / 1000;
        const x = cx + Math.sin(t * 0.95) * r.width * 0.2;
        const y = cy + Math.sin(t * 1.9) * r.height * 0.11;
        placeCursor(x, y);
        dispatchLook(x, y);
        await sleep(16);
      }
    },

    async gazeHoldCenter(ms) {
      const canvas = $("#avatar");
      const r = canvas.getBoundingClientRect();
      const x = r.left + r.width * 0.5;
      const y = r.top + r.height * 0.38;
      await moveTo(x, y, 400);
      dispatchLook(x, y);
      await sleep(ms);
    },

    async clickText(text) {
      await clickEl(buttonByText(text));
      return text;
    },

    async holdChip(id) {
      await clickEl(chipById(id));
      return id;
    },

    async setWind(value, ms = 900) {
      const slider = document.querySelector('input[type="range"]');
      if (!slider) throw new Error("缺少风力滑杆");
      await moveToEl(slider, 400);
      const start = Number(slider.value);
      const t0 = performance.now();
      while (true) {
        const t = Math.min(1, (performance.now() - t0) / ms);
        const next = start + (value - start) * ease(t);
        slider.value = String(next);
        slider.dispatchEvent(new Event("input", { bubbles: true }));
        if (t >= 1) break;
        await sleep(16);
      }
      return Number(slider.value);
    },

    async fillLine(text) {
      const ta = $("#line");
      await moveToEl(ta, 350);
      ta.focus();
      ta.value = text;
      ta.dispatchEvent(new Event("input", { bubbles: true }));
      return text;
    },

    async speakNow() {
      await clickEl(buttonByText("开口"));
    },

    async stopNow() {
      await clickEl(buttonByText("收声"));
    },

    async waitSpeaking(timeout = 20000) {
      const t0 = Date.now();
      while (Date.now() - t0 < timeout) {
        if (window.__MOXI.getState().speaking) return true;
        await sleep(40);
      }
      throw new Error("开口后未进入 speaking");
    },

    async waitSilent(timeout = 20000) {
      const t0 = Date.now();
      while (Date.now() - t0 < timeout) {
        if (!window.__MOXI.getState().speaking) return true;
        await sleep(50);
      }
      throw new Error("对口型未结束");
    },

    state() {
      return window.__MOXI.getState();
    },

    endCard() {
      setProgress(5);
      document.getElementById("tour-title").textContent = "庭中又静下来";
      document.getElementById("tour-sub").textContent = "墨汐已回座 · 闲置呼吸";
    },
  };
})();
