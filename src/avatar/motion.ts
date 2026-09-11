/**
 * Blink scheduling, hair secondary motion, gaze, breath, idle theater.
 * Rounds 1–20 live in the blink/hair defaults; rounds 21–120 tune MOTION in place.
 */

export type ExpressionName =
  | "neutral"
  | "smile"
  | "laugh"
  | "surprise"
  | "sad"
  | "shy"
  | "wink"
  | "sleepy";

export type Lids = { left: number; right: number; lash: number; browDip: number; cheek: number };

export type BlinkShot = {
  t0: number;
  close: number;
  hold: number;
  open: number;
  floor: number;
  leftLag: number;
  rightLag: number;
  double: boolean;
  thoughtful: boolean;
  ampLeft: number;
  ampRight: number;
};

export type StrandState = {
  angle: number;
  velocity: number;
  sag: number;
  sagVelocity: number;
};

export type WindSample = {
  wander: number;
  gust: number;
  turb: number;
  sines: number;
  value: number;
  dir: number;
};

export type GazeState = {
  x: number;
  y: number;
  pupil: number;
  mode: "fix" | "saccade" | "drift";
  inSaccade: boolean;
};

export type BreathState = {
  chest: number;
  shoulder: number;
  crane: number;
  shawl: number;
  phase: number;
};

export type IdleBeat = "rest" | "glance" | "almostSmile" | "sigh" | "peek";

export type IdleState = {
  beat: IdleBeat;
  lookBiasX: number;
  lookBiasY: number;
  mouthCurveAdd: number;
  browAdd: number;
  breathBoost: number;
  lowerLidAdd: number;
};

export type AfterglowState = {
  active: boolean;
  amount: number;
  lookY: number;
  mouth: number;
};

export type MotionDebug = {
  lids: Lids;
  nextBlinkAt: number;
  activeShots: number;
  hair: StrandState;
  bangs: StrandState;
  tassel: StrandState;
  nape: StrandState;
  wind: WindSample;
  gaze: GazeState;
  breath: BreathState;
  idle: IdleState;
  afterglow: AfterglowState;
};

type Rng = {
  next: () => number;
  range: (min: number, max: number) => number;
  chance: (p: number) => boolean;
  gauss: () => number;
};

export const MOTION = {
  hair: {
    integrator: "sho" as "legacy" | "sho",
    k: 0.058,
    damp: 0.86,
    freq: 0.62,
    zeta: 0.59,
    lookCoupling: 0.1,
    windScale: 1.18,
    impulseScale: 0.85,
    minAngle: -0.26,
    maxAngle: 0.16,
    lookDelay: 0.05,
    windDelay: 0,
    sagFreq: 0.38,
    sagZeta: 0.64,
    sagAmount: 0.48,
    drag: 2.55,
    idleAmp: 0.008,
    idleFreq: 0.47,
    phase: 0.2,
    turbAmp: 0.08,
    gravity: 0,
  },
  bangs: {
    integrator: "sho" as "legacy" | "sho",
    k: 0.07,
    damp: 0.8,
    freq: 1.28,
    zeta: 0.8,
    lookCoupling: 0.028,
    windScale: 0.3,
    impulseScale: 0.32,
    minAngle: -0.08,
    maxAngle: 0.08,
    lookDelay: 0.016,
    windDelay: 0.055,
    sagFreq: 0.9,
    sagZeta: 0.85,
    sagAmount: 0,
    drag: 3.4,
    idleAmp: 0.0055,
    idleFreq: 1.12,
    phase: 1.35,
    turbAmp: 0.03,
    gravity: 0,
  },
  tassel: {
    integrator: "sho" as "legacy" | "sho",
    k: 0.042,
    damp: 0.9,
    freq: 0.44,
    zeta: 0.36,
    lookCoupling: 0.045,
    windScale: 1.58,
    impulseScale: 1.15,
    minAngle: -0.34,
    maxAngle: 0.34,
    lookDelay: 0.09,
    windDelay: 0.2,
    sagFreq: 0.33,
    sagZeta: 0.45,
    sagAmount: 0.22,
    drag: 1.5,
    idleAmp: 0.014,
    idleFreq: 0.67,
    phase: 2.15,
    turbAmp: 0.12,
    gravity: 0.3,
  },
  nape: {
    integrator: "sho" as "legacy" | "sho",
    k: 0.05,
    damp: 0.88,
    freq: 0.5,
    zeta: 0.7,
    lookCoupling: 0.04,
    windScale: 0.52,
    impulseScale: 0.28,
    minAngle: -0.18,
    maxAngle: 0.14,
    lookDelay: 0.08,
    windDelay: 0.1,
    sagFreq: 0.36,
    sagZeta: 0.72,
    sagAmount: 0.18,
    drag: 2.2,
    idleAmp: 0.006,
    idleFreq: 0.39,
    phase: 3.55,
    turbAmp: 0.05,
    gravity: 0,
  },
  wind: {
    model: "gusty" as "sines" | "wander" | "gusty",
    spectrum: "oneOverF" as "sines" | "oneOverF",
    sineA: 0.85,
    sineB: 1.7,
    sineAmpA: 0.08,
    sineAmpB: 0.03,
    wanderSigma: 0.38,
    wanderDecay: 1.7,
    gustGapMin: 1.8,
    gustGapMax: 5.5,
    gustMag: 0.09,
    gustDecay: 2.1,
    idleFloor: 0.08,
    turbMix: 0.44,
    dirWander: 0.32,
    bangsGust: 0.45,
    softStiffness: 13.5,
    goldenPhase: 1,
  },
  talk: {
    spikeThreshold: 0.15,
    spikeKick: 0.07,
    spikeBase: 0.04,
    energyKick: 0.0046,
    kickGain: 12,
    napeOpposite: 1,
    headNod: 0.012,
    bob: 1.05,
    bounceHz: 11,
  },
  gaze: {
    pursuitLerp: 0.075,
    saccadeThresh: 0.18,
    saccadeSpeed: 18,
    saccadeMin: 0.9,
    saccadeMax: 2.6,
    saccadeAmpX: 0.32,
    saccadeAmpY: 0.14,
    smallAmp: 0.11,
    largeAmp: 0.3,
    largeSaccadeProb: 0.18,
    driftSigma: 0.016,
    driftDecay: 2.2,
    centerSpring: 0.18,
    microsaccadeProb: 0,
    microsaccadeAmp: 0.04,
    microsaccadeGapMin: 0.35,
    microsaccadeGapMax: 0.9,
    speakLookY: 0.05,
    speakLookX: 0,
    vergence: 0.02,
    pointerSmooth: 0.92,
    lognormalFixation: 0,
    waypointMix: 0,
    autoSaccade: 1,
  },
  blink: {
    closeMin: 0.168,
    closeMax: 0.19,
    holdMin: 0.014,
    holdMax: 0.028,
    openMin: 0.21,
    openMax: 0.27,
    intervalMean: 4.05,
    intervalMin: 2.15,
    intervalMax: 6.2,
    intervalSigma: 1.05,
    doubleProb: 0.16,
    doubleGapMin: 0.02,
    doubleGapMax: 0.07,
    incompleteProb: 0.12,
    incompleteFloorMin: 0.12,
    incompleteFloorMax: 0.24,
    lagMin: 0.01,
    lagMax: 0.028,
    saccadeBlinkProb: 0.22,
    durationJitter: 0.065,
    speakingIntervalScale: 1.2,
    closeEase: "visibleClose" as "linear" | "smooth" | "inOut" | "inOutClose" | "visibleClose",
    openEase: "visibleOpen" as "linear" | "outCubic" | "outQuart" | "smooth" | "visibleOpen",
    lashFollow: 0.2,
    browDip: 0.12,
    cheekSqueeze: 0.1,
    speakingSuppress: 0.2,
    suppressEnergy: 0.45,
    postSpeechBurst: 2,
    thoughtfulProb: 0,
    thoughtfulScale: 1.38,
    closedVisemeBlink: 0.2,
    lidAsym: 0.05,
    headNod: 0.03,
  },
  pupil: {
    base: 0.5,
    speakDilate: 0.1,
    surpriseDilate: 0.16,
    sleepyConstrict: 0.1,
    catchlightFollow: 0.55,
    pulseHz: 0.26,
  },
  breath: {
    hz: 0.21,
    chest: 3.05,
    shoulder: 0.8,
    crane: 0.48,
    shawl: 0.32,
    speakHzBoost: 0.05,
    hairCoupling: 0.16,
    blushCoupling: 0.2,
    sighBoost: 0.7,
  },
  idle: {
    enabled: 1,
    glanceProb: 0.3,
    almostSmile: 0.18,
    sighProb: 0,
    peekProb: 0,
    gapMin: 6,
    gapMax: 13,
  },
  afterglow: {
    ms: 0.6,
    lookDown: 0.1,
    mouthHold: 0.18,
  },
  face: {
    smileAsym: 0.07,
    surpriseFreeze: 0.09,
    shyPeek: 0.42,
    tearPhysics: 1,
    transK: 0.16,
    transDamp: 0.7,
    sliceLook: 5.3,
    exprImpulse: 0.038,
  },
  viseme: {
    blend: 0.038,
    lookahead: 0.028,
    attack: 0.035,
    release: 0.06,
    jerkLimit: 16,
    restHold: 0.14,
    punctRest: 1.15,
    closedHold: 1.14,
    jawSplit: 0.2,
    mouthCurveTalk: 0.16,
    englishUnit: 1.08,
  },
  atmosphere: {
    lanternSync: 1,
    firefly: 1.18,
    petal: 1.14,
    vignettePulse: 0.07,
    courtyard: 38,
    warmth: 0.03,
  },
};

