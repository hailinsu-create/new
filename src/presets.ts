export type ModelPreset = {
  id: string;
  label: string;
  url: string;
  note: string;
};

/**
 * Remote samples are for loading/runtime research only.
 * Self-built characters should be placed under /models and loaded as local paths.
 */
export const MODEL_PRESETS = [
  {
    id: "haru-remote",
    label: "Haru（远程样例 · Cubism4）",
    url: "https://cdn.jsdelivr.net/gh/guansss/pixi-live2d-display/test/assets/haru/haru_greeter_t03.model3.json",
    note: "官方风格样例，用来验证播放器链路。自建角色请换成本地 /models/.../xxx.model3.json。",
  },
  {
    id: "local-placeholder",
    label: "本地自建角色（占位路径）",
    url: "/models/local/character.model3.json",
    note: "把导出的 moc3 包放到 public/models/local/，并把入口文件名对齐，或在下方自定义路径。",
  },
] as const satisfies readonly ModelPreset[];
