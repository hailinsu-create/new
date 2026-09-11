import "./styles.css";
import pinyinBlob from "./avatar/pinyin.txt?raw";
import { SpeechDriver, type VoiceMode } from "./avatar/speech";
import {
  AvatarRig,
  EXPRESSIONS,
  EXPRESSION_LABELS,
  type Expression,
} from "./avatar/rig";
import {
  VISEME_IDS,
  VISEME_SHAPE,
  loadPinyin,
  timelineDuration,
  visemeLabel,
  type VisemeId,
  type VisemeSample,
} from "./avatar/viseme";

loadPinyin(pinyinBlob);

const LINES = [
  "月色入庭，风过竹梢。纸鹤还在，我也还在。",
  "我是墨汐。立领盘扣，肩上这一件，是水墨留下的影子。",
  "你若说话，我便对上口型；你若静默，发丝也自己摇。",
  "Hello. I can lip-sync in English too.",
];

function el<K extends keyof HTMLElementTagNameMap>(
  tag: K,
  props: Record<string, unknown> = {},
  children: Array<Node | string> = [],
): HTMLElementTagNameMap[K] {
  const node = document.createElement(tag);
  const { className, style, ...rest } = props;
  if (typeof className === "string") node.className = className;
  if (typeof style === "string") node.setAttribute("style", style);
  Object.assign(node, rest);
  for (const child of children) {
    node.append(typeof child === "string" ? document.createTextNode(child) : child);
  }
  return node;
}

const root = document.querySelector("#app");
if (!root) throw new Error("#app missing");

const scene = el("div", { className: "scene" });
const courtyard = el("div", { className: "courtyard" });
courtyard.setAttribute("aria-hidden", "true");
const vignette = el("div", { className: "vignette" });
const lantern = el("div", { className: "lantern-pulse" });

const fireflies = Array.from({ length: 8 }, (_, i) =>
  el("span", {
    className: "firefly",
    style: `--x:${12 + i * 10}%; --y:${18 + (i % 4) * 12}%; --dur:${8 + i}s; --delay:${i * 0.7}s;`,
  }),
);
const petals = Array.from({ length: 10 }, (_, i) =>
  el("span", {
    className: "petal",
    style: `--x:${6 + i * 9}%; --dur:${11 + (i % 5)}s; --delay:${i * 0.8}s;`,
  }),
);

const seal = el("img", {
  className: "seal",
  src: "./ui/crane-seal.jpg",
  alt: "纸鹤印",
});
const visemeLive = el("div", { className: "viseme-live" }, [
  el("small", {}, ["口型"]),
  el("b", { id: "viseme-glyph" }, ["静"]),
]);
const topbar = el("header", { className: "topbar" }, [
  el("div", { className: "brand" }, [
    seal,
    el("div", {}, [el("h1", {}, ["墨汐"]), el("p", {}, ["庭前对口 · 纸鹤听风"])]),
  ]),
  visemeLive,
]);

const stage = el("section", { className: "stage" });
const canvas = el("canvas", { id: "avatar" });
stage.append(canvas);
const caption = el("div", { className: "caption", id: "caption" });

const faceBox = el("div", { className: "faces" });
const faceButtons = new Map<Expression, HTMLButtonElement>();
for (const name of EXPRESSIONS) {
  const button = el("button", { type: "button" }, [EXPRESSION_LABELS[name]]);
  button.addEventListener("click", () => setExpression(name));
  faceButtons.set(name, button);
  faceBox.append(button);
}

const textarea = el("textarea", {
  id: "line",
  spellcheck: false,
  value: LINES[0],
  placeholder: "写一句，让她说。",
});
const speakBtn = el("button", { className: "speak", type: "button" }, ["开口"]);
const stopBtn = el("button", { className: "stop", type: "button" }, ["收声"]);
const nextBtn = el("button", { className: "ghost", type: "button" }, ["换一句"]);
const mode = el("select", { id: "voice-mode" }, [
  el("option", { value: "auto", textContent: "自动（朗读 / 声纹）" }),
  el("option", { value: "tts", textContent: "浏览器朗读" }),
  el("option", { value: "murmur", textContent: "模拟声纹" }),
  el("option", { value: "silent", textContent: "仅口型" }),
]);
const wind = el("input", { type: "range", min: "0", max: "2", step: "0.05", value: "1" });
const status = el("p", { className: "status", id: "status" }, ["正在铺庭、请墨汐入座…"]);

const chips = el("div", { className: "chips" });
const chipButtons = new Map<VisemeId, HTMLButtonElement>();
for (const id of VISEME_IDS) {
  const chip = el("button", { className: "chip", type: "button" }, [`${id} ${visemeLabel(id)}`]);
  chip.addEventListener("click", () => holdViseme(id));
  chipButtons.set(id, chip);
  chips.append(chip);
}