export type MotionTuning = typeof MOTION;
export type StrandTuning = typeof MOTION.hair;

export function cloneMotion(src: MotionTuning = MOTION): MotionTuning {
  return JSON.parse(JSON.stringify(src)) as MotionTuning;
}

export function assignMotion(dst: MotionTuning, src: MotionTuning): void {
  const copy = cloneMotion(src);
  const keys = Object.keys(copy) as Array<keyof MotionTuning>;
  for (const key of keys) {
    (dst as Record<string, unknown>)[key as string] = copy[key];
  }
}

export function emptyLids(): Lids {
  return { left: 1, right: 1, lash: 0, browDip: 0, cheek: 0 };
}

export function createRng(seed = 1): Rng {
  let state = seed >>> 0 || 1;
  const next = (): number => {
    state = (Math.imul(state, 1664525) + 1013904223) >>> 0;
    return state / 4294967296;
  };
  const gauss = (): number => {
    const u = Math.max(1e-9, next());
    const v = next();
    return Math.sqrt(-2 * Math.log(u)) * Math.cos(2 * Math.PI * v);
  };
  return {
    next,
    range: (min, max) => min + (max - min) * next(),
    chance: (p) => next() < p,
    gauss,
  };
}

export function clamp(value: number, min: number, max: number): number {
  return Math.max(min, Math.min(max, value));
}

export function lerp(a: number, b: number, t: number): number {
  return a + (b - a) * t;
}

export function easeLinear(t: number): number {
  return t;
}

export function easeSmooth(t: number): number {
  return t * t * (3 - 2 * t);
}

export function easeInOutCubic(t: number): number {
  return t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2;
}

/** Close a bit faster in the middle, settle into the closed pose. */
export function easeInOutClose(t: number): number {
  const c = easeInOutCubic(t);
  return c * 0.72 + easeSmooth(t) * 0.28;
}

export function easeOutCubic(t: number): number {
  return 1 - Math.pow(1 - t, 3);
}

export function easeOutQuart(t: number): number {
  return 1 - Math.pow(1 - t, 4);
}

/** Spend most of the close duration in the visible 0.9→0.18 band; snap shut only at the end. */
export function easeVisibleClose(t: number): number {
  const x = clamp(t, 0, 1);
  if (x < 0.05) return (x / 0.05) * 0.1;
  if (x < 0.93) return 0.1 + ((x - 0.05) / 0.88) * 0.72;
  return 0.82 + ((x - 0.93) / 0.07) * 0.18;
}

/** Leave the closed pose quickly, then spend time in the visible open, then settle. */
export function easeVisibleOpen(t: number): number {
  const x = clamp(t, 0, 1);
  if (x < 0.06) return (x / 0.06) * 0.2;
  if (x < 0.8) return 0.2 + ((x - 0.06) / 0.74) * 0.68;
  return 0.88 + ((x - 0.8) / 0.2) * 0.12;
}

export function applyEase(kind: string, t: number): number {
  const x = clamp(t, 0, 1);
  switch (kind) {
    case "smooth":
      return easeSmooth(x);
    case "inOut":
      return easeInOutCubic(x);
    case "inOutClose":
      return easeInOutClose(x);
    case "outCubic":
      return easeOutCubic(x);
    case "outQuart":
      return easeOutQuart(x);
    case "visibleClose":
      return easeVisibleClose(x);
    case "visibleOpen":
      return easeVisibleOpen(x);
    default:
      return easeLinear(x);
  }
}

/** Original metronome blink — kept for before/after metrics. */
export function legacyBlinkAmount(seconds: number, period: number): number {
  const phase = seconds % period;
  const closeStart = period - 0.38;
  if (phase < closeStart) return 1;
  const t = phase - closeStart;
  if (t < 0.1) return 1 - t / 0.1;
  if (t < 0.18) return 0.04;
  return Math.min(1, (t - 0.18) / 0.2);
}

export function lidFromShot(seconds: number, shot: BlinkShot, lag: number, amp = 1): number {
  const u = seconds - shot.t0 - lag;
  if (u <= 0) return 1;
  const close = shot.close;
  const hold = shot.hold;
  const open = shot.open;
  const floor = shot.floor;
  let lid = 1;
  if (u < close) {
    const e = applyEase(MOTION.blink.closeEase, u / close);
    lid = 1 - (1 - floor) * e;
  } else if (u < close + hold) {
    lid = floor;
  } else if (u < close + hold + open) {
    const e = applyEase(MOTION.blink.openEase, (u - close - hold) / open);
    lid = floor + (1 - floor) * e;
  } else {
    return 1;
  }
  return 1 - (1 - lid) * amp;
}

function blinkProfile(expression: ExpressionName, speaking: boolean) {
  const b = MOTION.blink;
  const talking = speaking ? b.speakingIntervalScale : 1;
  if (expression === "sleepy") {
    return {
      closeMin: b.closeMin * 1.45,
      closeMax: b.closeMax * 1.55,
      holdMin: b.holdMin * 1.2,
      holdMax: b.holdMax * 1.4,
      openMin: b.openMin * 1.3,
      openMax: b.openMax * 1.45,
      intervalMean: 2.55 * talking,
      intervalMin: 1.6,
      intervalMax: 3.8,
      intervalSigma: b.intervalSigma,
      doubleProb: Math.min(0.08, b.doubleProb),
      incompleteProb: Math.max(b.incompleteProb, 0.28),
    };
  }
  if (expression === "surprise") {
    return {
      closeMin: b.closeMin * 0.92,
      closeMax: b.closeMax,
      holdMin: b.holdMin,
      holdMax: b.holdMax,
      openMin: b.openMin * 1.05,
      openMax: b.openMax * 1.1,
      intervalMean: 5.4 * talking,
      intervalMin: 4.2,
      intervalMax: 8.2,
      intervalSigma: b.intervalSigma * 1.1,
      doubleProb: 0,
      incompleteProb: b.incompleteProb * 0.4,
    };
  }
  if (expression === "laugh") {
    return {
      closeMin: b.closeMin,
      closeMax: b.closeMax,
      holdMin: b.holdMin,
      holdMax: b.holdMax,
      openMin: b.openMin,
      openMax: b.openMax,
      intervalMean: 99,
      intervalMin: 90,
      intervalMax: 120,
      intervalSigma: 1,
      doubleProb: 0,
      incompleteProb: 0,
    };
  }
  return {
    closeMin: b.closeMin,
    closeMax: b.closeMax,
    holdMin: b.holdMin,
    holdMax: b.holdMax,
    openMin: b.openMin,
    openMax: b.openMax,
    intervalMean: b.intervalMean * talking,
    intervalMin: b.intervalMin,
    intervalMax: b.intervalMax,
    intervalSigma: b.intervalSigma,
    doubleProb: b.doubleProb,
    incompleteProb: b.incompleteProb,
  };
}

