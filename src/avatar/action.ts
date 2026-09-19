/**
 * Full-body performance clips: nod, bow, hop, step, shy, and speech afterglow.
 * Tuned in-place by MOTION.action / MOTION.fx across rounds 121–220.
 */
import {
  MOTION,
  clamp,
  createRng,
  easeSmooth,
  type ExpressionName,
  type StrandState,
} from "./motion.ts";

export const ACTION_IDS = [
  "rest",
  "nod",
  "sideTurn",
  "bow",
  "weightShift",
  "tiptoe",
  "gesture",
  "step",
  "walkPrep",
  "shyDown",
  "surpriseBack",
  "hop",
  "sighSink",
  "afterBow",
] as const;

export type ActionId = (typeof ACTION_IDS)[number];

export const ACTION_LABELS: Record<ActionId, string> = {
  rest: "静立",
  nod: "点头",
  sideTurn: "侧身",
  bow: "微鞠躬",
  weightShift: "移重心",
  tiptoe: "踮脚",
  gesture: "手势",
  step: "踏步",
  walkPrep: "欲走",
  shyDown: "害羞低头",
  surpriseBack: "讶异后仰",
  hop: "轻跳",
  sighSink: "叹气沉肩",
  afterBow: "说完鞠躬",
};

export const ACTION_BUTTONS: ActionId[] = [
  "nod",
  "sideTurn",
  "bow",
  "weightShift",
  "tiptoe",
  "gesture",
  "step",
  "shyDown",
  "surpriseBack",
  "hop",
  "sighSink",
];

export type PerformanceState = {
  action: ActionId;
  amount: number;
  headPitch: number;
  headYaw: number;
  torsoLean: number;
  extraWeight: number;
  hopY: number;
  plantLift: number;
  stepPhase: number;
  stepL: number;
  stepR: number;
  shoulderL: number;
  shoulderR: number;
  skirtKick: number;
  shawlFlip: number;
  tasselKick: number;
  lookX: number;
  lookY: number;
  blushAdd: number;
  mouthAdd: number;
  browAdd: number;
  breathBoost: number;
  hairKick: number;
  napeKick: number;
  clothDrag: number;
};

type Rng = ReturnType<typeof createRng>;

export function emptyPerformance(): PerformanceState {
  return {
    action: "rest",
    amount: 0,
    headPitch: 0,
    headYaw: 0,
    torsoLean: 0,
    extraWeight: 0,
    hopY: 0,
    plantLift: 0,
    stepPhase: 0,
    stepL: 0,
    stepR: 0,
    shoulderL: 0,
    shoulderR: 0,
    skirtKick: 0,
    shawlFlip: 0,
    tasselKick: 0,
    lookX: 0,
    lookY: 0,
    blushAdd: 0,
    mouthAdd: 0,
    browAdd: 0,
    breathBoost: 0,
    hairKick: 0,
    napeKick: 0,
    clothDrag: 0,
  };
}

export function actionEnvelope(u: number, easeIn: number, easeOut: number): number {
  const a = Math.max(0.04, easeIn);
  const b = Math.max(0.04, easeOut);
  if (u <= 0 || u >= 1) return 0;
  if (u < a) return easeSmooth(u / a);
  if (u > 1 - b) return easeSmooth((1 - u) / b);
  return 1;
}

function bowShape(u: number): number {
  if (u < 0.42) return easeSmooth(u / 0.42);
  if (u < 0.58) return 1;
  return 1 - easeSmooth((u - 0.58) / 0.42);
}

function hopShape(u: number): number {
  if (u < 0.38) return Math.sin((u / 0.38) * Math.PI * 0.5);
  if (u < 0.52) return 1;
  return Math.max(0, Math.cos(((u - 0.52) / 0.48) * Math.PI * 0.5));
}

function mixPerf(a: PerformanceState, b: PerformanceState, t: number): PerformanceState {
  const out = emptyPerformance();
  out.action = t > 0.45 ? b.action : a.action;
  const keys = Object.keys(a) as Array<keyof PerformanceState>;
  for (const key of keys) {
    if (key === "action") continue;
    const av = a[key];
    const bv = b[key];
    if (typeof av === "number" && typeof bv === "number") {
      (out[key] as number) = av + (bv - av) * t;
    }
  }
  return out;
}

