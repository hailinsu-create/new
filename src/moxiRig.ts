export const RIG_EXPRESSIONS = [
  "neutral",
  "smile",
  "laugh",
  "surprise",
  "sad",
  "angry",
  "shy",
  "wink",
  "talk",
  "sleepy",
] as const;

export type RigExpression = (typeof RIG_EXPRESSIONS)[number];

export const RIG_EXPRESSION_LABELS: Record<RigExpression, string> = {
  neutral: "neutral · 平静",
  smile: "smile · 浅笑",
  laugh: "laugh · 大笑",
  surprise: "surprise · 吃惊",
  sad: "sad · 难过",
  angry: "angry · 生气",
  shy: "shy · 害羞",
  wink: "wink · 眨眼",
  talk: "talk · 说话",
  sleepy: "sleepy · 困倦",
};

const PORTRAIT_WIDTH = 1536;
const PORTRAIT_HEIGHT = 1024;
const SLICE_COUNT = 64;
const MOUTH_TILT = -0.175;
const SKIN_A = (alpha: number) => `rgba(247, 223, 207, ${alpha})`;

const ASSETS = {
  base: "/characters/moxi/portrait-rig/base.png",
  eyeLeft: "/characters/moxi/portrait-rig/eye_left.png",
  eyeRight: "/characters/moxi/portrait-rig/eye_right.png",
  hairLock: "/characters/moxi/portrait-rig/hair_lock.png",
  tassel: "/characters/moxi/portrait-rig/tassel.png",
} as const;

const FACE = {
  eyeLeft: { x: 657, y: 307 },
  eyeRight: { x: 802, y: 289 },
  mouth: { x: 753, y: 401 },
  head: { x: 746, y: 285 },
  browLeft: { innerX: 688, innerY: 271, outerX: 628, outerY: 276 },
  browRight: { innerX: 764, innerY: 256, outerX: 838, outerY: 250 },
} as const;

type FacePose = {
  leftOpen: number;
  rightOpen: number;
  eyeWidth: number;
  lowerLid: number;
  browInner: number;
  browRaise: number;
  mouthOpen: number;
  mouthCurve: number;
  mouthWidth: number;
  mouthCover: number;
  blush: number;
  lookBiasX: number;
  lookBiasY: number;
  sparkle: number;
  tear: number;
  sweat: number;
  headBounce: number;
};

const POSE_KEYS = [
  "leftOpen",
  "rightOpen",
  "eyeWidth",
  "lowerLid",
  "browInner",
  "browRaise",
  "mouthOpen",
  "mouthCurve",
  "mouthWidth",
  "mouthCover",
  "blush",
  "lookBiasX",
  "lookBiasY",
  "sparkle",
  "tear",
  "sweat",
  "headBounce",
] as const satisfies readonly (keyof FacePose)[];

const NEUTRAL_POSE: FacePose = {
  leftOpen: 1,
  rightOpen: 1,
  eyeWidth: 1,
  lowerLid: 0,
  browInner: 0,
  browRaise: 0,
  mouthOpen: 0,
  mouthCurve: 0.28,
  mouthWidth: 1,
  mouthCover: 0,
  blush: 0.08,
  lookBiasX: 0,
  lookBiasY: 0,
  sparkle: 0.35,
  tear: 0,
  sweat: 0,
  headBounce: 0,
};

