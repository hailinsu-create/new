#!/usr/bin/env node
/**
 * Quantify blink + hair motion. Writes JSON (+ SVG sparkline) for a round.
 *
 *   node --experimental-strip-types --no-warnings scripts/sim-motion.mjs 01
 */
import { mkdirSync, writeFileSync } from "node:fs";
import { MOTION, simulateMotion, analyzeBlinkTrace, legacyBlinkAmount } from "../src/avatar/motion.ts";

const round = String(process.argv[2] || "dev").padStart(2, "0");
const outDir = process.env.MOXI_OUT || "/opt/cursor/artifacts/moxi-motion-rounds";
mkdirSync(outDir, { recursive: true });

const dt = 1 / 60;
const sim = simulateMotion({ seconds: 180, dt, seed: 11 });

const legacy = [];
for (let t = 0; t < 180; t += dt) {
  const v = legacyBlinkAmount(t, 3.8);
  legacy.push({ t, left: v, right: v });
}
const legacyA = analyzeBlinkTrace(legacy, dt);

function svgWave(simWave, dest) {
  const w = 920;
  const h = 280;
  const n = simWave.length;
  if (!n) return;
  const t0 = simWave[0].t;
  const t1 = simWave[n - 1].t;
  const xOf = (t) => ((t - t0) / (t1 - t0)) * (w - 40) + 20;
  const yLid = (v) => 20 + (1 - v) * 90;
  const hairVals = simWave.map((s) => s.hair);
  const hMax = Math.max(0.04, ...hairVals.map((v) => Math.abs(v)));
  const yHair = (v) => 160 + (-v / hMax) * 50;
  const poly = (key, yfn, color) => {
    const pts = simWave.map((s) => `${xOf(s.t).toFixed(1)},${yfn(s[key]).toFixed(1)}`).join(" ");
    return `<polyline fill="none" stroke="${color}" stroke-width="1.4" points="${pts}" />`;
  };
  const svg = `<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${h}" viewBox="0 0 ${w} ${h}">
  <rect width="${w}" height="${h}" fill="#111814"/>
  <text x="20" y="16" fill="#c9a36a" font-size="12" font-family="sans-serif">Round ${round} · lids (top) / hair·bangs·tassel (bottom)</text>
  ${poly("left", yLid, "#f2d2c4")}
  ${poly("right", yLid, "#d08a8a")}
  ${poly("hair", yHair, "#9ad0b4")}
  ${poly("bangs", yHair, "#7aa0d6")}
  ${poly("tassel", yHair, "#e0c56e")}
</svg>`;
  writeFileSync(dest, svg);
}

const payload = {
  round,
  at: new Date().toISOString(),
  MOTION,
  legacy: legacyA,
  sim: {
    blink: sim.blink,
    sleepy: sim.sleepy,
    hair0: sim.hair0,
    hair1: sim.hair1,
    hair2: sim.hair2,
    talk: sim.talk,
  },
};

const jsonPath = `${outDir}/round-${round}.json`;
const svgPath = `${outDir}/round-${round}.svg`;
writeFileSync(jsonPath, `${JSON.stringify(payload, null, 2)}\n`);
svgWave(sim.waveform, svgPath);

const b = sim.blink;
const h = sim.hair1;
console.log(
  JSON.stringify(
    {
      round,
      jsonPath,
      svgPath,
      blink: {
        n: b.count,
        interval: Number(b.meanIntervalS.toFixed(3)),
        intervalRange: [Number(b.minIntervalS.toFixed(2)), Number(b.maxIntervalS.toFixed(2))],
        closeMs: Number(b.meanCloseMs.toFixed(1)),
        holdMs: Number(b.meanHoldMs.toFixed(1)),
        openMs: Number(b.meanOpenMs.toFixed(1)),
        totalMs: Number(b.meanTotalMs.toFixed(1)),
        minOpen: Number(b.meanMinOpen.toFixed(3)),
        lagMs: Number(b.meanLagMs.toFixed(1)),
        doubleRate: Number(b.doubleRate.toFixed(3)),
        notchRate: Number(b.notchRate.toFixed(3)),
      },
      hair1: {
        rms: Number(h.rms.toFixed(4)),
        peak: Number(h.peak.toFixed(4)),
        Hz: Number(h.freqHz.toFixed(3)),
        jerk: Number(h.maxJerk.toFixed(1)),
        bangsCorr: Number(h.bangsHairCorr.toFixed(3)),
        tasselCorr: Number(h.tasselHairCorr.toFixed(3)),
        bangsLagMs: Number(h.bangsLagMs.toFixed(0)),
        tasselLagMs: Number(h.tasselLagMs.toFixed(0)),
        sagRms: Number(h.sagRms.toFixed(4)),
        sagLagMs: Number(h.sagLagMs.toFixed(0)),
      },
      hair0rms: Number(sim.hair0.rms.toFixed(4)),
      hair2peak: Number(sim.hair2.peak.toFixed(4)),
      talkPeak: Number(sim.talk.peak.toFixed(4)),
      sleepyInterval: Number(sim.sleepy.meanIntervalS.toFixed(3)),
      sleepyTotalMs: Number(sim.sleepy.meanTotalMs.toFixed(1)),
      vsLegacyTotalMs: Number((b.meanTotalMs - legacyA.meanTotalMs).toFixed(1)),
      gaze: sim.gaze,
      breath: sim.breath,
      speakingInterval: Number(sim.speakingBlink.meanIntervalS.toFixed(3)),
      postSpeechExtra: sim.postSpeechExtra,
      idleBeats: sim.idleBeats,
      browBlinkCorr: Number(sim.browBlinkCorr.toFixed(3)),
      napeRms: Number(h.napeRms.toFixed(4)),
    },
    null,
    2,
  ),
);