function sampleInterval(rng: Rng, profile: ReturnType<typeof blinkProfile>): number {
  if (Math.abs(profile.intervalMax - profile.intervalMin) < 1e-6) return profile.intervalMean;
  const raw = profile.intervalMean + rng.gauss() * profile.intervalSigma;
  return clamp(raw, profile.intervalMin, profile.intervalMax);
}

export class BlinkController {
  private rng: Rng;
  private shots: BlinkShot[] = [];
  private nextAt = 1.6;
  private lastSaccadeBlinkAt = -10;
  private lastVisemeBlinkAt = -10;
  private lastClosedViseme: string | null = null;
  private wasSpeaking = false;
  lastNod = 0;

  constructor(seed = 0x51ed) {
    this.rng = createRng(seed);
  }

  reset(seed?: number): void {
    if (seed != null) this.rng = createRng(seed);
    this.shots = [];
    this.nextAt = 1.15 + this.rng.range(0, 1.8);
    this.lastSaccadeBlinkAt = -10;
    this.lastVisemeBlinkAt = -10;
    this.lastClosedViseme = null;
    this.wasSpeaking = false;
    this.lastNod = 0;
  }

  notifySaccade(seconds: number, expression: ExpressionName): void {
    if (MOTION.blink.saccadeBlinkProb <= 0) return;
    if (expression === "laugh" || expression === "wink") return;
    if (seconds - this.lastSaccadeBlinkAt < 1.4) return;
    if (!this.rng.chance(MOTION.blink.saccadeBlinkProb)) return;
    this.lastSaccadeBlinkAt = seconds;
    this.queueBlink(seconds + this.rng.range(0.04, 0.16), expression, false);
  }

  notifySpeechEnd(seconds: number, expression: ExpressionName): void {
    const n = MOTION.blink.postSpeechBurst;
    if (n <= 0) return;
    if (expression === "laugh" || expression === "wink") return;
    this.queueBlink(seconds + this.rng.range(0.08, 0.22), expression, false);
    if (n >= 2) {
      this.queueBlink(seconds + this.rng.range(0.42, 0.72), expression, false);
    }
    this.armNext(seconds + 0.9, expression, false);
  }

  notifyViseme(seconds: number, id: string, expression: ExpressionName, speaking: boolean): void {
    const p = MOTION.blink.closedVisemeBlink;
    if (p <= 0 || !speaking) return;
    if (expression === "laugh" || expression === "wink") return;
    if (id !== "M" && id !== "F") {
      this.lastClosedViseme = id;
      return;
    }
    if (this.lastClosedViseme === id) return;
    this.lastClosedViseme = id;
    if (seconds - this.lastVisemeBlinkAt < 1.6) return;
    if (!this.rng.chance(p)) return;
    this.lastVisemeBlinkAt = seconds;
    this.queueBlink(seconds + this.rng.range(0.02, 0.08), expression, speaking);
  }

  trigger(seconds: number, expression: ExpressionName): void {
    this.queueBlink(seconds, expression, false);
    this.armNext(seconds, expression, false);
  }

  sample(seconds: number, expression: ExpressionName, speaking: boolean, energy = 0): Lids {
    if (expression === "wink") {
      return { left: 0, right: 1, lash: MOTION.blink.lashFollow, browDip: 0, cheek: MOTION.blink.cheekSqueeze * 0.4 };
    }
    if (speaking && MOTION.blink.speakingSuppress > 0 && energy > MOTION.blink.suppressEnergy) {
      this.nextAt = Math.max(this.nextAt, seconds + MOTION.blink.speakingSuppress);
    }
    if (this.wasSpeaking && !speaking) {
      this.notifySpeechEnd(seconds, expression);
    }
    this.wasSpeaking = speaking;
    if (seconds >= this.nextAt) {
      this.queueBlink(seconds, expression, speaking);
      this.armNext(seconds, expression, speaking);
    }
    this.shots = this.shots.filter((shot) => seconds < shot.t0 + shot.close + shot.hold + shot.open + 0.08);
    let left = 1;
    let right = 1;
    let closedness = 0;
    for (const shot of this.shots) {
      left = Math.min(left, lidFromShot(seconds, shot, shot.leftLag, shot.ampLeft));
      right = Math.min(right, lidFromShot(seconds, shot, shot.rightLag, shot.ampRight));
    }
    closedness = 1 - (left + right) * 0.5;
    const lash = closedness * MOTION.blink.lashFollow;
    const browDip = closedness * MOTION.blink.browDip;
    const cheek = closedness * MOTION.blink.cheekSqueeze;
    this.lastNod = closedness * MOTION.blink.headNod;
    return { left, right, lash, browDip, cheek };
  }

  debug(): { nextBlinkAt: number; activeShots: number } {
    return { nextBlinkAt: this.nextAt, activeShots: this.shots.length };
  }

  private armNext(seconds: number, expression: ExpressionName, speaking: boolean): void {
    const profile = blinkProfile(expression, speaking);
    this.nextAt = seconds + sampleInterval(this.rng, profile);
  }

  private queueBlink(seconds: number, expression: ExpressionName, speaking: boolean, asDouble = false): void {
    if (expression === "laugh") return;
    const profile = blinkProfile(expression, speaking);
    const jitter = MOTION.blink.durationJitter;
    const j = (baseMin: number, baseMax: number) => {
      const mid = this.rng.range(baseMin, Math.max(baseMin, baseMax));
      if (jitter <= 0) return mid;
      return Math.max(0.03, mid * (1 + this.rng.gauss() * jitter));
    };
    const incomplete = this.rng.chance(profile.incompleteProb);
    const thoughtful = !asDouble && this.rng.chance(MOTION.blink.thoughtfulProb);
    const scale = thoughtful ? MOTION.blink.thoughtfulScale : 1;
    const lagSpan = MOTION.blink.lagMax - MOTION.blink.lagMin;
    const lag = lagSpan <= 0 ? 0 : this.rng.range(MOTION.blink.lagMin, MOTION.blink.lagMax);
    const lagOnLeft = this.rng.chance(0.5);
    const asym = MOTION.blink.lidAsym;
    const leftHeavier = this.rng.chance(0.5);
    const shot: BlinkShot = {
      t0: seconds,
      close: j(profile.closeMin, profile.closeMax) * scale,
      hold: j(profile.holdMin, profile.holdMax) * (thoughtful ? 1.15 : 1),
      open: j(profile.openMin, profile.openMax) * scale,
      floor: incomplete
        ? this.rng.range(MOTION.blink.incompleteFloorMin, MOTION.blink.incompleteFloorMax)
        : 0,
      leftLag: lagOnLeft ? lag : 0,
      rightLag: lagOnLeft ? 0 : lag,
      double: asDouble,
      thoughtful,
      ampLeft: 1 + (leftHeavier ? asym : -asym * 0.6),
      ampRight: 1 + (leftHeavier ? -asym * 0.6 : asym),
    };
    this.shots.push(shot);
    if (!asDouble && this.rng.chance(profile.doubleProb)) {
      const gap = this.rng.range(MOTION.blink.doubleGapMin, MOTION.blink.doubleGapMax);
      const secondAt = seconds + shot.close + shot.hold + shot.open * 0.4 + gap;
      this.queueBlink(secondAt, expression, speaking, true);
    }
  }
}

export function emptyStrand(): StrandState {
  return { angle: 0, velocity: 0, sag: 0, sagVelocity: 0 };
}

