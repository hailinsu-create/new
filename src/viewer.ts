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
  getDrawableIndex?(drawableId: string): number;
  getDrawableIds?: () => string[];
  getCoreModel?: () => { drawables?: { ids?: string[]; opacities?: Float32Array } };
  _model?: { drawables?: { ids?: string[]; opacities?: Float32Array } };
};

type CharacterPack = {
  displayName?: string;
  lipSync?: { parameter?: string; group?: string };
  layout?: {
    scaleMode?: string;
    scale?: number;
    anchorX?: number;
    anchorY?: number;
  };
};

const DEFAULT_LIP_SYNC = "ParamMouthOpenY";
const MOUTH_DRAWABLE = "mouth_open";
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

function characterUrlFor(model3Url: string): string {
  return model3Url.replace(/[^/]+$/, "character.json");
}

async function loadCharacterPack(model3Url: string): Promise<CharacterPack | null> {
  try {
    const response = await fetch(characterUrlFor(model3Url));
    if (!response.ok) return null;
    return (await response.json()) as CharacterPack;
  } catch {
    return null;
  }
}

export class Live2DViewer {
  private readonly app: Application;
  private readonly onStatus: ViewerOptions["onStatus"];
  private readonly root = new PIXI.Container();
  private model: CubismLive2DModel | null = null;
  private character: CharacterPack | null = null;
  private lipSyncParam = DEFAULT_LIP_SYNC;
  private destroyed = false;
  private talking = false;
  private mouthHold = 0;
  private readonly onTick: () => void;
  private resizeObserver: ResizeObserver | null = null;

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

    Live2DModel.registerTicker(PIXI.Ticker);

    this.app.stage.addChild(this.root);
    this.onTick = () => this.updateTalk();
    this.app.ticker.add(this.onTick, undefined, PIXI.UPDATE_PRIORITY.LOW);
    window.addEventListener("resize", this.handleResize);
    const host = options.canvas.parentElement;
    if (host && typeof ResizeObserver !== "undefined") {
      this.resizeObserver = new ResizeObserver(() => this.fitModel());
      this.resizeObserver.observe(host);
    }
  }

  async load(url: string): Promise<LoadResult> {
    this.onStatus(`正在加载：${url}`, "info");
    this.character = await loadCharacterPack(url);
    this.lipSyncParam = this.character?.lipSync?.parameter ?? DEFAULT_LIP_SYNC;

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
    this.mouthHold = 0;
    this.fitModel();
    requestAnimationFrame(() => this.fitModel());
    const core = coreModelOf(next);
    if (core) this.setMouthOpen(core, 0);

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

    const who = this.character?.displayName ?? url.split("/").pop() ?? url;
    this.onStatus(
      `已加载 ${who}\n动作组 ${motions.join(", ") || "无"} · 表情 ${expressionNames.join(", ") || "无"}\n口型 ${this.lipSyncParam}（character.json LipSync）。`,
      "ok",
    );

    return { modelName: who, motions, expressions: expressionNames };
  }

  playMotion(group: string): void {
    if (!this.model) return;
    this.talking = group === "Talk";
    if (!this.talking) this.mouthHold = 0;
    void this.model.motion(group).catch(() => undefined);
    if (!this.talking) {
      const core = coreModelOf(this.model);
      if (core) this.setMouthOpen(core, 0);
    }
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
    const core = coreModelOf(this.model);
    if (this.talking) {
      this.mouthHold = 0;
      void this.model.motion("Talk").catch(() => undefined);
    } else {
      void this.model.motion("Idle").catch(() => undefined);
      this.mouthHold = name === "surprise" ? 0.35 : 0;
      if (core) this.setMouthOpen(core, this.mouthHold);
    }
  }

  setIdleEnabled(_enabled: boolean): void {
    // Idle is the model motion, not a container transform.
  }

  destroy(): void {
    this.destroyed = true;
    this.app.ticker.remove(this.onTick);
    this.resizeObserver?.disconnect();
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

  /**
   * pixi-live2d-display sizes the sprite by moc3 canvas pixels (1536×1024).
   * Do not use Mao min(view, 3000), and do not rely on Live2DModel.anchor:
   * if pivot is still 0, the bust sits in the bottom-right corner.
   */
  private fitModel(): void {
    if (!this.model) return;
    const host = this.app.view.parentElement;
    const width = host?.clientWidth || this.app.renderer.width;
    const height = host?.clientHeight || this.app.renderer.height;
    if (width < 32 || height < 32) return;

    const iw = this.model.internalModel.width || 1;
    const ih = this.model.internalModel.height || 1;
    const bust = this.character?.layout?.scaleMode === "portraitBust";
    const bodyFrac = bust ? 0.52 : 1;
    const scale = Math.min(width / (iw * bodyFrac), height / ih) * 0.9;
    const safe = Number.isFinite(scale) && scale > 0 ? scale : 1;

    this.model.anchor.set(0, 0);
    this.model.pivot.set(0, 0);
    this.model.scale.set(safe);
    this.model.rotation = 0;
    this.root.position.set(0, 0);
    this.root.scale.set(1);
    this.root.rotation = 0;
    this.model.position.set(width / 2 - (iw * safe) / 2, height / 2 - (ih * safe) / 2);
  }

  private setMouthOpen(core: CubismCoreModel, value: number): void {
    core.setParameterValueById(this.lipSyncParam, value);
    const drawables = core.getCoreModel?.()?.drawables ?? core._model?.drawables;
    const opacities = drawables?.opacities;
    if (!opacities) return;
    let index = typeof core.getDrawableIndex === "function" ? core.getDrawableIndex(MOUTH_DRAWABLE) : -1;
    if (index < 0) {
      const ids = core.getDrawableIds?.() ?? drawables.ids;
      if (ids) index = Array.from(ids).indexOf(MOUTH_DRAWABLE);
    }
    if (index < 0 || index >= opacities.length) return;
    opacities[index] = value;
  }

  private updateTalk(): void {
    if (!this.model) return;
    const core = coreModelOf(this.model);
    if (!core) return;
    if (!this.talking) {
      this.setMouthOpen(core, this.mouthHold);
      return;
    }
    this.setMouthOpen(core, Math.min(1, 0.55 + pulse * 0.45));
  }
}
