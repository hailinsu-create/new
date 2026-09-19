#!/usr/bin/env node
/**
 * 100-round motion iteration (Round 21–120).
 * Each round mutates MOTION, simulates, keeps or reverts against a quality floor.
 *
 *   node --experimental-strip-types --no-warnings scripts/run-100-rounds.mjs
 */
import { mkdirSync, writeFileSync, readFileSync } from "node:fs";
import { MOTION, assignMotion, cloneMotion, simulateMotion } from "../src/avatar/motion.ts";
import {
  VISEME_TUNE,
  loadPinyin,
  sampleTimeline,
  textToVisemes,
  timelineDuration,
} from "../src/avatar/viseme.ts";

const outDir = process.env.MOXI_OUT || "/opt/cursor/artifacts/moxi-motion-rounds";
const logPath = process.env.MOXI_LOG || "/opt/cursor/artifacts/moxi-motion-iter-log-100.md";
const winnersPath = process.env.MOXI_WINNERS || "/opt/cursor/artifacts/moxi-motion-winners.json";
mkdirSync(outDir, { recursive: true });

loadPinyin(readFileSync(new URL("../src/avatar/pinyin.txt", import.meta.url), "utf8"));

function syncViseme() {
  Object.assign(VISEME_TUNE, MOTION.viseme);
}

function visemeMetrics() {
  const events = textToVisemes("月色入庭，风过竹梢。纸鹤还在，我也还在。Hello.");
  const dt = 1 / 60;
  const end = timelineDuration(events);
  let prev = 0;
  let prevD = 0;
  let maxJ = 0;
  let sumAbs = 0;
  let n = 0;
  for (let t = 0; t < end; t += dt) {
    const s = sampleTimeline(events, t);
    const d = (s.shape.open - prev) / dt;
    const j = (d - prevD) / dt;
    maxJ = Math.max(maxJ, Math.abs(j));
    sumAbs += Math.abs(d);
    n += 1;
    prev = s.shape.open;
    prevD = d;
  }
  return { maxJerk: maxJ, meanAbsVel: n ? sumAbs / n : 0, dur: end, events: events.length };
}

function floorBreak(sim) {
  if (sim.blink.meanTotalMs < 200 || sim.blink.meanTotalMs > 680) return `blink total ${sim.blink.meanTotalMs.toFixed(0)}ms`;
  if (sim.blink.meanMinOpen > 0.22) return `eyes not closing ${sim.blink.meanMinOpen.toFixed(3)}`;
  if (sim.blink.count < 8) return `few blinks ${sim.blink.count}`;
  if (sim.hair1.rms < 0.002) return "hair dead";
  if (sim.hair2.peak + 1e-6 < sim.hair0.peak * 0.85) return "wind=2 weaker than idle";
  if (sim.hair1.maxJerk > 90) return `jerk ${sim.hair1.maxJerk.toFixed(1)}`;
  if (sim.talk.peak > 0.26) return `talk peak ${sim.talk.peak.toFixed(3)}`;
  if (sim.hair2.peak > 0.33) return `hair wall ${sim.hair2.peak.toFixed(3)}`;
  if (sim.blink.meanIntervalS < 1.15 || sim.blink.meanIntervalS > 8.5) return `interval ${sim.blink.meanIntervalS.toFixed(2)}s`;
  return null;
}

function score(sim, vj) {
  const b = sim.blink;
  const h = sim.hair1;
  let s = 0;
  s -= Math.abs(b.meanTotalMs - 400) / 90;
  s -= Math.abs(b.meanIntervalS - 3.7) / 1.4;
  s -= Math.abs(b.notchRate - 0.15) / 0.14;
  s -= Math.abs(b.meanLagMs - 20) / 16;
  s += (0.985 - h.bangsHairCorr) * 2.2;
  s += Math.min(0.18, Math.abs(h.tasselLagMs) / 2200);
  s -= Math.min(2.4, h.maxJerk / 45);
  s += Math.min(0.55, sim.gaze.saccadeRate * 1.6);
  s += Math.min(0.45, sim.idleBeats / 18);
  s += Math.min(0.5, Math.max(0, sim.browBlinkCorr));
  if (sim.speakingBlink.meanIntervalS > b.meanIntervalS + 0.15) s += 0.28;
  if (sim.postSpeechExtra > 0) s += 0.18;
  s += Math.min(0.25, h.napeRms * 8);
  s += Math.min(0.2, sim.breath.rms / 8);
  s -= Math.min(1.2, vj.maxJerk / 400);
  return s;
}