function softLimit(angle: number, velocity: number, min: number, max: number, dt: number): { angle: number; velocity: number } {
  let a = angle;
  let v = velocity;
  const k = MOTION.wind.softStiffness;
  if (a > max) {
    v += (max - a) * k * dt;
    v *= Math.exp(-6 * dt);
  } else if (a < min) {
    v += (min - a) * k * dt;
    v *= Math.exp(-6 * dt);
  }
  a = clamp(a, min - 0.04, max + 0.04);
  return { angle: a, velocity: v };
}

export function stepStrand(
  strand: StrandState,
  dt: number,
  target: number,
  spec: StrandTuning,
): void {
  if (spec.integrator === "sho") {
    const omega = 2 * Math.PI * spec.freq;
    const accel = omega * omega * (target - strand.angle) - 2 * spec.zeta * omega * strand.velocity;
    const drag = spec.drag > 0 ? -spec.drag * strand.velocity * Math.abs(strand.velocity) : 0;
    strand.velocity += (accel + drag) * dt;
    strand.angle += strand.velocity * dt;
    if (spec.sagAmount > 0) {
      const sagOmega = 2 * Math.PI * spec.sagFreq;
      const sagTarget = strand.angle * spec.sagAmount;
      const sagAccel = sagOmega * sagOmega * (sagTarget - strand.sag) - 2 * spec.sagZeta * sagOmega * strand.sagVelocity;
      strand.sagVelocity += sagAccel * dt;
      strand.sag += strand.sagVelocity * dt;
    } else {
      strand.sag *= Math.exp(-8 * dt);
      strand.sagVelocity *= Math.exp(-8 * dt);
    }
  } else {
    const dtFrame = dt * 60;
    strand.velocity += (target - strand.angle) * spec.k * dtFrame;
    strand.velocity *= Math.pow(spec.damp, dtFrame);
    strand.angle += strand.velocity * dtFrame;
    strand.sag = 0;
    strand.sagVelocity = 0;
  }
  const limited = softLimit(strand.angle, strand.velocity, spec.minAngle, spec.maxAngle, dt);
  strand.angle = limited.angle;
  strand.velocity = limited.velocity;
}

export class WindField {
  private rng: Rng;
  wander = 0;
  gust = 0;
  smooth = 0;
  dir = 0;
  nextGustAt = 1.4;
  last: WindSample = { wander: 0, gust: 0, turb: 0, sines: 0, value: 0, dir: 0 };

  constructor(seed = 0xc0ffee) {
    this.rng = createRng(seed);
  }

  reset(seed?: number): void {
    if (seed != null) this.rng = createRng(seed);
    this.wander = 0;
    this.gust = 0;
    this.smooth = 0;
    this.dir = 0;
    this.nextGustAt = 1.2 + this.rng.range(0, 2);
    this.last = { wander: 0, gust: 0, turb: 0, sines: 0, value: 0, dir: 0 };
  }

  step(seconds: number, dt: number, wind: number): WindSample {
    const cfg = MOTION.wind;
    const boosted = wind <= 1 ? wind : 1 + (wind - 1) * 1.5;
    const level = Math.max(cfg.idleFloor, boosted);
    const sines =
      Math.sin(seconds * cfg.sineA) * cfg.sineAmpA * wind +
      Math.sin(seconds * cfg.sineB) * cfg.sineAmpB * wind;
    let turb = 0;
    if (cfg.spectrum === "oneOverF") {
      const amps = [1, 0.5, 0.25, 0.125, 0.0625];
      const freqs = [0.23, 0.47, 0.91, 1.73, 3.31];
      const phases = [0.2, 1.1, 2.4, 0.7, 1.9];
      let norm = 0;
      for (let i = 0; i < amps.length; i += 1) {
        turb += Math.sin(seconds * freqs[i] + phases[i]) * amps[i];
        norm += amps[i];
      }
      turb = (turb / norm) * 0.035 * level * cfg.turbMix;
    } else {
      turb =
        (Math.sin(seconds * 0.61 + 0.3) * 0.5 +
          Math.sin(seconds * 1.13 + 1.9) * 0.28 +
          Math.sin(seconds * 0.29 + 2.4) * 0.55) *
        0.035 *
        level *
        cfg.turbMix;
    }

    this.wander += (this.rng.next() - 0.5) * 2 * cfg.wanderSigma * dt * Math.max(0.12, level);
    this.wander *= Math.exp(-cfg.wanderDecay * dt);

    if (cfg.dirWander > 0) {
      this.dir += (this.rng.next() - 0.5) * 2 * cfg.dirWander * dt;
      this.dir *= Math.exp(-0.45 * dt);
    } else {
      this.dir *= Math.exp(-4 * dt);
    }

    if (cfg.model === "gusty" && wind >= 0.35 && seconds >= this.nextGustAt) {
      const mag = (0.035 + this.rng.next() * cfg.gustMag) * level;
      this.gust += mag * (this.rng.chance(0.5) ? -1 : 1);
      this.nextGustAt = seconds + this.rng.range(cfg.gustGapMin, cfg.gustGapMax);
    }
    this.gust *= Math.exp(-cfg.gustDecay * dt);

    let raw = sines;
    if (cfg.model === "wander") raw = this.wander + turb;
    if (cfg.model === "gusty") raw = this.wander + this.gust + turb * 0.55;
    this.smooth += (raw - this.smooth) * (1 - Math.exp(-5.2 * dt));
    this.last = { wander: this.wander, gust: this.gust, turb, sines, value: this.smooth, dir: this.dir };
    return this.last;
  }
}

export class HairSystem {
  hair = emptyStrand();
  bangs = emptyStrand();
  tassel = emptyStrand();
  nape = emptyStrand();
  wind = new WindField();
  private lookHist: number[] = [];
  private windHist: number[] = [];
  private lastEnergy = 0;
  private breath = 0;

  reset(seed?: number): void {
    this.hair = emptyStrand();
    this.bangs = emptyStrand();
    this.tassel = emptyStrand();
    this.nape = emptyStrand();
    this.wind.reset(seed);
    this.lookHist = [];
    this.windHist = [];
    this.lastEnergy = 0;
    this.breath = 0;
  }

  impulse(strength: number): void {
    const gain = MOTION.hair.integrator === "sho" ? MOTION.talk.kickGain : 1;
    this.hair.velocity -= strength * MOTION.hair.impulseScale * gain;
    this.bangs.velocity -= strength * MOTION.bangs.impulseScale * gain;
    this.tassel.velocity += strength * MOTION.tassel.impulseScale * gain;
    const napeSign = MOTION.talk.napeOpposite > 0 ? -1 : 1;
    this.nape.velocity += napeSign * strength * MOTION.nape.impulseScale * gain;
  }

  setBreath(value: number): void {
    this.breath = value;
  }