function durationOf(id: ActionId): number {
  const a = MOTION.action;
  switch (id) {
    case "nod":
      return a.nodDur;
    case "sideTurn":
      return a.sideDur;
    case "bow":
      return a.bowDur;
    case "weightShift":
      return a.weightDur;
    case "tiptoe":
      return a.tiptoeDur;
    case "gesture":
      return a.gestureDur;
    case "step":
      return a.stepDur;
    case "walkPrep":
      return a.walkPrepDur;
    case "shyDown":
      return a.shyDur;
    case "surpriseBack":
      return a.surpriseDur;
    case "hop":
      return a.hopDur;
    case "sighSink":
      return a.sighDur;
    case "afterBow":
      return a.bowDur * 0.82;
    default:
      return 0.6;
  }
}

export class ActionDirector {
  current: ActionId = "rest";
  private rng: Rng;
  private t = 0;
  private dur = 1;
  private nextAt = 4.8;
  private queued: ActionId | null = null;
  private sideSign = 1;
  private clickIndex = 0;
  private kicked = false;
  private lastExpr: ExpressionName = "neutral";
  private wasSpeaking = false;
  private visemeOpen = 0;
  private speechEndLock = false;
  private prev = emptyPerformance();
  private tail = emptyPerformance();
  private tailAmt = 0;
  lastHairKick = 0;
  lastNapeKick = 0;

  constructor(seed = 0xa071) {
    this.rng = createRng(seed);
  }

  reset(seed?: number): void {
    if (seed != null) this.rng = createRng(seed);
    this.current = "rest";
    this.t = 0;
    this.dur = 1;
    this.nextAt = 3.4 + this.rng.range(0, 3);
    this.queued = null;
    this.sideSign = 1;
    this.clickIndex = 0;
    this.kicked = false;
    this.lastExpr = "neutral";
    this.wasSpeaking = false;
    this.visemeOpen = 0;
    this.speechEndLock = false;
    this.prev = emptyPerformance();
    this.tail = emptyPerformance();
    this.tailAmt = 0;
    this.lastHairKick = 0;
    this.lastNapeKick = 0;
  }

  play(id: ActionId, force = false): boolean {
    if (MOTION.action.enabled <= 0) return false;
    if (id === "rest") return false;
    if (this.current !== "rest" && this.t < this.dur - 0.12 && !force) {
      this.queued = id;
      return false;
    }
    this.start(id);
    return true;
  }

  onClick(): ActionId | null {
    if (MOTION.action.clickEnabled <= 0) return null;
    const list = ACTION_BUTTONS;
    let id: ActionId;
    if (MOTION.action.clickCycle > 0) {
      id = list[this.clickIndex % list.length];
      this.clickIndex += 1;
    } else {
      id = list[Math.floor(this.rng.next() * list.length)] ?? "nod";
    }
    this.play(id, true);
    return id;
  }

  onExpression(name: ExpressionName): void {
    if (name === this.lastExpr) return;
    this.lastExpr = name;
    const a = MOTION.action;
    if (name === "shy" && a.shyExpr > 0) this.play("shyDown", true);
    if (name === "surprise" && a.surpriseExpr > 0) this.play("surpriseBack", true);
    if (name === "laugh" && a.laughHop > 0) this.play("hop", true);
    if (name === "sad" && a.sadSigh > 0) this.play("sighSink", true);
    if (name === "smile" && a.smileTiptoe > 0) this.play("tiptoe", false);
  }

  onSpeechEnd(): void {
    if (this.speechEndLock) return;
    this.speechEndLock = true;
    const a = MOTION.action;
    if (a.afterBowProb > 0 && this.rng.chance(a.afterBowProb)) {
      this.play("afterBow", true);
    } else if (a.weightBetween > 0) {
      this.play("weightShift", false);
    }
  }

  onViseme(id: string, energy: number, speaking: boolean): void {
    if (!speaking) {
      this.visemeOpen *= 0.7;
      return;
    }
    const open = id === "A" || id === "O" || id === "E" ? 1 : id === "U" || id === "I" ? 0.45 : 0.15;
    this.visemeOpen += (open * energy - this.visemeOpen) * 0.35;
  }

