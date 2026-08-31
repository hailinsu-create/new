export type RigExpression = "neutral" | "smile" | "surprise";

type LayerName =
  | "hair_back"
  | "body"
  | "face"
  | "eyes_open"
  | "eyes_closed"
  | "brows"
  | "mouth_closed"
  | "mouth_open"
  | "hair_front";

const LAYER_FILES: Record<LayerName, string> = {
  hair_back: "/characters/moxi/rig/01_hair_back.png",
  body: "/characters/moxi/rig/02_body.png",
  face: "/characters/moxi/rig/03_face.png",
  eyes_open: "/characters/moxi/rig/04_eyes.png",
  eyes_closed: "/characters/moxi/rig/04_eyes_closed.png",
  brows: "/characters/moxi/rig/05_brows.png",
  mouth_closed: "/characters/moxi/rig/06_mouth.png",
  mouth_open: "/characters/moxi/rig/06_mouth_open.png",
  hair_front: "/characters/moxi/rig/07_hair_front.png",
};

const DRAW_ORDER: LayerName[] = [
  "hair_back",
  "body",
  "face",
  "eyes_open",
  "eyes_closed",
  "brows",
  "mouth_closed",
  "mouth_open",
  "hair_front",
];

function loadImage(src: string): Promise<HTMLImageElement> {
  return new Promise((resolve, reject) => {
    const img = new Image();
    img.onload = () => resolve(img);
    img.onerror = () => reject(new Error(`无法加载图层 ${src}`));
    img.src = src;
  });
}

/**
 * Layered Moxi runtime. This is the actual moving character until Cubism
 * FREE can export a fully keyed moc3.
 */
export class MoxiRigViewer {
  private readonly canvas: HTMLCanvasElement;
  private readonly ctx: CanvasRenderingContext2D;
  private readonly images = new Map<LayerName, HTMLImageElement>();
  private readonly onStatus: (message: string, kind: "info" | "ok" | "error") => void;
  private running = false;
  private raf = 0;
  private start = 0;
  private lookX = 0;
  private lookY = 0;
  private targetLookX = 0;
  private targetLookY = 0;
  private blink = 1;
  private mouth = 0;
  private expression: RigExpression = "neutral";
  private readonly onPointer: (event: PointerEvent) => void;
  private readonly onResize: () => void;

  constructor(
    canvas: HTMLCanvasElement,
    onStatus: (message: string, kind: "info" | "ok" | "error") => void,
  ) {
    const ctx = canvas.getContext("2d");
    if (!ctx) throw new Error("2D canvas unavailable");
    this.canvas = canvas;
    this.ctx = ctx;
    this.onStatus = onStatus;
    this.onPointer = (event: PointerEvent) => {
      const rect = this.canvas.getBoundingClientRect();
      if (rect.width <= 0 || rect.height <= 0) return;
      this.targetLookX = ((event.clientX - rect.left) / rect.width - 0.5) * 2;
      this.targetLookY = ((event.clientY - rect.top) / rect.height - 0.5) * 2;
    };
    this.onResize = () => this.resize();
  }

  async load(): Promise<{ expressions: string[]; motions: string[] }> {
    this.onStatus("正在加载墨汐分层绑定…", "info");
    const entries = await Promise.all(
      (Object.keys(LAYER_FILES) as LayerName[]).map(async (name) => {
        const img = await loadImage(LAYER_FILES[name]);
        return [name, img] as const;
      }),
    );
    this.images.clear();
    for (const [name, img] of entries) this.images.set(name, img);

    this.resize();
    this.canvas.addEventListener("pointermove", this.onPointer);
    window.addEventListener("resize", this.onResize);
    this.running = true;
    this.start = performance.now();
    this.raf = requestAnimationFrame(this.frame);
    this.onStatus(
      "墨汐分层绑定已加载\n眨眼、转头、张嘴、呼吸都是真图层切换/变形，不是整图晃一下。\n表情：neutral / smile / surprise。",
      "ok",
    );
    return {
      expressions: ["neutral", "smile", "surprise"],
      motions: ["Idle"],
    };
  }