  step(
    dt: number,
    seconds: number,
    input: { lookX: number; wind: number; speaking: boolean; energy: number },
  ): void {
    const field = this.wind.step(seconds, dt, input.wind);
    this.lookHist.push(input.lookX);
    if (this.lookHist.length > 30) this.lookHist.shift();
    this.windHist.push(field.value);
    if (this.windHist.length > 30) this.windHist.shift();

    const delayed = (hist: number[], secondsDelay: number, fallback: number) => {
      if (secondsDelay <= 0 || hist.length === 0) return fallback;
      const frames = Math.round(secondsDelay * 60);
      const index = Math.max(0, hist.length - 1 - frames);
      return hist[index] ?? fallback;
    };

    if (input.speaking) {
      const spike = Math.max(0, input.energy - this.lastEnergy);
      if (spike > MOTION.talk.spikeThreshold) {
        this.impulse(MOTION.talk.spikeBase + spike * MOTION.talk.spikeKick);
      }
      if (MOTION.talk.energyKick > 0 && input.energy > 0.18) {
        this.hair.velocity -= input.energy * MOTION.talk.energyKick * MOTION.hair.impulseScale;
        this.bangs.velocity -= input.energy * MOTION.talk.energyKick * 0.4 * MOTION.bangs.impulseScale;
        this.tassel.velocity += input.energy * MOTION.talk.energyKick * 0.7 * MOTION.tassel.impulseScale;
      }
    }
    this.lastEnergy = input.energy;

    this.drive(
      this.hair,
      MOTION.hair,
      dt,
      seconds,
      delayed(this.lookHist, MOTION.hair.lookDelay, input.lookX),
      { ...field, value: delayed(this.windHist, MOTION.hair.windDelay, field.value) },
      0,
    );
    this.drive(
      this.bangs,
      MOTION.bangs,
      dt,
      seconds,
      delayed(this.lookHist, MOTION.bangs.lookDelay, input.lookX),
      { ...field, value: delayed(this.windHist, MOTION.bangs.windDelay, field.value) * (1 + MOTION.wind.bangsGust * field.gust) },
      1,
    );
    this.drive(
      this.tassel,
      MOTION.tassel,
      dt,
      seconds,
      delayed(this.lookHist, MOTION.tassel.lookDelay, input.lookX),
      { ...field, value: delayed(this.windHist, MOTION.tassel.windDelay, field.value) },
      2,
    );
    this.drive(
      this.nape,
      MOTION.nape,
      dt,
      seconds,
      delayed(this.lookHist, MOTION.nape.lookDelay, input.lookX),
      { ...field, value: delayed(this.windHist, MOTION.nape.windDelay, field.value) },
      3,
    );
  }

  debug(): { hair: StrandState; bangs: StrandState; tassel: StrandState; nape: StrandState; wind: WindSample } {
    return {
      hair: { ...this.hair },
      bangs: { ...this.bangs },
      tassel: { ...this.tassel },
      nape: { ...this.nape },
      wind: { ...this.wind.last },
    };
  }

  private drive(
    strand: StrandState,
    spec: StrandTuning,
    dt: number,
    seconds: number,
    lookX: number,
    field: WindSample,
    layer = 0,
  ): void {
    const phase =
      MOTION.wind.goldenPhase > 0 ? spec.phase + layer * 2.399963 * MOTION.wind.goldenPhase : spec.phase;
    const idle = Math.sin(seconds * spec.idleFreq + phase) * spec.idleAmp;
    const layerTurb = field.turb * spec.turbAmp * (0.7 + 0.4 * Math.sin(phase + 0.8));
    const dirScale = 1 + Math.cos(field.dir + layer * 0.7) * Math.min(0.35, Math.abs(field.dir));
    const gust = field.value * spec.windScale * dirScale;
    const grav = spec.gravity ? -spec.gravity * 0.05 : 0;
    const breath = this.breath * MOTION.breath.hairCoupling * (layer === 0 || layer === 3 ? 0.012 : 0.006);
    const target = -lookX * spec.lookCoupling + gust + idle + layerTurb + grav + breath;
    stepStrand(strand, dt, target, spec);
  }
}

const WAYPOINTS: Array<{ x: number; y: number }> = [
  { x: 0, y: 0 },
  { x: -0.22, y: 0.04 },
  { x: 0.26, y: -0.03 },
  { x: -0.12, y: 0.16 },
  { x: 0.1, y: -0.12 },
  { x: 0.18, y: 0.1 },
];

export class GazeController {
  x = 0;
  y = 0;
  pupil = MOTION.pupil.base;
  mode: GazeState["mode"] = "fix";
  inSaccade = false;
  private rng: Rng;
  private pointerX = 0;
  private pointerY = 0;
  private driftX = 0;
  private driftY = 0;
  private targetX = 0;
  private targetY = 0;
  private nextSaccadeAt = 1.6;
  private nextMicroAt = 0.4;
  private waypoint = 0;
  private lastSaccade = false;

  constructor(seed = 0x9a11) {
    this.rng = createRng(seed);
  }

  reset(seed?: number): void {
    if (seed != null) this.rng = createRng(seed);
    this.x = 0;
    this.y = 0;
    this.pupil = MOTION.pupil.base;
    this.mode = "fix";
    this.inSaccade = false;
    this.pointerX = 0;
    this.pointerY = 0;
    this.driftX = 0;
    this.driftY = 0;
    this.targetX = 0;
    this.targetY = 0;
    this.nextSaccadeAt = 1.4 + this.rng.range(0, 1.2);
    this.nextMicroAt = 0.4;
    this.waypoint = 0;
    this.lastSaccade = false;
  }

  setPointer(x: number, y: number): void {
    this.pointerX = x;
    this.pointerY = y;
  }

  didSaccade(): boolean {
    const flag = this.lastSaccade;
    this.lastSaccade = false;
    return flag;
  }

  step(
    dt: number,
    seconds: number,
    input: { speaking: boolean; energy: number; expression: ExpressionName; lookBiasX: number; lookBiasY: number },
  ): GazeState {
    const g = MOTION.gaze;
    const pointerMag = Math.hypot(this.pointerX, this.pointerY);
    let aimX = this.pointerX;
    let aimY = this.pointerY;
    if (pointerMag < 0.08 && g.waypointMix > 0) {
      const wp = WAYPOINTS[this.waypoint % WAYPOINTS.length];
      aimX = wp.x * g.waypointMix;
      aimY = wp.y * g.waypointMix;
    }
    if (input.speaking) {
      aimX += g.speakLookX;
      aimY += g.speakLookY;
    }
    aimX = clamp(aimX + input.lookBiasX, -1, 1);
    aimY = clamp(aimY + input.lookBiasY, -1, 1);

    if (g.centerSpring > 0 && pointerMag < 0.06 && !input.speaking) {
      aimX *= 1 - g.centerSpring * 0.35;
      aimY *= 1 - g.centerSpring * 0.35;
    }

    const dtSec = dt;
    this.driftX += this.rng.gauss() * g.driftSigma * Math.sqrt(Math.max(dtSec, 1e-4));
    this.driftY += this.rng.gauss() * g.driftSigma * 0.6 * Math.sqrt(Math.max(dtSec, 1e-4));
    this.driftX *= Math.exp(-g.driftDecay * dtSec);
    this.driftY *= Math.exp(-g.driftDecay * dtSec);

    if (seconds >= this.nextMicroAt && g.microsaccadeProb > 0 && !this.inSaccade) {
      this.nextMicroAt = seconds + this.rng.range(g.microsaccadeGapMin, g.microsaccadeGapMax);
      if (this.rng.chance(g.microsaccadeProb)) {
        this.driftX += this.rng.range(-g.microsaccadeAmp, g.microsaccadeAmp);
        this.driftY += this.rng.range(-g.microsaccadeAmp, g.microsaccadeAmp) * 0.5;
      }
    }

    const err = Math.hypot(aimX - this.x, aimY - this.y);
    if (!this.inSaccade && err > g.saccadeThresh) {
      this.inSaccade = true;
      this.lastSaccade = true;
      this.targetX = aimX;
      this.targetY = aimY;
      this.mode = "saccade";
    }

    if (g.autoSaccade > 0 && seconds >= this.nextSaccadeAt && !this.inSaccade && pointerMag < 0.12) {
      const large = g.largeSaccadeProb > 0 && this.rng.chance(g.largeSaccadeProb);
      const ampX = large ? g.largeAmp : g.smallAmp || g.saccadeAmpX;
      const ampY = (large ? g.largeAmp : g.smallAmp || g.saccadeAmpY) * 0.45;
      this.targetX = clamp((this.rng.next() - 0.5) * 2 * ampX, -1, 1);
      this.targetY = clamp((this.rng.next() - 0.5) * 2 * ampY, -1, 1);
      this.inSaccade = true;
      this.lastSaccade = true;
      this.mode = "saccade";
      this.waypoint = (this.waypoint + 1 + (this.rng.chance(0.5) ? 1 : 0)) % WAYPOINTS.length;
      let gap = this.rng.range(g.saccadeMin, g.saccadeMax);
      if (g.lognormalFixation > 0) {
        const mu = Math.log(Math.max(0.4, (g.saccadeMin + g.saccadeMax) * 0.5));
        gap = clamp(Math.exp(mu + this.rng.gauss() * 0.35 * g.lognormalFixation), g.saccadeMin * 0.6, g.saccadeMax * 1.15);
      }
      this.nextSaccadeAt = seconds + gap;
    }

    if (this.inSaccade) {
      const k = 1 - Math.exp(-g.saccadeSpeed * dtSec);
      this.x += (this.targetX - this.x) * k;
      this.y += (this.targetY - this.y) * k;
      if (Math.hypot(this.targetX - this.x, this.targetY - this.y) < 0.012) {
        this.inSaccade = false;
        this.mode = "fix";
      }
    } else {
      const follow = aimX + this.driftX;
      const followY = aimY + this.driftY;
      const k = 1 - Math.pow(1 - g.pursuitLerp, Math.max(0.25, dtSec * 60));
      this.x += (follow - this.x) * k * g.pointerSmooth;
      this.y += (followY - this.y) * k * g.pointerSmooth;
      this.mode = Math.hypot(this.driftX, this.driftY) > 0.01 ? "drift" : "fix";
    }

    this.x = clamp(this.x, -1, 1);
    this.y = clamp(this.y, -1, 1);

    let pupil = MOTION.pupil.base;
    pupil += input.energy * MOTION.pupil.speakDilate;
    if (input.expression === "surprise") pupil += MOTION.pupil.surpriseDilate;
    if (input.expression === "sleepy") pupil -= MOTION.pupil.sleepyConstrict;
    pupil += Math.sin(seconds * MOTION.pupil.pulseHz * Math.PI * 2) * 0.015;
    this.pupil = clamp(pupil, 0.28, 0.82);
    return { x: this.x, y: this.y, pupil: this.pupil, mode: this.mode, inSaccade: this.inSaccade };
  }
}

