import {
  VISEME_SHAPE,
  type VisemeId,
  type VisemeSample,
} from "./viseme";
import { BlinkController, HairSystem, type Lids } from "./motion";

export const EXPRESSIONS = [
  "neutral",
  "smile",
  "laugh",
  "surprise",
  "sad",
  "shy",
  "wink",
  "sleepy",
] as const;

export type Expression = (typeof EXPRESSIONS)[number];

export const EXPRESSION_LABELS: Record<Expression, string> = {
  neutral: "平静",
  smile: "浅笑",
  laugh: "开怀",
  surprise: "讶异",
  sad: "低眉",
  shy: "含羞",
  wink: "眨眼",
  sleepy: "困倦",
};

const W = 1536;
const H = 1024;
const SLICES = 96;
const MOUTH_TILT = -0.175;
const SKIN = (alpha: number) => `rgba(238, 205, 186, ${alpha})`;
/** Sampled from the plate just above the mouth; used to hide the painted lips. */
const FACE_SKIN = (alpha: number) => `rgba(247, 223, 207, ${alpha})`;

const FACE = {
  eyeLeft: { x: 657, y: 307 },
  eyeRight: { x: 802, y: 289 },
  mouth: { x: 753, y: 404 },
  browLeft: { innerX: 688, innerY: 271, outerX: 628, outerY: 276 },
  browRight: { innerX: 764, innerY: 256, outerX: 838, outerY: 250 },
} as const;

const ASSETS = {
  plate: "./characters/moxi/base-plate.png",
  eyeLeft: "./characters/moxi/portrait-rig/eye_left.png",
  eyeRight: "./characters/moxi/portrait-rig/eye_right.png",
  hairLock: "./characters/moxi/portrait-rig/hair_lock.png",
  tassel: "./characters/moxi/portrait-rig/tassel.png",
  bangs: "./characters/moxi/portrait-rig/bangs.png",
} as const;

type FacePose = {
  leftOpen: number;
  rightOpen: number;
  eyeWidth: number;
  lowerLid: number;
  browInner: number;
  browRaise: number;
  blush: number;
  lookBiasX: number;
  lookBiasY: number;
  sparkle: number;
  tear: number;
  headTilt: number;
  mouthCurve: number;
};

const POSE_KEYS = [
  "leftOpen",
  "rightOpen",
  "eyeWidth",
  "lowerLid",
  "browInner",
  "browRaise",
  "blush",
  "lookBiasX",
  "lookBiasY",
  "sparkle",
  "tear",
  "headTilt",
  "mouthCurve",
] as const satisfies readonly (keyof FacePose)[];

const NEUTRAL: FacePose = {
  leftOpen: 1,
  rightOpen: 1,
  eyeWidth: 1,
  lowerLid: 0,
  browInner: 0,
  browRaise: 0,
  blush: 0.08,
  lookBiasX: 0,
  lookBiasY: 0,
  sparkle: 0.3,
  tear: 0,
  headTilt: 0,
  mouthCurve: 0.28,
};

const POSES: Record<Expression, FacePose> = {
  neutral: NEUTRAL,
  smile: {
    ...NEUTRAL,
    leftOpen: 0.78,
    rightOpen: 0.78,
    lowerLid: 0.82,
    mouthCurve: 0.9,
    blush: 0.4,
    sparkle: 0.5,
    headTilt: 0.016,
  },
  laugh: {
    ...NEUTRAL,
    leftOpen: 0,
    rightOpen: 0,
    browRaise: 0.34,
    mouthCurve: 1,
    blush: 0.55,
    sparkle: 0,
    headTilt: 0.03,
  },
  surprise: {
    ...NEUTRAL,
    leftOpen: 1.08,
    rightOpen: 1.08,
    eyeWidth: 1.05,
    browRaise: 0.92,
    mouthCurve: 0.04,
    blush: 0,
    sparkle: 0.9,
    headTilt: -0.012,
  },
  sad: {
    ...NEUTRAL,
    leftOpen: 0.82,
    rightOpen: 0.8,
    lowerLid: 0.22,
    browInner: 1,
    browRaise: 0.28,
    mouthCurve: -0.86,
    blush: 0.12,
    lookBiasY: 0.24,
    sparkle: 0.08,
    tear: 1,
    headTilt: -0.03,
  },
  shy: {
    ...NEUTRAL,
    leftOpen: 0.8,
    rightOpen: 0.82,
    lowerLid: 0.48,
    mouthCurve: 0.55,
    blush: 1,
    lookBiasX: 0.34,
    lookBiasY: 0.3,
    sparkle: 0.22,
    headTilt: 0.05,
  },
  wink: {
    ...NEUTRAL,
    leftOpen: 0,
    rightOpen: 1,
    lowerLid: 0.22,
    mouthCurve: 0.74,
    blush: 0.32,
    sparkle: 0.6,
    headTilt: 0.022,
  },
  sleepy: {
    ...NEUTRAL,
    leftOpen: 0.36,
    rightOpen: 0.34,
    lowerLid: 0.52,
    browRaise: -0.42,
    mouthCurve: 0.1,
    blush: 0.14,
    lookBiasY: 0.22,
    sparkle: 0.05,
    headTilt: 0.022,
  },
};

