import {
  sampleTimeline,
  textToVisemes,
  timelineDuration,
  VisemeFilter,
  VISEME_TUNE,
  warpSpeechClock,
  type VisemeEvent,
  type VisemeId,
  type VisemeSample,
} from "./viseme";

export type VoiceMode = "auto" | "tts" | "murmur" | "silent";

export type SpeechListeners = {
  onStart?: () => void;
  onEnd?: () => void;
  onChar?: (char: string, index: number) => void;
};

type MurmurNodes = {
  context: AudioContext;
  osc: OscillatorNode;
  noise: AudioBufferSourceNode;
  filter: BiquadFilterNode;
  gain: GainNode;
  analyser: AnalyserNode;
  bins: Uint8Array<ArrayBuffer>;
};

const FORMANT_HZ: Record<VisemeId, number> = {
  rest: 220,
  A: 820,
  E: 540,
  I: 330,
  O: 560,
  U: 340,
  WQ: 300,
  M: 180,
  F: 420,
  L: 480,
  S: 2100,
};

export class SpeechDriver {
  private events: VisemeEvent[] = [];
  private startedAt = 0;
  private playing = false;
  private utterance: SpeechSynthesisUtterance | null = null;
  private murmur: MurmurNodes | null = null;
  private lastCharIndex = -1;
  private hold: VisemeSample | null = null;
  private listeners: SpeechListeners = {};
  private filter = new VisemeFilter();
  private clockOffset = 0;
  private ttsActive = false;
  private envelope = 0;
  muted = false;

  get speaking(): boolean {
    return this.playing;
  }

  get timeline(): readonly VisemeEvent[] {
    return this.events;
  }

  configure(listeners: SpeechListeners): void {
    this.listeners = listeners;
  }

  holdViseme(sample: VisemeSample | null): void {
    this.hold = sample;
  }

  stop(): void {
    this.playing = false;
    this.events = [];
    this.ttsActive = false;
    this.clockOffset = 0;
    this.envelope = 0;
    if (this.utterance && typeof speechSynthesis !== "undefined") {
      speechSynthesis.cancel();
      this.utterance = null;
    }
    this.stopMurmur();
    this.listeners.onEnd?.();
  }

  async speak(text: string, mode: VoiceMode = "auto"): Promise<void> {
    const trimmed = text.trim();
    if (!trimmed) return;
    this.stop();
    this.events = textToVisemes(trimmed);
    this.startedAt = performance.now();
    this.playing = true;
    this.lastCharIndex = -1;
    this.clockOffset = 0;
    this.ttsActive = false;
    this.envelope = 0;
    this.filter.reset();
    this.listeners.onStart?.();

    const resolved = this.resolveMode(mode);
    if (resolved === "tts") {
      this.speakTts(trimmed);
    } else if (resolved === "murmur" && !this.muted) {
      await this.startMurmur();
    }
  }

  sample(now = performance.now()): VisemeSample {
    if (this.hold) return this.hold;
    if (!this.playing) {
      return sampleTimeline([], 0);
    }
    const wall = (now - this.startedAt) / 1000;
    const env = this.readEnvelope();
    if (env > 0) this.envelope += (env - this.envelope) * 0.35;
    else this.envelope *= 0.86;
    const time = wall + this.clockOffset;
    const dur = timelineDuration(this.events);
    if (time >= dur) {
      if (this.ttsActive) {
        const tail = this.filter.sample(sampleTimeline(this.events, Math.max(0, dur - 0.04)), now);
        return { ...tail, energy: tail.energy * 0.35, speaking: true };
      }
      this.finish();
      return sampleTimeline([], 0);
    }
    let sample = this.filter.sample(sampleTimeline(this.events, Math.max(0, time)), now);
    if (this.envelope > 0.08 && sample.speaking) {
      const boost = 0.82 + 0.28 * Math.min(1, this.envelope);
      sample = {
        ...sample,
        shape: { ...sample.shape, open: Math.min(1, sample.shape.open * boost) },
        energy: sample.energy * (0.85 + 0.25 * Math.min(1, this.envelope)),
      };
    }
    if (sample.index !== this.lastCharIndex && sample.char) {
      this.lastCharIndex = sample.index;
      this.listeners.onChar?.(sample.char, sample.index);
    }
    this.updateMurmur(sample);
    return sample;
  }

  private finish(): void {
    if (!this.playing) return;
    this.playing = false;
    this.ttsActive = false;
    this.clockOffset = 0;
    this.stopMurmur();
    if (this.utterance && typeof speechSynthesis !== "undefined") {
      speechSynthesis.cancel();
      this.utterance = null;
    }
    this.listeners.onEnd?.();
  }

  private resolveMode(mode: VoiceMode): VoiceMode {
    if (mode === "auto") {
      return this.hasTtsVoice() ? "tts" : "murmur";
    }
    if (mode === "tts" && !this.hasTtsVoice()) return "murmur";
    return mode;
  }

