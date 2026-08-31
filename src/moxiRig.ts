export type RigExpression = "neutral" | "smile" | "surprise";

const PORTRAIT_WIDTH = 1536;
const PORTRAIT_HEIGHT = 1024;
const SLICE_COUNT = 64;

const ASSETS = {
  base: "/characters/moxi/portrait-rig/base.png",
  eyeLeft: "/characters/moxi/portrait-rig/eye_left.png",
  eyeRight: "/characters/moxi/portrait-rig/eye_right.png",
} as const;

const FACE = {
  eyeLeft: { x: 657, y: 307 },
  eyeRight: { x: 802, y: 289 },
  mouth: { x: 753, y: 406 },
  head: { x: 746, y: 285 },
} as const;

type LoadedAssets = {
  base: HTMLImageElement;
  eyeLeft: HTMLImageElement;
  eyeRight: HTMLImageElement;
};

function loadImage(src: string): Promise<HTMLImageElement> {
  return new Promise((resolve, reject) => {
    const image = new Image();
    image.onload = () => resolve(image);
    image.onerror = () => reject(new Error(`无法加载角色素材：${src}`));
    image.src = src;
  });
}

function blinkAmount(seconds: number): number {
  const phase = seconds % 3.8;
  if (phase < 3.52) return 1;
  if (phase < 3.62) return 1 - (phase - 3.52) / 0.1;
  if (phase < 3.7) return 0.06;
  return Math.min(1, (phase - 3.7) / 0.1);
}