type Images = {
  plate: HTMLImageElement;
  eyeLeft: HTMLImageElement;
  eyeRight: HTMLImageElement;
  hairLock: HTMLImageElement;
  tassel: HTMLImageElement;
  bangs: HTMLImageElement;
};

function loadImage(src: string): Promise<HTMLImageElement> {
  return new Promise((resolve, reject) => {
    const image = new Image();
    image.onload = () => resolve(image);
    image.onerror = () => reject(new Error(`无法加载：${src}`));
    image.src = src;
  });
}

function clamp(value: number, min: number, max: number): number {
  return Math.max(min, Math.min(max, value));
}

function lerp(a: number, b: number, t: number): number {
  return a + (b - a) * t;
}

function emptyPose(): FacePose {
  return {
    leftOpen: 0,
    rightOpen: 0,
    eyeWidth: 0,
    lowerLid: 0,
    browInner: 0,
    browRaise: 0,
    blush: 0,
    lookBiasX: 0,
    lookBiasY: 0,
    sparkle: 0,
    tear: 0,
    headTilt: 0,
    mouthCurve: 0,
  };
}

function integrate(current: FacePose, velocity: FacePose, target: FacePose, dt: number): void {
  for (const key of POSE_KEYS) {
    const error = target[key] - current[key];
    velocity[key] += error * 0.2 * dt;
    velocity[key] *= Math.pow(0.62, dt);
    current[key] += velocity[key] * dt;
    if (Math.abs(error) < 0.001 && Math.abs(velocity[key]) < 0.002) {
      current[key] = target[key];
      velocity[key] = 0;
    }
  }
}

export type RigHooks = {
  sampleMouth: () => VisemeSample;
  wind: () => number;
};

export class AvatarRig {
  readonly canvas: HTMLCanvasElement;
  private readonly ctx: CanvasRenderingContext2D;
  private readonly portrait = document.createElement("canvas");
  private readonly portraitCtx: CanvasRenderingContext2D;
  private readonly features = document.createElement("canvas");
  private readonly featureCtx: CanvasRenderingContext2D;
  private assets: Images | null = null;
  private expression: Expression = "neutral";
  private pose: FacePose = { ...NEUTRAL };
  private poseVel: FacePose = emptyPose();
  private running = false;
  private frameId = 0;
  private startedAt = 0;
  private lastFrameAt = 0;
  private lookX = 0;
  private lookY = 0;
  private targetLookX = 0;
  private targetLookY = 0;
  private readonly blinkCtrl = new BlinkController();
  private readonly hairSys = new HairSystem();
  private lastLids: Lids = { left: 1, right: 1 };
  private bounce = 0;
  private saccadeX = 0;
  private saccadeY = 0;
  private nextSaccadeAt = 1.4;
  private hooks: RigHooks;
  visemeId: VisemeId = "rest";
  speaking = false;

  constructor(canvas: HTMLCanvasElement, hooks: RigHooks) {
    const ctx = canvas.getContext("2d");
    const portraitCtx = this.portrait.getContext("2d");
    const featureCtx = this.features.getContext("2d");
    if (!ctx || !portraitCtx || !featureCtx) throw new Error("浏览器不支持 Canvas 2D");
    this.canvas = canvas;
    this.ctx = ctx;
    this.portraitCtx = portraitCtx;
    this.featureCtx = featureCtx;
    this.hooks = hooks;
    this.portrait.width = W;
    this.portrait.height = H;
    this.features.width = W;
    this.features.height = H;
    this.ctx.imageSmoothingEnabled = true;
    this.ctx.imageSmoothingQuality = "high";
  }

  async load(): Promise<void> {
    const [plate, eyeLeft, eyeRight, hairLock, tassel, bangs] = await Promise.all([
      loadImage(ASSETS.plate),
      loadImage(ASSETS.eyeLeft),
      loadImage(ASSETS.eyeRight),
      loadImage(ASSETS.hairLock),
      loadImage(ASSETS.tassel),
      loadImage(ASSETS.bangs),
    ]);
    this.assets = { plate, eyeLeft, eyeRight, hairLock, tassel, bangs };
    this.resize();
    this.canvas.addEventListener("pointermove", this.onPointer);
    this.canvas.addEventListener("pointerleave", this.onPointerLeave);
    window.addEventListener("resize", this.onResize);
    this.running = true;
    this.startedAt = performance.now();
    this.lastFrameAt = this.startedAt;
    this.blinkCtrl.reset(Math.floor(this.startedAt) || 1);
    this.hairSys.reset(Math.floor(this.startedAt) + 17);
    this.frameId = requestAnimationFrame(this.tick);
  }