function snap(sim, vj) {
  const b = sim.blink;
  const h = sim.hair1;
  return {
    blink: {
      n: b.count,
      interval: Number(b.meanIntervalS.toFixed(3)),
      range: [Number(b.minIntervalS.toFixed(2)), Number(b.maxIntervalS.toFixed(2))],
      closeMs: Number(b.meanCloseMs.toFixed(1)),
      holdMs: Number(b.meanHoldMs.toFixed(1)),
      openMs: Number(b.meanOpenMs.toFixed(1)),
      totalMs: Number(b.meanTotalMs.toFixed(1)),
      minOpen: Number(b.meanMinOpen.toFixed(3)),
      lagMs: Number(b.meanLagMs.toFixed(1)),
      notchRate: Number(b.notchRate.toFixed(3)),
    },
    hair1: {
      rms: Number(h.rms.toFixed(4)),
      peak: Number(h.peak.toFixed(4)),
      jerk: Number(h.maxJerk.toFixed(1)),
      bangsCorr: Number(h.bangsHairCorr.toFixed(3)),
      tasselLagMs: Number(h.tasselLagMs.toFixed(0)),
      napeRms: Number(h.napeRms.toFixed(4)),
    },
    talkPeak: Number(sim.talk.peak.toFixed(4)),
    hair2peak: Number(sim.hair2.peak.toFixed(4)),
    gazeRate: Number(sim.gaze.saccadeRate.toFixed(3)),
    breathRms: Number(sim.breath.rms.toFixed(3)),
    speakingInterval: Number(sim.speakingBlink.meanIntervalS.toFixed(3)),
    postSpeechExtra: sim.postSpeechExtra,
    idleBeats: sim.idleBeats,
    browBlinkCorr: Number(sim.browBlinkCorr.toFixed(3)),
    visemeJerk: Number(vj.maxJerk.toFixed(1)),
  };
}

