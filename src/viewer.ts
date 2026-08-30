import type { Application } from "pixi.js";
import * as PIXI from "pixi.js";
import { Live2DModel } from "pixi-live2d-display/cubism4";

export type LoadResult = {
  modelName: string;
  motions: string[];
  expressions: string[];
};

type ViewerOptions = {
  canvas: HTMLCanvasElement;
  onStatus: (message: string, kind: "info" | "ok" | "error") => void;
};

type CubismLive2DModel = Awaited<ReturnType<typeof Live2DModel.from>>;

function hasCubismCore(): boolean {
  const core = (window as Window & { Live2DCubismCore?: unknown }).Live2DCubismCore;
  return typeof core !== "undefined";
}

export class Live2DViewer {
  private readonly app: Application;
  private readonly onStatus: ViewerOptions["onStatus"];
  private model: CubismLive2DModel | null = null;
  private destroyed = false;

  constructor(options: ViewerOptions) {
    if (!hasCubismCore()) {
      throw new Error(
        "未找到 Live2DCubismCore。请先运行 npm run fetch-core，再刷新页面。",
      );
    }

    (window as Window & { PIXI?: typeof PIXI }).PIXI = PIXI;

    this.onStatus = options.onStatus;
    this.app = new PIXI.Application({
      view: options.canvas,
      autoStart: true,
      backgroundAlpha: 0,
      antialias: true,
      resolution: Math.min(window.devicePixelRatio || 1, 2),
      resizeTo: options.canvas.parentElement ?? undefined,
    });

    window.addEventListener("resize", this.handleResize);
  }

  async load(url: string): Promise<LoadResult> {
    this.onStatus(`正在加载：${url}`, "info");
    const next = await Live2DModel.from(url, {
      autoInteract: true,
    });

    if (this.destroyed) {
      next.destroy();
      throw new Error("Viewer already destroyed");
    }

    if (this.model) {
      this.app.stage.removeChild(this.model);
      this.model.destroy();
    }

    this.model = next;
    this.app.stage.addChild(next);
    this.fitModel();

    const motions = Object.keys(next.internalModel.motionManager.definitions);
    const expressions = Object.keys(
      next.internalModel.motionManager.expressionManager?.definitions ?? {},
    );

    const modelName = url.split("/").pop() ?? url;
    this.onStatus(
      `已加载 ${modelName}\n动作组 ${motions.length} · 表情 ${expressions.length}\n拖动指针可看视线跟随；点角色可触发 hit。`,
      "ok",
    );

    return { modelName, motions, expressions };
  }

  playMotion(group: string): void {
    if (!this.model) return;
    void this.model.motion(group);
  }

  playExpression(name: string): void {
    if (!this.model) return;
    void this.model.expression(name);
  }

  destroy(): void {
    this.destroyed = true;
    window.removeEventListener("resize", this.handleResize);
    if (this.model) {
      this.model.destroy();
      this.model = null;
    }
    this.app.destroy(true, { children: true });
  }

  private readonly handleResize = () => {
    this.fitModel();
  };

  private fitModel(): void {
    if (!this.model) return;
    const { width, height } = this.app.renderer;
    const bounds = this.model.getLocalBounds();
    const scale = Math.min(width / bounds.width, height / bounds.height) * 0.92;
    this.model.anchor.set(0.5, 0.5);
    this.model.scale.set(scale);
    this.model.x = width / 2;
    this.model.y = height / 2 + height * 0.04;
  }
}