  destroy(): void {
    this.running = false;
    cancelAnimationFrame(this.frameId);
    this.canvas.removeEventListener("pointermove", this.onPointer);
    this.canvas.removeEventListener("pointerleave", this.onPointerLeave);
    window.removeEventListener("resize", this.onResize);
  }

  setExpression(name: Expression): void {
    if (name === this.expression) return;
    const next = POSES[name];
    for (const key of POSE_KEYS) {
      this.poseVel[key] += (next[key] - this.pose[key]) * 0.22;
    }
    this.expression = name;
    this.hairSys.impulse(0.05);
    this.bounce = name === "laugh" ? 1 : name === "surprise" ? 0.62 : 0.28;
    if (this.running && name !== "wink" && name !== "sleepy" && name !== "laugh") {
      this.blinkCtrl.trigger((performance.now() - this.startedAt) / 1000, name);
    }
  }

  getExpression(): Expression {
    return this.expression;
  }

  impulse(strength = 0.08): void {
    this.hairSys.impulse(strength);
  }

  debugMotion(): {
    lids: Lids;
    nextBlinkAt: number;
    activeShots: number;
    hair: ReturnType<HairSystem["debug"]>;
  } {
    const blink = this.blinkCtrl.debug();
    return {
      lids: { ...this.lastLids },
      nextBlinkAt: blink.nextBlinkAt,
      activeShots: blink.activeShots,
      hair: this.hairSys.debug(),
    };
  }

  resize(): void {
    const parent = this.canvas.parentElement;
    if (!parent) return;
    const dpr = Math.min(window.devicePixelRatio || 1, 2);
    this.canvas.width = Math.max(1, Math.floor(parent.clientWidth * dpr));
    this.canvas.height = Math.max(1, Math.floor(parent.clientHeight * dpr));
    this.canvas.style.width = `${parent.clientWidth}px`;
    this.canvas.style.height = `${parent.clientHeight}px`;
    this.ctx.imageSmoothingEnabled = true;
    this.ctx.imageSmoothingQuality = "high";
  }

  private readonly onResize = () => this.resize();

  private readonly onPointer = (event: PointerEvent) => {
    const bounds = this.canvas.getBoundingClientRect();
    if (bounds.width === 0 || bounds.height === 0) return;
    const nextX = clamp(((event.clientX - bounds.left) / bounds.width - 0.5) * 2, -1, 1);
    const delta = nextX - this.targetLookX;
    this.hairSys.impulse(delta * 0.055);
    this.targetLookX = nextX;
    this.targetLookY = clamp(((event.clientY - bounds.top) / bounds.height - 0.5) * 2, -1, 1);
  };

  private readonly onPointerLeave = () => {
    this.targetLookX = 0;
    this.targetLookY = 0;
  };

  private readonly tick = (now: number) => {
    if (!this.running || !this.assets) return;
    const seconds = (now - this.startedAt) / 1000;
    const dt = Math.min(2, Math.max(0.25, (now - this.lastFrameAt) / 16.67));
    this.lastFrameAt = now;

    const target = { ...POSES[this.expression] };
    if (this.expression === "neutral") {
      target.mouthCurve = 0.28 + Math.sin(seconds * 1.55) * 0.04;
      target.lowerLid = 0.08 + Math.sin(seconds * 0.85) * 0.05;
      target.browRaise = Math.sin(seconds * 1.05) * 0.06;
    } else if (this.expression === "smile") {
      target.lowerLid = 0.82 + Math.sin(seconds * 1.3) * 0.05;
      target.mouthCurve = 0.9 + Math.sin(seconds * 2.1) * 0.03;
    } else if (this.expression === "sleepy") {
      const droop = 0.5 + 0.5 * Math.sin(seconds * 0.52);
      target.leftOpen = 0.3 + droop * 0.1;
      target.rightOpen = 0.28 + droop * 0.1;
    }
    integrate(this.pose, this.poseVel, target, dt);
    if (this.expression === "wink") {
      this.pose.leftOpen += (0 - this.pose.leftOpen) * (1 - Math.pow(0.48, dt));
    }
    this.bounce *= Math.pow(0.9, dt);

    if (seconds > this.nextSaccadeAt && this.expression !== "shy") {
      this.saccadeX = (Math.random() - 0.5) * 0.32;
      this.saccadeY = (Math.random() - 0.5) * 0.14;
      this.nextSaccadeAt = seconds + 2.1 + Math.random() * 2.8;
      this.blinkCtrl.notifySaccade(seconds, this.expression);
    }
    this.saccadeX *= Math.pow(0.92, dt);
    this.saccadeY *= Math.pow(0.92, dt);

    this.lookX += (clamp(this.targetLookX + this.pose.lookBiasX + this.saccadeX, -1, 1) - this.lookX) * 0.075;
    this.lookY += (clamp(this.targetLookY + this.pose.lookBiasY + this.saccadeY, -1, 1) - this.lookY) * 0.075;

    const mouth = this.hooks.sampleMouth();
    this.visemeId = mouth.id;
    this.speaking = mouth.speaking;

    const dtSec = Math.min(0.05, Math.max(1 / 240, dt * 0.01667));
    this.hairSys.step(dtSec, seconds, {
      lookX: this.lookX,
      wind: this.hooks.wind(),
      speaking: mouth.speaking,
      energy: mouth.energy,
    });
    const lids = this.blinkCtrl.sample(seconds, this.expression, mouth.speaking);
    this.lastLids = lids;
    this.compose(this.lastLids, seconds, mouth);
    this.drawStage(seconds);
    this.frameId = requestAnimationFrame(this.tick);
  };

