export const VISEME_IDS = [
  "rest",
  "A",
  "E",
  "I",
  "O",
  "U",
  "WQ",
  "M",
  "F",
  "L",
  "S",
] as const;

export type VisemeId = (typeof VISEME_IDS)[number];

export type VisemeShape = {
  open: number;
  width: number;
  round: number;
  teeth: number;
  tongue: number;
  closed: number;
  curve: number;
};

export type VisemeEvent = {
  t: number;
  dur: number;
  id: VisemeId;
  char: string;
  index: number;
};

export const VISEME_SHAPE: Record<VisemeId, VisemeShape> = {
  rest: { open: 0, width: 1, round: 0, teeth: 0, tongue: 0, closed: 0, curve: 0.28 },
  A: { open: 0.94, width: 1.16, round: 0.18, teeth: 0.12, tongue: 0.08, closed: 0, curve: 0.12 },
  E: { open: 0.46, width: 1.22, round: 0.06, teeth: 0.42, tongue: 0.1, closed: 0, curve: 0.18 },
  I: { open: 0.2, width: 1.3, round: 0, teeth: 0.62, tongue: 0.05, closed: 0, curve: 0.22 },
  O: { open: 0.72, width: 0.7, round: 0.88, teeth: 0.06, tongue: 0.04, closed: 0, curve: 0.08 },
  U: { open: 0.36, width: 0.52, round: 1, teeth: 0, tongue: 0, closed: 0, curve: 0.04 },
  WQ: { open: 0.26, width: 0.46, round: 1, teeth: 0, tongue: 0, closed: 0, curve: 0.02 },
  M: { open: 0, width: 0.88, round: 0.22, teeth: 0, tongue: 0, closed: 1, curve: 0.06 },
  F: { open: 0.14, width: 1.04, round: 0.05, teeth: 0.82, tongue: 0, closed: 0.28, curve: 0.04 },
  L: { open: 0.42, width: 1.02, round: 0.12, teeth: 0.22, tongue: 1, closed: 0, curve: 0.1 },
  S: { open: 0.1, width: 1.14, round: 0, teeth: 0.92, tongue: 0, closed: 0, curve: 0.08 },
};

const INITIALS = [
  "zh",
  "ch",
  "sh",
  "b",
  "p",
  "m",
  "f",
  "d",
  "t",
  "n",
  "l",
  "g",
  "k",
  "h",
  "j",
  "q",
  "x",
  "r",
  "z",
  "c",
  "s",
  "y",
  "w",
] as const;

const INITIAL_VISEME: Record<string, VisemeId | null> = {
  b: "M",
  p: "M",
  m: "M",
  f: "F",
  d: "L",
  t: "L",
  n: "L",
  l: "L",
  zh: "S",
  ch: "S",
  sh: "S",
  z: "S",
  c: "S",
  s: "S",
  j: "S",
  q: "S",
  x: "S",
  r: "S",
  g: null,
  k: null,
  h: null,
  y: "I",
  w: "WQ",
};

const PINYIN = new Map<string, string>();

export function loadPinyin(blob: string): number {
  PINYIN.clear();
  const re = /(\p{Script=Han})([a-z]+)/gu;
  let count = 0;
  for (const match of blob.matchAll(re)) {
    PINYIN.set(match[1], match[2]);
    count += 1;
  }
  return count;
}

export function pinyinOf(char: string): string | undefined {
  return PINYIN.get(char);
}

export function splitPinyin(py: string): { initial: string; final: string } {
  const lower = py.toLowerCase();
  for (const initial of INITIALS) {
    if (lower.startsWith(initial) && lower.length > initial.length) {
      return { initial, final: lower.slice(initial.length) };
    }
  }
  return { initial: "", final: lower };
}

export function finalToViseme(final: string): VisemeId {
  const f = final.toLowerCase();
  if (f.includes("a")) return "A";
  if (f === "o" || f === "uo" || f === "ong" || f === "iong") return "O";
  if (f === "ou" || f === "iu") return "WQ";
  if (f === "u" || f === "un") return "U";
  if (f === "i" || f === "in" || f === "ing" || f === "v" || f === "vn") return "I";
  if (
    f === "e" ||
    f === "en" ||
    f === "eng" ||
    f === "er" ||
    f === "ei" ||
    f === "ui" ||
    f === "ie" ||
    f === "ue" ||
    f === "ve"
  ) {
    return "E";
  }
  return "E";
}

export function initialToViseme(initial: string): VisemeId | null {
  if (!initial) return null;
  return INITIAL_VISEME[initial] ?? null;
}

const CJK = /\p{Script=Han}/u;
const LATIN = /[A-Za-z]/;
const PUNCT = /[，。！？、；：,.!?;:…—～~]/;
const PAUSE = /[\s\n\r]/;

function hashViseme(char: string): VisemeId {
  const vowels: VisemeId[] = ["A", "E", "I", "O", "U"];
  const code = char.codePointAt(0) ?? 0;
  return vowels[code % vowels.length];
}

function push(
  events: VisemeEvent[],
  t: number,
  dur: number,
  id: VisemeId,
  char: string,
  index: number,
): number {
  events.push({ t, dur, id, char, index });
  return t + dur;
}

function appendSyllable(
  events: VisemeEvent[],
  start: number,
  char: string,
  index: number,
  py: string,
): number {
  const { initial, final } = splitPinyin(py);
  const onset = initialToViseme(initial);
  const nucleus = finalToViseme(final);
  let t = start;
  if (onset && onset !== nucleus) {
    t = push(events, t, 0.05, onset, char, index);
    t = push(events, t, 0.16, nucleus, char, index);
  } else {
    t = push(events, t, 0.2, nucleus, char, index);
  }
  return t;
}