  playExpression(name: string): void {
    if (name === "smile" || name === "surprise" || name === "neutral") {
      this.expression = name;
    }
  }

  playMotion(_group: string): void {
    this.mouth = 0.15;
  }

  destroy(): void {
    this.running = false;
    if (this.raf) cancelAnimationFrame(this.raf);
    this.canvas.removeEventListener("pointermove", this.onPointer);
    window.removeEventListener("resize", this.onResize);
    this.ctx.clearRect(0, 0, this.canvas.width, this.canvas.height);
  }

  private resize(): void {
    const parent = this.canvas.parentElement;
    if (!parent) return;
    const dpr = Math.min(window.devicePixelRatio || 1, 2);
    const width = parent.clientWidth;
    const height = parent.clientHeight;
    this.canvas.width = Math.max(1, Math.floor(width * dpr));
    this.canvas.height = Math.max(1, Math.floor(height * dpr));
    this.canvas.style.width = `${width}px`;
    this.canvas.style.height = `${height}px`;
  }

  private readonly frame = (now: number) => {
    if (!this.running) return;
    const t = (now - this.start) / 1000;
    this.lookX += (this.targetLookX - this.lookX) * 0.12;
    this.lookY += (this.targetLookY - this.lookY) * 0.12;

    const blinkCycle = t % 3.4;
    if (blinkCycle > 3.18) {
      this.blink = Math.max(0, 1 - (blinkCycle - 3.18) * 12);
    } else if (blinkCycle > 3.08) {
      this.blink = Math.min(1, (blinkCycle - 3.08) * 12);
    } else {
      this.blink = 1;
    }

    const breath = (Math.sin(t * 1.7) + 1) / 2;
    const talk =
      this.expression === "surprise" ? 0.55 : this.expression === "smile" ? 0.08 : 0;
    this.mouth += (talk - this.mouth) * 0.14;

    this.draw({ t, breath });
    this.raf = requestAnimationFrame(this.frame);
  };

  private draw(state: { t: number; breath: number }): void {
    const { width, height } = this.canvas;
    const ctx = this.ctx;
    ctx.clearRect(0, 0, width, height);
    const sample = this.images.get("body");
    if (!sample) return;

    const scale =
      Math.min(width / sample.width, height / sample.height) *
      (0.9 + state.breath * 0.018);
    const drawW = sample.width * scale;
    const drawH = sample.height * scale;
    const baseX = (width - drawW) / 2 + this.lookX * width * 0.03;
    const baseY = (height - drawH) / 2 + height * 0.04 + this.lookY * height * 0.015;

    const headTurn = this.lookX * 0.11;
    const headTilt = this.lookY * 0.06;
    const browLift = this.expression === "surprise" ? -0.012 : this.expression === "smile" ? 0.006 : 0;

    for (const name of DRAW_ORDER) {
      const img = this.images.get(name);
      if (!img) continue;

      let alpha = 1;
      if (name === "eyes_open") alpha = this.blink;
      if (name === "eyes_closed") alpha = 1 - this.blink;
      if (name === "mouth_closed") alpha = 1 - this.mouth;
      if (name === "mouth_open") alpha = this.mouth;
      if (alpha < 0.02) continue;

      ctx.save();
      ctx.globalAlpha = alpha;
      const isHead =
        name !== "body" && name !== "hair_back";
      const cx = baseX + drawW / 2;
      const cy = baseY + drawH * 0.38;
      if (isHead) {
        ctx.translate(cx, cy);
        ctx.rotate(headTurn * 0.35);
        ctx.transform(1, 0, headTurn * 0.18, 1 + headTilt * 0.15, 0, 0);
        ctx.translate(-cx, -cy);
        if (name === "brows") {
          ctx.translate(0, browLift * drawH);
        }
        if (name === "hair_front") {
          ctx.translate(this.lookX * 6, Math.sin(state.t * 1.7) * 3);
        }
      } else if (name === "body") {
        ctx.translate(0, Math.sin(state.t * 1.7) * 5);
      }
      ctx.drawImage(img, baseX, baseY, drawW, drawH);
      ctx.restore();
    }
  }
}