const EXPRESSION_POSES: Record<RigExpression, FacePose> = {
  neutral: NEUTRAL_POSE,
  smile: {
    ...NEUTRAL_POSE,
    leftOpen: 0.84,
    rightOpen: 0.84,
    lowerLid: 0.72,
    mouthCurve: 0.92,
    mouthWidth: 1.12,
    mouthCover: 1,
    blush: 0.42,
    sparkle: 0.45,
  },
  laugh: {
    ...NEUTRAL_POSE,
    leftOpen: 0.08,
    rightOpen: 0.08,
    lowerLid: 0.15,
    browRaise: 0.22,
    mouthOpen: 0.88,
    mouthCurve: 1,
    mouthWidth: 1.28,
    mouthCover: 1,
    blush: 0.58,
    sparkle: 0.2,
    headBounce: 0.45,
  },
  surprise: {
    ...NEUTRAL_POSE,
    leftOpen: 1.14,
    rightOpen: 1.14,
    eyeWidth: 1.08,
    browRaise: 1,
    mouthOpen: 1,
    mouthCurve: 0.02,
    mouthWidth: 0.62,
    mouthCover: 1,
    blush: 0,
    sparkle: 1,
    sweat: 0.25,
  },
  sad: {
    ...NEUTRAL_POSE,
    leftOpen: 0.86,
    rightOpen: 0.86,
    lowerLid: 0.18,
    browInner: 1,
    browRaise: 0.2,
    mouthCurve: -0.9,
    mouthWidth: 0.84,
    mouthCover: 1,
    blush: 0.1,
    lookBiasY: 0.18,
    sparkle: 0.12,
    tear: 1,
  },
  angry: {
    ...NEUTRAL_POSE,
    leftOpen: 0.72,
    rightOpen: 0.72,
    eyeWidth: 0.92,
    lowerLid: 0.28,
    browInner: -1,
    mouthOpen: 0.08,
    mouthCurve: -0.42,
    mouthWidth: 0.7,
    mouthCover: 1,
    blush: 0.18,
    sparkle: 0.12,
    sweat: 0.45,
  },
  shy: {
    ...NEUTRAL_POSE,
    leftOpen: 0.86,
    rightOpen: 0.86,
    lowerLid: 0.38,
    mouthCurve: 0.62,
    mouthWidth: 0.8,
    mouthCover: 1,
    blush: 1,
    lookBiasX: 0.32,
    lookBiasY: 0.3,
    sparkle: 0.35,
    sweat: 0.8,
  },
  wink: {
    ...NEUTRAL_POSE,
    leftOpen: 0.05,
    rightOpen: 1,
    lowerLid: 0.2,
    mouthCurve: 0.7,
    mouthWidth: 1.04,
    mouthCover: 1,
    blush: 0.28,
    sparkle: 0.75,
  },
  talk: {
    ...NEUTRAL_POSE,
    mouthOpen: 0.45,
    mouthCurve: 0.22,
    mouthWidth: 1.02,
    mouthCover: 1,
    sparkle: 0.45,
  },
  sleepy: {
    ...NEUTRAL_POSE,
    leftOpen: 0.4,
    rightOpen: 0.38,
    lowerLid: 0.4,
    browRaise: -0.35,
    mouthOpen: 0.08,
    mouthCurve: 0.12,
    mouthWidth: 0.86,
    mouthCover: 1,
    blush: 0.16,
    lookBiasY: 0.18,
    sparkle: 0.08,
  },
};

type LoadedAssets = {
  base: HTMLImageElement;
  eyeLeft: HTMLImageElement;
  eyeRight: HTMLImageElement;
  hairLock: HTMLImageElement;
  tassel: HTMLImageElement;
};

function isRigExpression(name: string): name is RigExpression {
  return (RIG_EXPRESSIONS as readonly string[]).includes(name);
}

function loadImage(src: string): Promise<HTMLImageElement> {
  return new Promise((resolve, reject) => {
    const image = new Image();
    image.onload = () => resolve(image);
    image.onerror = () => reject(new Error(`无法加载角色素材：${src}`));
    image.src = src;
  });
}

function lerp(a: number, b: number, t: number): number {
  return a + (b - a) * t;
}

function lerpPose(current: FacePose, target: FacePose, t: number): FacePose {
  const next = { ...current };
  for (const key of POSE_KEYS) {
    next[key] = lerp(current[key], target[key], t);
  }
  return next;
}

function blinkAmount(seconds: number, period: number): number {
  const phase = seconds % period;
  const closeStart = period - 0.4;
  if (phase < closeStart) return 1;
  const t = phase - closeStart;
  if (t < 0.11) return 1 - t / 0.11;
  if (t < 0.2) return 0.05;
  return Math.min(1, (t - 0.2) / 0.2);
}

function talkViseme(seconds: number): { open: number; width: number; curve: number } {
  const a = Math.sin(seconds * 8.4);
  const b = Math.sin(seconds * 13.1 + 0.7);
  const envelope = 0.5 + 0.5 * Math.sin(seconds * 2.15);
  const open = Math.min(1, Math.max(0.06, (0.38 + 0.34 * a + 0.18 * b) * (0.4 + 0.6 * envelope)));
  return {
    open,
    width: 0.9 + 0.18 * Math.sin(seconds * 5.6 + 1.1),
    curve: 0.3 + 0.22 * a,
  };
}

/**
 * Portrait-mesh runtime. Keeps the finished painting and deforms eyes, brows,
 * mouth, blush, and a few physics pieces on top.
 */