const patches = [
  { r: 21, title: "扫视-注视模型接管闲置眼动", hyp: "autoSaccade 替代固定 2–5s 随机跳，注视更像活人。", keepIfSafe: true, apply: (m) => { m.gaze.autoSaccade = 1; m.gaze.saccadeSpeed = 18; m.gaze.saccadeMin = 0.9; m.gaze.saccadeMax = 2.6; } },
  { r: 22, title: "注视点 OU 微漂移", hyp: "driftSigma 0.016 让注视不是钉死像素。", keepIfSafe: true, apply: (m) => { m.gaze.driftSigma = 0.016; m.gaze.driftDecay = 2.2; } },
  { r: 23, title: "回中弹簧", hyp: "无指针时轻微回画面中心，避免眼神漂走。", keepIfSafe: true, apply: (m) => { m.gaze.centerSpring = 0.14; } },
  { r: 24, title: "说话时视线略垂", hyp: "speakLookY 0.07 像看对方嘴/胸前，更交谈。", keepIfSafe: true, apply: (m) => { m.gaze.speakLookY = 0.07; } },
  { r: 25, title: "微扫视", hyp: "12% 微跳 0.04 幅，打破蜡像眼。", keepIfSafe: true, apply: (m) => { m.gaze.microsaccadeProb = 0.12; m.gaze.microsaccadeAmp = 0.038; } },
  { r: 26, title: "睫毛跟随闭眼", hyp: "lashFollow 0.26，闭眼时外眼角睫毛压下。", keepIfSafe: true, apply: (m) => { m.blink.lashFollow = 0.26; } },
  { r: 27, title: "眨眼连带眉峰微沉", hyp: "browDip 0.17，闭眼时眉不是钢板。", keepIfSafe: true, apply: (m) => { m.blink.browDip = 0.17; } },
  { r: 28, title: "眨眼颊部轻挤", hyp: "cheekSqueeze 0.13，下睑/颊跟着闭眼。", keepIfSafe: true, apply: (m) => { m.blink.cheekSqueeze = 0.13; } },
  { r: 29, title: "说话时抑制眨眼", hyp: "intervalScale 1.2 + suppress 0.16s，说话少眨，更像真人。", keepIfSafe: true, apply: (m) => { m.blink.speakingIntervalScale = 1.2; m.blink.speakingSuppress = 0.16; m.blink.suppressEnergy = 0.5; } },
  { r: 30, title: "说完补偿双眨", hyp: "postSpeechBurst=2，句末补两下，余韵。", keepIfSafe: true, apply: (m) => { m.blink.postSpeechBurst = 2; } },
  { r: 31, title: "8% 深思慢眨", hyp: "thoughtful 拉长开合 1.38 倍，闲置偶尔「想一下」。", keepIfSafe: true, apply: (m) => { m.blink.thoughtfulProb = 0.08; m.blink.thoughtfulScale = 1.38; } },
  { r: 32, title: "闭口音眨眼", hyp: "M/F 20% 连带轻眨，口型-眼协同。", keepIfSafe: true, apply: (m) => { m.blink.closedVisemeBlink = 0.2; } },
  { r: 33, title: "瞳孔随说话微扩", hyp: "speakDilate 0.1，交谈时眼睛更「有神」。", keepIfSafe: true, apply: (m) => { m.pupil.speakDilate = 0.1; m.pupil.surpriseDilate = 0.16; m.pupil.sleepyConstrict = 0.1; } },
  { r: 34, title: "高光跟随视线", hyp: "catchlightFollow 0.55，眼球高光不再钉死。", keepIfSafe: true, apply: (m) => { m.pupil.catchlightFollow = 0.55; } },
  { r: 35, title: "左右睑幅度不对称", hyp: "lidAsym 0.05，去掉双胞胎眼。", keepIfSafe: true, apply: (m) => { m.blink.lidAsym = 0.05; } },
  { r: 36, title: "偶尔大扫视", hyp: "16% 大幅度扫视，其余小跳，符合主注视+偶离。", keepIfSafe: true, apply: (m) => { m.gaze.largeSaccadeProb = 0.16; m.gaze.smallAmp = 0.12; m.gaze.largeAmp = 0.34; } },
  { r: 37, title: "眨眼微点头", hyp: "headNod 0.03，闭眼带一点头颈。", keepIfSafe: true, apply: (m) => { m.blink.headNod = 0.03; } },
  { r: 38, title: "说完余韵计时", hyp: "afterglow 0.6s 把表情留住再松开。", keepIfSafe: true, apply: (m) => { m.afterglow.ms = 0.6; } },
  { r: 39, title: "闲置小剧场：斜睨", hyp: "idle 开启，32% glance。", keepIfSafe: true, apply: (m) => { m.idle.enabled = 1; m.idle.glanceProb = 0.32; m.idle.gapMin = 6; m.idle.gapMax = 13; } },
  { r: 40, title: "闲置将笑未笑", hyp: "almostSmile 0.22，嘴角与下睑轻抬。", keepIfSafe: true, apply: (m) => { m.idle.almostSmile = 0.22; } },
  { r: 41, title: "风场 1/f 频谱", hyp: "五倍频湍流比三正弦更像自然风。", keepIfSafe: true, apply: (m) => { m.wind.spectrum = "oneOverF"; } },
  { r: 42, title: "颈后发层", hyp: "nape 0.5Hz、弱风，侧发不再单片。", keepIfSafe: true, apply: (m) => { m.nape.windScale = 0.52; m.nape.idleAmp = 0.006; m.nape.impulseScale = 0.28; m.nape.sagAmount = 0.18; } },
  { r: 43, title: "流苏重力静置角", hyp: "gravity 0.3，流苏略垂，不像无重量丝带。", keepIfSafe: true, apply: (m) => { m.tassel.gravity = 0.3; } },
  { r: 44, title: "呼吸耦合头发", hyp: "hairCoupling 0.16，胸起伏轻轻带发。", keepIfSafe: true, apply: (m) => { m.breath.hairCoupling = 0.16; } },
  { r: 45, title: "碰撞软限制更软", hyp: "stiffness 18→13.5，强风顶墙不那么硬。", keepIfSafe: true, apply: (m) => { m.wind.softStiffness = 13.5; } },
  { r: 46, title: "锁发略增阻尼（湿重）", hyp: "ζ 0.55→0.59，少一点弹、多一点重量。", keepIfSafe: true, apply: (m) => { m.hair.zeta = 0.59; m.hair.drag = 2.55; } },
  { r: 47, title: "刘海独立阵风通道", hyp: "bangsGust 0.45，刘海不再只是侧发缩小版。", keepIfSafe: true, apply: (m) => { m.wind.bangsGust = 0.45; } },
  { r: 48, title: "黄金相位分层", hyp: "goldenPhase 打散三层 idle 相位。", keepIfSafe: true, apply: (m) => { m.wind.goldenPhase = 1; } },
  { r: 49, title: "风向游走", hyp: "dirWander 0.32，阵风方向慢慢转。", keepIfSafe: true, apply: (m) => { m.wind.dirWander = 0.32; } },
  { r: 50, title: "颈发反向冲量", hyp: "说话时 nape 与锁发反相，更有体积。", keepIfSafe: true, apply: (m) => { m.talk.napeOpposite = 1; } },
  { r: 51, title: "呼吸更慢更深", hyp: "0.21Hz、chest 2.7，闲置起伏更从容。", keepIfSafe: true, apply: (m) => { m.breath.hz = 0.21; m.breath.chest = 2.7; m.breath.speakHzBoost = 0.05; } },
  { r: 52, title: "肩线二次运动", hyp: "shoulder 0.8，披肩根随呼吸。", keepIfSafe: true, apply: (m) => { m.breath.shoulder = 0.8; } },
  { r: 53, title: "纸鹤别针 + 披肩", hyp: "crane 0.48 / shawl 0.32，胸口与肩有二级。", keepIfSafe: true, apply: (m) => { m.breath.crane = 0.48; m.breath.shawl = 0.32; } },
  { r: 54, title: "说话微点头包络", hyp: "headNod 0.012，口型能量带一点颔首。", keepIfSafe: true, apply: (m) => { m.talk.headNod = 0.012; } },
  { r: 55, title: "说完目光略垂", hyp: "afterglow.lookDown 0.12，句末余韵。", keepIfSafe: true, apply: (m) => { m.afterglow.lookDown = 0.12; } },
  { r: 56, title: "表情过渡更临界阻尼", hyp: "k 0.16 / damp 0.7，切换不那么「弹」。", keepIfSafe: true, apply: (m) => { m.face.transK = 0.16; m.face.transDamp = 0.7; } },
  { r: 57, title: "浅笑左右不对称", hyp: "smileAsym 0.07，右眼略睁、左睑略垂。", keepIfSafe: true, apply: (m) => { m.face.smileAsym = 0.07; } },
  { r: 58, title: "讶异先冻结再落", hyp: "surpriseFreeze 0.09s，像被吓到定住。", keepIfSafe: true, apply: (m) => { m.face.surpriseFreeze = 0.09; } },
  { r: 59, title: "含羞偷看", hyp: "shyPeek 0.42，羞时目光偶尔抬一点。", keepIfSafe: true, apply: (m) => { m.face.shyPeek = 0.42; } },
  { r: 60, title: "泪滴重力下落", hyp: "tearPhysics 用锯齿下落代替正弦闪。", keepIfSafe: true, apply: (m) => { m.face.tearPhysics = 1; } },
  { r: 61, title: "口型 blend 28→42ms", hyp: "加宽 viseme 交叉，减少咔哒换形。", keepIfSafe: true, apply: (m) => { m.viseme.blend = 0.042; } },
  { r: 62, title: "协同发音前瞻", hyp: "lookahead 32ms 提前向下一 viseme 融。", keepIfSafe: true, apply: (m) => { m.viseme.lookahead = 0.032; } },
  { r: 63, title: "口型攻放包络", hyp: "attack 35ms / release 60ms，开快收慢。", keepIfSafe: true, apply: (m) => { m.viseme.attack = 0.035; m.viseme.release = 0.06; } },
  { r: 64, title: "收声口型余韵", hyp: "restHold 140ms，说完嘴不瞬间回 rest。", keepIfSafe: true, apply: (m) => { m.viseme.restHold = 0.14; } },
  { r: 65, title: "A/O 颌部分开", hyp: "jawSplit 0.2，大开口略加深。", keepIfSafe: true, apply: (m) => { m.viseme.jawSplit = 0.2; } },
  { r: 66, title: "说话嘴角跟随 viseme", hyp: "mouthCurveTalk 0.16，表情与口型不打架。", keepIfSafe: true, apply: (m) => { m.viseme.mouthCurveTalk = 0.16; } },
  { r: 67, title: "标点停顿略长", hyp: "punctRest 1.15，句号更像换气。", keepIfSafe: true, apply: (m) => { m.viseme.punctRest = 1.15; } },
  { r: 68, title: "英文簇稍拉长", hyp: "englishUnit 1.08，英文口型不那么赶。", keepIfSafe: true, apply: (m) => { m.viseme.englishUnit = 1.08; } },
  { r: 69, title: "口型 jerk 上限", hyp: "jerkLimit 20 削掉 viseme 尖峰。", keepIfSafe: true, apply: (m) => { m.viseme.jerkLimit = 20; } },
  { r: 70, title: "闭口音稍延长", hyp: "closedHold 1.14，M/F 更咬得住。", keepIfSafe: true, apply: (m) => { m.viseme.closedHold = 1.14; } },
  { r: 71, title: "灯笼呼吸同步", hyp: "lantern 周期跟 breath.hz，庭院活一点。", keepIfSafe: true, apply: (m) => { m.atmosphere.lanternSync = 1; } },
  { r: 72, title: "萤火略亮", hyp: "firefly 1.18，仍克制。", keepIfSafe: true, apply: (m) => { m.atmosphere.firefly = 1.18; } },
  { r: 73, title: "花瓣更慢", hyp: "petal 1.14，飘落不赶。", keepIfSafe: true, apply: (m) => { m.atmosphere.petal = 1.14; } },
  { r: 74, title: "暗角呼吸", hyp: "vignettePulse 0.07，光影微起伏。", keepIfSafe: true, apply: (m) => { m.atmosphere.vignettePulse = 0.07; } },
  { r: 75, title: "庭院漂移更缓", hyp: "courtyard 28→38s。", keepIfSafe: true, apply: (m) => { m.atmosphere.courtyard = 38; } },
  { r: 76, title: "克制暖色温", hyp: "warmth 0.045，浅笑时再加一点，不毁水墨。", keepIfSafe: true, apply: (m) => { m.atmosphere.warmth = 0.045; } },
  { r: 77, title: "高光脉动放慢", hyp: "pulseHz 0.35→0.26，不闪。", keepIfSafe: true, apply: (m) => { m.pupil.pulseHz = 0.26; } },
  { r: 78, title: "腮红随呼吸", hyp: "blushCoupling 0.2。", keepIfSafe: true, apply: (m) => { m.breath.blushCoupling = 0.2; } },
  { r: 79, title: "切片视差减弱", hyp: "sliceLook 6.5→5.3，少橡胶头。", keepIfSafe: true, apply: (m) => { m.face.sliceLook = 5.3; } },
  { r: 80, title: "胸起伏略加深", hyp: "chest 2.7→3.05，仍是半身肖像幅度。", keepIfSafe: true, apply: (m) => { m.breath.chest = 3.05; } },
  { r: 81, title: "闲置叹气", hyp: "sighProb 0.15，慢眨+呼吸加深。", keepIfSafe: true, apply: (m) => { m.idle.sighProb = 0.15; m.breath.sighBoost = 0.55; } },
  { r: 82, title: "闲置偷看", hyp: "peekProb 0.11。", keepIfSafe: true, apply: (m) => { m.idle.peekProb = 0.11; } },
  { r: 83, title: "闲置节拍略密", hyp: "gap 5–11s，小剧场更常出现但仍稀疏。", keepIfSafe: true, apply: (m) => { m.idle.gapMin = 5; m.idle.gapMax = 11; } },
  { r: 84, title: "说完嘴角余韵", hyp: "mouthHold 0.18。", keepIfSafe: true, apply: (m) => { m.afterglow.mouthHold = 0.18; } },
  { r: 85, title: "开怀弹跳降频", hyp: "bounceHz 13.5→11，少抖。", keepIfSafe: true, apply: (m) => { m.talk.bounceHz = 11; } },
  { r: 86, title: "说话头颠减轻", hyp: "bob 1.6→1.05。", keepIfSafe: true, apply: (m) => { m.talk.bob = 1.05; } },
  { r: 87, title: "表情切换发丝冲量收一点", hyp: "exprImpulse 0.05→0.038，切表情不甩头。", keepIfSafe: true, apply: (m) => { m.face.exprImpulse = 0.038; } },
  { r: 88, title: "扫视阈值略降", hyp: "0.22→0.18，中等视线差也走扫视而非滑动。", keepIfSafe: true, apply: (m) => { m.gaze.saccadeThresh = 0.18; } },
  { r: 89, title: "扫视幅度混合", hyp: "小 0.11 / 大 0.3，大扫视 18%。", keepIfSafe: true, apply: (m) => { m.gaze.smallAmp = 0.11; m.gaze.largeAmp = 0.3; m.gaze.largeSaccadeProb = 0.18; } },
  { r: 90, title: "注视时长对数正态", hyp: "fixation 不再均匀，更像真人。", keepIfSafe: true, apply: (m) => { m.gaze.lognormalFixation = 1; m.gaze.waypointMix = 0.48; } },
  { r: 91, title: "收 hold 若被抖动拉长", hyp: "若可见 hold>48ms 则收 holdMax。", keepIfSafe: false, apply: (m, sim) => { if (sim.blink.meanHoldMs > 48) { m.blink.holdMax = 0.022; m.blink.holdMin = 0.012; } else { m.blink.durationJitter = 0.065; } } },
  { r: 92, title: "1/f 若 jerk 升高则降 turbMix", hyp: "守 jerk 底线，宁可风老实。", keepIfSafe: false, apply: (m, sim) => { if (sim.hair1.maxJerk > 18) m.wind.turbMix = 0.32; else m.wind.turbMix = 0.44; } },
  { r: 93, title: "流苏 look 再解耦", hyp: "tassel lookCoupling 0.06→0.045，层间更开。", keepIfSafe: false, apply: (m) => { m.tassel.lookCoupling = 0.045; m.tassel.windDelay = 0.2; } },
  { r: 94, title: "抑制能量阈微调", hyp: "suppressEnergy 0.5→0.45，轻声也少眨。", keepIfSafe: false, apply: (m) => { m.blink.suppressEnergy = 0.45; m.blink.speakingSuppress = 0.2; } },
  { r: 95, title: "双眨与慢眨互不抢", hyp: "若 notch>0.22 则略降 doubleProb。", keepIfSafe: false, apply: (m, sim) => { if (sim.blink.notchRate > 0.22) m.blink.doubleProb = 0.13; else if (sim.blink.notchRate < 0.1) m.blink.doubleProb = 0.17; else m.blink.doubleGapMax = 0.07; } },
  { r: 96, title: "说完回中 + 余韵目光", hyp: "centerSpring 在说话结束后更明显。", keepIfSafe: false, apply: (m) => { m.gaze.centerSpring = 0.18; m.afterglow.lookDown = 0.1; } },
  { r: 97, title: "闲置将笑 vs 余韵分工", hyp: "almostSmile 0.18，避免说完还假笑太满。", keepIfSafe: false, apply: (m) => { m.idle.almostSmile = 0.18; m.idle.glanceProb = 0.3; } },
  { r: 98, title: "强风峰值保险", hyp: "若 hair2.peak>0.18 则略收 gustMag。", keepIfSafe: false, apply: (m, sim) => { if (sim.hair2.peak > 0.18) m.wind.gustMag = 0.078; else m.wind.gustMag = 0.095; } },
  { r: 99, title: "兴趣点路点加强", hyp: "waypointMix 0.62，闲置眼神有故事。", keepIfSafe: true, apply: (m) => { m.gaze.waypointMix = 0.62; m.gaze.autoSaccade = 1; } },
  { r: 100, title: "闲置小剧场略勤（仍克制）", hyp: "gap 4.6–10s，glance 0.34，为 after 短片铺戏。", keepIfSafe: true, apply: (m) => { m.idle.gapMin = 4.6; m.idle.gapMax = 10; m.idle.glanceProb = 0.34; } },
  { r: 101, title: "不完全眨眼地板略收", hyp: "floor 0.12–0.24，轻眨别飘成半睁。", keepIfSafe: false, apply: (m) => { m.blink.incompleteFloorMax = 0.24; } },
  { r: 102, title: "刘海风延迟略增", hyp: "40→55ms，刘海更落后。", keepIfSafe: false, apply: (m) => { m.bangs.windDelay = 0.055; } },
  { r: 103, title: "锁发 sag 略增惯性", hyp: "sagZeta 0.7→0.64，拖尾更明显。", keepIfSafe: false, apply: (m) => { m.hair.sagZeta = 0.64; } },
  { r: 104, title: "困倦时呼吸更慢", hyp: "sleepy 不改 blink 底，只让 breath.hz 可被 idle sigh 用。", keepIfSafe: true, apply: (m) => { m.breath.sighBoost = 0.7; } },
  { r: 105, title: "瞳孔基础略放大", hyp: "base 0.46→0.5，夜庭里更湿润。", keepIfSafe: true, apply: (m) => { m.pupil.base = 0.5; } },
  { r: 106, title: "辐辏微内斜", hyp: "vergence 0.02，近处看时双眼略向内。", keepIfSafe: true, apply: (m) => { m.gaze.vergence = 0.02; } },
  { r: 107, title: "说话看嘴再克制", hyp: "speakLookY 0.07→0.05，别一直低头。", keepIfSafe: false, apply: (m) => { m.gaze.speakLookY = 0.05; } },
  { r: 108, title: "睫毛跟随略收", hyp: "0.26→0.2，避免画上睫毛抢原画。", keepIfSafe: false, apply: (m) => { m.blink.lashFollow = 0.2; } },
  { r: 109, title: "眉沉略收", hyp: "browDip 0.17→0.12，国风眉形别被压垮。", keepIfSafe: false, apply: (m) => { m.blink.browDip = 0.12; } },
  { r: 110, title: "颊挤略收", hyp: "cheek 0.13→0.1。", keepIfSafe: false, apply: (m) => { m.blink.cheekSqueeze = 0.1; } },
  { r: 111, title: "nape 频率再错开", hyp: "0.5→0.41Hz，与锁发 0.62 更分得开。", keepIfSafe: false, apply: (m) => { m.nape.freq = 0.41; m.nape.phase = 4.1; } },
  { r: 112, title: "流苏 ζ 略升防乱甩", hyp: "0.32→0.36。", keepIfSafe: false, apply: (m) => { m.tassel.zeta = 0.36; } },
  { r: 113, title: "口型 jerkLimit 若过钝则放松", hyp: "若 viseme 太肉则 20→28。", keepIfSafe: false, apply: (m, sim, vj) => { if (vj.maxJerk < 40) m.viseme.jerkLimit = 28; else if (vj.maxJerk > 180) m.viseme.jerkLimit = 16; } },
  { r: 114, title: "blend 与 lookahead 平衡", hyp: "blend 38ms / look 28ms，防双重融化。", keepIfSafe: false, apply: (m) => { m.viseme.blend = 0.038; m.viseme.lookahead = 0.028; } },
  { r: 115, title: "说话冲量微增但仍安全", hyp: "energyKick 0.004→0.0046，说话发丝更跟。", keepIfSafe: false, apply: (m) => { m.talk.energyKick = 0.0046; } },
  { r: 116, title: "闲置底噪刘海", hyp: "bangs.idleAmp 0.004→0.0055。", keepIfSafe: false, apply: (m) => { m.bangs.idleAmp = 0.0055; } },
  { r: 117, title: "指针平滑", hyp: "pointerSmooth 0.92，鼠标带动不那么黏。", keepIfSafe: true, apply: (m) => { m.gaze.pointerSmooth = 0.92; } },
  { r: 118, title: "暖色再克制", hyp: "warmth 0.045→0.03，水墨优先。", keepIfSafe: true, apply: (m) => { m.atmosphere.warmth = 0.03; } },
  { r: 119, title: "综合：注视路点 + 呼吸", hyp: "waypoint 0.55、chest 2.9，避免过火。", keepIfSafe: false, apply: (m) => { m.gaze.waypointMix = 0.55; m.breath.chest = 2.9; } },
  { r: 120, title: "收束：守眨眼 400ms 带", hyp: "若 total 偏离 400 超过 40ms 则微调控时长。", keepIfSafe: false, apply: (m, sim) => {
    const t = sim.blink.meanTotalMs;
    if (t > 450) { m.blink.openMax = 0.255; m.blink.closeMax = 0.185; }
    else if (t < 360) { m.blink.openMin = 0.22; m.blink.closeMin = 0.172; }
    else { m.blink.openMax = 0.265; }
  } },
];