export class BreathSystem {
  phase = 0;
  chest = 0;
  shoulder = 0;
  crane = 0;
  shawl = 0;

  reset(): void {
    this.phase = 0;
    this.chest = 0;
    this.shoulder = 0;
    this.crane = 0;
    this.shawl = 0;
  }

  step(dt: number, _seconds: number, speaking: boolean, energy: number, sighBoost = 0): BreathState {
    const b = MOTION.breath;
    const hz = b.hz + (speaking ? b.speakHzBoost : 0);
    this.phase += Math.PI * 2 * hz * dt;
    const wave = Math.sin(this.phase);
    const amp = 1 + sighBoost * b.sighBoost;
    this.chest = wave * b.chest * amp;
    this.shoulder = Math.sin(this.phase + 0.4) * b.shoulder * amp;
    this.crane = Math.sin(this.phase * 2.15 + 1.1) * b.crane + energy * b.crane * 0.35;
    this.shawl = Math.sin(this.phase + 0.9) * b.shawl * amp;
    return { chest: this.chest, shoulder: this.shoulder, crane: this.crane, shawl: this.shawl, phase: this.phase };
  }
}

export class IdleDirector {
  beat: IdleBeat = "rest";
  private rng: Rng;
  private nextAt = 4.5;
  private beatUntil = 0;
  private lookX = 0;
  private lookY = 0;
  private mouth = 0;
  private brow = 0;
  private breathBoost = 0;
  private lowerLid = 0;

  constructor(seed = 0x1d1e) {
    this.rng = createRng(seed);
  }

  reset(seed?: number): void {
    if (seed != null) this.rng = createRng(seed);
    this.beat = "rest";
    this.nextAt = 3.2 + this.rng.range(0, 4);
    this.beatUntil = 0;
    this.lookX = 0;
    this.lookY = 0;
    this.mouth = 0;
    this.brow = 0;
    this.breathBoost = 0;
    this.lowerLid = 0;
  }

  step(seconds: number, speaking: boolean, expression: ExpressionName): IdleState {
    if (!MOTION.idle.enabled || speaking || expression !== "neutral") {
      this.beat = "rest";
      this.lookX *= 0.9;
      this.lookY *= 0.9;
      this.mouth *= 0.9;
      this.brow *= 0.9;
      this.breathBoost *= 0.85;
      this.lowerLid *= 0.9;
      return this.snapshot();
    }
    if (seconds >= this.beatUntil && this.beat !== "rest") {
      this.beat = "rest";
      this.nextAt = seconds + this.rng.range(MOTION.idle.gapMin, MOTION.idle.gapMax);
    }
    if (seconds >= this.nextAt && this.beat === "rest") {
      const pick = this.rng.next();
      const g = MOTION.idle.glanceProb;
      const s = g + MOTION.idle.almostSmile;
      const h = s + MOTION.idle.sighProb;
      const p = h + MOTION.idle.peekProb;
      if (pick < g) {
        this.beat = "glance";
        this.lookX = this.rng.range(-0.34, 0.34);
        this.lookY = this.rng.range(-0.08, 0.12);
        this.beatUntil = seconds + this.rng.range(0.7, 1.4);
      } else if (pick < s) {
        this.beat = "almostSmile";
        this.mouth = 0.16;
        this.lowerLid = 0.12;
        this.beatUntil = seconds + this.rng.range(1.1, 2.0);
      } else if (pick < h) {
        this.beat = "sigh";
        this.breathBoost = 1;
        this.lowerLid = 0.18;
        this.brow = -0.08;
        this.beatUntil = seconds + this.rng.range(1.4, 2.2);
      } else if (pick < p) {
        this.beat = "peek";
        this.lookX = this.rng.range(0.18, 0.36) * (this.rng.chance(0.5) ? -1 : 1);
        this.lookY = 0.14;
        this.mouth = 0.08;
        this.beatUntil = seconds + this.rng.range(0.8, 1.5);
      } else {
        this.nextAt = seconds + this.rng.range(MOTION.idle.gapMin, MOTION.idle.gapMax);
      }
      if (this.beat !== "rest") this.nextAt = this.beatUntil + this.rng.range(MOTION.idle.gapMin, MOTION.idle.gapMax);
    }
    const ease = 0.12;
    const targetLookX = this.beat === "rest" ? 0 : this.lookX;
    const targetLookY = this.beat === "rest" ? 0 : this.lookY;
    const targetMouth = this.beat === "almostSmile" || this.beat === "peek" ? this.mouth : 0;
    const targetBrow = this.beat === "sigh" ? this.brow : 0;
    const targetBreath = this.beat === "sigh" ? this.breathBoost : 0;
    const targetLid = this.beat === "rest" ? 0 : this.lowerLid;
    this.lookX += (targetLookX - this.lookX) * ease;
    this.lookY += (targetLookY - this.lookY) * ease;
    this.mouth += (targetMouth - this.mouth) * ease;
    this.brow += (targetBrow - this.brow) * ease;
    this.breathBoost += (targetBreath - this.breathBoost) * 0.08;
    this.lowerLid += (targetLid - this.lowerLid) * ease;
    return this.snapshot();
  }

  private snapshot(): IdleState {
    return {
      beat: this.beat,
      lookBiasX: this.lookX,
      lookBiasY: this.lookY,
      mouthCurveAdd: this.mouth,
      browAdd: this.brow,
      breathBoost: this.breathBoost,
      lowerLidAdd: this.lowerLid,
    };
  }
}

export class AfterglowController {
  private t = 99;
  lookY = 0;
  mouth = 0;

  reset(): void {
    this.t = 99;
    this.lookY = 0;
    this.mouth = 0;
  }

  trigger(): void {
    this.t = 0;
  }

  step(dt: number): AfterglowState {
    const dur = MOTION.afterglow.ms;
    if (dur <= 0) {
      this.lookY = 0;
      this.mouth = 0;
      return { active: false, amount: 0, lookY: 0, mouth: 0 };
    }
    this.t += dt;
    const u = clamp(1 - this.t / dur, 0, 1);
    const amount = u * u * (3 - 2 * u);
    this.lookY = amount * MOTION.afterglow.lookDown;
    this.mouth = amount * MOTION.afterglow.mouthHold;
    return { active: u > 0.02, amount, lookY: this.lookY, mouth: this.mouth };
  }
}