export class MoxiRigViewer {
  private readonly canvas: HTMLCanvasElement;
  private readonly ctx: CanvasRenderingContext2D;
  private readonly portrait = document.createElement("canvas");
  private readonly portraitCtx: CanvasRenderingContext2D;
  private readonly onStatus: (
    message: string,
    kind: "info" | "ok" | "error",
  ) => void;
  private assets: LoadedAssets | null = null;
  private expression: RigExpression = "neutral";
  private pose: FacePose = { ...NEUTRAL_POSE };
  private running = false;
  private frameId = 0;
  private startedAt = 0;
  private lookX = 0;
  private lookY = 0;
  private targetLookX = 0;
  private targetLookY = 0;
  private lastFrameAt = 0;
  private hairAngle = 0;
  private hairVelocity = 0;
  private tasselAngle = 0;
  private tasselVelocity = 0;
  private readonly handlePointer: (event: PointerEvent) => void;
  private readonly handlePointerLeave: () => void;
  private readonly handleResize: () => void;

  constructor(
    canvas: HTMLCanvasElement,
    onStatus: (message: string, kind: "info" | "ok" | "error") => void,
  ) {
    const context = canvas.getContext("2d");
    const portraitContext = this.portrait.getContext("2d");
    if (!context || !portraitContext) {
      throw new Error("浏览器不支持 Canvas 2D");
    }

    this.canvas = canvas;
    this.ctx = context;
    this.portraitCtx = portraitContext;
    this.onStatus = onStatus;
    this.portrait.width = PORTRAIT_WIDTH;
    this.portrait.height = PORTRAIT_HEIGHT;
    this.ctx.imageSmoothingEnabled = true;
    this.ctx.imageSmoothingQuality = "high";
    this.portraitCtx.imageSmoothingEnabled = true;
    this.portraitCtx.imageSmoothingQuality = "high";

    this.handlePointer = (event: PointerEvent) => {
      const bounds = this.canvas.getBoundingClientRect();
      if (bounds.width === 0 || bounds.height === 0) return;
      const nextLookX = Math.max(
        -1,
        Math.min(1, ((event.clientX - bounds.left) / bounds.width - 0.5) * 2),
      );
      const directionChange = nextLookX - this.targetLookX;
      this.hairVelocity -= directionChange * 0.055;
      this.tasselVelocity -= directionChange * 0.08;
      this.targetLookX = nextLookX;
      this.targetLookY = Math.max(
        -1,
        Math.min(1, ((event.clientY - bounds.top) / bounds.height - 0.5) * 2),
      );
    };
    this.handlePointerLeave = () => {
      this.targetLookX = 0;
      this.targetLookY = 0;
    };
    this.handleResize = () => this.resize();
  }

  async load(): Promise<{ expressions: string[]; motions: string[] }> {
    this.onStatus("正在加载墨汐肖像网格…", "info");
    const [base, eyeLeft, eyeRight, hairLock, tassel] = await Promise.all([
      loadImage(ASSETS.base),
      loadImage(ASSETS.eyeLeft),
      loadImage(ASSETS.eyeRight),
      loadImage(ASSETS.hairLock),
      loadImage(ASSETS.tassel),
    ]);
    this.assets = { base, eyeLeft, eyeRight, hairLock, tassel };
    this.resize();
    this.canvas.addEventListener("pointermove", this.handlePointer);
    this.canvas.addEventListener("pointerleave", this.handlePointerLeave);
    window.addEventListener("resize", this.handleResize);
    this.running = true;
    this.startedAt = performance.now();
    this.lastFrameAt = this.startedAt;
    this.frameId = requestAnimationFrame(this.renderFrame);
    this.onStatus(
      "墨汐已加载。眼、眉、嘴、颊分开变形；发梢和流苏有弹性。\n表情可在下拉里直接切换。",
      "ok",
    );
    return {
      expressions: [...RIG_EXPRESSIONS],
      motions: ["Idle"],
    };
  }

  playExpression(name: string): void {
    if (!isRigExpression(name) || name === this.expression) return;
    this.expression = name;
    this.hairVelocity -= 0.045;
    this.tasselVelocity += 0.06;
  }

  playMotion(_group: string): void {
    this.targetLookX = this.targetLookX === 0 ? 0.35 : -this.targetLookX;
    const direction = this.targetLookX >= 0 ? 1 : -1;
    this.hairVelocity -= direction * 0.13;
    this.tasselVelocity -= direction * 0.2;
  }

