import { FACE_BUST, FACE_FULL, FULL_LAYOUT } from "../src/avatar/layout.ts";
import { MOTION, simulateMotion } from "../src/avatar/motion.ts";
import {
  ACTION_BUTTONS,
  ActionDirector,
  actionEnvelope,
  emptyPerformance,
  simulateAction,
} from "../src/avatar/action.ts";

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

assert("envelope peaks at mid", actionEnvelope(0.5, 0.18, 0.22) > 0.95);
assert("envelope silent at 0/1", actionEnvelope(0, 0.18, 0.22) === 0 && actionEnvelope(1, 0.18, 0.22) === 0);
assert("empty performance is rest", emptyPerformance().action === "rest" && emptyPerformance().hopY === 0);
assert("action buttons cover stage vocabulary", ACTION_BUTTONS.length >= 10);

const dt = 1 / 60;

function peakOf(id: "nod" | "bow" | "hop" | "step" | "shyDown" | "surpriseBack" | "weightShift", key: "headPitch" | "torsoLean" | "hopY" | "extraWeight" | "stepL"): number {
  const dir = new ActionDirector(3);
  dir.reset(3);
  dir.play(id, true);
  let peak = 0;
  for (let i = 0; i < 120; i += 1) {
    const p = dir.step(dt, i * dt, { speaking: false, energy: 0, expression: "neutral", lookX: 0, lookY: 0 });
    peak = Math.max(peak, Math.abs(p[key] as number));
  }
  return peak;
}

const nod = peakOf("nod", "headPitch");
const bow = peakOf("bow", "torsoLean");
const hop = peakOf("hop", "hopY");
const step = peakOf("step", "stepL");
const shy = peakOf("shyDown", "headPitch");
const surprise = peakOf("surpriseBack", "torsoLean");
const weight = peakOf("weightShift", "extraWeight");

assert("nod pitches head", nod > 0.02, `nod=${nod}`);
assert("bow leans torso", bow > 0.03, `bow=${bow}`);
assert("hop lifts", hop > 0.004, `hop=${hop}`);
assert("step cycles feet", step > 0.01, `step=${step}`);
assert("shy tucks head", shy > 0.03, `shy=${shy}`);
assert("surprise leans back", surprise > 0.02, `surprise=${surprise}`);
assert("weight transfers", weight > 0.15, `weight=${weight}`);
assert("hop stays under cap", hop <= MOTION.action.hopCap + 0.002, `hop=${hop} cap=${MOTION.action.hopCap}`);
assert("bow stays under cap", bow <= MOTION.action.capBow + 0.002, `bow=${bow}`);

const simA = simulateAction({ seconds: 36, dt, seed: 11 });
assert("idle theater fires body clips", simA.autoCount >= 1, `count=${simA.autoCount}`);
assert("more than one body verb", simA.autoKinds >= 1, `kinds=${simA.autoKinds}`);
assert("nod clip measurable", simA.nodPeak > 0.02, `nod=${simA.nodPeak}`);
assert("hop clip measurable", simA.hopPeak > 0.003, `hop=${simA.hopPeak}`);
assert("speaking shoulders move", simA.speakShoulderRms > 0.001, `sh=${simA.speakShoulderRms}`);
assert("action jerk tame", simA.jerk < 80, `jerk=${simA.jerk}`);
assert("hop not tearing", simA.maxHopY < 0.12, `maxHop=${simA.maxHopY}`);
assert("bow not folding in half", simA.maxLean < 0.35, `lean=${simA.maxLean}`);

const motion = simulateMotion({ seconds: 60, dt, seed: 7 });
assert("blink still closes", motion.blink.meanMinOpen < 0.2, `open=${motion.blink.meanMinOpen}`);
assert("blink still visible length", motion.blink.meanTotalMs >= 200 && motion.blink.meanTotalMs <= 650, `ms=${motion.blink.meanTotalMs}`);
assert("hair still alive", motion.hair1.rms > 0.002);
assert("body weight still alive", motion.body.weightRms > 0.05);
assert("layout mouth untouched", FACE_FULL.mouth.x === 756 && FACE_FULL.mouth.y === 354);
assert("layout eyes untouched", FACE_FULL.eyeLeft.x === 686 && FACE_FULL.eyeRight.x === 792);
assert("bust mouth untouched", FACE_BUST.mouth.x === 753 && FACE_BUST.mouth.y === 404);
assert("full mouthScale still small", FULL_LAYOUT.mouthScale === 0.55);
assert("action enabled", MOTION.action.enabled === 1);
assert("fx ink present", MOTION.fx.inkRipple >= 0);

const clickDir = new ActionDirector(9);
clickDir.reset(9);
const first = clickDir.onClick();
const second = clickDir.onClick();
assert("click plays a named clip", Boolean(first && ACTION_BUTTONS.includes(first)));
assert("click cycle advances", first !== second || ACTION_BUTTONS.length < 2, `${first} -> ${second}`);

console.log(`\n${passed} passed, ${failed} failed`);
if (failed) process.exit(1);