  private compose(lids: Lids, seconds: number, mouth: VisemeSample): void {
    if (!this.assets) return;
    const context = this.portraitCtx;
    context.clearRect(0, 0, W, H);
    context.drawImage(this.assets.plate, 0, 0);
    this.drawHairAndTassel();
    this.drawMouth(mouth);

    this.featureCtx.clearRect(0, 0, W, H);
    this.drawEyes(lids, seconds);
    this.drawBrows();
    this.featureCtx.save();
    this.featureCtx.globalCompositeOperation = "destination-out";
    this.featureCtx.filter = "blur(0.8px)";
    this.featureCtx.drawImage(this.assets.bangs, 0, 0);
    this.featureCtx.restore();
    context.drawImage(this.features, 0, 0);
    this.drawBangs();
    this.drawCheeks(seconds);
    this.drawTears(seconds);
  }

  private drawHairAndTassel(): void {
    if (!this.assets) return;
    const context = this.portraitCtx;
    context.save();
    context.beginPath();
    context.rect(0, 0, W, H);
    context.ellipse(748, 334, 176, 208, -0.08, 0, Math.PI * 2);
    context.clip("evenodd");
    const hairAngle = this.hairSys.hair.angle;
    const hairSag = this.hairSys.hair.sag;
    context.translate(526, 292);
    context.rotate(hairAngle);
    context.translate(-526, -292);
    context.translate(hairAngle * 34 + hairSag * 18, Math.abs(hairAngle) * 8 + Math.abs(hairSag) * 6);
    context.drawImage(this.assets.hairLock, 0, 0);
    context.restore();

    context.save();
    const tasselAngle = this.hairSys.tassel.angle;
    context.translate(819, 658);
    context.rotate(tasselAngle);
    context.translate(-819, -658);
    context.translate(tasselAngle * 38, Math.abs(tasselAngle) * 8);
    context.drawImage(this.assets.tassel, 0, 0);
    context.restore();
  }

  private drawBangs(): void {
    if (!this.assets) return;
    const context = this.portraitCtx;
    context.save();
    const bangsAngle = this.hairSys.bangs.angle;
    context.translate(724, 176);
    context.rotate(bangsAngle);
    context.translate(-724, -176);
    context.globalAlpha = 0.92;
    context.drawImage(this.assets.bangs, 0, 0);
    context.restore();
  }

  private drawMouth(sample: VisemeSample): void {
    const speaking = sample.speaking;
    const laugh = this.expression === "laugh" && !speaking;
    const surprise = this.expression === "surprise" && !speaking;
    const cover = speaking || laugh || surprise || Math.abs(this.pose.mouthCurve - 0.28) > 0.22;
    if (!cover) return;

    const context = this.portraitCtx;
    const shape = speaking
      ? sample.shape
      : laugh
        ? { ...VISEME_SHAPE.A, open: 0.88, width: 1.22, curve: 1, teeth: 0.4 }
        : surprise
          ? { ...VISEME_SHAPE.O, open: 0.78, width: 0.62, curve: 0.04 }
          : {
              ...VISEME_SHAPE.rest,
              open: 0,
              width: 1 + Math.max(0, this.pose.mouthCurve) * 0.12,
              curve: this.pose.mouthCurve,
              closed: this.pose.mouthCurve < 0 ? 0.2 : 0,
            };

    context.save();
    context.translate(FACE.mouth.x + this.lookX * 1.8, FACE.mouth.y + this.lookY * 1.1);
    context.rotate(MOUTH_TILT);
    this.paintMouthCover(context, shape);

    if (shape.closed > 0.65 || shape.open < 0.12) {
      this.strokeClosedMouth(context, shape.curve, shape.width, shape.closed);
    } else {
      this.fillOpenMouth(context, shape);
    }
    context.restore();
  }

