#!/usr/bin/env node
/**
 * 100-round body-action iteration (Round 121–220).
 * Each round mutates MOTION.action / fx / cloth, simulates, keeps or reverts.
 *
 *   node --experimental-strip-types --no-warnings scripts/run-action-100.mjs
 */
import { mkdirSync, writeFileSync } from "node:fs";
import { MOTION, assignMotion, cloneMotion, simulateMotion } from "../src/avatar/motion.ts";
import { simulateAction } from "../src/avatar/action.ts";
import { FACE_FULL, FULL_LAYOUT } from "../src/avatar/layout.ts";
import { buildPatches } from "./action-patches.mjs";

const outDir = process.env.MOXI_OUT || "/opt/cursor/artifacts/moxi-action-rounds";
const logPath = process.env.MOXI_LOG || "/opt/cursor/artifacts/moxi-action-iter-log-100.md";
const winnersPath = process.env.MOXI_WINNERS || "/opt/cursor/artifacts/moxi-action-winners.json";
mkdirSync(outDir, { recursive: true });

function setPath(root, path, value) {
  const keys = path.split(".");
  let cur = root;
  for (let i = 0; i < keys.length - 1; i += 1) cur = cur[keys[i]];
  cur[keys[keys.length - 1]] = value;
}

function getPath(root, path) {
  const keys = path.split(".");
  let cur = root;
  for (const key of keys) cur = cur?.[key];
  return cur;
}



function floorBreak(sim, act) {
  if (sim.blink.meanTotalMs < 200 || sim.blink.meanTotalMs > 680) return `blink total ${sim.blink.meanTotalMs.toFixed(0)}ms`;
  if (sim.blink.meanMinOpen > 0.22) return `eyes not closing ${sim.blink.meanMinOpen.toFixed(3)}`;
  if (sim.hair1.rms < 0.002) return "hair dead";
  if (sim.hair1.maxJerk > 90) return `hair jerk ${sim.hair1.maxJerk.toFixed(1)}`;
  if (sim.body.weightRms < 0.04) return "weight dead";
  if (act.maxHopY > 0.11) return `hop tear ${act.maxHopY.toFixed(3)}`;
  if (act.maxLean > 0.32) return `bow fold ${act.maxLean.toFixed(3)}`;
  if (act.maxHeadPitch > 0.3) return `pitch ${act.maxHeadPitch.toFixed(3)}`;
  if (act.maxSkirt > 0.42) return `skirt ${act.maxSkirt.toFixed(3)}`;
  if (act.jerk > 90) return `action jerk ${act.jerk.toFixed(1)}`;
  if (FACE_FULL.mouth.x !== 756 || FACE_FULL.mouth.y !== 354) return "mouth landmark drifted";
  if (FULL_LAYOUT.mouthScale !== 0.55) return "mouthScale drifted";
  return null;
}

function score(sim, act) {
  let s = 0;
  s -= Math.abs(sim.blink.meanTotalMs - 400) / 90;
  s += Math.min(1.4, act.autoKinds / 5);
  s += Math.min(0.8, act.autoCount / 8);
  s += Math.min(0.95, act.nodPeak / 0.07);
  s += Math.min(0.95, act.bowPeak / 0.13);
  s += Math.min(0.95, act.hopPeak / 0.022);
  s += Math.min(0.6, act.stepRms * 20);
  s += Math.min(0.45, act.weightPeak / 1.15);
  s += Math.min(0.5, act.speakShoulderRms * 14);
  s += Math.min(0.4, act.afterBow * 0.18);
  s += Math.min(0.4, act.shyPeak * 4);
  s += Math.min(0.35, act.laughHop * 20);
  s += Math.min(0.3, act.shyExprPeak * 3);
  s += Math.min(0.2, act.clickPlays / 8);
  s -= Math.min(1.6, act.jerk / 50);
  s -= Math.min(1.2, sim.hair1.maxJerk / 45);
  if (act.nodPeak > 0.1) s -= (act.nodPeak - 0.1) * 10;
  if (act.maxHopY > 0.055) s -= (act.maxHopY - 0.055) * 16;
  if (act.maxLean > 0.2) s -= (act.maxLean - 0.2) * 8;
  if (act.hopPeak > 0.034) s -= (act.hopPeak - 0.034) * 12;
  s += Math.min(0.25, sim.body.skirtRms * 8);
  s += Math.min(0.2, sim.body.hemRms * 6);
  if (sim.body.shawlSkirtCorr < 0.96) s += 0.12;
  return s;
}

