import "./styles.css";
import { MODEL_PRESETS } from "./presets";
import { MoxiArtPreview } from "./moxiPreview";
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

const viewport = el("section", { className: "viewport", id: "viewport" });
let canvas = el("canvas", { id: "live2d-canvas" });
const overlay = el("div", { className: "overlay-meta" }, [
  el("span", {}, ["原创角色 · 墨汐"]),
  el("span", {}, ["Haru 仅对照"]),
]);
viewport.append(canvas, overlay);

const status = el("p", { className: "status", id: "status" }, [
  "目标角色：墨汐。默认加载本地 moc3 Live2D。",
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
motionSelect.append(el("option", { value: "", textContent: "（立绘预览无动作组）" }));
expressionSelect.append(el("option", { value: "", textContent: "（立绘预览无表情）" }));
motionSelect.disabled = true;
expressionSelect.disabled = true;

const hint = el("p", { className: "hint" }, [MODEL_PRESETS[0].note]);

const loadBtn = el("button", { className: "primary", type: "button" }, ["加载"]);
const motionBtn = el("button", { className: "ghost", type: "button", disabled: true }, [
  "播放动作",
]);
const expressionBtn = el("button", { className: "ghost", type: "button", disabled: true }, [
  "切换表情",
]);
const idleBtn = el("button", { className: "accent", type: "button", disabled: true }, [
  "随机 idle",
]);

root.append(
  el("div", { className: "stage" }, [
    el("header", { className: "topbar" }, [
      el("div", { className: "brand" }, [
        el("h1", {}, ["墨汐"]),
        el("p", {}, [
          "咱们自己的 Live2D 角色。已开呼吸晃动与表情切换；精致五官表情还要继续在 Cubism 分层绑定。",
        ]),
      ]),
      el("nav", { className: "links" }, [
        el("a", { href: "/docs/07-our-character-moxi.md", target: "_blank" }, ["墨汐进度"]),
        el("a", { href: "/docs/02-creation-pipeline.md", target: "_blank" }, ["制作流程"]),
        el("a", { href: "/docs/04-web-selfhost.md", target: "_blank" }, ["Web 自托管"]),
        el("a", { href: "/docs/05-license-and-compliance.md", target: "_blank" }, ["授权"]),
      ]),
    ]),
    el("div", { className: "workspace" }, [
      el("aside", { className: "panel" }, [
        el("h2", {}, ["角色台"]),
        el("div", { className: "field" }, [
          el("label", { htmlFor: "preset-select" }, ["预设"]),
          presetSelect,
        ]),
        el("div", { className: "field" }, [
          el("label", { htmlFor: "model-url" }, ["资源路径"]),
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
          "绑定指南：",
          el("code", {}, ["characters/moxi/cubism/BINDING_CHECKLIST.md"]),
          "。验收：",
          el("code", {}, ["npm run check-model -- public/models/moxi"]),
        ]),
      ]),
      viewport,
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

function setLive2dControlsEnabled(enabled: boolean): void {
  motionBtn.disabled = !enabled;
  expressionBtn.disabled = !enabled;
  idleBtn.disabled = !enabled;
  if (!enabled) {
    fillSelect(motionSelect, [], "（立绘预览无动作组）");
    fillSelect(expressionSelect, [], "（立绘预览无表情）");
  }
}

type Mode = "art" | "live2d";

let mode: Mode = "art";
let artPreview: MoxiArtPreview | null = null;
let liveViewer: Live2DViewer | null = null;

/** 2D and WebGL cannot share one canvas; replace it on mode switches. */
function replaceCanvas(): HTMLCanvasElement {
  const next = el("canvas", { id: "live2d-canvas" });
  canvas.replaceWith(next);
  canvas = next;
  return canvas;
}

function teardown(): void {
  if (artPreview) {
    artPreview.destroy();
    artPreview = null;
  }
  if (liveViewer) {
    liveViewer.destroy();
    liveViewer = null;
  }
}

function currentPresetKind(): (typeof MODEL_PRESETS)[number]["kind"] {
  const preset = MODEL_PRESETS.find((item) => item.id === presetSelect.value);
  return preset?.kind ?? "ours-live2d";
}

presetSelect.addEventListener("change", () => {
  const preset = MODEL_PRESETS.find((item) => item.id === presetSelect.value);
  if (!preset) return;
  urlInput.value = preset.url;
  hint.textContent = preset.note;
});

loadBtn.addEventListener("click", () => {
  void (async () => {
    loadBtn.disabled = true;
    try {
      const kind = currentPresetKind();
      teardown();
      const view = replaceCanvas();

      if (kind === "ours-preview") {
        mode = "art";
        artPreview = new MoxiArtPreview(view, { setStatus });
        await artPreview.show(urlInput.value.trim());
        setLive2dControlsEnabled(false);
        return;
      }

      mode = "live2d";
      liveViewer = new Live2DViewer({ canvas: view, onStatus: setStatus });
      const result = await liveViewer.load(urlInput.value.trim());
      fillSelect(motionSelect, result.motions, "（无动作组）");
      fillSelect(expressionSelect, result.expressions, "（无表情）");
      setLive2dControlsEnabled(true);
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      setStatus(`加载失败\n${message}`, "error");
      setLive2dControlsEnabled(false);
    } finally {
      loadBtn.disabled = false;
    }
  })();
});

motionBtn.addEventListener("click", () => {
  if (mode !== "live2d" || !liveViewer || !motionSelect.value) return;
  liveViewer.playMotion(motionSelect.value);
});

expressionBtn.addEventListener("click", () => {
  if (mode !== "live2d" || !liveViewer || !expressionSelect.value) return;
  liveViewer.playExpression(expressionSelect.value);
});

idleBtn.addEventListener("click", () => {
  if (mode !== "live2d" || !liveViewer) return;
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
  liveViewer.playMotion(pick);
});

loadBtn.click();