  destroy(): void {
    this.running = false;
    cancelAnimationFrame(this.frameId);
    this.canvas.removeEventListener("pointermove", this.handlePointer);
    this.canvas.removeEventListener("pointerleave", this.handlePointerLeave);
    window.removeEventListener("resize", this.handleResize);
    this.ctx.clearRect(0, 0, this.canvas.width, this.canvas.height);
  }

  private resize(): void {
    const parent = this.canvas.parentElement;
    if (!parent) return;
    const density = Math.min(window.devicePixelRatio || 1, 2);
    this.canvas.width = Math.max(1, Math.floor(parent.clientWidth * density));
    this.canvas.height = Math.max(1, Math.floor(parent.clientHeight * density));
    this.canvas.style.width = `${parent.clientWidth}px`;
    this.canvas.style.height = `${parent.clientHeight}px`;
    this.ctx.imageSmoothingEnabled = true;
    this.ctx.imageSmoothingQuality = "high";
  }

  private readonly renderFrame = (now: number) => {
    if (!this.running || !this.assets) return;
    const seconds = (now - this.startedAt) / 1000;
    const frameDelta = Math.min(2, Math.max(0.25, (now - this.lastFrameAt) / 16.67));
    this.lastFrameAt = now;

    const targetPose = { ...EXPRESSION_POSES[this.expression] };
    if (this.expression === "talk") {
      const viseme = talkViseme(seconds);
      targetPose.mouthOpen = viseme.open;
      targetPose.mouthWidth = viseme.width;
      targetPose.mouthCurve = viseme.curve;
      targetPose.mouthCover = 1;
    }
    this.pose = lerpPose(this.pose, targetPose, 1 - Math.pow(0.86, frameDelta));

    const lookTargetX = Math.max(-1, Math.min(1, this.targetLookX + this.pose.lookBiasX));
    const lookTargetY = Math.max(-1, Math.min(1, this.targetLookY + this.pose.lookBiasY));
    this.lookX += (lookTargetX - this.lookX) * 0.075;
    this.lookY += (lookTargetY - this.lookY) * 0.075;
    this.updatePhysics(seconds, frameDelta);

    const blinkPeriod = this.expression === "sleepy" ? 2.35 : this.expression === "surprise" ? 5.2 : 3.8;
    const blink = blinkAmount(seconds, blinkPeriod);
    this.composePortrait({
      blink,
      seconds,
    });
    this.drawDeformedPortrait(seconds);
    this.frameId = requestAnimationFrame(this.renderFrame);
  };

  private composePortrait(state: { blink: number; seconds: number }): void {
    if (!this.assets) return;
    const context = this.portraitCtx;
    context.clearRect(0, 0, PORTRAIT_WIDTH, PORTRAIT_HEIGHT);
    context.drawImage(this.assets.base, 0, 0);
    this.drawSecondaryPhysics();
    this.drawMouth();
    this.drawEyes(state.blink, state.seconds);
    this.drawBrows();
    this.drawCheeks(state.seconds);
    this.drawTears(state.seconds);
    this.drawSweat(state.seconds);
  }

  private updatePhysics(seconds: number, frameDelta: number): void {
    const hairTarget = -this.lookX * 0.22 + Math.sin(seconds * 0.85) * 0.1;
    this.hairVelocity += (hairTarget - this.hairAngle) * 0.065 * frameDelta;
    this.hairVelocity *= Math.pow(0.86, frameDelta);
    this.hairAngle += this.hairVelocity * frameDelta;

    const tasselTarget = -this.lookX * 0.28 + Math.sin(seconds * 1.15 + 0.7) * 0.14;
    this.tasselVelocity += (tasselTarget - this.tasselAngle) * 0.045 * frameDelta;
    this.tasselVelocity *= Math.pow(0.9, frameDelta);
    this.tasselAngle += this.tasselVelocity * frameDelta;
  }

  private drawSecondaryPhysics(): void {
    if (!this.assets) return;
    const context = this.portraitCtx;

    context.save();
    context.translate(526, 292);
    context.rotate(this.hairAngle);
    context.translate(-526, -292);
    context.translate(this.hairAngle * 85, Math.abs(this.hairAngle) * 14);
    context.drawImage(this.assets.hairLock, 0, 0);
    context.restore();

    context.save();
    context.translate(819, 658);
    context.rotate(this.tasselAngle);
    context.translate(-819, -658);
    context.translate(this.tasselAngle * 52, Math.abs(this.tasselAngle) * 10);
    context.drawImage(this.assets.tassel, 0, 0);
    context.restore();
  }