  step(
    dt: number,
    seconds: number,
    input: {
      speaking: boolean;
      energy: number;
      expression: ExpressionName;
      lookX: number;
      lookY: number;
    },
  ): PerformanceState {
    const a = MOTION.action;
    if (a.enabled <= 0) return emptyPerformance();

    if (input.speaking) this.speechEndLock = false;
    if (this.wasSpeaking && !input.speaking) this.onSpeechEnd();
    this.wasSpeaking = input.speaking;

    if (this.current !== "rest") {
      this.t += dt;
      if (this.t >= this.dur) {
        this.tail = this.prev;
        this.tailAmt = Math.max(0.02, a.blend);
        this.current = "rest";
        this.t = 0;
        if (this.queued) {
          const next = this.queued;
          this.queued = null;
          this.start(next);
        } else {
          this.nextAt = seconds + this.rng.range(a.gapMin, a.gapMax) * a.idleGapScale;
        }
      }
    }

    if (
      this.current === "rest" &&
      a.autoIdle > 0 &&
      !input.speaking &&
      input.expression === "neutral" &&
      seconds >= this.nextAt
    ) {
      const pick = this.pickIdle(input.speaking);
      if (pick) this.start(pick);
      else this.nextAt = seconds + this.rng.range(a.gapMin, a.gapMax) * a.idleGapScale;
    }

    const u = this.current === "rest" ? 1 : clamp(this.t / Math.max(0.08, this.dur), 0, 1);
    let clip = this.evaluate(this.current, u, seconds, input);

    if (input.speaking) {
      const wave = Math.sin(seconds * 6.2) * input.energy;
      clip.shoulderL += wave * a.speakShoulder;
      clip.shoulderR += Math.sin(seconds * 6.2 + 0.4) * input.energy * a.speakShoulder * 0.8;
      clip.extraWeight += Math.sin(seconds * 2.4) * a.speakWeight * input.energy;
      clip.headPitch += Math.sin(seconds * 5.1) * a.visemeNod * input.energy;
      clip.shoulderL += this.visemeOpen * a.visemeShoulder;
      clip.shoulderR += this.visemeOpen * a.visemeShoulder * 0.85;
      if (a.preferNodSpeak > 0 && this.current === "rest") {
        clip.headPitch += Math.sin(seconds * 4.6) * a.nodAmp * 0.22 * input.energy;
      }
    }

    clip.headYaw += input.lookX * a.dragHead;
    clip.lookX += input.lookX * a.lookLead * 0.15;

    if (this.tailAmt > 0 && a.blend > 0) {
      this.tailAmt *= Math.exp(-dt / Math.max(0.04, a.blend));
      if (this.tailAmt < 0.02) this.tailAmt = 0;
      else clip = mixPerf(this.tail, clip, 1 - this.tailAmt);
    }

    clip = this.limit(clip, dt);
    this.prev = clip;
    this.lastHairKick = clip.hairKick;
    this.lastNapeKick = clip.napeKick;
    return clip;
  }

  debug(): { action: ActionId; t: number; dur: number; nextAt: number } {
    return { action: this.current, t: this.t, dur: this.dur, nextAt: this.nextAt };
  }

  private start(id: ActionId): void {
    this.current = id;
    this.t = 0;
    this.dur = Math.max(0.2, durationOf(id));
    this.kicked = false;
    if (id === "sideTurn") {
      this.sideSign = MOTION.action.sideSignRandom > 0 ? (this.rng.chance(0.5) ? -1 : 1) : -this.sideSign;
    }
  }

  private pickIdle(speaking: boolean): ActionId | null {
    const a = MOTION.action;
    const items: Array<{ id: ActionId; w: number }> = [
      { id: "nod", w: a.nodProb },
      { id: "sideTurn", w: a.sideProb },
      { id: "bow", w: a.playlistBow > 0 ? a.bowProb : 0 },
      { id: "weightShift", w: a.weightProb },
      { id: "tiptoe", w: a.tiptoeProb },
      { id: "gesture", w: a.playlistGesture > 0 ? a.gestureProb : 0 },
      { id: "step", w: a.playlistStep > 0 ? a.stepProb : 0 },
      { id: "walkPrep", w: a.walkPrepProb },
      { id: "shyDown", w: a.playlistShy > 0 ? a.shyProb : 0 },
      { id: "surpriseBack", w: a.surpriseProb },
      { id: "hop", w: a.playlistHop > 0 ? a.hopProb : 0 },
      { id: "sighSink", w: a.sighProb },
    ];
    let filtered = items.filter((item) => item.w > 0.001);
    if (speaking && a.noHopSpeak > 0) filtered = filtered.filter((item) => item.id !== "hop");
    if (speaking && a.preferNodSpeak > 0) {
      filtered = filtered.map((item) => (item.id === "nod" ? { ...item, w: item.w * 1.8 } : item));
    }
    const total = filtered.reduce((s, item) => s + item.w, 0);
    if (total <= 0) return null;
    let pick = this.rng.next() * total;
    for (const item of filtered) {
      pick -= item.w;
      if (pick <= 0) return item.id;
    }
    return filtered[0]?.id ?? null;
  }

