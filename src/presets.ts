export type ModelPreset = {
  id: string;
  label: string;
  url: string;
  note: string;
  kind: "ours-live2d" | "ours-rig" | "reference";
};

/**
 * 墨汐是本仓库原创角色。Haru 仅作播放器对照，不是自建目标。
 */
export const MODEL_PRESETS = [
  {
    id: "moxi-rig",
    label: "墨汐（肖像网格 · 重制版）",
    url: "/characters/moxi/portrait-rig/base.png",
    note: "眼窝和碎点清过。眼睛用眼皮裁切，刘海仍压在睫毛前。表情带过冲，不再整只眼睛压扁。",
    kind: "ours-rig",
  },
  {
    id: "moxi-local",
    label: "墨汐（Cubism moc3）",
    url: "/models/moxi/moxi.model3.json",
    note: "Cubism 导出包。FREE 版关键形不完整，脸部细表情仍弱，作对照。",
    kind: "ours-live2d",
  },
  {
    id: "haru-remote",
    label: "Haru（官方样例 · 仅对照）",
    url: "https://cdn.jsdelivr.net/gh/guansss/pixi-live2d-display/test/assets/haru/haru_greeter_t03.model3.json",
    note: "Live2D 官方版权样例，用来对照「真 Live2D 该长什么样」。",
    kind: "reference",
  },
] as const satisfies readonly ModelPreset[];