  private drawEyes(blink: number, seconds: number): void {
    if (!this.assets) return;
    const leftOpen = Math.max(
      0.04,
      this.pose.leftOpen * (this.expression === "wink" ? 1 : blink),
    );
    const rightOpen = Math.max(0.04, this.pose.rightOpen * blink);

    this.drawEyeSocketFill(FACE.eyeLeft, leftOpen);
    this.drawEyeSocketFill(FACE.eyeRight, rightOpen);
    if (leftOpen >= 0.16) {
      this.drawEye(this.assets.eyeLeft, FACE.eyeLeft, leftOpen, -1);
    }
    if (rightOpen >= 0.16) {
      this.drawEye(this.assets.eyeRight, FACE.eyeRight, rightOpen, 1);
    }
    this.drawLowerLid(FACE.eyeLeft, this.pose.lowerLid * Math.min(1, leftOpen * 1.2), -1);
    this.drawLowerLid(FACE.eyeRight, this.pose.lowerLid * Math.min(1, rightOpen * 1.2), 1);
    this.drawSparkle(FACE.eyeLeft, leftOpen, -1, seconds);
    this.drawSparkle(FACE.eyeRight, rightOpen, 1, seconds);

    if (leftOpen < 0.22) {
      this.drawClosedEye(FACE.eyeLeft, leftOpen < 0.16 ? 1 : 1 - leftOpen / 0.22, -1);
    }
    if (rightOpen < 0.22) {
      this.drawClosedEye(FACE.eyeRight, rightOpen < 0.16 ? 1 : 1 - rightOpen / 0.22, 1);
    }
  }

  private drawEyeSocketFill(center: { x: number; y: number }, open: number): void {
    if (open > 0.92) return;
    const context = this.portraitCtx;
    const cover = 1 - Math.min(1, open);
    context.save();
    context.translate(center.x + this.lookX * 2.4, center.y + this.lookY * 1.5);
    const fill = context.createRadialGradient(0, 0, 4, 0, 0, 34);
    fill.addColorStop(0, SKIN_A(0.94 * cover));
    fill.addColorStop(0.55, SKIN_A(0.55 * cover));
    fill.addColorStop(1, SKIN_A(0));
    context.fillStyle = fill;
    context.beginPath();
    context.ellipse(0, 1, 32, 20, 0, 0, Math.PI * 2);
    context.fill();
    context.restore();
  }

  private drawEye(
    image: HTMLImageElement,
    center: { x: number; y: number },
    scaleY: number,
    side: -1 | 1,
  ): void {
    const context = this.portraitCtx;
    const perspectiveScaleX = (1 + side * this.lookX * 0.045) * this.pose.eyeWidth;
    const depthOffset = side * Math.abs(this.lookX) * 1.4;
    context.save();
    context.translate(
      center.x + this.lookX * 2.8 + depthOffset,
      center.y + this.lookY * 1.8,
    );
    context.scale(perspectiveScaleX, scaleY);
    context.translate(-center.x, -center.y);
    context.drawImage(image, 0, 0);
    context.restore();
  }

  private drawLowerLid(
    center: { x: number; y: number },
    amount: number,
    side: -1 | 1,
  ): void {
    if (amount < 0.03) return;
    const context = this.portraitCtx;
    context.save();
    context.translate(center.x + this.lookX * 2.8, center.y + this.lookY * 1.8);
    context.scale(1 + side * this.lookX * 0.045, 1);
    context.lineCap = "round";
    context.strokeStyle = SKIN_A(0.55 * amount);
    context.lineWidth = 7.5;
    context.beginPath();
    context.moveTo(-26, 6);
    context.quadraticCurveTo(0, 12 + amount * 4, 26, 5);
    context.stroke();
    context.strokeStyle = `rgba(42, 31, 34, ${0.45 * amount})`;
    context.lineWidth = 1.2;
    context.beginPath();
    context.moveTo(-24, 7);
    context.quadraticCurveTo(0, 13 + amount * 3, 24, 6);
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
    const context = this.portraitCtx;
    const pulse = 0.85 + 0.15 * Math.sin(seconds * 3.2 + side);
    context.save();
    context.translate(
      center.x + this.lookX * 4.2 + side * 4,
      center.y + this.lookY * 2.4 - 4,
    );
    context.globalAlpha = amount * pulse;
    context.fillStyle = "rgba(255, 252, 248, 0.92)";
    context.beginPath();
    context.ellipse(-2, -3, 3.4, 4.2, -0.2, 0, Math.PI * 2);
    context.fill();
    context.beginPath();
    context.ellipse(6, 5, 1.6, 1.9, 0.3, 0, Math.PI * 2);
    context.fill();
    context.restore();
  }