  /** Hide the painted mouth (and its perioral shade) with plate-matched skin. */
  private paintMouthCover(context: CanvasRenderingContext2D, shape: VisemeSample["shape"]): void {
    const coverRx = Math.max(56, 32 * shape.width + shape.open * 10);
    const coverRy = Math.max(28, 18 + shape.open * 16);
    context.save();
    context.translate(0, 1.6);
    context.scale(coverRx, coverRy);
    const fill = context.createRadialGradient(0, 0, 0, 0, 0, 1);
    fill.addColorStop(0, FACE_SKIN(1));
    fill.addColorStop(0.76, FACE_SKIN(1));
    fill.addColorStop(0.9, FACE_SKIN(0.55));
    fill.addColorStop(1, FACE_SKIN(0));
    context.fillStyle = fill;
    context.beginPath();
    context.arc(0, 0, 1, 0, Math.PI * 2);
    context.fill();
    context.restore();
  }

  private strokeClosedMouth(
    context: CanvasRenderingContext2D,
    curve: number,
    width: number,
    pressed: number,
  ): void {
    const half = 22 * width;
    const dip = 9.5 * curve;
    context.strokeStyle = pressed > 0.7 ? "#4a2c32" : "#5a353c";
    context.lineWidth = 1.45 + pressed * 0.6;
    context.lineCap = "round";
    context.beginPath();
    context.moveTo(-half, -dip * 0.1);
    context.quadraticCurveTo(-half * 0.08, dip, half, -dip * 0.22);
    context.stroke();
    if (curve > 0.5) {
      context.globalAlpha *= 0.38;
      context.lineWidth = 0.95;
      context.beginPath();
      context.moveTo(-half + 1, 0.8);
      context.quadraticCurveTo(-half - 2.5, 3.4, -half - 0.5, 6.2);
      context.moveTo(half - 1, 0.4);
      context.quadraticCurveTo(half + 2.5, 2.8, half + 0.6, 5.6);
      context.stroke();
    }
  }

  private fillOpenMouth(
    context: CanvasRenderingContext2D,
    shape: VisemeSample["shape"],
  ): void {
    context.save();
    context.translate(0, 2);
    const round = shape.round;
    if (round > 0.55) {
      const rx = 6.2 * shape.width + shape.open * 3.4;
      const ry = 5.2 + shape.open * 8.4;
      context.beginPath();
      context.ellipse(0, 1.6, rx, ry, 0, 0, Math.PI * 2);
      context.fillStyle = "#7a454c";
      context.fill();
      context.fillStyle = "#3a181e";
      context.beginPath();
      context.ellipse(0, 2.6, rx * 0.68, ry * 0.58, 0, 0, Math.PI * 2);
      context.fill();
      if (shape.teeth > 0.08) {
        context.fillStyle = "rgba(247, 236, 230, 0.92)";
        context.beginPath();
        context.ellipse(0, -ry * 0.28, rx * 0.62, 2.1, 0, 0, Math.PI * 2);
        context.fill();
      }
      context.strokeStyle = "rgba(92, 51, 56, 0.72)";
      context.lineWidth = 1.15;
      context.beginPath();
      context.ellipse(0, 1.6, rx, ry, 0, 0, Math.PI * 2);
      context.stroke();
    } else {
      const half = 17 * shape.width + shape.open * 3;
      const depth = 7 + shape.open * 10;
      const curve = shape.curve;
      context.beginPath();
      context.moveTo(-half, 0);
      context.quadraticCurveTo(0, -3.5 - curve * 1.5, half, 0);
      context.quadraticCurveTo(half * 0.35, depth, 0, depth + 1);
      context.quadraticCurveTo(-half * 0.35, depth, -half, 0);
      context.closePath();
      context.fillStyle = "#6e3a43";
      context.fill();
      context.fillStyle = "#2a1218";
      context.beginPath();
      context.ellipse(0, depth * 0.42, half * 0.55, depth * 0.38, 0, 0, Math.PI * 2);
      context.fill();
      if (shape.teeth > 0.15) {
        context.fillStyle = `rgba(247, 236, 230, ${0.7 + shape.teeth * 0.25})`;
        context.beginPath();
        context.moveTo(-half * 0.72, 0.4);
        context.quadraticCurveTo(0, -1.2, half * 0.72, 0.4);
        context.lineTo(half * 0.62, 3.4);
        context.quadraticCurveTo(0, 2.2, -half * 0.62, 3.4);
        context.closePath();
        context.fill();
      }
      if (shape.tongue > 0.4) {
        context.fillStyle = "rgba(196, 112, 122, 0.88)";
        context.beginPath();
        context.ellipse(0, depth * 0.58, half * 0.34, depth * 0.22, 0, 0, Math.PI * 2);
        context.fill();
      }
      context.strokeStyle = "rgba(92, 51, 56, 0.78)";
      context.lineWidth = 1.35;
      context.beginPath();
      context.moveTo(-half, 0);
      context.quadraticCurveTo(0, -3.5 - curve * 1.5, half, 0);
      context.quadraticCurveTo(half * 0.35, depth, 0, depth + 1);
      context.quadraticCurveTo(-half * 0.35, depth, -half, 0);
      context.stroke();
      context.fillStyle = "rgba(236, 204, 196, 0.42)";
      context.beginPath();
      context.ellipse(0, depth * 0.78, half * 0.42, 1.8, 0, 0, Math.PI * 2);
      context.fill();
    }
    context.restore();
  }

