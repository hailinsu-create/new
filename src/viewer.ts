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

type CubismCoreModel = {
  setParameterValueById(parameterId: string, value: number, weight?: number): void;
};

const LIP_SYNC_PARAM = "ParamMouthOpenY";
const TALK_EXPRESSIONS = new Set(["talk"]);

function hasCubismCore(): boolean {
  const core = (window as Window & { Live2DCubismCore?: unknown }).Live2DCubismCore;
  return typeof core !== "undefined";
}

function isCubismCoreModel(value: unknown): value is CubismCoreModel {
  if (typeof value !== "object" || value === null) return false;
  const record = value as Record<string, unknown>;
  return typeof record.setParameterValueById === "function";
}

function coreModelOf(model: CubismLive2DModel): CubismCoreModel | null {
  const core = model.internalModel.coreModel;
  return isCubismCoreModel(core) ? core : null;
}

export class Live2DViewer {
  private readonly app: Application;
  private readonly onStatus: ViewerOptions["onStatus"];
  private readonly root = new PIXI.Container();
  private model: CubismLive2DModel | null = null;
  private destroyed = false;
  private talking = false;
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
    this.onTick = () => this.updateTalk();
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
    this.talking = false;
    this.fitModel();

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
      void next.motion("Idle").catch(() => undefined);
    }

    const modelName = url.split("/").pop() ?? url;
    this.onStatus(
      `已加载 ${modelName}\n动作组 ${motions.join(", ") || "无"} · 表情 ${expressionNames.join(", ") || "无"}\n口型走 LipSync / ${LIP_SYNC_PARAM}。Idle 用模型动作，不再整张图摇摆。`,
      "ok",
    );

    return { modelName, motions, expressions: expressionNames };
  }

  playMotion(group: string): void {
    if (!this.model) return;
    this.talking = group === "Talk";
    void this.model.motion(group).catch(() => undefined);
  }

  playExpression(name: string): void {
    if (!this.model) return;
    this.talking = TALK_EXPRESSIONS.has(name);
    const manager = this.model.internalModel.motionManager.expressionManager;
    if (manager) {
      void this.model.expression(name).catch((error: unknown) => {
        const message = error instanceof Error ? error.message : String(error);
        this.onStatus(`表情加载失败：${message}`, "error");
      });
    }
    if (this.talking) {
      void this.model.motion("Talk").catch(() => undefined);
    } else {
      void this.model.motion("Idle").catch(() => undefined);
      const core = coreModelOf(this.model);
      if (core && name !== "surprise") {
        core.setParameterValueById(LIP_SYNC_PARAM, 0);
      }
    }
  }

  setIdleEnabled(_enabled: boolean): void {
    // Idle is the model motion, not a container transform.
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
    const scale = Math.min(width / bounds.width, height / bounds.height) * 0.92;
    this.model.anchor.set(0.5, 0.52);
    this.model.scale.set(scale);
    this.model.x = 0;
    this.model.y = 0;
    this.model.rotation = 0;
    this.root.x = width / 2;
    this.root.y = height / 2 + height * 0.02;
    this.root.rotation = 0;
    this.root.scale.set(1);
  }

  private updateTalk(): void {
    if (!this.model || !this.talking) return;
    const core = coreModelOf(this.model);
    if (!core) return;
    const seconds = performance.now() / 1000;
    const pulse = Math.abs(Math.sin(seconds * 8.4));
    const envelope = 0.45 + 0.55 * (0.5 + 0.5 * Math.sin(seconds * 2.2));
    core.setParameterValueById(LIP_SYNC_PARAM, Math.min(1, 0.12 + pulse * envelope));
  }
}