  private drawClosedEye(
    center: { x: number; y: number },
    alpha: number,
    side: -1 | 1,
  ): void {
    const context = this.portraitCtx;
    const happy = Math.max(0, this.pose.mouthCurve);
    const sad = Math.max(0, -this.pose.mouthCurve);
    const outerLift = happy * 5 - sad * 4;
    context.save();
    context.globalAlpha = alpha;
    context.translate(center.x + this.lookX * 2.2, center.y + this.lookY * 1.2);
    context.strokeStyle = "#211a1d";
    context.lineCap = "round";
    context.lineJoin = "round";
    context.lineWidth = 4.4;
    const leftX = -36;
    const rightX = 36;
    const leftY = 2 + (side === -1 ? -outerLift : outerLift * 0.12);
    const rightY = 1 + (side === 1 ? -outerLift * 0.45 : outerLift * 0.1);
    context.beginPath();
    context.moveTo(leftX, leftY);
    context.bezierCurveTo(
      -12,
      16 - happy * 4 + sad * 6,
      12,
      16 - happy * 4 + sad * 6,
      rightX,
      rightY,
    );
    context.stroke();
    context.lineWidth = 1.5;
    context.globalAlpha = alpha * 0.7;
    const flickX = side === -1 ? leftX - 2 : rightX + 2;
    context.beginPath();
    context.moveTo(flickX, 2);
    context.quadraticCurveTo(flickX + side * 6, 8, flickX + side * 9, 14);
    context.stroke();
    context.restore();
  }

  private drawBrows(): void {
    const inner = this.pose.browInner;
    const raise = this.pose.browRaise;
    if (Math.abs(inner) < 0.32 && Math.abs(raise) < 0.28) return;
    const context = this.portraitCtx;
    const lift = -raise * 7;
    this.strokeBrow(context, {
      outerX: FACE.browLeft.outerX + this.lookX * 1.4,
      outerY: FACE.browLeft.outerY + lift * 0.45 + this.lookY * 0.8,
      innerX: FACE.browLeft.innerX + this.lookX * 1.4,
      innerY: FACE.browLeft.innerY - inner * 8 + lift + this.lookY * 0.8,
    });
    this.strokeBrow(context, {
      outerX: FACE.browRight.outerX + this.lookX * 1.4,
      outerY: FACE.browRight.outerY + lift * 0.45 + this.lookY * 0.8,
      innerX: FACE.browRight.innerX + this.lookX * 1.4,
      innerY: FACE.browRight.innerY - inner * 8 + lift + this.lookY * 0.8,
    });
  }

  private strokeBrow(
    context: CanvasRenderingContext2D,
    points: { outerX: number; outerY: number; innerX: number; innerY: number },
  ): void {
    const midX = (points.outerX + points.innerX) / 2;
    const midY = (points.outerY + points.innerY) / 2 - 2;
    context.save();
    context.lineCap = "round";
    context.lineJoin = "round";
    context.strokeStyle = "#2a2428";
    context.lineWidth = 2.35;
    context.globalAlpha = 0.78;
    context.beginPath();
    context.moveTo(points.outerX, points.outerY);
    context.quadraticCurveTo(midX, midY, points.innerX, points.innerY);
    context.stroke();
    context.restore();
  }

  private drawMouth(): void {
    const cover = this.pose.mouthCover;
    if (cover < 0.04) return;
    const context = this.portraitCtx;
    const open = this.pose.mouthOpen;
    const curve = this.pose.mouthCurve;
    const width = this.pose.mouthWidth;
    context.save();
    context.translate(
      FACE.mouth.x + this.lookX * 1.8,
      FACE.mouth.y + this.lookY * 1.1,
    );
    context.rotate(MOUTH_TILT);
    context.globalAlpha = cover;

    const coverRx = 32 * width + open * 8;
    const coverRy = 16 + open * 16;
    const skinBlend = context.createRadialGradient(0, 0, 2, 0, 1, Math.max(coverRx, coverRy));
    skinBlend.addColorStop(0, SKIN_A(1));
    skinBlend.addColorStop(0.45, SKIN_A(1));
    skinBlend.addColorStop(0.78, SKIN_A(0.82));
    skinBlend.addColorStop(1, SKIN_A(0));
    context.fillStyle = skinBlend;
    context.beginPath();
    context.ellipse(0, 2, coverRx, coverRy, 0, 0, Math.PI * 2);
    context.fill();

    if (open < 0.18) {
      this.drawClosedMouth(context, curve, width);
    } else {
      this.drawOpenMouth(context, open, curve, width);
    }
    context.restore();
  }