export type BlinkEventMetrics = {
  t0: number;
  closeMs: number;
  holdMs: number;
  openMs: number;
  totalMs: number;
  minOpen: number;
  lagMs: number;
  double: boolean;
  notch: boolean;
};

export type BlinkAnalysis = {
  count: number;
  meanIntervalS: number;
  minIntervalS: number;
  maxIntervalS: number;
  stdIntervalS: number;
  meanCloseMs: number;
  meanHoldMs: number;
  meanOpenMs: number;
  meanTotalMs: number;
  minTotalMs: number;
  maxTotalMs: number;
  meanMinOpen: number;
  meanLagMs: number;
  doubleRate: number;
  notchRate: number;
  closedDuty: number;
};

export type HairAnalysis = {
  rms: number;
  peak: number;
  freqHz: number;
  maxJerk: number;
  bangsHairCorr: number;
  bangsLagMs: number;
  tasselHairCorr: number;
  tasselLagMs: number;
  sagRms: number;
  sagLagMs: number;
  napeRms: number;
};

function mean(values: number[]): number {
  if (!values.length) return 0;
  return values.reduce((a, b) => a + b, 0) / values.length;
}

function stdev(values: number[]): number {
  if (values.length < 2) return 0;
  const m = mean(values);
  return Math.sqrt(mean(values.map((v) => (v - m) ** 2)));
}

function pearson(a: number[], b: number[]): number {
  const n = Math.min(a.length, b.length);
  if (n < 8) return 0;
  const aa = a.slice(0, n);
  const bb = b.slice(0, n);
  const ma = mean(aa);
  const mb = mean(bb);
  let num = 0;
  let da = 0;
  let db = 0;
  for (let i = 0; i < n; i += 1) {
    const x = aa[i] - ma;
    const y = bb[i] - mb;
    num += x * y;
    da += x * x;
    db += y * y;
  }
  if (da < 1e-12 || db < 1e-12) return 0;
  return num / Math.sqrt(da * db);
}

function bestLag(a: number[], b: number[], dt: number, maxLagS: number): { corr: number; lagMs: number } {
  const maxLag = Math.min(Math.floor(maxLagS / dt), Math.floor(a.length / 6));
  let best = pearson(a, b);
  let bestLagFrames = 0;
  for (let lag = -maxLag; lag <= maxLag; lag += 1) {
    if (lag === 0) continue;
    const aa = lag > 0 ? a.slice(lag) : a.slice(0, a.length + lag);
    const bb = lag > 0 ? b.slice(0, b.length - lag) : b.slice(-lag);
    const c = pearson(aa, bb);
    if (c > best) {
      best = c;
      bestLagFrames = lag;
    }
  }
  return { corr: best, lagMs: bestLagFrames * dt * 1000 };
}

function zcFreq(values: number[], dt: number): number {
  const m = mean(values);
  let zc = 0;
  for (let i = 1; i < values.length; i += 1) {
    if ((values[i - 1] - m) * (values[i] - m) < 0) zc += 1;
  }
  const dur = values.length * dt;
  return dur > 0 ? zc / 2 / dur : 0;
}

export function analyzeBlinkTrace(samples: Array<{ t: number; left: number; right: number }>, dt: number): BlinkAnalysis {
  const open = samples.map((s) => (s.left + s.right) / 2);
  const events: BlinkEventMetrics[] = [];
  let i = 0;
  while (i < open.length) {
    if (open[i] < 0.9 && (i === 0 || open[i - 1] >= 0.9)) {
      const start = i;
      let minOpen = 1;
      let minI = i;
      let j = i;
      while (j < open.length && open[j] < 0.9) {
        if (open[j] < minOpen) {
          minOpen = open[j];
          minI = j;
        }
        j += 1;
      }
      const end = j;
      let closedStart = minI;
      let closedEnd = minI;
      for (let k = start; k < end; k += 1) {
        if (open[k] <= 0.18) {
          closedStart = k;
          break;
        }
      }
      for (let k = end - 1; k >= start; k -= 1) {
        if (open[k] <= 0.18) {
          closedEnd = k;
          break;
        }
      }
      let leftHalf = start;
      let rightHalf = start;
      for (let k = start; k < end; k += 1) {
        if (samples[k].left <= 0.5) {
          leftHalf = k;
          break;
        }
      }
      for (let k = start; k < end; k += 1) {
        if (samples[k].right <= 0.5) {
          rightHalf = k;
          break;
        }
      }
      let sawClosed = false;
      let reopened = false;
      let secondClose = false;
      for (let k = start; k < end; k += 1) {
        if (!sawClosed && open[k] <= 0.2) sawClosed = true;
        else if (sawClosed && !reopened && open[k] > 0.35) reopened = true;
        else if (reopened && open[k] <= 0.2) secondClose = true;
      }
      events.push({
        t0: samples[start].t,
        closeMs: (closedStart - start) * dt * 1000,
        holdMs: Math.max(0, (closedEnd - closedStart) * dt * 1000),
        openMs: (end - closedEnd) * dt * 1000,
        totalMs: (end - start) * dt * 1000,
        minOpen,
        lagMs: (rightHalf - leftHalf) * dt * 1000,
        double: false,
        notch: secondClose,
      });
      i = Math.max(end, start + 1);
    } else {
      i += 1;
    }
  }
  for (let e = 1; e < events.length; e += 1) {
    const gap = events[e].t0 - events[e - 1].t0;
    if (gap < 0.55) events[e].double = true;
  }
  const intervals: number[] = [];
  for (let e = 1; e < events.length; e += 1) {
    if (events[e].double) continue;
    let prev = e - 1;
    while (prev > 0 && events[prev].double) prev -= 1;
    intervals.push(events[e].t0 - events[prev].t0);
  }
  const closed = open.filter((v) => v < 0.2).length;
  const singles = events.filter((e) => !e.double && !e.notch);
  const timed = singles.length ? singles : events;
  const totals = timed.map((e) => e.totalMs);
  return {
    count: events.length,
    meanIntervalS: mean(intervals),
    minIntervalS: intervals.length ? Math.min(...intervals) : 0,
    maxIntervalS: intervals.length ? Math.max(...intervals) : 0,
    stdIntervalS: stdev(intervals),
    meanCloseMs: mean(timed.map((e) => e.closeMs)),
    meanHoldMs: mean(timed.map((e) => e.holdMs)),
    meanOpenMs: mean(timed.map((e) => e.openMs)),
    meanTotalMs: mean(totals),
    minTotalMs: totals.length ? Math.min(...totals) : 0,
    maxTotalMs: totals.length ? Math.max(...totals) : 0,
    meanMinOpen: mean(events.map((e) => e.minOpen)),
    meanLagMs: mean(events.map((e) => Math.abs(e.lagMs))),
    doubleRate: events.length ? events.filter((e) => e.double).length / events.length : 0,
    notchRate: events.length ? events.filter((e) => e.notch).length / events.length : 0,
    closedDuty: open.length ? closed / open.length : 0,
  };
}

export function analyzeHairTrace(
  samples: Array<{ hair: number; bangs: number; tassel: number; sag?: number; nape?: number }>,
  dt: number,
): HairAnalysis {
  const hair = samples.map((s) => s.hair);
  const bangs = samples.map((s) => s.bangs);
  const tassel = samples.map((s) => s.tassel);
  const sag = samples.map((s) => s.sag ?? 0);
  const nape = samples.map((s) => s.nape ?? 0);
  const rms = Math.sqrt(mean(hair.map((v) => v * v)));
  const peak = hair.reduce((m, v) => Math.max(m, Math.abs(v)), 0);
  let maxJerk = 0;
  for (let i = 3; i < hair.length; i += 1) {
    const jerk = (hair[i] - 3 * hair[i - 1] + 3 * hair[i - 2] - hair[i - 3]) / dt ** 3;
    maxJerk = Math.max(maxJerk, Math.abs(jerk));
  }
  const bangsLag = bestLag(hair, bangs, dt, 0.35);
  const tasselLag = bestLag(hair, tassel, dt, 0.45);
  const sagLag = bestLag(hair, sag, dt, 0.45);
  return {
    rms,
    peak,
    freqHz: zcFreq(hair, dt),
    maxJerk,
    bangsHairCorr: bangsLag.corr,
    bangsLagMs: bangsLag.lagMs,
    tasselHairCorr: tasselLag.corr,
    tasselLagMs: tasselLag.lagMs,
    sagRms: Math.sqrt(mean(sag.map((v) => v * v))),
    sagLagMs: sagLag.lagMs,
    napeRms: Math.sqrt(mean(nape.map((v) => v * v))),
  };
}