  private evaluate(
    id: ActionId,
    u: number,
    seconds: number,
    _input: { speaking: boolean; energy: number; expression: ExpressionName; lookX: number; lookY: number },
  ): PerformanceState {
    const p = emptyPerformance();
    p.action = id;
    const a = MOTION.action;
    const env = actionEnvelope(u, a.easeIn, a.easeOut);
    p.amount = id === "rest" ? 0 : env;
    const kickOnce = (flag: "hair" | "nape", mag: number) => {
      if (this.kicked || mag === 0) return;
      if (u > 0.42 && u < 0.62) {
        if (flag === "hair") p.hairKick = mag;
        else p.napeKick = mag;
        this.kicked = true;
      }
    };

    switch (id) {
      case "nod": {
        p.headPitch = a.nodAmp * Math.sin(u * Math.PI * 2) * (0.35 + 0.65 * env);
        p.lookY = p.headPitch * 0.45;
        kickOnce("hair", a.nodHair * 0.035);
        break;
      }
      case "sideTurn": {
        p.headYaw = a.sideAmp * Math.sin(u * Math.PI) * this.sideSign * env;
        p.lookX = p.headYaw * a.sideLook;
        p.torsoLean = p.headYaw * 0.22;
        p.shawlFlip = p.headYaw * a.shawlFlipAmp;
        p.extraWeight = p.headYaw * 0.35;
        break;
      }
      case "bow": {
        const b = bowShape(u);
        p.headPitch = a.bowAmp * b;
        p.torsoLean = a.bowAmp * 0.95 * b;
        p.lookY = a.bowAmp * 0.72 * b;
        p.skirtKick = a.bowSkirt * b;
        p.extraWeight = 0.22 * b;
        p.shawlFlip = a.bowAmp * 0.35 * b;
        kickOnce("hair", a.bowHair * 0.04);
        break;
      }
      case "weightShift": {
        const w = Math.sin(u * Math.PI) * env;
        p.extraWeight = a.weightAmp * w;
        p.shawlFlip = w * a.shawlFlipAmp * 0.6;
        p.torsoLean = w * 0.03;
        p.headYaw = w * 0.04;
        break;
      }
      case "tiptoe": {
        const w = Math.sin(u * Math.PI) * env;
        p.plantLift = a.tiptoeAmp * w;
        p.hopY = a.tiptoeAmp * 0.35 * w;
        p.stepL = w * a.tiptoeLeg * 0.04;
        p.stepR = -w * a.tiptoeLeg * 0.02;
        p.lookY = -0.06 * w;
        break;
      }
      case "gesture": {
        const g = Math.sin(u * Math.PI * 2) * env;
        p.shoulderL = a.gestureAmp * g;
        p.shoulderR = a.gestureAmp * -g * 0.55;
        p.shawlFlip = g * a.shawlFlipAmp;
        p.tasselKick = g * a.gestureTassel * 0.08;
        p.headYaw = g * 0.03;
        break;
      }
      case "step": {
        const phase = u * Math.PI * 2 * a.stepHz * a.stepDur * 0.35;
        p.stepPhase = phase;
        p.stepL = Math.sin(phase) * a.stepAmp;
        p.stepR = Math.sin(phase + Math.PI) * a.stepAmp;
        p.extraWeight = Math.sin(phase) * a.stepAmp * 8 * a.stepHip * a.hipStep;
        p.plantLift = Math.abs(Math.sin(phase)) * a.stepAmp * a.stepPlant * 0.7;
        p.skirtKick = Math.sin(phase * 2) * a.stepAmp * 1.35;
        p.headYaw = Math.sin(phase) * 0.03;
        p.shawlFlip = Math.sin(phase) * a.shawlFlipAmp * 0.45;
        break;
      }
      case "walkPrep": {
        const w = bowShape(u);
        p.extraWeight = a.walkPrepAmp * 4 * w;
        p.plantLift = a.walkPrepAmp * 0.25 * w;
        p.lookY = a.walkLookY * w;
        p.headPitch = 0.03 * w;
        p.torsoLean = 0.04 * w;
        p.stepL = 0.02 * w;
        break;
      }
      case "shyDown": {
        const b = bowShape(u);
        p.headPitch = a.shyAmp * b;
        p.torsoLean = a.shyAmp * 0.45 * b;
        p.lookY = a.shyLookY * b;
        p.lookX = 0.16 * b * this.sideSign;
        p.blushAdd = a.shyBlush * b;
        p.mouthAdd = 0.08 * b;
        p.extraWeight = 0.12 * b;
        break;
      }
      case "surpriseBack": {
        const b = Math.sin(u * Math.PI) * env;
        p.torsoLean = -a.surpriseAmp * b;
        p.headPitch = -a.surpriseAmp * 0.45 * b;
        p.hopY = a.hopAmp * a.surpriseHop * b;
        p.plantLift = p.hopY * 0.4;
        p.browAdd = 0.2 * b;
        p.lookY = -0.08 * b;
        p.skirtKick = 0.04 * b;
        break;
      }
      case "hop": {
        const h = hopShape(u);
        const cap = Math.min(a.hopCap, a.capHop);
        p.hopY = cap * h;
        p.plantLift = p.hopY * 0.28;
        p.skirtKick = 0;
        if (u > 0.5) p.skirtKick = -a.hopSkirt * hopShape(Math.min(1, (u - 0.5) * 2));
        else p.skirtKick = a.hopSkirt * (0.45 + 0.55 * h);
        p.clothDrag = a.clothDrag * h;
        p.extraWeight = Math.sin(u * Math.PI * 2) * 0.28;
        p.shawlFlip = Math.sin(u * Math.PI) * 0.12;
        if (!this.kicked && u > 0.4 && u < 0.62) {
          p.napeKick = a.hopNape * 0.05;
          p.hairKick = a.hopNape * 0.03;
          this.kicked = true;
        }
        if (a.fireflyOnHop > 0 && u > 0.2 && u < 0.4) p.amount = Math.max(p.amount, 0.8);
        break;
      }
      case "sighSink": {
        const b = bowShape(u);
        p.shoulderL = -a.sighAmp * b;
        p.shoulderR = -a.sighAmp * b * 0.92;
        p.headPitch = a.sighAmp * 0.7 * b;
        p.torsoLean = a.sighAmp * 0.5 * b;
        p.breathBoost = a.sighBreath * b;
        p.lookY = 0.1 * b;
        p.browAdd = -0.08 * b;
        p.mouthAdd = -0.05 * b;
        break;
      }
      case "afterBow": {
        const b = bowShape(u);
        p.headPitch = a.afterBowAmp * b;
        p.torsoLean = a.afterBowAmp * 0.8 * b;
        p.lookY = a.afterBowLook * b;
        p.mouthAdd = 0.06 * b;
        p.skirtKick = a.bowSkirt * 0.6 * b;
        break;
      }
      default:
        break;
    }

    if (a.shawlPhase > 0 && p.shawlFlip !== 0) {
      p.shawlFlip *= 1 + 0.08 * Math.sin(seconds * 2.1);
    }
    return p;
  }