if (patches.length !== 100) {
  throw new Error(`expected 100 patches, got ${patches.length}`);
}

const dt = 1 / 60;
syncViseme();
const baselineSim = simulateMotion({ seconds: 180, dt, seed: 11 });
const baselineV = visemeMetrics();
let baselineScore = score(baselineSim, baselineV);
const baselineSnap = snap(baselineSim, baselineV);

const lines = [];
lines.push("# 墨汐运动 · 100 轮迭代（Round 21–120）");
lines.push("");
lines.push("接续 `/opt/cursor/artifacts/moxi-motion-iter-log.md` 的 20 轮眨眼/头发成果。度量：`scripts/run-100-rounds.mjs`，180s @ 60fps，seed=11。");
lines.push("");
lines.push("质量底线：可见眨眼 200–680ms、能闭上、头发有运动、强风>无风、jerk<90、说话冲量不炸、不撞墙。坏轮回退。");
lines.push("");
lines.push(`## 进入本阶段时的基线（R20 默认 + 新系统关闭）`);
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
let lastV = baselineV;

writeFileSync(`${outDir}/round-20-baseline.json`, `${JSON.stringify({ MOTION, sim: baselineSnap, score: baselineScore }, null, 2)}\n`);

for (const patch of patches) {
  const before = cloneMotion(MOTION);
  const beforeScore = currentScore;
  const simBefore = lastSim;
  const vBefore = lastV;

  patch.apply(MOTION, simBefore, vBefore);
  syncViseme();
  const sim = simulateMotion({ seconds: 180, dt, seed: 11 });
  const vj = visemeMetrics();
  const broken = floorBreak(sim);
  const nowScore = score(sim, vj);
  const delta = nowScore - beforeScore;
  let verdict = "持平";
  let keptThis = true;
  if (broken) {
    verdict = "更差";
    keptThis = false;
  } else if (delta > 0.035) {
    verdict = "更好";
  } else if (delta < -0.045) {
    verdict = "更差";
    keptThis = patch.keepIfSafe ? true : false;
    if (patch.keepIfSafe && delta < -0.12) keptThis = false;
  } else {
    verdict = "持平";
    keptThis = patch.keepIfSafe || delta >= 0;
  }

  if (!keptThis) {
    assignMotion(MOTION, before);
    syncViseme();
    reverted += 1;
  } else {
    kept += 1;
    currentScore = nowScore;
    lastSim = sim;
    lastV = vj;
  }

  const evidence = snap(keptThis ? sim : simBefore, keptThis ? vj : vBefore);
  const payload = {
    round: patch.r,
    title: patch.title,
    hyp: patch.hyp,
    verdict,
    kept: keptThis,
    broken,
    score: Number((keptThis ? nowScore : beforeScore).toFixed(3)),
    delta: Number(delta.toFixed(3)),
    evidence,
  };
  writeFileSync(`${outDir}/round-${String(patch.r).padStart(3, "0")}.json`, `${JSON.stringify(payload, null, 2)}\n`);

  lines.push(`## Round ${patch.r} — ${patch.title}`);
  lines.push("");
  lines.push(`- **假设**：${patch.hyp}`);
  lines.push(`- **改动**：见 round-${String(patch.r).padStart(3, "0")}.json / MOTION 对应字段`);
  lines.push(`- **证据**：\`moxi-motion-rounds/round-${String(patch.r).padStart(3, "0")}.json\``);
  lines.push(`- **指标**：total=${evidence.blink.totalMs}ms interval=${evidence.blink.interval}s notch=${evidence.blink.notchRate} jerk=${evidence.hair1.jerk} bangsCorr=${evidence.hair1.bangsCorr} tasselLag=${evidence.hair1.tasselLagMs}ms talkPeak=${evidence.talkPeak} gaze=${evidence.gazeRate} idleBeats=${evidence.idleBeats} speakInt=${evidence.speakingInterval} post=${evidence.postSpeechExtra} browCorr=${evidence.browBlinkCorr} visemeJerk=${evidence.visemeJerk} scoreΔ=${delta.toFixed(3)}${broken ? ` floor=${broken}` : ""}`);
  lines.push(`- **结论**：**${verdict}**${keptThis ? "（保留）" : "（回退）"}。`);
  lines.push("");

  summary.push({
    round: patch.r,
    title: patch.title,
    verdict,
    kept: keptThis,
  });

  console.log(
    JSON.stringify({
      round: patch.r,
      verdict,
      kept: keptThis,
      delta: Number(delta.toFixed(3)),
      broken,
      totalMs: evidence.blink.totalMs,
      jerk: evidence.hair1.jerk,
    }),
  );
}

syncViseme();
const finalSim = simulateMotion({ seconds: 180, dt, seed: 11 });
const finalV = visemeMetrics();
const finalSnap = snap(finalSim, finalV);

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
lines.push("npm run sim:rounds");
lines.push("npm run sim:motion -- 120");
lines.push("npm run dev          # http://localhost:5173/");
lines.push("npm run record:motion-100");
lines.push("```");
lines.push("");

writeFileSync(logPath, `${lines.join("\n")}\n`);
writeFileSync(winnersPath, `${JSON.stringify({ MOTION, VISEME_TUNE, final: finalSnap, kept, reverted }, null, 2)}\n`);
console.log(`wrote ${logPath}`);
console.log(`wrote ${winnersPath}`);
console.log(JSON.stringify({ kept, reverted, baselineScore, finalScore: currentScore, final: finalSnap }, null, 2));
