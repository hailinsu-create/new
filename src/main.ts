import "./styles.css";
import { MODEL_PRESETS } from "./presets";
import { Live2DViewer } from "./viewer";

function el<K extends keyof HTMLElementTagNameMap>(
  tag: K,
  props?: Partial<HTMLElementTagNameMap[K]> & { className?: string },
  children: Array<Node | string> = [],
): HTMLElementTagNameMap[K] {
  const node = document.createElement(tag);
  if (props) {
    const { className, ...rest } = props;
    if (className) node.className = className;
    Object.assign(node, rest);
  }
  for (const child of children) {
    node.append(typeof child === "string" ? document.createTextNode(child) : child);
  }
  return node;
}

const root = document.querySelector("#app");
if (!root) throw new Error("#app missing");

const canvas = el("canvas", { id: "live2d-canvas" });
const status = el("p", { className: "status", id: "status" }, [
  "准备就绪。先拉一次 Cubism Core，再加载样例或本地模型。",
]);
const motionSelect = el("select", { id: "motion-select" });
const expressionSelect = el("select", { id: "expression-select" });
const urlInput = el("input", {
  id: "model-url",
  type: "text",
  value: MODEL_PRESETS[0].url,
  spellcheck: false,
});
const presetSelect = el("select", { id: "preset-select" });

for (const preset of MODEL_PRESETS) {
  presetSelect.append(
    el("option", { value: preset.id, textContent: preset.label }),
  );
}
motionSelect.append(el("option", { value: "", textContent: "（暂无）" }));
expressionSelect.append(el("option", { value: "", textContent: "（暂无）" }));

const hint = el("p", { className: "hint" }, [
  MODEL_PRESETS[0].note,
]);

const loadBtn = el("button", { className: "primary", type: "button" }, ["加载模型"]);
const motionBtn = el("button", { className: "ghost", type: "button" }, ["播放动作"]);
const expressionBtn = el("button", { className: "ghost", type: "button" }, ["切换表情"]);
const idleBtn = el("button", { className: "accent", type: "button" }, ["随机 idle"]);

root.append(
  el("div", { className: "stage" }, [
    el("header", { className: "topbar" }, [
      el("div", { className: "brand" }, [
        el("h1", {}, ["自建 Live2D"]),
        el("p", {}, [
          "从立绘拆分到 moc3 导出，再到浏览器自托管。这个研究台用来验证你自己的角色能不能在本机跑起来。",
        ]),
      ]),
      el("nav", { className: "links" }, [
        el("a", { href: "/docs/01-overview.md", target: "_blank" }, ["总览"]),
        el("a", { href: "/docs/02-creation-pipeline.md", target: "_blank" }, ["制作流程"]),
        el("a", { href: "/docs/04-web-selfhost.md", target: "_blank" }, ["Web 自托管"]),
        el("a", { href: "https://github.com/Live2D/CubismWebSamples", target: "_blank", rel: "noreferrer" }, [
          "官方 Samples",
        ]),
      ]),
    ]),
    el("div", { className: "workspace" }, [
      el("aside", { className: "panel" }, [
        el("h2", {}, ["研究控制台"]),
        el("div", { className: "field" }, [
          el("label", { htmlFor: "preset-select" }, ["预设"]),
          presetSelect,
        ]),
        el("div", { className: "field" }, [
          el("label", { htmlFor: "model-url" }, ["model3.json 路径"]),
          urlInput,
        ]),
        el("div", { className: "actions" }, [loadBtn]),
        hint,
        el("div", { className: "field" }, [
          el("label", { htmlFor: "motion-select" }, ["动作组"]),
          motionSelect,
        ]),
        el("div", { className: "field" }, [
          el("label", { htmlFor: "expression-select" }, ["表情"]),
          expressionSelect,
        ]),
        el("div", { className: "actions" }, [motionBtn, expressionBtn, idleBtn]),
        status,
        el("p", { className: "hint" }, [
          "本地模型：把 Cubism Editor 导出包放进 ",
          el("code", {}, ["public/models/local/"]),
          "，然后用 ",
          el("code", {}, ["npm run check-model -- public/models/local"]),
          " 检查文件清单。",
        ]),
      ]),
      el("section", { className: "viewport", id: "viewport" }, [
        canvas,
        el("div", { className: "overlay-meta" }, [
          el("span", {}, ["PixiJS + Cubism4 runtime"]),
          el("span", {}, ["研究用途 · 注意授权"]),
        ]),
      ]),
    ]),
  ]),
);

function setStatus(message: string, kind: "info" | "ok" | "error"): void {
  status.textContent = message;
  status.className = `status${kind === "info" ? "" : ` ${kind}`}`;
}

function fillSelect(select: HTMLSelectElement, values: string[], emptyLabel: string): void {
  select.replaceChildren();
  if (values.length === 0) {
    select.append(el("option", { value: "", textContent: emptyLabel }));
    select.disabled = true;
    return;
  }
  select.disabled = false;
  for (const value of values) {
    select.append(el("option", { value, textContent: value }));
  }
}

let viewer: Live2DViewer | null = null;

try {
  viewer = new Live2DViewer({ canvas, onStatus: setStatus });
} catch (error) {
  const message = error instanceof Error ? error.message : String(error);
  setStatus(message, "error");
  loadBtn.disabled = true;
}

presetSelect.addEventListener("change", () => {
  const preset = MODEL_PRESETS.find((item) => item.id === presetSelect.value);
  if (!preset) return;
  urlInput.value = preset.url;
  hint.textContent = preset.note;
});

loadBtn.addEventListener("click", () => {
  void (async () => {
    if (!viewer) return;
    loadBtn.disabled = true;
    try {
      const result = await viewer.load(urlInput.value.trim());
      fillSelect(motionSelect, result.motions, "（无动作组）");
      fillSelect(expressionSelect, result.expressions, "（无表情）");
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      setStatus(`加载失败\n${message}`, "error");
    } finally {
      loadBtn.disabled = false;
    }
  })();
});

motionBtn.addEventListener("click", () => {
  if (!viewer || !motionSelect.value) return;
  viewer.playMotion(motionSelect.value);
});

expressionBtn.addEventListener("click", () => {
  if (!viewer || !expressionSelect.value) return;
  viewer.playExpression(expressionSelect.value);
});

idleBtn.addEventListener("click", () => {
  if (!viewer) return;
  const options = [...motionSelect.options]
    .map((option) => option.value)
    .filter(Boolean);
  const idleLike = options.filter((name) => /idle/i.test(name));
  const pool = idleLike.length > 0 ? idleLike : options;
  if (pool.length === 0) {
    setStatus("当前模型没有可播放的动作组。", "error");
    return;
  }
  const pick = pool[Math.floor(Math.random() * pool.length)]!;
  motionSelect.value = pick;
  viewer.playMotion(pick);
});
