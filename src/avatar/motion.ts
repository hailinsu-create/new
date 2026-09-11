/**
 * Blink scheduling and hair secondary motion.
 * Tuned in-place across the 20-round iteration; MOTION is the live preset.
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

export type Lids = { left: number; right: number };

export type BlinkShot = {
  t0: number;
  close: number;
  hold: number;
  open: number;
  floor: number;
  leftLag: number;
  rightLag: number;
  double: boolean;
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
};

export type MotionDebug = {
  lids: Lids;
  nextBlinkAt: number;
  activeShots: number;
  hair: StrandState;
  bangs: StrandState;
  tassel: StrandState;
  wind: WindSample;
};

type Rng = {
  next: () => number;
  range: (min: number, max: number) => number;
  chance: (p: number) => boolean;
  gauss: () => number;
};

export const MOTION = {
  blink: {
    /** Close / hold / open durations in seconds. */
    closeMin: 0.168,
    closeMax: 0.19,
    holdMin: 0.014,
    holdMax: 0.028,
    openMin: 0.21,
    openMax: 0.27,
    /** Rest interval between blink *onsets*. */
    intervalMean: 4.05,
    intervalMin: 2.15,
    intervalMax: 6.2,
    intervalSigma: 1.05,
    doubleProb: 0.16,
    doubleGapMin: 0.02,
    doubleGapMax: 0.08,
    incompleteProb: 0.12,
    incompleteFloorMin: 0.12,
    incompleteFloorMax: 0.28,
    lagMin: 0.01,
    lagMax: 0.028,
    saccadeBlinkProb: 0.22,
    durationJitter: 0.07,
    speakingIntervalScale: 0.84,
    /** close easing: linear | smooth | inOut | inOutClose */
    closeEase: "visibleClose" as "linear" | "smooth" | "inOut" | "inOutClose" | "visibleClose",
    /** open easing: linear | outCubic | outQuart | smooth | visibleOpen */
    openEase: "visibleOpen" as "linear" | "outCubic" | "outQuart" | "smooth" | "visibleOpen",
  },
  hair: {
    integrator: "sho" as "legacy" | "sho",
    k: 0.058,
    damp: 0.86,
    freq: 0.62,
    zeta: 0.55,
    lookCoupling: 0.1,
    windScale: 1.18,
    impulseScale: 0.85,
    minAngle: -0.26,
    maxAngle: 0.16,
    lookDelay: 0.05,
    windDelay: 0,
    sagFreq: 0.38,
    sagZeta: 0.7,
    sagAmount: 0.48,
    drag: 2.4,
    idleAmp: 0.008,
    idleFreq: 0.47,
    phase: 0.2,
    turbAmp: 0.08,
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
    windDelay: 0.04,
    sagFreq: 0.9,
    sagZeta: 0.85,
    sagAmount: 0,
    drag: 3.4,
    idleAmp: 0.004,
    idleFreq: 1.12,
    phase: 1.35,
    turbAmp: 0.03,
  },
  tassel: {
    integrator: "sho" as "legacy" | "sho",
    k: 0.042,
    damp: 0.9,
    freq: 0.44,
    zeta: 0.32,
    lookCoupling: 0.06,
    windScale: 1.58,
    impulseScale: 1.15,
    minAngle: -0.34,
    maxAngle: 0.34,
    lookDelay: 0.09,
    windDelay: 0.18,
    sagFreq: 0.33,
    sagZeta: 0.45,
    sagAmount: 0.22,
    drag: 1.5,
    idleAmp: 0.014,
    idleFreq: 0.67,
    phase: 2.15,
    turbAmp: 0.12,
  },
  wind: {
    model: "gusty" as "sines" | "wander" | "gusty",
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
    turbMix: 0.4,
  },
  talk: {
    spikeThreshold: 0.15,
    spikeKick: 0.07,
    spikeBase: 0.04,
    energyKick: 0.004,
    kickGain: 12,
  },
};

export type MotionTuning = typeof MOTION;
export type StrandTuning = typeof MOTION.hair;

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

