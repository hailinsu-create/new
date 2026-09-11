import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import {
  finalToViseme,
  loadPinyin,
  pinyinOf,
  sampleTimeline,
  splitPinyin,
  textToVisemes,
  timelineDuration,
  type VisemeId,
} from "../src/avatar/viseme.ts";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const blob = readFileSync(join(root, "src/avatar/pinyin.txt"), "utf8");
const loaded = loadPinyin(blob);

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

function firstIds(text: string): VisemeId[] {
  return textToVisemes(text)
    .filter((event) => event.id !== "rest")
    .map((event) => event.id);
}

assert("pinyin dict loaded", loaded > 10000, `count=${loaded}`);
assert("墨 = mo", pinyinOf("墨") === "mo", `got ${pinyinOf("墨")}`);
assert("汐 = xi", pinyinOf("汐") === "xi", `got ${pinyinOf("汐")}`);
assert("妈 splits to m+a", splitPinyin("ma").initial === "m" && splitPinyin("ma").final === "a");
assert("a → A", finalToViseme("a") === "A");
assert("i → I", finalToViseme("i") === "I");
assert("u → U", finalToViseme("u") === "U");
assert("e → E", finalToViseme("e") === "E");
assert("o → O", finalToViseme("o") === "O");
assert("ong → O", finalToViseme("ong") === "O");
assert("ao → A", finalToViseme("ao") === "A");
assert("ing → I", finalToViseme("ing") === "I");

const ah = firstIds("啊");
assert("啊 uses A", ah[0] === "A", `got ${ah.join(",")}`);
const yi = firstIds("衣");
assert("衣 uses I", yi.includes("I"), `got ${yi.join(",")}`);
const wu = firstIds("乌");
assert("乌 uses U", wu.includes("U"), `got ${wu.join(",")}`);
const o = firstIds("哦");
assert("哦 uses O", o.includes("O"), `got ${o.join(",")}`);
const ei = firstIds("诶");
assert("诶 uses E", ei.includes("E"), `got ${ei.join(",")}`);

const ma = textToVisemes("妈");
assert("妈 starts with M", ma[0].id === "M", `got ${ma.map((e) => e.id).join(",")}`);
assert("妈 then A", ma.some((event) => event.id === "A"));

const feng = textToVisemes("风");
assert("风 starts with F", feng[0].id === "F", `got ${feng.map((e) => e.id).join(",")}`);

const pause = textToVisemes("月色。");
assert("句号产生 rest", pause.some((event) => event.char === "。" && event.id === "rest"));

const events = textToVisemes("月色入庭，风过竹梢。");
assert("中文台词有多帧口型", events.filter((event) => event.id !== "rest").length >= 8);
let t = -1;
let monotonic = true;
for (const event of events) {
  if (event.t < t) monotonic = false;
  t = event.t;
}
assert("时间轴单调", monotonic);
assert("时长为正", timelineDuration(events) > 1);

const hello = firstIds("hello");
assert("英文 hello 含开口型", hello.includes("E") || hello.includes("O"), `got ${hello.join(",")}`);
assert("英文 hello 含 L", hello.includes("L"), `got ${hello.join(",")}`);

const empty = textToVisemes("");
assert("空文本仍有收尾 rest", empty.length >= 1 && empty.every((event) => event.id === "rest"));

const mid = sampleTimeline(events, events[2].t + 0.01);
assert("采样命中当前 viseme", mid.id === events[2].id, `got ${mid.id} expected ${events[2].id}`);
assert("结束后回到 rest", sampleTimeline(events, timelineDuration(events) + 0.2).id === "rest");
assert("说话能量在开口时 > 0", sampleTimeline(events, events.find((e) => e.id === "A")?.t ?? 0.1).energy >= 0);
const spoken = textToVisemes("啊哦呜衣诶妈妈，月色入庭。");
assert("演示台词时长超过两秒", timelineDuration(spoken) > 2);
const pauseMid = spoken.find((event) => event.char === "，");
assert(
  "句中停顿仍算说话中",
  pauseMid ? sampleTimeline(spoken, pauseMid.t + 0.01).speaking : false,
);

if (failed) {
  console.error(`\n${failed} failed, ${passed} passed`);
  process.exit(1);
}
console.log(`\n${passed} passed`);
