export type ArtPreviewHandles = {
  setStatus: (message: string, kind: "info" | "ok" | "error") => void;
};

/**
 * Until moc3 exists, show our original character art with light motion.
 * This is not Live2D; it keeps the project centered on 墨汐.
 */
export class MoxiArtPreview {
  private readonly canvas: HTMLCanvasElement;
  private readonly ctx: CanvasRenderingContext2D;
  private readonly img = new Image();
  private readonly setStatus: ArtPreviewHandles["setStatus"];
  private raf = 0;
  private start = performance.now();
  private pointerX = 0.5;
  private pointerY = 0.5;
  private running = false;
  private readonly onPointerMove: (event: PointerEvent) => void;
  private readonly onResize: () => void;

  constructor(canvas: HTMLCanvasElement, handles: ArtPreviewHandles) {
    const ctx = canvas.getContext("2d");
    if (!ctx) throw new Error("2D canvas unavailable");
    this.canvas = canvas;
    this.ctx = ctx;
    this.setStatus = handles.setStatus;

    this.onPointerMove = (event: PointerEvent) => {
      const rect = this.canvas.getBoundingClientRect();
      if (rect.width <= 0 || rect.height <= 0) return;
      this.pointerX = (event.clientX - rect.left) / rect.width;
      this.pointerY = (event.clientY - rect.top) / rect.height;
    };
    this.onResize = () => this.resize();
  }

  async show(url: string): Promise<void> {
    this.stopLoop();
    this.setStatus("正在载入墨汐立绘…", "info");
    await this.loadImage(url);
    this.resize();
    this.canvas.addEventListener("pointermove", this.onPointerMove);
    window.addEventListener("resize", this.onResize);
    this.running = true;
    this.start = performance.now();
    this.raf = requestAnimationFrame(this.frame);
    this.setStatus(
      "墨汐立绘预览（原创）\n下一步：按 characters/moxi/cubism/BINDING_CHECKLIST.md 在 Cubism 绑定并导出 moc3。\n指针移动会有轻微视差，还不是 Live2D 网格。",
      "ok",
    );
  }

  destroy(): void {
    this.stopLoop();
    this.canvas.removeEventListener("pointermove", this.onPointerMove);
    window.removeEventListener("resize", this.onResize);
    this.ctx.clearRect(0, 0, this.canvas.width, this.canvas.height);
  }

  private loadImage(url: string): Promise<void> {
    return new Promise((resolve, reject) => {
      this.img.onload = () => resolve();
      this.img.onerror = () => reject(new Error(`无法加载立绘：${url}`));
      this.img.src = url;
    });
  }

  private stopLoop(): void {
    this.running = false;
    if (this.raf) cancelAnimationFrame(this.raf);
    this.raf = 0;
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
    const { width, height } = this.canvas;
    const ctx = this.ctx;
    ctx.clearRect(0, 0, width, height);

    const breath = Math.sin(t * 1.4) * 0.008;
    const lookX = (this.pointerX - 0.5) * 0.04;
    const lookY = (this.pointerY - 0.5) * 0.03;
    const scale = Math.min(width / this.img.width, height / this.img.height) * (0.9 + breath);
    const drawW = this.img.width * scale;
    const drawH = this.img.height * scale;
    const x = (width - drawW) / 2 + lookX * width;
    const y = (height - drawH) / 2 + height * 0.03 + lookY * height;

    ctx.save();
    ctx.globalAlpha = 0.98;
    ctx.drawImage(this.img, x, y, drawW, drawH);
    ctx.restore();

    this.raf = requestAnimationFrame(this.frame);
  };
}