  private drawClosedMouth(
    context: CanvasRenderingContext2D,
    curve: number,
    width: number,
  ): void {
    const half = 24 * width;
    const dip = 11 * curve;
    context.fillStyle = "rgba(232, 184, 174, 0.78)";
    context.beginPath();
    context.ellipse(0, 5 + Math.max(0, dip) * 0.15, 9 * width, 4.2, 0, 0, Math.PI * 2);
    context.fill();
    context.fillStyle = "rgba(255, 252, 249, 0.85)";
    context.beginPath();
    context.ellipse(1, 5.2, 2.1, 1.15, 0, 0, Math.PI * 2);
    context.fill();
    context.strokeStyle = "#5c3338";
    context.lineWidth = 1.85;
    context.lineCap = "round";
    context.beginPath();
    context.moveTo(-half, -dip * 0.08);
    context.quadraticCurveTo(0, dip, half, -dip * 0.18);
    context.stroke();
    if (curve > 0.45) {
      context.globalAlpha *= 0.45;
      context.lineWidth = 1.1;
      context.beginPath();
      context.moveTo(-half + 1, 1);
      context.quadraticCurveTo(-half - 3, 4, -half - 1, 7);
      context.moveTo(half - 1, 0);
      context.quadraticCurveTo(half + 3, 3, half + 1, 6);
      context.stroke();
    }
  }

  private drawOpenMouth(
    context: CanvasRenderingContext2D,
    open: number,
    curve: number,
    width: number,
  ): void {
    context.save();
    context.translate(0, 2);
    if (curve < 0.35) {
      const rx = 6.5 * width + open * 4.5;
      const ry = 5.5 + open * 9.5;
      context.beginPath();
      context.ellipse(0, 2, rx, ry, 0, 0, Math.PI * 2);
      context.fillStyle = "#6e3a43";
      context.fill();
      context.fillStyle = "#2a1218";
      context.beginPath();
      context.ellipse(0, 3.2, rx * 0.72, ry * 0.62, 0, 0, Math.PI * 2);
      context.fill();
      context.strokeStyle = "rgba(92, 51, 56, 0.8)";
      context.lineWidth = 1.4;
      context.beginPath();
      context.ellipse(0, 2, rx, ry, 0, 0, Math.PI * 2);
      context.stroke();
      context.fillStyle = "rgba(232, 184, 174, 0.88)";
      context.beginPath();
      context.ellipse(0, ry + 1.2, rx * 0.7, 2.6, 0, 0, Math.PI * 2);
      context.fill();
    } else {
      const half = 17 * width + open * 3;
      const depth = 7 + open * 10;
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
      context.fillStyle = "rgba(247, 236, 230, 0.95)";
      context.beginPath();
      context.moveTo(-half * 0.72, 0.4);
      context.quadraticCurveTo(0, -1.2, half * 0.72, 0.4);
      context.lineTo(half * 0.62, 3.4);
      context.quadraticCurveTo(0, 2.2, -half * 0.62, 3.4);
      context.closePath();
      context.fill();
      context.fillStyle = "rgba(196, 112, 122, 0.82)";
      context.beginPath();
      context.ellipse(0, depth * 0.55, half * 0.32, depth * 0.2, 0, 0, Math.PI * 2);
      context.fill();
      context.strokeStyle = "rgba(92, 51, 56, 0.78)";
      context.lineWidth = 1.35;
      context.beginPath();
      context.moveTo(-half, 0);
      context.quadraticCurveTo(0, -3.5 - curve * 1.5, half, 0);
      context.quadraticCurveTo(half * 0.35, depth, 0, depth + 1);
      context.quadraticCurveTo(-half * 0.35, depth, -half, 0);
      context.stroke();
      context.fillStyle = "rgba(232, 184, 174, 0.9)";
      context.beginPath();
      context.ellipse(0, depth * 0.82, half * 0.55, 2.8, 0, 0, Math.PI * 2);
      context.fill();
    }
    context.restore();
  }