  private drawEyes(lids: Lids, seconds: number): void {
    if (!this.assets) return;
    const leftOpen = Math.max(0, this.pose.leftOpen * (this.expression === "wink" ? 1 : lids.left));
    const rightOpen = Math.max(0, this.pose.rightOpen * lids.right);
    if (leftOpen >= 0.12) this.drawEye(this.assets.eyeLeft, FACE.eyeLeft, leftOpen, -1);
    if (rightOpen >= 0.12) this.drawEye(this.assets.eyeRight, FACE.eyeRight, rightOpen, 1);
    this.drawLowerLid(
      FACE.eyeLeft,
      this.pose.lowerLid * Math.min(1, leftOpen * 1.15) + (1 - leftOpen) * 0.2,
      -1,
    );
    this.drawLowerLid(
      FACE.eyeRight,
      this.pose.lowerLid * Math.min(1, rightOpen * 1.15) + (1 - rightOpen) * 0.2,
      1,
    );
    this.drawSparkle(FACE.eyeLeft, leftOpen, -1, seconds);
    this.drawSparkle(FACE.eyeRight, rightOpen, 1, seconds);
    if (leftOpen < 0.2) this.drawClosedEye(FACE.eyeLeft, leftOpen < 0.12 ? 1 : 1 - leftOpen / 0.2, -1);
    if (rightOpen < 0.2) this.drawClosedEye(FACE.eyeRight, rightOpen < 0.12 ? 1 : 1 - rightOpen / 0.2, 1);
  }

  private drawEye(
    image: HTMLImageElement,
    center: { x: number; y: number },
    open: number,
    side: -1 | 1,
  ): void {
    const context = this.featureCtx;
    const cx = center.x + this.lookX * 2.6 + side * Math.abs(this.lookX) * 1.15;
    const cy = center.y + this.lookY * 1.55;
    const width = 39 * this.pose.eyeWidth;
    const height = 18.5;
    const openClamped = clamp(open, 0, 1.16);
    const upper = lerp(-height, height * 0.12, 1 - openClamped);
    const lower = lerp(height, -height * 0.04, 1 - openClamped) - this.pose.lowerLid * 7.5;
    if (lower - upper < 3.4) return;
    context.save();
    context.translate(cx, cy);
    context.rotate(MOUTH_TILT * 0.22);
    context.beginPath();
    context.moveTo(-width, (upper + lower) * 0.12);
    context.bezierCurveTo(-width * 0.46, upper, width * 0.46, upper, width, (upper + lower) * 0.08);
    context.bezierCurveTo(width * 0.42, lower, -width * 0.42, lower, -width, (upper + lower) * 0.12);
    context.closePath();
    context.clip();
    context.rotate(-MOUTH_TILT * 0.22);
    context.scale(1 + side * this.lookX * 0.035, 1);
    context.translate(-cx, -cy);
    context.drawImage(image, 0, 0);
    context.restore();
    if (openClamped < 0.94) {
      const lidAlpha = (1 - openClamped) * 0.82;
      context.save();
      context.translate(cx, cy);
      context.rotate(MOUTH_TILT * 0.22);
      context.lineCap = "round";
      context.strokeStyle = `rgba(38, 30, 34, ${lidAlpha})`;
      context.lineWidth = 1.45 + (1 - openClamped) * 1.2;
      context.beginPath();
      context.moveTo(-width * 0.9, (upper + lower) * 0.1);
      context.quadraticCurveTo(0, upper + 0.6, width * 0.9, (upper + lower) * 0.06);
      context.stroke();
      context.restore();
    }
  }