const dock = el("aside", { className: "dock" }, [
  el("div", { className: "panel" }, [el("h2", {}, ["神情"]), faceBox]),
  el("div", { className: "panel script" }, [
    el("h2", {}, ["台词"]),
    textarea,
    el("div", { className: "row" }, [
      speakBtn,
      stopBtn,
      nextBtn,
      el("label", { className: "mode" }, ["声", mode]),
    ]),
    status,
  ]),
  el("div", { className: "panel" }, [
    el("h2", {}, ["口型 / 风"]),
    chips,
    el("label", { className: "wind" }, ["发丝", wind]),
  ]),
]);

scene.append(courtyard, vignette, lantern, ...fireflies, ...petals, topbar, stage, caption, dock);
root.append(scene);

const speech = new SpeechDriver();
speech.configure({
  onStart: () => setStatus("正在对口型…"),
  onEnd: () => {
    setStatus("庭中又静下来。");
    renderCaption("");
  },
  onChar: (char, index) => renderCaption(textarea.value, index, char),
});

let windValue = 1;
const rig = new AvatarRig(canvas, {
  sampleMouth: () => speech.sample(),
  wind: () => windValue,
});

wind.addEventListener("input", () => {
  windValue = Number(wind.value);
});

speakBtn.addEventListener("click", () => void speakNow());
stopBtn.addEventListener("click", () => speech.stop());
nextBtn.addEventListener("click", () => {
  const current = textarea.value;
  const index = LINES.indexOf(current);
  textarea.value = LINES[(index + 1) % LINES.length];
});
textarea.addEventListener("keydown", (event) => {
  if (event.key === "Enter" && (event.metaKey || event.ctrlKey)) {
    event.preventDefault();
    void speakNow();
  }
});

function setStatus(message: string, kind: "ok" | "error" = "ok"): void {
  status.textContent = message;
  status.className = kind === "error" ? "status is-error" : "status";
}

function setExpression(name: Expression): void {
  rig.setExpression(name);
  for (const [key, button] of faceButtons) {
    button.classList.toggle("is-on", key === name);
  }
}

function holdViseme(id: VisemeId): void {
  if (paramsHold === id) {
    speech.holdViseme(null);
    paramsHold = null;
    highlightViseme("rest");
    return;
  }
  paramsHold = id;
  const sample: VisemeSample = {
    id,
    shape: VISEME_SHAPE[id],
    char: visemeLabel(id),
    index: 0,
    speaking: id !== "rest",
    energy: VISEME_SHAPE[id].open,
  };
  speech.holdViseme(sample);
  highlightViseme(id);
}

let paramsHold: VisemeId | null = null;

function highlightViseme(id: VisemeId): void {
  const glyph = document.querySelector("#viseme-glyph");
  if (glyph) glyph.textContent = visemeLabel(id);
  for (const [key, button] of chipButtons) {
    button.classList.toggle("is-on", key === id);
  }
}

function renderCaption(text: string, index = -1, current = ""): void {
  if (!text) {
    caption.textContent = "";
    return;
  }
  if (index < 0) {
    caption.textContent = text;
    return;
  }
  caption.replaceChildren();
  const before = text.slice(0, index);
  const after = text.slice(index + current.length);
  if (before) caption.append(before);
  if (current) caption.append(el("span", { className: "now" }, [current]));
  if (after) caption.append(after);
}

async function speakNow(): Promise<void> {
  speech.holdViseme(null);
  paramsHold = null;
  const text = textarea.value.trim();
  if (!text) {
    setStatus("先写一句再开口。", "error");
    return;
  }
  await speech.speak(text, mode.value as VoiceMode);
}

const query = new URLSearchParams(location.search);
if (query.get("mute") === "1") speech.muted = true;
const exprParam = query.get("expr");
if (exprParam && (EXPRESSIONS as readonly string[]).includes(exprParam)) {
  setExpression(exprParam as Expression);
} else {
  setExpression("neutral");
}
const holdParam = query.get("hold");
if (holdParam && (VISEME_IDS as readonly string[]).includes(holdParam)) {
  holdViseme(holdParam as VisemeId);
}

let lastViseme: VisemeId = "rest";
function watchViseme(): void {
  const id = rig.visemeId;
  if (id !== lastViseme) {
    lastViseme = id;
    highlightViseme(id);
  }
  requestAnimationFrame(watchViseme);
}

const api = {
  ready: false,
  speak: (text: string) => speech.speak(text, mode.value as VoiceMode),
  setExpression,
  holdViseme,
  getState: () => ({
    viseme: rig.visemeId,
    expression: rig.getExpression(),
    speaking: speech.speaking,
    duration: timelineDuration(speech.timeline),
    events: speech.timeline.length,
  }),
};
(window as Window & { __MOXI?: typeof api }).__MOXI = api;

void rig
  .load()
  .then(() => {
    api.ready = true;
    setStatus("墨汐已入座。写一句，或点口型试张嘴。");
    watchViseme();
    const autoText = query.get("say");
    if (autoText) {
      textarea.value = autoText;
      void speakNow();
    }
  })
  .catch((error: unknown) => {
    setStatus(error instanceof Error ? error.message : "立绘加载失败", "error");
  });
