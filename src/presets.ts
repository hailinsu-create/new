export type ModelPreset = {
  id: string;
  label: string;
  url: string;
  note: string;
  kind: "ours-preview" | "ours-live2d" | "reference";
};

/**
 * 墨汐是本仓库原创角色。Haru 仅作播放器对照，不是自建目标。
 */
export const MODEL_PRESETS = [
  {
    id: "moxi-local",
    label: "墨汐（咱们的 Live2D · moc3）",
    url: "/models/moxi/moxi.model3.json",
    note: "原创角色墨汐的 Cubism 导出包。当前为单网格 MVP，可继续在 Editor 里加参数与动作。",
    kind: "ours-live2d",
  },
  {
    id: "moxi-preview",
    label: "墨汐（立绘预览）",
    url: "/characters/moxi/master.png",
    note: "未进 Live2D 前的静帧预览对照。",
    kind: "ours-preview",
  },
  {
    id: "haru-remote",
    label: "Haru（官方样例 · 仅对照）",
    url: "https://cdn.jsdelivr.net/gh/guansss/pixi-live2d-display/test/assets/haru/haru_greeter_t03.model3.json",
    note: "Live2D 官方版权样例，只用来确认播放器没坏。不是咱们的角色。",
    kind: "reference",
  },
] as const satisfies readonly ModelPreset[];
