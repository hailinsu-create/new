import {
  VISEME_SHAPE,
  type VisemeId,
  type VisemeSample,
} from "./viseme";
import {
  AfterglowController,
  BlinkController,
  BodySystem,
  BreathSystem,
  GazeController,
  HairSystem,
  IdleDirector,
  MOTION,
  emptyLids,
  type BodyState,
  type BreathState,
  type Lids,
} from "./motion";
import {
  BUST_ASSETS,
  BUST_H,
  BUST_W,
  FULL_ASSETS,
  FULL_LAYOUT,
  layoutOf,
  type Layout,
  type ViewMode,
} from "./layout";

export type { ViewMode };

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

const W = BUST_W;
const H = BUST_H;
const SLICES = 96;
const SKIN = (alpha: number) => `rgba(238, 205, 186, ${alpha})`;
/** Sampled from the plate just above the mouth; used to hide the painted lips. */
const FACE_SKIN = (alpha: number) => `rgba(247, 223, 207, ${alpha})`;

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
  skirt?: HTMLImageElement;
  hem?: HTMLImageElement;
  shawlLeft?: HTMLImageElement;
  shawlRight?: HTMLImageElement;
  crane?: HTMLImageElement;
  legs?: HTMLImageElement;
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
  const k = MOTION.face.transK;
  const damp = MOTION.face.transDamp;
  for (const key of POSE_KEYS) {
    const error = target[key] - current[key];
    velocity[key] += error * k * dt;
    velocity[key] *= Math.pow(damp, dt);
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
  private bustAssets: Images | null = null;
  private fullAssets: Images | null = null;
  private view: ViewMode = "full";
  private layout: Layout = FULL_LAYOUT;
  private readonly bodySys = new BodySystem();
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
  private readonly gaze = new GazeController();
  private readonly breathSys = new BreathSystem();
  private readonly idle = new IdleDirector();
  private readonly afterglow = new AfterglowController();
  private lastLids: Lids = emptyLids();
  private bounce = 0;
  private saccadeX = 0;
  private saccadeY = 0;
  private nextSaccadeAt = 1.4;
  private freezeUntil = 0;
  private lastVisemeId: VisemeId = "rest";
  private wasSpeaking = false;
  private shyPeekT = 0;
  private hooks: RigHooks;
  visemeId: VisemeId = "rest";
  speaking = false;

  constructor(canvas: HTMLCanvasElement, hooks: RigHooks, view: ViewMode = "full") {
    const ctx = canvas.getContext("2d");
    const portraitCtx = this.portrait.getContext("2d");
    const featureCtx = this.features.getContext("2d");
    if (!ctx || !portraitCtx || !featureCtx) throw new Error("浏览器不支持 Canvas 2D");
    this.canvas = canvas;
    this.ctx = ctx;
    this.portraitCtx = portraitCtx;
    this.featureCtx = featureCtx;
    this.hooks = hooks;
    this.view = view === "bust" ? "bust" : "full";
    this.layout = layoutOf(this.view);
    this.applyCanvasSize();
    this.ctx.imageSmoothingEnabled = true;
    this.ctx.imageSmoothingQuality = "high";
  }

  private applyCanvasSize(): void {
    this.portrait.width = this.layout.w;
    this.portrait.height = this.layout.h;
    this.features.width = this.layout.w;
    this.features.height = this.layout.h;
    this.portraitCtx.imageSmoothingEnabled = true;
    this.portraitCtx.imageSmoothingQuality = "high";
    this.featureCtx.imageSmoothingEnabled = true;
    this.featureCtx.imageSmoothingQuality = "high";
  }

  async load(): Promise<void> {
    const [bust, full] = await Promise.all([
      Promise.all([
        loadImage(BUST_ASSETS.plate),
        loadImage(BUST_ASSETS.eyeLeft),
        loadImage(BUST_ASSETS.eyeRight),
        loadImage(BUST_ASSETS.hairLock),
        loadImage(BUST_ASSETS.tassel),
        loadImage(BUST_ASSETS.bangs),
      ]),
      Promise.all([
        loadImage(FULL_ASSETS.plate),
        loadImage(FULL_ASSETS.eyeLeft),
        loadImage(FULL_ASSETS.eyeRight),
        loadImage(FULL_ASSETS.hairLock),
        loadImage(FULL_ASSETS.tassel),
        loadImage(FULL_ASSETS.bangs),
        loadImage(FULL_ASSETS.skirt),
        loadImage(FULL_ASSETS.hem),
        loadImage(FULL_ASSETS.shawlLeft),
        loadImage(FULL_ASSETS.shawlRight),
        loadImage(FULL_ASSETS.crane),
        loadImage(FULL_ASSETS.legs),
      ]),
    ]);
    this.bustAssets = {
      plate: bust[0],
      eyeLeft: bust[1],
      eyeRight: bust[2],
      hairLock: bust[3],
      tassel: bust[4],
      bangs: bust[5],
    };
    this.fullAssets = {
      plate: full[0],
      eyeLeft: full[1],
      eyeRight: full[2],
      hairLock: full[3],
      tassel: full[4],
      bangs: full[5],
      skirt: full[6],
      hem: full[7],
      shawlLeft: full[8],
      shawlRight: full[9],
      crane: full[10],
      legs: full[11],
    };
    this.bindAssets();
    this.resize();
    this.canvas.addEventListener("pointermove", this.onPointer);
    this.canvas.addEventListener("pointerleave", this.onPointerLeave);
    window.addEventListener("resize", this.onResize);
    this.running = true;
    this.startedAt = performance.now();
    this.lastFrameAt = this.startedAt;
    this.blinkCtrl.reset(Math.floor(this.startedAt) || 1);
    this.hairSys.reset(Math.floor(this.startedAt) + 17);
    this.gaze.reset(Math.floor(this.startedAt) + 23);
    this.breathSys.reset();
    this.bodySys.reset();
    this.idle.reset(Math.floor(this.startedAt) + 29);
    this.afterglow.reset();
    this.frameId = requestAnimationFrame(this.tick);
  }

  setView(view: ViewMode): void {
    const next = view === "bust" ? "bust" : "full";
    if (next === this.view) return;
    this.view = next;
    this.layout = layoutOf(this.view);
    this.applyCanvasSize();
    this.bindAssets();
    this.hairSys.impulse(0.04);
    this.bodySys.impulse(0.03);
    this.resize();
  }

  getView(): ViewMode {
    return this.view;
  }

  private bindAssets(): void {
    const pack = this.view === "full" ? this.fullAssets : this.bustAssets;
    if (pack) this.assets = pack;
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
    this.hairSys.impulse(MOTION.face.exprImpulse);
    this.bounce = name === "laugh" ? 1 : name === "surprise" ? 0.62 : 0.28;
    if (name === "surprise" && MOTION.face.surpriseFreeze > 0 && this.running) {
      this.freezeUntil = (performance.now() - this.startedAt) / 1000 + MOTION.face.surpriseFreeze;
    }
    if (name === "shy") this.shyPeekT = 0;
    if (this.running && name !== "wink" && name !== "sleepy" && name !== "laugh") {
      this.blinkCtrl.trigger((performance.now() - this.startedAt) / 1000, name);
    }
  }

  getExpression(): Expression {
    return this.expression;
  }

  impulse(strength = 0.08): void {
    this.hairSys.impulse(strength);
    this.bodySys.impulse(strength * 0.7);
  }

  notifySpeechEnd(): void {
    this.afterglow.trigger();
  }

  debugMotion(): {
    lids: Lids;
    nextBlinkAt: number;
    activeShots: number;
    hair: ReturnType<HairSystem["debug"]>;
    body: ReturnType<BodySystem["debug"]>;
    view: ViewMode;
  } {
    const blink = this.blinkCtrl.debug();
    return {
      lids: { ...this.lastLids },
      nextBlinkAt: blink.nextBlinkAt,
      activeShots: blink.activeShots,
      hair: this.hairSys.debug(),
      body: this.bodySys.debug(),
      view: this.view,
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
    this.gaze.setPointer(this.targetLookX, this.targetLookY);
  };

  private readonly onPointerLeave = () => {
    this.targetLookX = 0;
    this.targetLookY = 0;
    this.gaze.setPointer(0, 0);
  };

  private readonly tick = (now: number) => {
    if (!this.running || !this.assets) return;
    const seconds = (now - this.startedAt) / 1000;
    const dt = Math.min(2, Math.max(0.25, (now - this.lastFrameAt) / 16.67));
    this.lastFrameAt = now;

    const mouth = this.hooks.sampleMouth();
    this.visemeId = mouth.id;
    this.speaking = mouth.speaking;
    if (mouth.id !== this.lastVisemeId) {
      this.blinkCtrl.notifyViseme(seconds, mouth.id, this.expression, mouth.speaking);
      this.lastVisemeId = mouth.id;
    }
    if (this.wasSpeaking && !mouth.speaking) this.afterglow.trigger();
    this.wasSpeaking = mouth.speaking;

    const idleState = this.idle.step(seconds, mouth.speaking, this.expression);
    const glow = this.afterglow.step(Math.min(0.05, Math.max(1 / 240, dt * 0.01667)));

    const target = { ...POSES[this.expression] };
    if (this.expression === "neutral") {
      target.mouthCurve = 0.28 + Math.sin(seconds * 1.55) * 0.04 + idleState.mouthCurveAdd + glow.mouth;
      target.lowerLid = 0.08 + Math.sin(seconds * 0.85) * 0.05 + idleState.lowerLidAdd;
      target.browRaise = Math.sin(seconds * 1.05) * 0.06 + idleState.browAdd;
    } else if (this.expression === "smile") {
      target.lowerLid = 0.82 + Math.sin(seconds * 1.3) * 0.05;
      target.mouthCurve = 0.9 + Math.sin(seconds * 2.1) * 0.03;
      const asym = MOTION.face.smileAsym;
      target.leftOpen = 0.78 - asym * 0.12;
      target.rightOpen = 0.78 + asym * 0.08;
    } else if (this.expression === "sleepy") {
      const droop = 0.5 + 0.5 * Math.sin(seconds * 0.52);
      target.leftOpen = 0.3 + droop * 0.1;
      target.rightOpen = 0.28 + droop * 0.1;
    } else if (this.expression === "shy" && MOTION.face.shyPeek > 0) {
      this.shyPeekT += dt * 0.01667;
      const peek = 0.5 + 0.5 * Math.sin(this.shyPeekT * 0.7);
      target.lookBiasX = lerp(0.34, 0.06, peek * MOTION.face.shyPeek);
      target.lookBiasY = lerp(0.3, 0.08, peek * MOTION.face.shyPeek);
    }
    if (mouth.speaking && MOTION.viseme.mouthCurveTalk > 0) {
      target.mouthCurve += mouth.shape.curve * MOTION.viseme.mouthCurveTalk * 0.25;
    }
    if (seconds >= this.freezeUntil) {
      integrate(this.pose, this.poseVel, target, dt);
    }
    if (this.expression === "wink") {
      this.pose.leftOpen += (0 - this.pose.leftOpen) * (1 - Math.pow(0.48, dt));
    }
    this.bounce *= Math.pow(0.9, dt);

    const dtSec = Math.min(0.05, Math.max(1 / 240, dt * 0.01667));
    const lookBiasX = this.pose.lookBiasX + idleState.lookBiasX;
    const lookBiasY = this.pose.lookBiasY + idleState.lookBiasY + glow.lookY;
    if (MOTION.gaze.autoSaccade > 0) {
      const g = this.gaze.step(dtSec, seconds, {
        speaking: mouth.speaking,
        energy: mouth.energy,
        expression: this.expression,
        lookBiasX,
        lookBiasY,
      });
      if (this.gaze.didSaccade()) this.blinkCtrl.notifySaccade(seconds, this.expression);
      this.lookX = g.x;
      this.lookY = g.y;
    } else {
      if (seconds > this.nextSaccadeAt && this.expression !== "shy") {
        this.saccadeX = (Math.random() - 0.5) * MOTION.gaze.saccadeAmpX;
        this.saccadeY = (Math.random() - 0.5) * MOTION.gaze.saccadeAmpY;
        this.nextSaccadeAt = seconds + MOTION.gaze.saccadeMin + Math.random() * (MOTION.gaze.saccadeMax - MOTION.gaze.saccadeMin);
        this.blinkCtrl.notifySaccade(seconds, this.expression);
      }
      this.saccadeX *= Math.pow(0.92, dt);
      this.saccadeY *= Math.pow(0.92, dt);
      this.gaze.setPointer(this.targetLookX, this.targetLookY);
      const g = this.gaze.step(dtSec, seconds, {
        speaking: mouth.speaking,
        energy: mouth.energy,
        expression: this.expression,
        lookBiasX: lookBiasX + this.saccadeX,
        lookBiasY: lookBiasY + this.saccadeY,
      });
      this.lookX = g.x;
      this.lookY = g.y;
    }

    const breath = this.breathSys.step(dtSec, seconds, mouth.speaking, mouth.energy, idleState.breathBoost);
    this.hairSys.setBreath(breath.chest);
    this.hairSys.step(dtSec, seconds, {
      lookX: this.lookX,
      wind: this.hooks.wind(),
      speaking: mouth.speaking,
      energy: mouth.energy,
    });
    const body = this.bodySys.step(dtSec, seconds, {
      lookX: this.lookX,
      wind: this.hooks.wind(),
      speaking: mouth.speaking,
      energy: mouth.energy,
      breath: breath.chest,
      field: this.hairSys.wind.last,
    });
    const lids = this.blinkCtrl.sample(seconds, this.expression, mouth.speaking, mouth.energy);
    this.lastLids = lids;
    this.pose.browRaise -= lids.browDip * 0.35;
    this.pose.lowerLid = clamp(this.pose.lowerLid + lids.cheek * 0.25, 0, 1.2);
    this.compose(this.lastLids, seconds, mouth, breath, body);
    this.drawStage(seconds, breath, body);
    this.frameId = requestAnimationFrame(this.tick);
  };

  private compose(
    lids: Lids,
    seconds: number,
    mouth: VisemeSample,
    _breath?: BreathState,
    _body?: BodyState,
  ): void {
    if (!this.assets) return;
    const context = this.portraitCtx;
    const { w, h } = this.layout;
    context.clearRect(0, 0, w, h);
    context.drawImage(this.assets.plate, 0, 0);
    this.drawHairAndTassel();
    this.drawMouth(mouth);

    this.featureCtx.clearRect(0, 0, w, h);
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
    const { w, h, clip, hair, tassel } = this.layout;
    context.save();
    context.beginPath();
    context.rect(0, 0, w, h);
    context.ellipse(clip.x, clip.y, clip.rx, clip.ry, clip.rot, 0, Math.PI * 2);
    context.clip("evenodd");
    const hairAngle = this.hairSys.hair.angle;
    const hairSag = this.hairSys.hair.sag + this.hairSys.nape.angle * 0.35;
    context.translate(hair.x, hair.y);
    context.rotate(hairAngle);
    context.translate(-hair.x, -hair.y);
    context.translate(hairAngle * 34 + hairSag * 18, Math.abs(hairAngle) * 8 + Math.abs(hairSag) * 6);
    context.drawImage(this.assets.hairLock, 0, 0);
    context.restore();

    context.save();
    const tasselAngle = this.hairSys.tassel.angle;
    context.translate(tassel.x, tassel.y);
    context.rotate(tasselAngle);
    context.translate(-tassel.x, -tassel.y);
    context.translate(tasselAngle * 38, Math.abs(tasselAngle) * 8);
    context.drawImage(this.assets.tassel, 0, 0);
    context.restore();
  }

  private drawBangs(): void {
    if (!this.assets) return;
    const context = this.portraitCtx;
    const bangs = this.layout.bangs;
    context.save();
    const bangsAngle = this.hairSys.bangs.angle;
    context.translate(bangs.x, bangs.y);
    context.rotate(bangsAngle);
    context.translate(-bangs.x, -bangs.y);
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
    context.translate(this.layout.face.mouth.x + this.lookX * 1.8, this.layout.face.mouth.y + this.lookY * 1.1);
    context.rotate(this.layout.mouthTilt);
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
    if (leftOpen >= 0.12) this.drawEye(this.assets.eyeLeft, this.layout.face.eyeLeft, leftOpen, -1);
    if (rightOpen >= 0.12) this.drawEye(this.assets.eyeRight, this.layout.face.eyeRight, rightOpen, 1);
    this.drawLowerLid(
      this.layout.face.eyeLeft,
      this.pose.lowerLid * Math.min(1, leftOpen * 1.15) + (1 - leftOpen) * 0.2,
      -1,
    );
    this.drawLowerLid(
      this.layout.face.eyeRight,
      this.pose.lowerLid * Math.min(1, rightOpen * 1.15) + (1 - rightOpen) * 0.2,
      1,
    );
    this.drawSparkle(this.layout.face.eyeLeft, leftOpen, -1, seconds);
    this.drawSparkle(this.layout.face.eyeRight, rightOpen, 1, seconds);
    this.drawLashes(this.layout.face.eyeLeft, leftOpen, lids.lash, -1);
    this.drawLashes(this.layout.face.eyeRight, rightOpen, lids.lash, 1);
    if (leftOpen < 0.2) this.drawClosedEye(this.layout.face.eyeLeft, leftOpen < 0.12 ? 1 : 1 - leftOpen / 0.2, -1);
    if (rightOpen < 0.2) this.drawClosedEye(this.layout.face.eyeRight, rightOpen < 0.12 ? 1 : 1 - rightOpen / 0.2, 1);
  }

  private drawLashes(center: { x: number; y: number }, open: number, amount: number, side: -1 | 1): void {
    const closed = (1 - clamp(open, 0, 1)) * amount;
    if (closed < 0.04) return;
    const context = this.featureCtx;
    context.save();
    context.translate(center.x + this.lookX * 2.4, center.y + this.lookY * 1.4);
    context.rotate(this.layout.mouthTilt * 0.2);
    context.strokeStyle = `rgba(32, 24, 28, ${0.35 + closed * 0.4})`;
    context.lineWidth = 0.7;
    context.lineCap = "round";
    const n = 5;
    for (let i = 0; i < n; i += 1) {
      const u = (i / (n - 1) - 0.5) * 2;
      const x = u * 22;
      const y = -2 - (1 - open) * 2;
      const tipX = x + side * 1.2 + u * 2;
      const tipY = y - 3.4 - closed * 2.8 - Math.abs(u) * 0.8;
      context.beginPath();
      context.moveTo(x, y);
      context.quadraticCurveTo(x + side * 0.8, y - 1.6, tipX, tipY);
      context.stroke();
    }
    context.restore();
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
    context.rotate(this.layout.mouthTilt * 0.22);
    context.beginPath();
    context.moveTo(-width, (upper + lower) * 0.12);
    context.bezierCurveTo(-width * 0.46, upper, width * 0.46, upper, width, (upper + lower) * 0.08);
    context.bezierCurveTo(width * 0.42, lower, -width * 0.42, lower, -width, (upper + lower) * 0.12);
    context.closePath();
    context.clip();
    context.rotate(-this.layout.mouthTilt * 0.22);
    context.scale(1 + side * this.lookX * 0.035, 1);
    context.translate(-cx, -cy);
    context.drawImage(image, 0, 0);
    context.restore();
    if (openClamped < 0.94) {
      const lidAlpha = (1 - openClamped) * 0.82;
      context.save();
      context.translate(cx, cy);
      context.rotate(this.layout.mouthTilt * 0.22);
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
    const pulse = 0.85 + 0.15 * Math.sin(seconds * MOTION.pupil.pulseHz * 8 + side);
    const follow = 1 + MOTION.pupil.catchlightFollow;
    context.save();
    context.translate(
      center.x + this.lookX * 4.2 * follow + side * (3 + MOTION.gaze.vergence * 8),
      center.y + this.lookY * 2.4 * follow - 3,
    );
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
    context.rotate(this.layout.mouthTilt * 0.2);
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
      outerX: this.layout.face.browLeft.outerX + this.lookX * 1.3,
      outerY: this.layout.face.browLeft.outerY + lift * 0.4 + this.lookY * 0.7,
      innerX: this.layout.face.browLeft.innerX + this.lookX * 1.3,
      innerY: this.layout.face.browLeft.innerY - inner * 7.5 + lift + this.lookY * 0.7,
    });
    this.strokeBrow({
      outerX: this.layout.face.browRight.outerX + this.lookX * 1.3,
      outerY: this.layout.face.browRight.outerY + lift * 0.4 + this.lookY * 0.7,
      innerX: this.layout.face.browRight.innerX + this.lookX * 1.3,
      innerY: this.layout.face.browRight.innerY - inner * 7.5 + lift + this.lookY * 0.7,
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
    const breathWave = Math.sin(this.breathSys.phase);
    const pulse = 0.85 + 0.15 * Math.sin(seconds * 2.05) + breathWave * MOTION.breath.blushCoupling * 0.08;
    const squeeze = this.lastLids.cheek * 4;
    this.fillBlush(context, this.layout.face.cheekLeft.x, this.layout.face.cheekLeft.y + squeeze * 0.3, 38 + squeeze, amount * pulse * 0.72);
    this.fillBlush(context, this.layout.face.cheekRight.x, this.layout.face.cheekRight.y + squeeze * 0.3, 36 + squeeze, amount * pulse * 0.66);
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
    const phys = MOTION.face.tearPhysics;
    const drip = phys > 0
      ? Math.max(0, (seconds * 0.35 * phys) % 1.8) / 1.8
      : (Math.sin(seconds * 2.4) + 1) * 0.5;
    context.save();
    context.globalAlpha = amount * (0.55 + 0.45 * (phys > 0 ? Math.min(1, drip * 1.4) : drip));
    this.paintTear(context, this.layout.face.tearLeft.x, this.layout.face.tearLeft.y + drip * (phys > 0 ? 16 : 9));
    this.paintTear(context, this.layout.face.tearRight.x, this.layout.face.tearRight.y + drip * (phys > 0 ? 14 : 8));
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

  private drawStage(seconds: number, breath?: BreathState, body?: BodyState): void {
    if (this.view === "full") {
      this.drawStageFull(seconds, breath, body);
      return;
    }
    const context = this.ctx;
    const canvasWidth = this.canvas.width;
    const canvasHeight = this.canvas.height;
    context.clearRect(0, 0, canvasWidth, canvasHeight);
    const chest = breath ? breath.chest : Math.sin(seconds * 1.45) * MOTION.breath.chest;
    const shoulder = breath?.shoulder ?? 0;
    const crane = breath?.crane ?? 0;
    const shawl = breath?.shawl ?? 0;
    const idleSway = Math.sin(seconds * 0.6);
    const laughBounce = Math.sin(seconds * MOTION.talk.bounceHz) * this.bounce * 2.6;
    const talkBob = this.speaking ? Math.sin(seconds * 8.2) * MOTION.talk.bob : 0;
    const nod = this.speaking ? Math.sin(seconds * 5.4) * MOTION.talk.headNod * 8 : this.blinkCtrl.lastNod * 6;
    const scale = Math.min(canvasWidth / W, canvasHeight / H) * 1.08;
    const drawWidth = W * scale;
    const drawHeight = H * scale;
    const originX = (canvasWidth - drawWidth) / 2 - canvasWidth * 0.02;
    const originY =
      (canvasHeight - drawHeight) / 2 +
      canvasHeight * 0.06 +
      (chest * 1.15 + laughBounce + talkBob + nod) * scale;
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
      const craneInfluence = Math.exp(-(((normalizedY - 0.52) / 0.08) ** 2));
      const shawlInfluence = Math.exp(-(((normalizedY - 0.58) / 0.16) ** 2));
      const shoulderInfluence = Math.exp(-(((normalizedY - 0.48) / 0.12) ** 2));
      const xShift =
        (this.lookX * MOTION.face.sliceLook * headInfluence +
          idleSway * 1.1 +
          crane * craneInfluence * 0.35 +
          shawl * shawlInfluence * 0.25 +
          shoulder * shoulderInfluence * 0.4) *
        scale;
      const yShift =
        (this.lookY * 4.2 * headInfluence -
          chest * chestInfluence +
          laughBounce * 0.45 * headInfluence +
          nod * 0.2 * headInfluence) *
        scale;
      const horizontalScale = 1 - Math.abs(this.lookX) * 0.005 * headInfluence;
      const sliceWidth = drawWidth * horizontalScale;
      const sliceX = originX + xShift + (drawWidth - sliceWidth) / 2;
      const sliceY = originY + sourceY * scale + yShift;
      context.drawImage(this.portrait, 0, sourceY, W, sliceHeight + 1, sliceX, sliceY, sliceWidth, sliceHeight * scale + 1.25);
    }
    context.restore();
  }

  private drawStageFull(seconds: number, breath?: BreathState, body?: BodyState): void {
    const context = this.ctx;
    const canvasWidth = this.canvas.width;
    const canvasHeight = this.canvas.height;
    context.clearRect(0, 0, canvasWidth, canvasHeight);
    const { w, h, slices } = this.layout;
    const cfg = MOTION.body;
    const chest = breath ? breath.chest : Math.sin(seconds * 1.45) * MOTION.breath.chest;
    const shoulder = breath?.shoulder ?? 0;
    const crane = breath?.crane ?? 0;
    const shawl = breath?.shawl ?? 0;
    const idleSway = Math.sin(seconds * 0.55);
    const laughBounce = Math.sin(seconds * MOTION.talk.bounceHz) * this.bounce * 2.2;
    const talkBob = this.speaking ? Math.sin(seconds * 7.4) * MOTION.talk.bob * 0.7 : 0;
    const nod = this.speaking ? Math.sin(seconds * 5.4) * MOTION.talk.headNod * 6 : this.blinkCtrl.lastNod * 5;
    const weight = body?.weight ?? Math.sin(seconds * Math.PI * 2 * cfg.weightHz) * 0.4;
    const skirtA = body?.skirt.angle ?? 0;
    const hemA = body?.hem.angle ?? 0;
    const shawlLA = body?.shawlL.angle ?? 0;
    const shawlRA = body?.shawlR.angle ?? 0;
    const legA = body?.leg.angle ?? 0;

    const padX = canvasWidth * 0.04;
    const padY = canvasHeight * 0.02;
    const scale = Math.min((canvasWidth - padX * 2) / w, (canvasHeight - padY * 2) / h) * 0.98;
    const drawWidth = w * scale;
    const drawHeight = h * scale;
    const originX = (canvasWidth - drawWidth) / 2 + canvasWidth * 0.012;
    const originY =
      canvasHeight - drawHeight - canvasHeight * 0.018 + (chest * 0.35 + laughBounce + talkBob + nod) * scale;
    const sliceHeight = h / slices;
    const plant = this.layout.plant ?? { x: w * 0.52, y: h * 0.96 };
    const plantX = originX + plant.x * scale;
    const plantY = originY + plant.y * scale;

    context.save();
    context.translate(plantX, plantY);
    context.rotate(weight * cfg.lean + this.lookX * 0.003 + this.pose.headTilt * 0.22);
    context.translate(-plantX, -plantY);

    for (let index = 0; index < slices; index += 1) {
      const sourceY = index * sliceHeight;
      const normalizedY = sourceY / h;
      const headInfluence = Math.exp(-(((normalizedY - 0.12) / 0.14) ** 2));
      const chestInfluence = Math.exp(-(((normalizedY - 0.26) / 0.12) ** 2));
      const bellyInfluence = Math.exp(-(((normalizedY - 0.34) / 0.1) ** 2));
      const hipInfluence = Math.exp(-(((normalizedY - cfg.hipY) / 0.1) ** 2));
      const skirtInfluence = Math.exp(-(((normalizedY - 0.55) / 0.16) ** 2));
      const hemInfluence = Math.exp(-(((normalizedY - cfg.hemY) / 0.12) ** 2));
      const shoulderInfluence = Math.exp(-(((normalizedY - 0.24) / 0.08) ** 2));
      const craneInfluence = Math.exp(-(((normalizedY - 0.236) / 0.04) ** 2));
      const shawlInfluence = Math.max(
        Math.exp(-(((normalizedY - 0.42) / 0.22) ** 2)),
        Math.exp(-(((normalizedY - 0.58) / 0.18) ** 2)),
      );
      const legInfluence = Math.exp(-(((normalizedY - 0.84) / 0.12) ** 2));
      const footInfluence = Math.exp(-(((normalizedY - cfg.plantY) / 0.05) ** 2));
      const fromFeet = clamp((cfg.plantY - normalizedY) / Math.max(0.08, cfg.plantY), 0, 1);
      const xShift =
        (this.lookX * MOTION.face.sliceLook * 0.55 * headInfluence +
          idleSway * 0.7 * (1 - footInfluence) +
          weight * cfg.hipShift * hipInfluence +
          weight * cfg.hipShift * 0.45 * fromFeet * (1 - footInfluence) +
          skirtA * 42 * skirtInfluence * cfg.skirtCoupling +
          hemA * 52 * hemInfluence * cfg.hemCoupling +
          shawlLA * 28 * shawlInfluence * cfg.shawlCoupling * 0.5 +
          shawlRA * 28 * shawlInfluence * cfg.shawlCoupling * 0.5 +
          crane * craneInfluence * 0.28 +
          shawl * shawlInfluence * 0.2 +
          shoulder * shoulderInfluence * 0.35 +
          legA * 18 * legInfluence) *
        scale;
      const yShift =
        (this.lookY * 2.4 * headInfluence -
          chest * chestInfluence * cfg.chestBreath -
          chest * bellyInfluence * cfg.bellyBreath * 0.45 +
          laughBounce * 0.35 * headInfluence +
          nod * 0.18 * headInfluence) *
        scale;
      const horizontalScale =
        1 -
        Math.abs(this.lookX) * 0.004 * headInfluence +
        chest * chestInfluence * 0.0018 * cfg.chestBreath +
        chest * bellyInfluence * 0.0012 * cfg.bellyBreath;
      const sliceWidth = drawWidth * horizontalScale;
      const sliceX = originX + xShift + (drawWidth - sliceWidth) / 2;
      const sliceY = originY + sourceY * scale + yShift;
      context.drawImage(
        this.portrait,
        0,
        sourceY,
        w,
        sliceHeight + 1,
        sliceX,
        sliceY,
        sliceWidth,
        sliceHeight * scale + 1.25,
      );
    }

    this.drawFullOverlays(context, originX, originY, scale, body, breath);
    context.restore();
  }

  private drawFullOverlays(
    context: CanvasRenderingContext2D,
    originX: number,
    originY: number,
    scale: number,
    body?: BodyState,
    breath?: BreathState,
  ): void {
    if (!this.assets) return;
    const skirtA = body?.skirt.angle ?? 0;
    const hemA = body?.hem.angle ?? 0;
    const shawlLA = body?.shawlL.angle ?? 0;
    const shawlRA = body?.shawlR.angle ?? 0;
    const craneA = body?.crane.angle ?? 0;
    const chest = breath?.chest ?? 0;

    const paint = (
      image: HTMLImageElement | undefined,
      pivot: { x: number; y: number } | undefined,
      angle: number,
      sway: number,
      alpha = 0.92,
    ) => {
      if (!image || !pivot) return;
      context.save();
      context.translate(originX, originY);
      context.scale(scale, scale);
      context.translate(pivot.x, pivot.y);
      context.rotate(angle);
      context.translate(-pivot.x + angle * sway, -pivot.y + Math.abs(angle) * 6);
      context.globalAlpha = alpha;
      context.drawImage(image, 0, 0);
      context.restore();
    };

    paint(this.assets.shawlLeft, this.layout.shawlL, shawlLA, 36, 0.78);
    paint(this.assets.shawlRight, this.layout.shawlR, shawlRA, 36, 0.78);
    paint(this.assets.skirt, this.layout.skirt, skirtA * 0.55, 22, 0.42);
    paint(this.assets.hem, this.layout.hem, hemA, 48, 0.7);
    if (this.assets.crane && this.layout.crane) {
      const bob = chest * 0.12 * MOTION.body.craneCoupling;
      context.save();
      context.translate(originX, originY);
      context.scale(scale, scale);
      context.translate(this.layout.crane.x, this.layout.crane.y + bob);
      context.rotate(craneA);
      context.translate(-this.layout.crane.x, -this.layout.crane.y);
      context.globalAlpha = 0.9;
      context.drawImage(this.assets.crane, 0, 0);
      context.restore();
    }
  }
}