  private drawLowerLid(center: { x: number; y: number }, amount: number, side: -1 | 1): void {
    if (amount < 0.04) return;
    const context = this.featureCtx;
    context.save();
    context.translate(center.x + this.lookX * 2.6, center.y + this.lookY * 1.55);
    context.scale(1 + side * this.lookX * 0.035, 1);
    context.lineCap = "round";
    context.strokeStyle = SKIN(0.42 * amount);
    context.lineWidth = 6.2;
    context.beginPath();
    context.moveTo(-24, 7);
    context.quadraticCurveTo(0, 11 + amount * 3.2, 24, 6.5);
    context.stroke();
    context.strokeStyle = `rgba(48, 36, 40, ${0.28 * amount})`;
    context.lineWidth = 0.95;
    context.beginPath();
    context.moveTo(-22, 8);
    context.quadraticCurveTo(0, 12 + amount * 2.4, 22, 7.2);
    context.stroke();
    context.restore();
  }

  private drawSparkle(
    center: { x: number; y: number },
    open: number,
    side: -1 | 1,
    seconds: number,
  ): void {
    const amount = this.pose.sparkle * Math.max(0, open - 0.35);
    if (amount < 0.05) return;
    const context = this.featureCtx;
    const pulse = 0.85 + 0.15 * Math.sin(seconds * 3.2 + side);
    context.save();
    context.translate(center.x + this.lookX * 4.2 + side * 3, center.y + this.lookY * 2.4 - 3);
    context.beginPath();
    context.ellipse(0, 0, 14, 12, 0, 0, Math.PI * 2);
    context.clip();
    context.globalAlpha = amount * pulse;
    context.fillStyle = "rgba(255, 252, 248, 0.8)";
    context.beginPath();
    context.ellipse(-2, -3, 2.4, 3.1, -0.2, 0, Math.PI * 2);
    context.fill();
    context.beginPath();
    context.ellipse(5, 4, 1.2, 1.4, 0.3, 0, Math.PI * 2);
    context.fill();
    context.restore();
  }

  private drawClosedEye(center: { x: number; y: number }, alpha: number, side: -1 | 1): void {
    const context = this.featureCtx;
    const happy = Math.max(0, this.pose.mouthCurve);
    const sad = Math.max(0, -this.pose.mouthCurve);
    context.save();
    context.globalAlpha = alpha;
    context.translate(center.x + this.lookX * 2.1, center.y + this.lookY * 1.05);
    context.rotate(MOUTH_TILT * 0.2);
    context.lineCap = "round";
    const half = 27;
    const outerLift = happy * 6.2 - sad * 4.6;
    const leftY = 1.2 - (side === -1 ? outerLift * 0.4 : outerLift * 0.08);
    const rightY = 0.6 - (side === 1 ? outerLift * 0.32 : outerLift * 0.08);
    const midY = 3.4 - happy * 5.4 + sad * 5.8;
    context.beginPath();
    context.moveTo(-half, leftY);
    context.quadraticCurveTo(0, midY + 5.5, half, rightY);
    context.quadraticCurveTo(0, midY - 4.2, -half, leftY);
    context.fillStyle = SKIN(0.97);
    context.fill();
    context.beginPath();
    context.moveTo(-half, leftY);
    context.quadraticCurveTo(0, midY, half, rightY);
    context.strokeStyle = "#2a2226";
    context.lineWidth = 2.2;
    context.stroke();
    context.restore();
  }

  private drawBrows(): void {
    const inner = this.pose.browInner;
    const raise = this.pose.browRaise;
    if (Math.abs(inner) < 0.22 && Math.abs(raise) < 0.2) return;
    const lift = -raise * 6.5;
    this.strokeBrow({
      outerX: FACE.browLeft.outerX + this.lookX * 1.3,
      outerY: FACE.browLeft.outerY + lift * 0.4 + this.lookY * 0.7,
      innerX: FACE.browLeft.innerX + this.lookX * 1.3,
      innerY: FACE.browLeft.innerY - inner * 7.5 + lift + this.lookY * 0.7,
    });
    this.strokeBrow({
      outerX: FACE.browRight.outerX + this.lookX * 1.3,
      outerY: FACE.browRight.outerY + lift * 0.4 + this.lookY * 0.7,
      innerX: FACE.browRight.innerX + this.lookX * 1.3,
      innerY: FACE.browRight.innerY - inner * 7.5 + lift + this.lookY * 0.7,
    });
  }

  private strokeBrow(points: { outerX: number; outerY: number; innerX: number; innerY: number }): void {
    const context = this.featureCtx;
    const midX = (points.outerX + points.innerX) / 2;
    const midY = (points.outerY + points.innerY) / 2 - 1.6;
    context.save();
    context.lineCap = "round";
    context.beginPath();
    context.moveTo(points.outerX, points.outerY);
    context.quadraticCurveTo(midX, midY, points.innerX, points.innerY);
    context.strokeStyle = SKIN(0.92);
    context.lineWidth = 5.4;
    context.stroke();
    context.strokeStyle = "rgba(42, 34, 38, 0.72)";
    context.lineWidth = 2.1;
    context.stroke();
    context.restore();
  }

