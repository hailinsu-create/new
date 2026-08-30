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
    id: "moxi-preview",
    label: "墨汐（咱们的角色 · 立绘预览）",
    url: "/characters/moxi/master.png",
    note: "原创角色主视觉。Cubism 绑定完成后，改用「墨汐（本地 moc3）」加载真正的 Live2D。",
    kind: "ours-preview",
  },
  {
    id: "moxi-local",
    label: "墨汐（本地 moc3）",
    url: "/models/moxi/moxi.model3.json",
    note: "把 Cubism 导出包放到 public/models/moxi/ 后使用。现在若 404，说明还没完成绑定导出。",
    kind: "ours-live2d",
  },
  {
    id: "haru-remote",
    label: "Haru（官方样例 · 仅对照）",
    url: "https://cdn.jsdelivr.net/gh/guansss/pixi-live2d-display/test/assets/haru/haru_greeter_t03.model3.json",
    note: "Live2D 官方版权样例，只用来确认播放器没坏。不是咱们的角色。",
    kind: "reference",
  },
] as const satisfies readonly ModelPreset[];