export type GazeAnalysis = {
  saccadeRate: number;
  rms: number;
  meanAbsX: number;
  pupilMean: number;
};

export type BreathAnalysis = {
  rms: number;
  peak: number;
};

export type SimResult = {
  blink: BlinkAnalysis;
  hair0: HairAnalysis;
  hair1: HairAnalysis;
  hair2: HairAnalysis;
  talk: HairAnalysis;
  sleepy: BlinkAnalysis;
  speakingBlink: BlinkAnalysis;
  gaze: GazeAnalysis;
  breath: BreathAnalysis;
  postSpeechExtra: number;
  idleBeats: number;
  browBlinkCorr: number;
  waveform: { t: number; left: number; right: number; hair: number; bangs: number; tassel: number }[];
};

export function simulateMotion(opts?: {
  seconds?: number;
  dt?: number;
  seed?: number;
  expression?: ExpressionName;
}): SimResult {
  const seconds = opts?.seconds ?? 120;
  const dt = opts?.dt ?? 1 / 60;
  const seed = opts?.seed ?? 1;
  const expression = opts?.expression ?? "neutral";

  const blink = new BlinkController(seed);
  blink.reset(seed);
  const blinkSamples: Array<{ t: number; left: number; right: number }> = [];
  const wave: SimResult["waveform"] = [];
  const hairSys = new HairSystem();
  hairSys.reset(seed + 9);

  const runHair = (wind: number, lookAmp: number, speaking: boolean, dur: number) => {
    hairSys.reset(seed + Math.round(wind * 10) + (speaking ? 3 : 0));
    const samples: Array<{ hair: number; bangs: number; tassel: number; sag: number; nape: number }> = [];
    const nHair = Math.floor(dur / dt);
    const breath = new BreathSystem();
    for (let i = 0; i < nHair; i += 1) {
      const t = i * dt;
      const lookX = Math.sin(t * 0.55) * lookAmp;
      const energy = speaking ? 0.35 + 0.35 * Math.abs(Math.sin(t * 7.2)) : 0;
      const br = breath.step(dt, t, speaking, energy);
      hairSys.setBreath(br.chest);
      hairSys.step(dt, t, { lookX, wind, speaking, energy });
      samples.push({
        hair: hairSys.hair.angle,
        bangs: hairSys.bangs.angle,
        tassel: hairSys.tassel.angle,
        sag: hairSys.hair.sag,
        nape: hairSys.nape.angle,
      });
    }
    return analyzeHairTrace(samples, dt);
  };

  const n = Math.floor(seconds / dt);
  const hairWave = new HairSystem();
  hairWave.reset(seed + 4);
  const gaze = new GazeController(seed + 31);
  gaze.reset(seed + 31);
  const idle = new IdleDirector(seed + 41);
  idle.reset(seed + 41);
  const breathIdle = new BreathSystem();
  const saccadeRng = createRng(seed + 19);
  let nextSaccade = 1.4;
  let saccadeCount = 0;
  const gazeXs: number[] = [];
  const pupils: number[] = [];
  const chests: number[] = [];
  const closedness: number[] = [];
  const brows: number[] = [];
  let idleBeats = 0;
  let lastBeat: IdleBeat = "rest";
  for (let i = 0; i < n; i += 1) {
    const t = i * dt;
    const idleState = idle.step(t, false, expression);
    if (idleState.beat !== lastBeat && idleState.beat !== "rest") idleBeats += 1;
    lastBeat = idleState.beat;
    if (MOTION.gaze.autoSaccade <= 0 && t >= nextSaccade) {
      blink.notifySaccade(t, expression);
      nextSaccade = t + 2.05 + saccadeRng.range(0, 2.8);
    }
    const g = gaze.step(dt, t, {
      speaking: false,
      energy: 0,
      expression,
      lookBiasX: idleState.lookBiasX,
      lookBiasY: idleState.lookBiasY,
    });
    if (gaze.didSaccade()) {
      saccadeCount += 1;
      blink.notifySaccade(t, expression);
    }
    const lids = blink.sample(t, expression, false);
    blinkSamples.push({ t, left: lids.left, right: lids.right });
    gazeXs.push(g.x);
    pupils.push(g.pupil);
    const br = breathIdle.step(dt, t, false, 0, idleState.breathBoost);
    chests.push(br.chest);
    closedness.push(1 - (lids.left + lids.right) * 0.5);
    brows.push(lids.browDip);
    if (t <= 16) {
      hairWave.setBreath(br.chest);
      hairWave.step(dt, t, { lookX: g.x, wind: 1, speaking: false, energy: 0 });
      wave.push({
        t,
        left: lids.left,
        right: lids.right,
        hair: hairWave.hair.angle,
        bangs: hairWave.bangs.angle,
        tassel: hairWave.tassel.angle,
      });
    }
  }

  const sleepyCtrl = new BlinkController(seed + 2);
  sleepyCtrl.reset(seed + 2);
  const sleepySamples: Array<{ t: number; left: number; right: number }> = [];
  const nSleep = Math.floor(60 / dt);
  for (let i = 0; i < nSleep; i += 1) {
    const t = i * dt;
    const lids = sleepyCtrl.sample(t, "sleepy", false);
    sleepySamples.push({ t, left: lids.left, right: lids.right });
  }

  const speakCtrl = new BlinkController(seed + 5);
  speakCtrl.reset(seed + 5);
  const speakSamples: Array<{ t: number; left: number; right: number }> = [];
  const nSpeak = Math.floor(24 / dt);
  let postSpeechExtra = 0;
  const visemes = ["A", "I", "M", "O", "F", "E", "M", "U"];
  for (let i = 0; i < nSpeak; i += 1) {
    const t = i * dt;
    const speaking = t < 18;
    const energy = speaking ? 0.4 + 0.3 * Math.abs(Math.sin(t * 6.2)) : 0;
    if (speaking && i % 12 === 0) {
      speakCtrl.notifyViseme(t, visemes[(i / 12) % visemes.length], expression, true);
    }
    const before = speakCtrl.debug().activeShots;
    const lids = speakCtrl.sample(t, expression, speaking, energy);
    if (!speaking && t < 20 && speakCtrl.debug().activeShots > before) postSpeechExtra += 1;
    speakSamples.push({ t, left: lids.left, right: lids.right });
  }

  return {
    blink: analyzeBlinkTrace(blinkSamples, dt),
    hair0: runHair(0, 0.1, false, 16),
    hair1: runHair(1, 0.35, false, 16),
    hair2: runHair(2, 0.5, false, 16),
    talk: runHair(1, 0.2, true, 12),
    sleepy: analyzeBlinkTrace(sleepySamples, dt),
    speakingBlink: analyzeBlinkTrace(speakSamples, dt),
    gaze: {
      saccadeRate: saccadeCount / seconds,
      rms: Math.sqrt(mean(gazeXs.map((v) => v * v))),
      meanAbsX: mean(gazeXs.map((v) => Math.abs(v))),
      pupilMean: mean(pupils),
    },
    breath: {
      rms: Math.sqrt(mean(chests.map((v) => v * v))),
      peak: chests.reduce((m, v) => Math.max(m, Math.abs(v)), 0),
    },
    postSpeechExtra,
    idleBeats,
    browBlinkCorr: pearson(closedness, brows),
    waveform: wave,
  };
}