  private drawCheeks(seconds: number): void {
    const amount = this.pose.blush;
    if (amount < 0.03) return;
    const context = this.portraitCtx;
    const pulse = 0.85 + 0.15 * Math.sin(seconds * 2.05);
    this.fillBlush(context, 631, 357, 38, amount * pulse * 0.72);
    this.fillBlush(context, 855, 343, 36, amount * pulse * 0.66);
  }

  private fillBlush(context: CanvasRenderingContext2D, x: number, y: number, radius: number, alpha: number): void {
    const gradient = context.createRadialGradient(x, y, 2, x, y, radius);
    gradient.addColorStop(0, `rgba(224, 119, 121, ${alpha})`);
    gradient.addColorStop(0.55, `rgba(224, 119, 121, ${alpha * 0.35})`);
    gradient.addColorStop(1, "rgba(224, 119, 121, 0)");
    context.fillStyle = gradient;
    context.fillRect(x - radius, y - radius, radius * 2, radius * 2);
  }

  private drawTears(seconds: number): void {
    const amount = this.pose.tear;
    if (amount < 0.05) return;
    const context = this.portraitCtx;
    const drip = (Math.sin(seconds * 2.4) + 1) * 0.5;
    context.save();
    context.globalAlpha = amount * (0.55 + 0.45 * drip);
    this.paintTear(context, 688, 326 + drip * 9);
    this.paintTear(context, 770, 310 + drip * 8);
    context.restore();
  }

  private paintTear(context: CanvasRenderingContext2D, x: number, y: number): void {
    const gloss = context.createLinearGradient(x - 3, y - 4, x + 4, y + 10);
    gloss.addColorStop(0, "rgba(210, 232, 240, 0.85)");
    gloss.addColorStop(0.45, "rgba(140, 188, 210, 0.7)");
    gloss.addColorStop(1, "rgba(140, 188, 210, 0)");
    context.fillStyle = gloss;
    context.beginPath();
    context.moveTo(x, y - 5);
    context.quadraticCurveTo(x + 4, y + 2, x, y + 11);
    context.quadraticCurveTo(x - 4, y + 2, x, y - 5);
    context.fill();
  }

  private drawStage(seconds: number): void {
    const context = this.ctx;
    const canvasWidth = this.canvas.width;
    const canvasHeight = this.canvas.height;
    context.clearRect(0, 0, canvasWidth, canvasHeight);
    const breathing = Math.sin(seconds * 1.45);
    const idleSway = Math.sin(seconds * 0.6);
    const laughBounce = Math.sin(seconds * 13.5) * this.bounce * 2.6;
    const talkBob = this.speaking ? Math.sin(seconds * 8.2) * 1.6 : 0;
    const scale = Math.min(canvasWidth / W, canvasHeight / H) * 1.08;
    const drawWidth = W * scale;
    const drawHeight = H * scale;
    const originX = (canvasWidth - drawWidth) / 2 - canvasWidth * 0.02;
    const originY =
      (canvasHeight - drawHeight) / 2 +
      canvasHeight * 0.06 +
      (breathing * 2.5 + laughBounce + talkBob) * scale;
    const sliceHeight = H / SLICES;

    context.save();
    context.translate(canvasWidth / 2, canvasHeight / 2);
    context.rotate(this.lookX * 0.004 + idleSway * 0.002 + this.pose.headTilt * 0.35);
    context.translate(-canvasWidth / 2, -canvasHeight / 2);

    for (let index = 0; index < SLICES; index += 1) {
      const sourceY = index * sliceHeight;
      const normalizedY = sourceY / H;
      const headInfluence = Math.exp(-(((normalizedY - 0.28) / 0.34) ** 2));
      const chestInfluence = Math.exp(-(((normalizedY - 0.63) / 0.28) ** 2));
      const xShift = (this.lookX * 6.5 * headInfluence + idleSway * 1.1) * scale;
      const yShift =
        (this.lookY * 4.2 * headInfluence - breathing * 2.2 * chestInfluence + laughBounce * 0.45 * headInfluence) *
        scale;
      const horizontalScale = 1 - Math.abs(this.lookX) * 0.005 * headInfluence;
      const sliceWidth = drawWidth * horizontalScale;
      const sliceX = originX + xShift + (drawWidth - sliceWidth) / 2;
      const sliceY = originY + sourceY * scale + yShift;
      context.drawImage(this.portrait, 0, sourceY, W, sliceHeight + 1, sliceX, sliceY, sliceWidth, sliceHeight * scale + 1.25);
    }
    context.restore();
  }
}