function englishCluster(word: string): VisemeId[] {
  const w = word.toLowerCase();
  const ids: VisemeId[] = [];
  let i = 0;
  while (i < w.length) {
    const two = w.slice(i, i + 2);
    const one = w[i];
    if (two === "th" || two === "sh" || two === "ch") {
      ids.push("S");
      i += 2;
      continue;
    }
    if (two === "wh") {
      ids.push("WQ");
      i += 2;
      continue;
    }
    if (two === "oo") {
      ids.push("U");
      i += 2;
      continue;
    }
    if (two === "ee" || two === "ea" || two === "ey") {
      ids.push("I");
      i += 2;
      continue;
    }
    if (two === "ou" || two === "ow" || two === "aw") {
      ids.push("WQ");
      i += 2;
      continue;
    }
    if (two === "ar" || two === "ah") {
      ids.push("A");
      i += 2;
      continue;
    }
    if ("mbp".includes(one)) ids.push("M");
    else if ("fv".includes(one)) ids.push("F");
    else if ("lndt".includes(one)) ids.push("L");
    else if ("szcjx".includes(one)) ids.push("S");
    else if (one === "a") ids.push("A");
    else if (one === "e") ids.push("E");
    else if (one === "i" || one === "y") ids.push("I");
    else if (one === "o") ids.push("O");
    else if (one === "u" || one === "w") ids.push("U");
    i += 1;
  }
  return ids.length ? ids : ["E"];
}

export function textToVisemes(text: string): VisemeEvent[] {
  const events: VisemeEvent[] = [];
  let t = 0.04;
  let i = 0;
  const src = text.normalize("NFC");

  while (i < src.length) {
    const char = src[i];

    if (PAUSE.test(char)) {
      t = push(events, t, 0.08, "rest", char, i);
      i += 1;
      continue;
    }
    if (PUNCT.test(char)) {
      t = push(events, t, char === "。" || char === "." ? 0.32 : 0.2, "rest", char, i);
      i += 1;
      continue;
    }

    if (CJK.test(char)) {
      const py = PINYIN.get(char);
      if (py) {
        t = appendSyllable(events, t, char, i, py);
      } else {
        t = push(events, t, 0.2, hashViseme(char), char, i);
      }
      i += 1;
      continue;
    }

    if (LATIN.test(char)) {
      let j = i;
      while (j < src.length && LATIN.test(src[j])) j += 1;
      const word = src.slice(i, j);
      const clusters = englishCluster(word);
      const unit = Math.min(0.11, 0.42 / clusters.length);
      for (const id of clusters) {
        t = push(events, t, unit, id, word, i);
      }
      i = j;
      continue;
    }

    t = push(events, t, 0.12, "rest", char, i);
    i += 1;
  }

  t = push(events, t, 0.18, "rest", "", src.length);
  return events;
}

export function timelineDuration(events: readonly VisemeEvent[]): number {
  if (events.length === 0) return 0;
  const last = events[events.length - 1];
  return last.t + last.dur;
}

export function lerpShape(a: VisemeShape, b: VisemeShape, t: number): VisemeShape {
  const k = t < 0 ? 0 : t > 1 ? 1 : t;
  return {
    open: a.open + (b.open - a.open) * k,
    width: a.width + (b.width - a.width) * k,
    round: a.round + (b.round - a.round) * k,
    teeth: a.teeth + (b.teeth - a.teeth) * k,
    tongue: a.tongue + (b.tongue - a.tongue) * k,
    closed: a.closed + (b.closed - a.closed) * k,
    curve: a.curve + (b.curve - a.curve) * k,
  };
}

export type VisemeSample = {
  id: VisemeId;
  shape: VisemeShape;
  char: string;
  index: number;
  speaking: boolean;
  energy: number;
};

const REST_SAMPLE: VisemeSample = {
  id: "rest",
  shape: VISEME_SHAPE.rest,
  char: "",
  index: -1,
  speaking: false,
  energy: 0,
};

export function sampleTimeline(
  events: readonly VisemeEvent[],
  time: number,
  blend = 0.028,
): VisemeSample {
  if (events.length === 0 || time < 0) return REST_SAMPLE;
  const end = timelineDuration(events);
  if (time >= end) return REST_SAMPLE;

  let current = events[0];
  let currentIndex = 0;
  for (let i = 0; i < events.length; i += 1) {
    const event = events[i];
    if (time >= event.t && time < event.t + event.dur) {
      current = event;
      currentIndex = i;
      break;
    }
    if (time >= event.t) {
      current = event;
      currentIndex = i;
    }
  }

  let shape = VISEME_SHAPE[current.id];
  const local = time - current.t;
  if (local < blend && currentIndex > 0) {
    const prev = events[currentIndex - 1];
    shape = lerpShape(VISEME_SHAPE[prev.id], shape, local / blend);
  }

  return {
    id: current.id,
    shape,
    char: current.char,
    index: current.index,
    speaking: true,
    energy: shape.open * 0.75 + shape.round * 0.2 + (current.id === "M" ? 0.35 : 0),
  };
}

export function visemeLabel(id: VisemeId): string {
  const labels: Record<VisemeId, string> = {
    rest: "静",
    A: "啊",
    E: "诶",
    I: "衣",
    O: "哦",
    U: "乌",
    WQ: "喔",
    M: "姆",
    F: "夫",
    L: "勒",
    S: "斯",
  };
  return labels[id];
}