  private limit(clip: PerformanceState, dt: number): PerformanceState {
    const a = MOTION.action;
    clip.hopY = clamp(clip.hopY, 0, Math.min(a.hopCap, a.capHop));
    clip.plantLift = clamp(clip.plantLift, 0, Math.min(a.hopCap, a.capHop) * 1.2);
    clip.torsoLean = clamp(clip.torsoLean, -a.capBow, a.capBow);
    clip.headPitch = clamp(clip.headPitch, -a.capBow, a.capBow);
    clip.headYaw = clamp(clip.headYaw, -a.capBow * 1.4, a.capBow * 1.4);
    clip.skirtKick = clamp(clip.skirtKick, -a.capSkirt, a.capSkirt);
    clip.extraWeight = clamp(clip.extraWeight, -1.2, 1.2);
    if (a.jerkLimit > 0 && dt > 0) {
      const maxD = a.jerkLimit * dt;
      clip.headPitch = clamp(clip.headPitch, this.prev.headPitch - maxD, this.prev.headPitch + maxD);
      clip.headYaw = clamp(clip.headYaw, this.prev.headYaw - maxD, this.prev.headYaw + maxD);
      clip.torsoLean = clamp(clip.torsoLean, this.prev.torsoLean - maxD, this.prev.torsoLean + maxD);
      const hopRate = a.hopJerk > 0 ? a.hopJerk : Math.max(0.55, a.jerkLimit * 0.28);
      const hopD = hopRate * dt;
      clip.hopY = clamp(clip.hopY, this.prev.hopY - hopD, this.prev.hopY + hopD);
    }
    if (a.alignGuard > 0 && a.mouthFollow <= 0) {
      /* mouth stays painted in plate space; head slices carry it. */
    }
    return clip;
  }
}