  private hasTtsVoice(): boolean {
    if (typeof window === "undefined" || !("speechSynthesis" in window)) return false;
    try {
      return speechSynthesis.getVoices().length > 0;
    } catch {
      return false;
    }
  }

  private speakTts(text: string): void {
    if (this.muted) return;
    const utterance = new SpeechSynthesisUtterance(text);
    utterance.lang = /[\u4e00-\u9fff]/.test(text) ? "zh-CN" : "en-US";
    utterance.rate = 0.96;
    utterance.pitch = 1.05;
    const voices = speechSynthesis.getVoices();
    const preferred =
      voices.find((voice) => voice.lang.startsWith("zh") && /female|ting|xiao|hui|yaoyao/i.test(voice.name)) ??
      voices.find((voice) => voice.lang.startsWith("zh")) ??
      voices.find((voice) => voice.lang.startsWith(utterance.lang));
    if (preferred) utterance.voice = preferred;
    utterance.onstart = () => {
      this.ttsActive = true;
    };
    utterance.onboundary = (event) => {
      if (typeof event.charIndex !== "number") return;
      const match =
        this.events.find((item) => item.index === event.charIndex) ??
        this.events.find((item) => item.index >= event.charIndex && item.id !== "rest");
      if (!match) return;
      const wall = (performance.now() - this.startedAt) / 1000;
      this.clockOffset = warpSpeechClock(wall, this.clockOffset, match.t, VISEME_TUNE.audioFollow);
    };
    utterance.onend = () => {
      this.ttsActive = false;
      this.utterance = null;
      this.finish();
    };
    utterance.onerror = () => {
      this.ttsActive = false;
    };
    this.utterance = utterance;
    this.ttsActive = true;
    speechSynthesis.cancel();
    speechSynthesis.speak(utterance);
  }

  private async startMurmur(): Promise<void> {
    const AudioCtx = window.AudioContext || (window as typeof window & { webkitAudioContext?: typeof AudioContext }).webkitAudioContext;
    if (!AudioCtx) return;
    const context = new AudioCtx();
    if (context.state === "suspended") {
      try {
        await context.resume();
      } catch {
        return;
      }
    }
    const osc = context.createOscillator();
    osc.type = "triangle";
    osc.frequency.value = 208;
    const filter = context.createBiquadFilter();
    filter.type = "bandpass";
    filter.frequency.value = 540;
    filter.Q.value = 2.4;
    const gain = context.createGain();
    gain.gain.value = 0;
    const noise = context.createBufferSource();
    const buffer = context.createBuffer(1, context.sampleRate * 2, context.sampleRate);
    const data = buffer.getChannelData(0);
    for (let i = 0; i < data.length; i += 1) data[i] = (Math.random() * 2 - 1) * 0.22;
    noise.buffer = buffer;
    noise.loop = true;
    const noiseGain = context.createGain();
    noiseGain.gain.value = 0.18;
    osc.connect(filter);
    noise.connect(noiseGain);
    noiseGain.connect(filter);
    filter.connect(gain);
    const analyser = context.createAnalyser();
    analyser.fftSize = 256;
    analyser.smoothingTimeConstant = 0.5;
    gain.connect(analyser);
    gain.connect(context.destination);
    osc.start();
    noise.start();
    this.murmur = {
      context,
      osc,
      noise,
      filter,
      gain,
      analyser,
      bins: new Uint8Array(new ArrayBuffer(analyser.fftSize)),
    };
  }

  private readEnvelope(): number {
    if (!this.murmur) return 0;
    this.murmur.analyser.getByteTimeDomainData(this.murmur.bins);
    let sum = 0;
    const bins = this.murmur.bins;
    for (let i = 0; i < bins.length; i += 1) {
      const v = (bins[i] - 128) / 128;
      sum += v * v;
    }
    return Math.min(1, Math.sqrt(sum / bins.length) * 6.5);
  }

  private updateMurmur(sample: VisemeSample): void {
    if (!this.murmur) return;
    const now = this.murmur.context.currentTime;
    const hz = FORMANT_HZ[sample.id];
    this.murmur.filter.frequency.setTargetAtTime(hz, now, 0.03);
    this.murmur.osc.frequency.setTargetAtTime(196 + sample.shape.open * 28, now, 0.04);
    const amp = this.muted || sample.id === "rest" || sample.id === "M" ? 0 : 0.028 + sample.energy * 0.04;
    this.murmur.gain.gain.setTargetAtTime(amp, now, 0.02);
  }

  private stopMurmur(): void {
    if (!this.murmur) return;
    try {
      this.murmur.osc.stop();
      this.murmur.noise.stop();
      void this.murmur.context.close();
    } catch {
      // already stopped
    }
    this.murmur = null;
  }
}