/**
 * Preserves the finished portrait and deforms only facial features and
 * horizontal image bands. Broad cut-out masks caused the old pasted-on look.
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
  private running = false;
  private frameId = 0;
  private startedAt = 0;
  private lookX = 0;
  private lookY = 0;
  private targetLookX = 0;
  private targetLookY = 0;
  private mouthOpen = 0;
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

    this.handlePointer = (event: PointerEvent) => {
      const bounds = this.canvas.getBoundingClientRect();
      if (bounds.width === 0 || bounds.height === 0) return;
      this.targetLookX = Math.max(
        -1,
        Math.min(1, ((event.clientX - bounds.left) / bounds.width - 0.5) * 2),
      );
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
    const [base, eyeLeft, eyeRight] = await Promise.all([
      loadImage(ASSETS.base),
      loadImage(ASSETS.eyeLeft),
      loadImage(ASSETS.eyeRight),
    ]);
    this.assets = { base, eyeLeft, eyeRight };
    this.resize();
    this.canvas.addEventListener("pointermove", this.handlePointer);
    this.canvas.addEventListener("pointerleave", this.handlePointerLeave);
    window.addEventListener("resize", this.handleResize);
    this.running = true;
    this.startedAt = performance.now();
    this.frameId = requestAnimationFrame(this.renderFrame);
    this.onStatus(
      "墨汐重制版已加载\n完整原画保持不变；局部眨眼、细微转头和口型在脸上连续变形。\n表情：neutral / smile / surprise。",
      "ok",
    );
    return {
      expressions: ["neutral", "smile", "surprise"],
      motions: ["Idle"],
    };
  }

  playExpression(name: string): void {
    if (name === "neutral" || name === "smile" || name === "surprise") {
      this.expression = name;
    }
  }

  playMotion(_group: string): void {
    this.targetLookX = this.targetLookX === 0 ? 0.35 : -this.targetLookX;
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
  }

  private readonly renderFrame = (now: number) => {
    if (!this.running || !this.assets) return;
    const seconds = (now - this.startedAt) / 1000;
    this.lookX += (this.targetLookX - this.lookX) * 0.075;
    this.lookY += (this.targetLookY - this.lookY) * 0.075;
    const mouthTarget = this.expression === "surprise" ? 1 : 0;
    this.mouthOpen += (mouthTarget - this.mouthOpen) * 0.12;

    this.composePortrait({
      blink: blinkAmount(seconds),
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

    const smileSquint = this.expression === "smile" ? 0.86 : 1;
    const surpriseOpen = this.expression === "surprise" ? 1.06 : 1;
    const eyeScaleY = Math.max(
      0.05,
      state.blink * smileSquint * surpriseOpen,
    );
    this.drawEye(this.assets.eyeLeft, FACE.eyeLeft, eyeScaleY, -1);
    this.drawEye(this.assets.eyeRight, FACE.eyeRight, eyeScaleY, 1);

    if (eyeScaleY < 0.18) {
      this.drawClosedEyes(1 - eyeScaleY / 0.18);
    }
    this.drawExpression(state.seconds);
  }

  private drawEye(
    image: HTMLImageElement,
    center: { x: number; y: number },
    scaleY: number,
    side: -1 | 1,
  ): void {
    const context = this.portraitCtx;
    const perspectiveScaleX = 1 + side * this.lookX * 0.045;
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

  private drawClosedEyes(alpha: number): void {
    const context = this.portraitCtx;
    context.save();
    context.globalAlpha = alpha;
    context.strokeStyle = "#211a1d";
    context.lineWidth = 4.2;
    context.lineCap = "round";

    context.beginPath();
    context.moveTo(620, 304);
    context.bezierCurveTo(640, 321, 671, 322, 696, 302);
    context.stroke();

    context.beginPath();
    context.moveTo(764, 287);
    context.bezierCurveTo(786, 304, 819, 304, 846, 282);
    context.stroke();
    context.restore();
  }

  private drawExpression(seconds: number): void {
    const context = this.portraitCtx;
    const { x, y } = FACE.mouth;

    if (this.expression === "smile") {
      const pulse = (Math.sin(seconds * 2.1) + 1) * 0.5;
      context.save();
      context.strokeStyle = `rgba(112, 54, 62, ${0.3 + pulse * 0.15})`;
      context.lineWidth = 2.2;
      context.lineCap = "round";
      context.beginPath();
      context.moveTo(x - 24, y);
      context.quadraticCurveTo(x, y + 13, x + 25, y - 1);
      context.stroke();
      context.restore();
      return;
    }

    if (this.mouthOpen < 0.03) return;
    const open = this.mouthOpen;
    context.save();
    context.globalAlpha = open;
    const skinBlend = context.createRadialGradient(x, y + 2, 4, x, y + 2, 31);
    skinBlend.addColorStop(0, "rgba(246, 208, 193, 0.94)");
    skinBlend.addColorStop(0.62, "rgba(246, 208, 193, 0.56)");
    skinBlend.addColorStop(1, "rgba(246, 208, 193, 0)");
    context.fillStyle = skinBlend;
    context.beginPath();
    context.ellipse(x, y + 2, 32, 22, 0, 0, Math.PI * 2);
    context.fill();

    context.translate(x, y + 4);
    context.scale(1, 0.45 + open * 0.55);
    context.fillStyle = "#743d47";
    context.beginPath();
    context.ellipse(0, 0, 17, 11, 0, 0, Math.PI * 2);
    context.fill();
    context.fillStyle = "#2c131b";
    context.beginPath();
    context.ellipse(0, 1.5, 13, 8, 0, 0, Math.PI * 2);
    context.fill();
    context.fillStyle = "rgba(247, 233, 226, 0.92)";
    context.beginPath();
    context.ellipse(0, -3, 8.5, 2.4, 0, Math.PI, Math.PI * 2);
    context.fill();
    context.strokeStyle = "rgba(128, 65, 74, 0.7)";
    context.lineWidth = 1.4;
    context.beginPath();
    context.arc(0, 0, 17, 0.18, Math.PI - 0.18);
    context.stroke();
    context.restore();
  }

  private drawDeformedPortrait(seconds: number): void {
    const context = this.ctx;
    const canvasWidth = this.canvas.width;
    const canvasHeight = this.canvas.height;
    context.clearRect(0, 0, canvasWidth, canvasHeight);

    const breathing = Math.sin(seconds * 1.45);
    const idleSway = Math.sin(seconds * 0.6);
    const scale =
      Math.min(
        canvasWidth / PORTRAIT_WIDTH,
        canvasHeight / PORTRAIT_HEIGHT,
      ) *
      0.93;
    const drawWidth = PORTRAIT_WIDTH * scale;
    const drawHeight = PORTRAIT_HEIGHT * scale;
    const originX = (canvasWidth - drawWidth) / 2;
    const originY =
      (canvasHeight - drawHeight) / 2 +
      canvasHeight * 0.035 +
      breathing * 2.5 * scale;
    const sliceHeight = PORTRAIT_HEIGHT / SLICE_COUNT;

    context.save();
    context.translate(canvasWidth / 2, canvasHeight / 2);
    context.rotate(this.lookX * 0.006 + idleSway * 0.002);
    context.translate(-canvasWidth / 2, -canvasHeight / 2);

    for (let index = 0; index < SLICE_COUNT; index += 1) {
      const sourceY = index * sliceHeight;
      const normalizedY = sourceY / PORTRAIT_HEIGHT;
      const headInfluence = Math.exp(
        -Math.pow((normalizedY - 0.28) / 0.32, 2),
      );
      const chestInfluence = Math.exp(
        -Math.pow((normalizedY - 0.63) / 0.28, 2),
      );
      const xShift =
        (this.lookX * 18 * headInfluence + idleSway * 1.5) * scale;
      const yShift =
        (this.lookY * 8 * headInfluence -
          breathing * 2.2 * chestInfluence) *
        scale;
      const horizontalScale =
        1 - Math.abs(this.lookX) * 0.012 * headInfluence;
      const sliceWidth = drawWidth * horizontalScale;
      const sliceX =
        originX + xShift + (drawWidth - sliceWidth) / 2;
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
