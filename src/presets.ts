export type ModelPreset = {
  id: string;
  label: string;
  url: string;
  note: string;
  kind: "ours-live2d" | "ours-rig" | "reference";
};

/**
 * 墨汐是本仓库原创角色。Haru 仅作播放器对照，不是自建目标。
 * 默认走 Cubism moc3，给旁窗 APK 同一份包。
 */
export const MODEL_PRESETS = [
  {
    id: "moxi-local",
    label: "墨汐（Cubism moc3）",
    url: "/models/moxi/moxi.model3.json",
    note: "默认角色包。口型 ParamMouthOpenY，表情 idle / talk / smile / surprise。character.json 给 APK 读缩放和心情表。",
    kind: "ours-live2d",
  },
  {
    id: "moxi-rig",
    label: "墨汐（肖像网格 · 对照）",
    url: "/characters/moxi/portrait-rig/base.png",
    note: "画布覆盖网格，仅对照。产品默认不要用这一路。",
    kind: "ours-rig",
  },
  {
    id: "haru-remote",
    label: "Haru（官方样例 · 仅对照）",
    url: "https://cdn.jsdelivr.net/gh/guansss/pixi-live2d-display/test/assets/haru/haru_greeter_t03.model3.json",
    note: "Live2D 官方版权样例，用来对照「真 Live2D 该长什么样」。",
    kind: "reference",
  },
] as const satisfies readonly ModelPreset[];