function snap(sim, act) {
  return {
    blinkMs: Number(sim.blink.meanTotalMs.toFixed(1)),
    blinkOpen: Number(sim.blink.meanMinOpen.toFixed(3)),
    hairJerk: Number(sim.hair1.maxJerk.toFixed(1)),
    weightRms: Number(sim.body.weightRms.toFixed(4)),
    skirtRms: Number(sim.body.skirtRms.toFixed(4)),
    nodPeak: Number(act.nodPeak.toFixed(4)),
    bowPeak: Number(act.bowPeak.toFixed(4)),
    hopPeak: Number(act.hopPeak.toFixed(4)),
    stepRms: Number(act.stepRms.toFixed(4)),
    shyPeak: Number(act.shyPeak.toFixed(4)),
    autoCount: act.autoCount,
    autoKinds: act.autoKinds,
    afterBow: act.afterBow,
    speakSh: Number(act.speakShoulderRms.toFixed(4)),
    laughHop: Number(act.laughHop.toFixed(4)),
    shyExpr: Number(act.shyExprPeak.toFixed(4)),
    clickPlays: act.clickPlays,
    maxHop: Number(act.maxHopY.toFixed(4)),
    maxLean: Number(act.maxLean.toFixed(4)),
    jerk: Number(act.jerk.toFixed(1)),
    mouth: { ...FACE_FULL.mouth },
    mouthScale: FULL_LAYOUT.mouthScale,
  };
}

const patches = buildPatches();

if (patches.length !== 100) {
  throw new Error(`expected 100 patches, got ${patches.length}`);
}

const dt = 1 / 60;
const baselineSim = simulateMotion({ seconds: 90, dt, seed: 11 });
const baselineAct = simulateAction({ seconds: 40, dt, seed: 11 });
let baselineScore = score(baselineSim, baselineAct);
const baselineSnap = snap(baselineSim, baselineAct);

const lines = [];
lines.push("# 墨汐全身表演 · 100 轮迭代（Round 121–220）");
lines.push("");
lines.push("接续眨眼/发丝/全身二次运动。本阶段自己选题：站姿身段、踏步预备、情绪表演、布料弧度、庭院效果、点击交互，且不破坏已修好的嘴脸对齐。");
lines.push("");
lines.push("度量：`scripts/run-action-100.mjs`，运动仿真 90s + 身段仿真 40s @ 60fps，seed=11。");
lines.push("");
lines.push("质量底线：眨眼 200–680ms 能闭上、头发还在动、轻跳/鞠躬不撕层、裙摆不炸、`FACE_FULL.mouth` 与 `mouthScale` 不变。坏轮回退。");
lines.push("");
lines.push("## 进入本阶段时的基线（ActionDirector 已接入、参数未迭代）");
lines.push("");
lines.push("```json");
lines.push(JSON.stringify({ score: Number(baselineScore.toFixed(3)), ...baselineSnap }, null, 2));
lines.push("```");
lines.push("");

const summary = [];
let currentScore = baselineScore;
let kept = 0;
let reverted = 0;
let lastSim = baselineSim;
let lastAct = baselineAct;
const decade = [];

writeFileSync(
  `${outDir}/round-120-baseline.json`,
  `${JSON.stringify({ MOTION: { action: MOTION.action, fx: MOTION.fx }, sim: baselineSnap, score: baselineScore }, null, 2)}\n`,
);