  private drawCheeks(seconds: number): void {
    const amount = this.pose.blush;
    if (amount < 0.03) return;
    const context = this.portraitCtx;
    const pulse = 0.85 + 0.15 * Math.sin(seconds * 2.05);
    const alpha = amount * pulse;
    this.fillBlush(context, 631, 357, 38, alpha * 0.72);
    this.fillBlush(context, 855, 343, 36, alpha * 0.66);
    if (amount > 0.55) {
      context.save();
      context.globalAlpha = (amount - 0.55) * 0.9;
      context.fillStyle = "rgba(255, 236, 232, 0.55)";
      context.beginPath();
      context.ellipse(624, 350, 2.2, 1.4, 0.3, 0, Math.PI * 2);
      context.fill();
      context.beginPath();
      context.ellipse(862, 336, 2.1, 1.3, -0.2, 0, Math.PI * 2);
      context.fill();
      context.restore();
    }
  }

  private fillBlush(
    context: CanvasRenderingContext2D,
    x: number,
    y: number,
    radius: number,
    alpha: number,
  ): void {
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
    context.fillStyle = "rgba(255, 255, 255, 0.7)";
    context.beginPath();
    context.ellipse(x - 0.8, y - 1, 1.1, 1.6, -0.3, 0, Math.PI * 2);
    context.fill();
  }

  private drawSweat(seconds: number): void {
    const amount = this.pose.sweat;
    if (amount < 0.08) return;
    const context = this.portraitCtx;
    const bob = Math.sin(seconds * 4.4) * 1.5;
    context.save();
    context.globalAlpha = amount * 0.8;
    context.translate(846, 252 + bob);
    context.rotate(0.25);
    context.fillStyle = "rgba(196, 224, 232, 0.8)";
    context.beginPath();
    context.moveTo(0, -7);
    context.quadraticCurveTo(5, 1, 0, 9);
    context.quadraticCurveTo(-5, 1, 0, -7);
    context.fill();
    context.fillStyle = "rgba(255, 255, 255, 0.65)";
    context.beginPath();
    context.ellipse(-1, -1, 1.2, 2, 0, 0, Math.PI * 2);
    context.fill();
    context.restore();
  }

  private drawDeformedPortrait(seconds: number): void {
    const context = this.ctx;
    const canvasWidth = this.canvas.width;
    const canvasHeight = this.canvas.height;
    context.clearRect(0, 0, canvasWidth, canvasHeight);

    const breathing = Math.sin(seconds * 1.45);
    const idleSway = Math.sin(seconds * 0.6);
    const laughBounce = Math.sin(seconds * 9.2) * this.pose.headBounce;
    const scale =
      Math.min(canvasWidth / PORTRAIT_WIDTH, canvasHeight / PORTRAIT_HEIGHT) * 0.93;
    const drawWidth = PORTRAIT_WIDTH * scale;
    const drawHeight = PORTRAIT_HEIGHT * scale;
    const originX = (canvasWidth - drawWidth) / 2;
    const originY =
      (canvasHeight - drawHeight) / 2 +
      canvasHeight * 0.035 +
      (breathing * 2.5 + laughBounce * 3.2) * scale;
    const sliceHeight = PORTRAIT_HEIGHT / SLICE_COUNT;

    context.save();
    context.translate(canvasWidth / 2, canvasHeight / 2);
    context.rotate(this.lookX * 0.006 + idleSway * 0.002 + this.pose.lookBiasX * 0.01);
    context.translate(-canvasWidth / 2, -canvasHeight / 2);

    for (let index = 0; index < SLICE_COUNT; index += 1) {
      const sourceY = index * sliceHeight;
      const normalizedY = sourceY / PORTRAIT_HEIGHT;
      const headInfluence = Math.exp(-Math.pow((normalizedY - 0.28) / 0.32, 2));
      const chestInfluence = Math.exp(-Math.pow((normalizedY - 0.63) / 0.28, 2));
      const xShift = (this.lookX * 18 * headInfluence + idleSway * 1.5) * scale;
      const yShift =
        (this.lookY * 8 * headInfluence - breathing * 2.2 * chestInfluence + laughBounce * 1.4 * headInfluence) *
        scale;
      const horizontalScale = 1 - Math.abs(this.lookX) * 0.012 * headInfluence;
      const sliceWidth = drawWidth * horizontalScale;
      const sliceX = originX + xShift + (drawWidth - sliceWidth) / 2;
      const sliceY = originY + sourceY * scale + yShift;

      context.drawImage(
        this.portrait,
        0,
        sourceY,
        PORTRAIT_WIDTH,
        sliceHeight + 1,
        sliceX,
        sliceY,
        sliceWidth,
        sliceHeight * scale + 1.25,
      );
    }
    context.restore();
  }
}