export function collideTasselHem(tassel: StrandState, hem: StrandState, dt: number): void {
  const k = MOTION.action.tasselHit;
  if (k <= 0) return;
  const diff = tassel.angle - hem.angle;
  const span = 0.055;
  if (Math.abs(diff) >= span) return;
  const push = (span - Math.abs(diff)) * k * 10;
  const sign = diff >= 0 ? 1 : -1;
  tassel.velocity += sign * push * dt * 60;
  hem.velocity -= sign * push * 0.42 * dt * 60;
}

export type ActionClipMetrics = {
  id: ActionId;
  peakPitch: number;
  peakYaw: number;
  peakLean: number;
  peakHop: number;
  peakWeight: number;
  peakSkirt: number;
  rms: number;
};

export type ActionSimResult = {
  clips: Record<string, ActionClipMetrics>;
  nodPeak: number;
  bowPeak: number;
  hopPeak: number;
  stepRms: number;
  shyPeak: number;
  surprisePeak: number;
  weightPeak: number;
  skirtHopPeak: number;
  autoCount: number;
  autoKinds: number;
  afterBow: number;
  speakShoulderRms: number;
  maxHeadPitch: number;
  maxHopY: number;
  maxLean: number;
  maxSkirt: number;
  jerk: number;
  speakCoupling: number;
  laughHop: number;
  shyExprPeak: number;
  clickPlays: number;
};

function rmsOf(values: number[]): number {
  if (!values.length) return 0;
  let s = 0;
  for (const v of values) s += v * v;
  return Math.sqrt(s / values.length);
}

function playClipMetrics(id: ActionId, seed: number, dt: number): ActionClipMetrics {
  const dir = new ActionDirector(seed);
  dir.reset(seed);
  dir.play(id, true);
  const dur = durationOf(id) + 0.12;
  let peakPitch = 0;
  let peakYaw = 0;
  let peakLean = 0;
  let peakHop = 0;
  let peakWeight = 0;
  let peakSkirt = 0;
  const mag: number[] = [];
  for (let t = 0; t < dur; t += dt) {
    const p = dir.step(dt, t, { speaking: false, energy: 0, expression: "neutral", lookX: 0, lookY: 0 });
    peakPitch = Math.max(peakPitch, Math.abs(p.headPitch));
    peakYaw = Math.max(peakYaw, Math.abs(p.headYaw));
    peakLean = Math.max(peakLean, Math.abs(p.torsoLean));
    peakHop = Math.max(peakHop, p.hopY);
    peakWeight = Math.max(peakWeight, Math.abs(p.extraWeight));
    peakSkirt = Math.max(peakSkirt, Math.abs(p.skirtKick));
    mag.push(Math.abs(p.headPitch) + Math.abs(p.torsoLean) + p.hopY + Math.abs(p.extraWeight) * 0.1);
  }
  return {
    id,
    peakPitch,
    peakYaw,
    peakLean,
    peakHop,
    peakWeight,
    peakSkirt,
    rms: rmsOf(mag),
  };
}

