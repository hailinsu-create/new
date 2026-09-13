export type ViewMode = "bust" | "full";

export const BUST_W = 1536;
export const BUST_H = 1024;
export const FULL_W = 1536;
export const FULL_H = 2304;

export type FaceMarks = {
  eyeLeft: { x: number; y: number };
  eyeRight: { x: number; y: number };
  mouth: { x: number; y: number };
  browLeft: { innerX: number; innerY: number; outerX: number; outerY: number };
  browRight: { innerX: number; innerY: number; outerX: number; outerY: number };
  cheekLeft: { x: number; y: number };
  cheekRight: { x: number; y: number };
  tearLeft: { x: number; y: number };
  tearRight: { x: number; y: number };
};

export type Pivot = { x: number; y: number };

export type Layout = {
  id: ViewMode;
  w: number;
  h: number;
  mouthTilt: number;
  /** Procedural eye / brow / blush size vs the bust plate (1 = bust pixels). */
  faceScale: number;
  /** Viseme + mouth-cover size vs the bust plate. Full-body lips are smaller than the head. */
  mouthScale: number;
  face: FaceMarks;
  hair: Pivot;
  bangs: Pivot;
  tassel: Pivot;
  clip: { x: number; y: number; rx: number; ry: number; rot: number };
  skirt?: Pivot;
  hem?: Pivot;
  shawlL?: Pivot;
  shawlR?: Pivot;
  crane?: Pivot;
  hip?: Pivot;
  plant?: Pivot;
  slices: number;
};

export const FACE_BUST: FaceMarks = {
  eyeLeft: { x: 657, y: 307 },
  eyeRight: { x: 802, y: 289 },
  mouth: { x: 753, y: 404 },
  browLeft: { innerX: 688, innerY: 271, outerX: 628, outerY: 276 },
  browRight: { innerX: 764, innerY: 256, outerX: 838, outerY: 250 },
  cheekLeft: { x: 631, y: 357 },
  cheekRight: { x: 855, y: 343 },
  tearLeft: { x: 688, y: 326 },
  tearRight: { x: 770, y: 310 },
};

/** Landmarks in 1536×2304 plate pixels, measured on the painted features. */
export const FACE_FULL: FaceMarks = {
  eyeLeft: { x: 686, y: 292 },
  eyeRight: { x: 792, y: 270 },
  mouth: { x: 756, y: 354 },
  browLeft: { innerX: 702, innerY: 258, outerX: 655, outerY: 265 },
  browRight: { innerX: 768, innerY: 248, outerX: 820, outerY: 246 },
  cheekLeft: { x: 665, y: 325 },
  cheekRight: { x: 828, y: 308 },
  tearLeft: { x: 705, y: 305 },
  tearRight: { x: 775, y: 285 },
};

export const BUST_LAYOUT: Layout = {
  id: "bust",
  w: BUST_W,
  h: BUST_H,
  mouthTilt: -0.175,
  faceScale: 1,
  mouthScale: 1,
  face: FACE_BUST,
  hair: { x: 526, y: 292 },
  bangs: { x: 724, y: 176 },
  tassel: { x: 819, y: 658 },
  clip: { x: 748, y: 334, rx: 176, ry: 208, rot: -0.08 },
  slices: 96,
};

export const FULL_LAYOUT: Layout = {
  id: "full",
  w: FULL_W,
  h: FULL_H,
  mouthTilt: 0.1,
  faceScale: 0.8,
  mouthScale: 0.55,
  face: FACE_FULL,
  hair: { x: 560, y: 300 },
  bangs: { x: 750, y: 155 },
  tassel: { x: 760, y: 880 },
  clip: { x: 750, y: 310, rx: 155, ry: 185, rot: -0.04 },
  skirt: { x: 770, y: 820 },
  hem: { x: 770, y: 1580 },
  shawlL: { x: 500, y: 720 },
  shawlR: { x: 1080, y: 700 },
  crane: { x: 850, y: 545 },
  hip: { x: 770, y: 820 },
  plant: { x: 800, y: 2240 },
  slices: 168,
};

export const BUST_ASSETS = {
  plate: "./characters/moxi/base-plate.png",
  eyeLeft: "./characters/moxi/portrait-rig/eye_left.png",
  eyeRight: "./characters/moxi/portrait-rig/eye_right.png",
  hairLock: "./characters/moxi/portrait-rig/hair_lock.png",
  tassel: "./characters/moxi/portrait-rig/tassel.png",
  bangs: "./characters/moxi/portrait-rig/bangs.png",
} as const;

export const FULL_ASSETS = {
  plate: "./characters/moxi/fullbody-rig/plate.png",
  eyeLeft: "./characters/moxi/fullbody-rig/eye_left.png",
  eyeRight: "./characters/moxi/fullbody-rig/eye_right.png",
  hairLock: "./characters/moxi/fullbody-rig/hair_lock.png",
  tassel: "./characters/moxi/fullbody-rig/tassel.png",
  bangs: "./characters/moxi/fullbody-rig/bangs.png",
  skirt: "./characters/moxi/fullbody-rig/skirt.png",
  hem: "./characters/moxi/fullbody-rig/hem.png",
  shawlLeft: "./characters/moxi/fullbody-rig/shawl_left.png",
  shawlRight: "./characters/moxi/fullbody-rig/shawl_right.png",
  crane: "./characters/moxi/fullbody-rig/crane.png",
  legs: "./characters/moxi/fullbody-rig/legs.png",
} as const;

export function layoutOf(view: ViewMode): Layout {
  return view === "full" ? FULL_LAYOUT : BUST_LAYOUT;
}
