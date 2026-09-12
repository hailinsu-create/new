import {
  MOTION,
  analyzeBlinkTrace,
  applyEase,
  legacyBlinkAmount,
  lidFromShot,
  simulateMotion,
  type BlinkShot,
} from "../src/avatar/motion.ts";

let failed = 0;
let passed = 0;

function assert(name: string, condition: boolean, detail = ""): void {
  if (condition) {
    passed += 1;
    console.log(`ok  ${name}`);
  } else {
    failed += 1;
    console.error(`fail  ${name}${detail ? ` — ${detail}` : ""}`);
  }
}

const shot: BlinkShot = {
  t0: 0,
  close: MOTION.blink.closeMin,
  hold: MOTION.blink.holdMin,
  open: MOTION.blink.openMin,
  floor: 0,
  leftLag: 0,
  rightLag: 0,
  double: false,
  thoughtful: false,
  ampLeft: 1,
  ampRight: 1,
};

assert("open at t0", lidFromShot(0, shot, 0) > 0.99);
assert("mid-close darker than start", lidFromShot(shot.close * 0.5, shot, 0) < 0.7);
assert("fully closed at hold", lidFromShot(shot.close + shot.hold * 0.5, shot, 0) <= 0.02);
assert("open again after envelope", lidFromShot(shot.close + shot.hold + shot.open + 0.01, shot, 0) > 0.99);
assert("inOut ease mid is not linear 0.5", Math.abs(applyEase("inOut", 0.5) - 0.5) < 0.02);
assert("outCubic faster than linear at 0.3", applyEase("outCubic", 0.3) > 0.3);

const legacy: Array<{ t: number; left: number; right: number }> = [];
const dt = 1 / 60;
for (let t = 0; t < 40; t += dt) {
  const v = legacyBlinkAmount(t, 3.8);
  legacy.push({ t, left: v, right: v });
}
const legacyA = analyzeBlinkTrace(legacy, dt);
assert("legacy total under 420ms", legacyA.meanTotalMs < 420, `got ${legacyA.meanTotalMs.toFixed(1)}`);
assert("legacy interval ~3.8s", Math.abs(legacyA.meanIntervalS - 3.8) < 0.15, `got ${legacyA.meanIntervalS.toFixed(2)}`);

const sim = simulateMotion({ seconds: 90, dt, seed: 7 });
console.log("metrics", JSON.stringify({ blink: sim.blink, hair1: sim.hair1, sleepy: sim.sleepy }, null, 2));

assert(
  "new blink has events",
  sim.blink.count >= 8,
  `count=${sim.blink.count}`,
);
assert(
  "visible blink 200-650ms",
  sim.blink.meanTotalMs >= 200 && sim.blink.meanTotalMs <= 650,
  `got ${sim.blink.meanTotalMs.toFixed(1)}`,
);
assert("eyes actually close", sim.blink.meanMinOpen < 0.2, `got ${sim.blink.meanMinOpen.toFixed(3)}`);
assert("idle wind=1 has motion", sim.hair1.rms > 0.002, `rms=${sim.hair1.rms}`);
assert("wind=2 larger than wind=0", sim.hair2.peak >= sim.hair0.peak);
assert("sleepy blinks more often or slower", sim.sleepy.meanIntervalS < sim.blink.meanIntervalS + 0.4 || sim.sleepy.meanTotalMs > sim.blink.meanTotalMs);
assert("nape layer moves", sim.hair1.napeRms > 0.001, `nape=${sim.hair1.napeRms}`);
assert("gaze has saccades", sim.gaze.saccadeRate > 0.15, `rate=${sim.gaze.saccadeRate}`);
assert("idle theater fires", sim.idleBeats >= 1, `beats=${sim.idleBeats}`);
assert("brow follows blink", sim.browBlinkCorr > 0.4, `corr=${sim.browBlinkCorr}`);
assert("speaking blinks less often", sim.speakingBlink.meanIntervalS + 0.05 >= sim.blink.meanIntervalS * 0.7, `speak=${sim.speakingBlink.meanIntervalS} idle=${sim.blink.meanIntervalS}`);
assert("post-speech compensation exists", sim.postSpeechExtra >= 1, `extra=${sim.postSpeechExtra}`);
assert("layered hair still independent", sim.hair1.bangsHairCorr < 0.98, `corr=${sim.hair1.bangsHairCorr}`);
assert("hair jerk stays tame", sim.hair1.maxJerk < 80, `jerk=${sim.hair1.maxJerk}`);
assert("idle weight shift", sim.body.weightRms > 0.05, `weight=${sim.body.weightRms}`);
assert("skirt idle motion", sim.body.skirtRms > 0.002, `skirt=${sim.body.skirtRms}`);
assert("shawl idle motion", sim.body.shawlRms > 0.002, `shawl=${sim.body.shawlRms}`);
assert("hem idle motion", sim.body.hemRms > 0.002, `hem=${sim.body.hemRms}`);
assert("shawl not glued to skirt", sim.body.shawlSkirtCorr < 0.98, `corr=${sim.body.shawlSkirtCorr}`);

console.log(`\n${passed} passed, ${failed} failed`);
if (failed) process.exit(1);