export function simulateAction(opts?: { seconds?: number; dt?: number; seed?: number }): ActionSimResult {
  const dt = opts?.dt ?? 1 / 60;
  const seed = opts?.seed ?? 11;
  const seconds = opts?.seconds ?? 48;
  const ids: ActionId[] = [
    "nod",
    "sideTurn",
    "bow",
    "weightShift",
    "tiptoe",
    "gesture",
    "step",
    "walkPrep",
    "shyDown",
    "surpriseBack",
    "hop",
    "sighSink",
    "afterBow",
  ];
  const clips: Record<string, ActionClipMetrics> = {};
  for (const id of ids) clips[id] = playClipMetrics(id, seed + id.length, dt);

  const idle = new ActionDirector(seed + 17);
  idle.reset(seed + 17);
  let autoCount = 0;
  const kinds = new Set<string>();
  let last: ActionId = "rest";
  let maxHeadPitch = 0;
  let maxHopY = 0;
  let maxLean = 0;
  let maxSkirt = 0;
  let jerk = 0;
  let prevPitch = 0;
  let prevD = 0;
  for (let i = 0; i < Math.floor(seconds / dt); i += 1) {
    const t = i * dt;
    const p = idle.step(dt, t, { speaking: false, energy: 0, expression: "neutral", lookX: 0, lookY: 0 });
    if (p.action !== last && p.action !== "rest") {
      autoCount += 1;
      kinds.add(p.action);
    }
    last = p.action;
    maxHeadPitch = Math.max(maxHeadPitch, Math.abs(p.headPitch));
    maxHopY = Math.max(maxHopY, p.hopY);
    maxLean = Math.max(maxLean, Math.abs(p.torsoLean));
    maxSkirt = Math.max(maxSkirt, Math.abs(p.skirtKick));
    const d = (p.headPitch - prevPitch) / dt;
    jerk = Math.max(jerk, Math.abs((d - prevD) / dt));
    prevPitch = p.headPitch;
    prevD = d;
  }

  const shoulders: number[] = [];
  let afterBow = 0;
  for (let session = 0; session < 6; session += 1) {
    const talk = new ActionDirector(seed + 29 + session * 13);
    talk.reset(seed + 29 + session * 13);
    let lastTalk: ActionId = "rest";
    for (let i = 0; i < Math.floor(6 / dt); i += 1) {
      const t = i * dt;
      const speaking = t < 3.4;
      const energy = speaking ? 0.4 + 0.3 * Math.abs(Math.sin(t * 6.2)) : 0;
      if (speaking && i % 10 === 0) talk.onViseme(["A", "I", "O", "M"][(i / 10) % 4], energy, true);
      const p = talk.step(dt, t, { speaking, energy, expression: "neutral", lookX: 0, lookY: 0 });
      if (session === 0) shoulders.push(Math.abs(p.shoulderL) + Math.abs(p.shoulderR));
      if (p.action !== lastTalk && p.action === "afterBow") afterBow += 1;
      lastTalk = p.action;
    }
  }

  const laughDir = new ActionDirector(seed + 101);
  laughDir.reset(seed + 101);
  laughDir.onExpression("laugh");
  let laughHop = 0;
  for (let i = 0; i < 50; i += 1) {
    const p = laughDir.step(dt, i * dt, { speaking: false, energy: 0, expression: "laugh", lookX: 0, lookY: 0 });
    laughHop = Math.max(laughHop, p.hopY);
  }
  const shyDir = new ActionDirector(seed + 103);
  shyDir.reset(seed + 103);
  shyDir.onExpression("shy");
  let shyExprPeak = 0;
  for (let i = 0; i < 80; i += 1) {
    const p = shyDir.step(dt, i * dt, { speaking: false, energy: 0, expression: "shy", lookX: 0, lookY: 0 });
    shyExprPeak = Math.max(shyExprPeak, p.headPitch);
  }
  const clickDir = new ActionDirector(seed + 107);
  clickDir.reset(seed + 107);
  let clickPlays = 0;
  const seen = new Set<string>();
  for (let i = 0; i < 8; i += 1) {
    const id = clickDir.onClick();
    if (id) {
      clickPlays += 1;
      seen.add(id);
    }
  }

  return {
    clips,
    nodPeak: clips.nod.peakPitch,
    bowPeak: Math.max(clips.bow.peakLean, clips.bow.peakPitch),
    hopPeak: clips.hop.peakHop,
    stepRms: clips.step.rms,
    shyPeak: clips.shyDown.peakPitch,
    surprisePeak: clips.surpriseBack.peakLean,
    weightPeak: clips.weightShift.peakWeight,
    skirtHopPeak: clips.hop.peakSkirt,
    autoCount,
    autoKinds: kinds.size,
    afterBow,
    speakShoulderRms: rmsOf(shoulders),
    maxHeadPitch,
    maxHopY,
    maxLean,
    maxSkirt,
    jerk,
    speakCoupling: rmsOf(shoulders),
    laughHop,
    shyExprPeak,
    clickPlays,
  };
}