for (const patch of patches) {
  const before = cloneMotion(MOTION);
  const beforeScore = currentScore;
  const simBefore = lastSim;
  const actBefore = lastAct;

  const diff = {};
  if (patch.set) {
    for (const [path, value] of Object.entries(patch.set)) {
      const prev = getPath(before, path);
      if (Object.is(prev, value)) {
        diff[path] = { from: prev, to: value, already: true };
        continue;
      }
      diff[path] = { from: prev, to: value };
      setPath(MOTION, path, value);
    }
  }
  if (patch.apply) {
    patch.apply(MOTION, simBefore, actBefore);
    if (JSON.stringify(MOTION) === JSON.stringify(before)) {
      diff.apply = "already";
    } else {
      diff.apply = true;
    }
  }

  const sim = simulateMotion({ seconds: 90, dt, seed: 11 });
  const act = simulateAction({ seconds: 40, dt, seed: 11 });
  const broken = floorBreak(sim, act);
  const nowScore = score(sim, act);
  const delta = nowScore - beforeScore;
  let verdict = "持平";
  let keptThis = true;
  if (broken) {
    verdict = "更差";
    keptThis = false;
  } else if (delta > 0.03) {
    verdict = "更好";
  } else if (delta < -0.04) {
    verdict = "更差";
    keptThis = patch.keepIfSafe ? true : false;
    if (patch.keepIfSafe && delta < -0.12) keptThis = false;
  } else {
    verdict = "持平";
    keptThis = patch.keepIfSafe || delta >= 0;
  }

  if (!keptThis) {
    assignMotion(MOTION, before);
    reverted += 1;
  } else {
    kept += 1;
    currentScore = nowScore;
    lastSim = sim;
    lastAct = act;
  }

  const evidence = snap(keptThis ? sim : simBefore, keptThis ? act : actBefore);
  const payload = {
    round: patch.r,
    title: patch.title,
    hyp: patch.hyp,
    verdict,
    kept: keptThis,
    broken,
    score: Number((keptThis ? nowScore : beforeScore).toFixed(3)),
    delta: Number(delta.toFixed(3)),
    set: patch.set ?? null,
    diff,
    evidence,
  };
  writeFileSync(`${outDir}/round-${patch.r}.json`, `${JSON.stringify(payload, null, 2)}\n`);

  lines.push(`## Round ${patch.r} — ${patch.title}`);
  lines.push("");
  lines.push(`- **假设**：${patch.hyp}`);
  lines.push(`- **改动**：\`${JSON.stringify(diff)}\``);
  lines.push(`- **证据**：\`moxi-action-rounds/round-${patch.r}.json\``);
  lines.push(
    `- **指标**：nod=${evidence.nodPeak} bow=${evidence.bowPeak} hop=${evidence.hopPeak} step=${evidence.stepRms} auto=${evidence.autoCount}/${evidence.autoKinds} afterBow=${evidence.afterBow} speakSh=${evidence.speakSh} maxHop=${evidence.maxHop} jerk=${evidence.jerk} blink=${evidence.blinkMs}ms hairJerk=${evidence.hairJerk} mouth=(${evidence.mouth.x},${evidence.mouth.y}) scoreΔ=${delta.toFixed(3)}${broken ? ` floor=${broken}` : ""}`,
  );
  lines.push(`- **结论**：**${verdict}**${keptThis ? "（保留）" : "（回退）"}。`);
  lines.push("");

  summary.push({ round: patch.r, title: patch.title, verdict, kept: keptThis });
  decade.push({ round: patch.r, verdict, kept: keptThis, delta });

  if (patch.r % 10 === 0) {
    const chunk = decade.splice(0, decade.length);
    const keepN = chunk.filter((c) => c.kept).length;
    const backN = chunk.length - keepN;
    lines.push(`### 小结 Round ${patch.r - 9}–${patch.r}`);
    lines.push("");
    lines.push(`保留 ${keepN}，回退 ${backN}。嘴点仍为 (${FACE_FULL.mouth.x}, ${FACE_FULL.mouth.y})，mouthScale=${FULL_LAYOUT.mouthScale}。`);
    lines.push("");
  }

  console.log(
    JSON.stringify({
      round: patch.r,
      verdict,
      kept: keptThis,
      delta: Number(delta.toFixed(3)),
      broken,
      hop: evidence.hopPeak,
      nod: evidence.nodPeak,
    }),
  );
}

const finalSim = simulateMotion({ seconds: 90, dt, seed: 11 });
const finalAct = simulateAction({ seconds: 40, dt, seed: 11 });
const finalSnap = snap(finalSim, finalAct);

lines.push("---");
lines.push("");
lines.push("## 100 轮一览");
lines.push("");
lines.push("| 轮 | 焦点 | 结论 | 去留 |");
lines.push("| --- | --- | --- | --- |");
for (const row of summary) {
  lines.push(`| ${row.round} | ${row.title} | ${row.verdict} | ${row.kept ? "留" : "回"} |`);
}
lines.push("");
lines.push(`保留 ${kept} 轮，回退 ${reverted} 轮。最终 score ${currentScore.toFixed(3)}（基线 ${baselineScore.toFixed(3)}）。`);
lines.push("");
lines.push("## 最终指标");
lines.push("");
lines.push("```json");
lines.push(JSON.stringify(finalSnap, null, 2));
lines.push("```");
lines.push("");
lines.push("## 本地复现");
lines.push("");
lines.push("```bash");
lines.push("npm test");
lines.push("npm run sim:actions");
lines.push("npm run dev          # http://localhost:5173/");
lines.push("npm run record:actions-100");
lines.push("```");
lines.push("");

writeFileSync(logPath, `${lines.join("\n")}\n`);
writeFileSync(
  winnersPath,
  `${JSON.stringify({ action: MOTION.action, fx: MOTION.fx, body: MOTION.body, skirt: MOTION.skirt, hem: MOTION.hem, tassel: MOTION.tassel, atmosphere: MOTION.atmosphere, afterglow: MOTION.afterglow, blinkHeadNod: MOTION.blink.headNod, final: finalSnap, kept, reverted }, null, 2)}\n`,
);
console.log(`wrote ${logPath}`);
console.log(`wrote ${winnersPath}`);
console.log(JSON.stringify({ kept, reverted, baselineScore, finalScore: currentScore, final: finalSnap }, null, 2));
