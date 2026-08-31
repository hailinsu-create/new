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
  private readonly root = new PIXI.Container();
  private model: CubismLive2DModel | null = null;
  private destroyed = false;
  private baseScale = 1;
  private idleEnabled = true;
  private expressionPose: "neutral" | "smile" | "surprise" = "neutral";
  private readonly onTick: () => void;

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

    this.app.stage.addChild(this.root);
    this.onTick = () => this.updateIdle();
    this.app.ticker.add(this.onTick);
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
      this.root.removeChild(this.model);
      this.model.destroy();
    }

    this.model = next;
    this.root.addChild(next);
    this.fitModel();
    this.expressionPose = "neutral";
    this.idleEnabled = true;

    const motions = Object.keys(next.internalModel.motionManager.definitions);
    const settingsExpressions = (
      next.internalModel.settings as {
        expressions?: Array<{ name?: string; Name?: string }>;
      }
    ).expressions;
    const expressionNames =
      settingsExpressions
        ?.map((item) => item.name ?? item.Name)
        .filter((name): name is string => typeof name === "string" && name.length > 0) ??
      [];

    if (motions.includes("Idle")) {
      void next.motion("Idle").catch(() => {
        // Motion file optional; container idle still runs.
      });
    }

    const modelName = url.split("/").pop() ?? url;
    this.onStatus(
      `已加载 ${modelName}\n动作组 ${motions.length} · 表情 ${expressionNames.length}\n整身呼吸晃动已开。表情：${expressionNames.join(", ") || "无"}。脸部细表情仍受单网格限制。`,
      "ok",
    );

    return { modelName, motions, expressions: expressionNames };
  }

  playMotion(group: string): void {
    if (!this.model) return;
    this.idleEnabled = true;
    void this.model.motion(group).catch(() => undefined);
  }

  playExpression(name: string): void {
    if (!this.model) return;
    if (name === "smile" || name === "surprise" || name === "neutral") {
      this.expressionPose = name;
    }
    const manager = this.model.internalModel.motionManager.expressionManager;
    if (!manager) {
      this.onStatus(
        `表情「${name}」已切到网页侧姿态（模型未挂上 ExpressionManager，脸部网格形变不可用）。`,
        "info",
      );
      return;
    }
    void this.model.expression(name).catch((error: unknown) => {
      const message = error instanceof Error ? error.message : String(error);
      this.onStatus(`表情加载失败：${message}`, "error");
    });
  }

  setIdleEnabled(enabled: boolean): void {
    this.idleEnabled = enabled;
  }

  destroy(): void {
    this.destroyed = true;
    this.app.ticker.remove(this.onTick);
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
    this.baseScale = Math.min(width / bounds.width, height / bounds.height) * 0.92;
    this.model.anchor.set(0.5, 0.5);
    this.model.scale.set(this.baseScale);
    this.model.x = 0;
    this.model.y = 0;
    this.model.rotation = 0;
    this.root.x = width / 2;
    this.root.y = height / 2 + height * 0.04;
    this.root.rotation = 0;
    this.root.scale.set(1);
  }

  private updateIdle(): void {
    if (!this.model || !this.idleEnabled) return;
    const t = performance.now() / 1000;
    const breath = Math.sin(t * 1.8) * 0.08;
    const sway = Math.sin(t * 1.05) * 0.14;
    const poseBoost =
      this.expressionPose === "smile"
        ? 0.03
        : this.expressionPose === "surprise"
          ? 0.06
          : 0;

    this.root.scale.set(1 + breath + poseBoost);
    this.root.rotation = sway * 0.55;
    this.root.x =
      this.app.renderer.width / 2 + Math.sin(t * 0.8) * 70;
    this.root.y =
      this.app.renderer.height / 2 +
      this.app.renderer.height * 0.04 +
      Math.sin(t * 1.8) * 34;

    // Also nudge the model itself in case custom Live2D rendering ignores parents.
    this.model.rotation = Math.sin(t * 1.05) * 0.08;
    this.model.y = Math.sin(t * 1.8) * 10;
  }
}