export function lidFromShot(seconds: number, shot: BlinkShot, lag: number): number {
  const u = seconds - shot.t0 - lag;
  if (u <= 0) return 1;
  const close = shot.close;
  const hold = shot.hold;
  const open = shot.open;
  const floor = shot.floor;
  if (u < close) {
    const e = applyEase(MOTION.blink.closeEase, u / close);
    return 1 - (1 - floor) * e;
  }
  if (u < close + hold) return floor;
  if (u < close + hold + open) {
    const e = applyEase(MOTION.blink.openEase, (u - close - hold) / open);
    return floor + (1 - floor) * e;
  }
  return 1;
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

  constructor(seed = 0x51ed) {
    this.rng = createRng(seed);
  }

  reset(seed?: number): void {
    if (seed != null) this.rng = createRng(seed);
    this.shots = [];
    this.nextAt = 1.15 + this.rng.range(0, 1.8);
    this.lastSaccadeBlinkAt = -10;
  }

  notifySaccade(seconds: number, expression: ExpressionName): void {
    if (MOTION.blink.saccadeBlinkProb <= 0) return;
    if (expression === "laugh" || expression === "wink") return;
    if (seconds - this.lastSaccadeBlinkAt < 1.4) return;
    if (!this.rng.chance(MOTION.blink.saccadeBlinkProb)) return;
    this.lastSaccadeBlinkAt = seconds;
    this.queueBlink(seconds + this.rng.range(0.04, 0.16), expression, false);
  }

  trigger(seconds: number, expression: ExpressionName): void {
    this.queueBlink(seconds, expression, false);
    this.armNext(seconds, expression, false);
  }

  sample(seconds: number, expression: ExpressionName, speaking: boolean): Lids {
    if (seconds >= this.nextAt) {
      this.queueBlink(seconds, expression, speaking);
      this.armNext(seconds, expression, speaking);
    }
    this.shots = this.shots.filter((shot) => seconds < shot.t0 + shot.close + shot.hold + shot.open + 0.08);
    let left = 1;
    let right = 1;
    for (const shot of this.shots) {
      left = Math.min(left, lidFromShot(seconds, shot, shot.leftLag));
      right = Math.min(right, lidFromShot(seconds, shot, shot.rightLag));
    }
    return { left, right };
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
    const lagSpan = MOTION.blink.lagMax - MOTION.blink.lagMin;
    const lag = lagSpan <= 0 ? 0 : this.rng.range(MOTION.blink.lagMin, MOTION.blink.lagMax);
    const lagOnLeft = this.rng.chance(0.5);
    const shot: BlinkShot = {
      t0: seconds,
      close: j(profile.closeMin, profile.closeMax),
      hold: j(profile.holdMin, profile.holdMax),
      open: j(profile.openMin, profile.openMax),
      floor: incomplete
        ? this.rng.range(MOTION.blink.incompleteFloorMin, MOTION.blink.incompleteFloorMax)
        : 0,
      leftLag: lagOnLeft ? lag : 0,
      rightLag: lagOnLeft ? 0 : lag,
      double: asDouble,
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
  if (a > max) {
    v += (max - a) * 18 * dt;
    v *= Math.exp(-6 * dt);
  } else if (a < min) {
    v += (min - a) * 18 * dt;
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
  nextGustAt = 1.4;
  last: WindSample = { wander: 0, gust: 0, turb: 0, sines: 0, value: 0 };

  constructor(seed = 0xc0ffee) {
    this.rng = createRng(seed);
  }

  reset(seed?: number): void {
    if (seed != null) this.rng = createRng(seed);
    this.wander = 0;
    this.gust = 0;
    this.smooth = 0;
    this.nextGustAt = 1.2 + this.rng.range(0, 2);
    this.last = { wander: 0, gust: 0, turb: 0, sines: 0, value: 0 };
  }

  step(seconds: number, dt: number, wind: number): WindSample {
    const cfg = MOTION.wind;
    const boosted = wind <= 1 ? wind : 1 + (wind - 1) * 1.5;
    const level = Math.max(cfg.idleFloor, boosted);
    const sines =
      Math.sin(seconds * cfg.sineA) * cfg.sineAmpA * wind +
      Math.sin(seconds * cfg.sineB) * cfg.sineAmpB * wind;
    const turb =
      (Math.sin(seconds * 0.61 + 0.3) * 0.5 +
        Math.sin(seconds * 1.13 + 1.9) * 0.28 +
        Math.sin(seconds * 0.29 + 2.4) * 0.55) *
      0.035 *
      level *
      cfg.turbMix;

    this.wander += (this.rng.next() - 0.5) * 2 * cfg.wanderSigma * dt * Math.max(0.12, level);
    this.wander *= Math.exp(-cfg.wanderDecay * dt);

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
    this.last = { wander: this.wander, gust: this.gust, turb, sines, value: this.smooth };
    return this.last;
  }
}

export class HairSystem {
  hair = emptyStrand();
  bangs = emptyStrand();
  tassel = emptyStrand();
  wind = new WindField();
  private lookHist: number[] = [];
  private windHist: number[] = [];
  private lastEnergy = 0;

  reset(seed?: number): void {
    this.hair = emptyStrand();
    this.bangs = emptyStrand();
    this.tassel = emptyStrand();
    this.wind.reset(seed);
    this.lookHist = [];
    this.windHist = [];
    this.lastEnergy = 0;
  }

  impulse(strength: number): void {
    const gain = MOTION.hair.integrator === "sho" ? MOTION.talk.kickGain : 1;
    this.hair.velocity -= strength * MOTION.hair.impulseScale * gain;
    this.bangs.velocity -= strength * MOTION.bangs.impulseScale * gain;
    this.tassel.velocity += strength * MOTION.tassel.impulseScale * gain;
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
    );
    this.drive(
      this.bangs,
      MOTION.bangs,
      dt,
      seconds,
      delayed(this.lookHist, MOTION.bangs.lookDelay, input.lookX),
      { ...field, value: delayed(this.windHist, MOTION.bangs.windDelay, field.value) },
    );
    this.drive(
      this.tassel,
      MOTION.tassel,
      dt,
      seconds,
      delayed(this.lookHist, MOTION.tassel.lookDelay, input.lookX),
      { ...field, value: delayed(this.windHist, MOTION.tassel.windDelay, field.value) },
    );
  }

  debug(): { hair: StrandState; bangs: StrandState; tassel: StrandState; wind: WindSample } {
    return {
      hair: { ...this.hair },
      bangs: { ...this.bangs },
      tassel: { ...this.tassel },
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
  ): void {
    const idle = Math.sin(seconds * spec.idleFreq + spec.phase) * spec.idleAmp;
    const layerTurb = field.turb * spec.turbAmp * (0.7 + 0.4 * Math.sin(spec.phase + 0.8));
    const gust = field.value * spec.windScale;
    const target = -lookX * spec.lookCoupling + gust + idle + layerTurb;
    stepStrand(strand, dt, target, spec);
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
  samples: Array<{ hair: number; bangs: number; tassel: number; sag?: number }>,
  dt: number,
): HairAnalysis {
  const hair = samples.map((s) => s.hair);
  const bangs = samples.map((s) => s.bangs);
  const tassel = samples.map((s) => s.tassel);
  const sag = samples.map((s) => s.sag ?? 0);
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
  };
}

export type SimResult = {
  blink: BlinkAnalysis;
  hair0: HairAnalysis;
  hair1: HairAnalysis;
  hair2: HairAnalysis;
  talk: HairAnalysis;
  sleepy: BlinkAnalysis;
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
    const samples: Array<{ hair: number; bangs: number; tassel: number; sag: number }> = [];
    const n = Math.floor(dur / dt);
    for (let i = 0; i < n; i += 1) {
      const t = i * dt;
      const lookX = Math.sin(t * 0.55) * lookAmp;
      const energy = speaking ? 0.35 + 0.35 * Math.abs(Math.sin(t * 7.2)) : 0;
      hairSys.step(dt, t, { lookX, wind, speaking, energy });
      samples.push({
        hair: hairSys.hair.angle,
        bangs: hairSys.bangs.angle,
        tassel: hairSys.tassel.angle,
        sag: hairSys.hair.sag,
      });
    }
    return analyzeHairTrace(samples, dt);
  };

  const n = Math.floor(seconds / dt);
  const hairWave = new HairSystem();
  hairWave.reset(seed + 4);
  const saccadeRng = createRng(seed + 19);
  let nextSaccade = 1.4;
  for (let i = 0; i < n; i += 1) {
    const t = i * dt;
    if (t >= nextSaccade) {
      blink.notifySaccade(t, expression);
      nextSaccade = t + 2.05 + saccadeRng.range(0, 2.8);
    }
    const lids = blink.sample(t, expression, false);
    blinkSamples.push({ t, ...lids });
    if (t <= 16) {
      const lookX = Math.sin(t * 0.55) * 0.35;
      hairWave.step(dt, t, { lookX, wind: 1, speaking: false, energy: 0 });
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
    sleepySamples.push({ t, ...sleepyCtrl.sample(t, "sleepy", false) });
  }

  return {
    blink: analyzeBlinkTrace(blinkSamples, dt),
    hair0: runHair(0, 0.1, false, 16),
    hair1: runHair(1, 0.35, false, 16),
    hair2: runHair(2, 0.5, false, 16),
    talk: runHair(1, 0.2, true, 12),
    sleepy: analyzeBlinkTrace(sleepySamples, dt),
    waveform: wave,
  };
}
