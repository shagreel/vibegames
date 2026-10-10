import type { Cue } from './model';

/**
 * The game's sound effects, synthesised in the browser, so nothing is shipped as
 * an audio asset.
 *
 * A direct port of `SoundEngine.swift`, which does the same thing with
 * AVAudioEngine: the buzzer is a stack of detuned square waves with a slight
 * downward pitch bend through a low-pass, which is what makes it read as a
 * game-show "time's up" rather than a beep. Building the buffers once and
 * playing them back is what keeps the first cue from arriving late.
 */

const SAMPLE_RATE = 44100;

const DURATION: Record<Cue, number> = {
  start: 0.3,
  tick: 0.08,
  buzzer: 1.05,
};

function square(t: number, frequency: number): number {
  return Math.sin(2 * Math.PI * frequency * t) >= 0 ? 1 : -1;
}

function envelope(progress: number, attack: number, release: number): number {
  if (progress < attack) return progress / attack;
  if (progress > 1 - release) return Math.max(0, (1 - progress) / release);
  return 1;
}

/** Two quick rising notes: "ba-doop". */
function startSample(t: number, progress: number): number {
  const split = 0.5;
  const second = progress >= split;
  const frequency = second ? 880 : 587.33;
  const local = second ? (progress - split) / (1 - split) : progress / split;
  const wave = 0.6 * Math.sin(2 * Math.PI * frequency * t) + 0.25 * Math.sin(2 * Math.PI * frequency * 2 * t);
  return wave * envelope(local, 0.04, 0.65) * 0.5;
}

/** A short, dry click for the final seconds. */
function tickSample(t: number, progress: number): number {
  const wave = Math.sin(2 * Math.PI * 1450 * t);
  const attack = progress < 0.02 ? progress / 0.02 : 1;
  return wave * Math.exp(-30 * progress) * attack * 0.45;
}

/** Detuned square-wave buzzer with a pitch bend. */
function buzzerSample(t: number, progress: number): number {
  const bend = 1 - 0.16 * progress;
  const fundamental = 138 * bend;
  const wave =
    0.6 * square(t, fundamental) +
    0.34 * square(t, fundamental * 1.013) +
    0.26 * square(t, fundamental * 0.5) +
    0.14 * square(t, fundamental * 2.02);
  const roughness = 1 + 0.07 * Math.sin(2 * Math.PI * 24 * t);
  return wave * roughness * envelope(progress, 0.008, 0.22) * 0.4;
}

/** Cascaded one-pole low-pass, to take the digital edge off. */
function lowPass(samples: Float32Array, passes: number, coefficient = 0.5): void {
  for (let pass = 0; pass < passes; pass += 1) {
    let previous = samples[0];
    for (let i = 1; i < samples.length; i += 1) {
      previous += coefficient * (samples[i] - previous);
      samples[i] = previous;
    }
  }
}

// Typed against ArrayBuffer rather than ArrayBufferLike: copyToChannel will
// not accept a view that might be backed by a SharedArrayBuffer.
function makeSamples(cue: Cue): Float32Array<ArrayBuffer> {
  const total = Math.floor(SAMPLE_RATE * DURATION[cue]);
  const samples = new Float32Array(total);
  for (let i = 0; i < total; i += 1) {
    const t = i / SAMPLE_RATE;
    const progress = i / total;
    const value =
      cue === 'start' ? startSample(t, progress)
      : cue === 'tick' ? tickSample(t, progress)
      : buzzerSample(t, progress);
    samples[i] = Math.max(-1, Math.min(1, value));
  }
  // The buzzer gets more passes: stacked square waves are especially brittle.
  lowPass(samples, cue === 'buzzer' ? 3 : 1);
  return samples;
}

export class Sound {
  private context: AudioContext | null = null;
  private buffers = new Map<Cue, AudioBuffer>();
  /** Set when audio is unavailable, so failures stay cheap and quiet. */
  private failed = false;

  /**
   * Builds the buffers ahead of time.
   *
   * Browsers will not start an AudioContext without a gesture, so this is called
   * from the first tap rather than on mount — a context created on load starts
   * suspended and every cue before a tap would be silently dropped.
   */
  warmUp(): void {
    if (this.context || this.failed) return;
    try {
      const Ctor = window.AudioContext ?? (window as { webkitAudioContext?: typeof AudioContext }).webkitAudioContext;
      if (!Ctor) {
        this.failed = true;
        return;
      }
      const context = new Ctor({ sampleRate: SAMPLE_RATE });
      for (const cue of ['start', 'tick', 'buzzer'] as Cue[]) {
        const samples = makeSamples(cue);
        const buffer = context.createBuffer(1, samples.length, SAMPLE_RATE);
        buffer.copyToChannel(samples, 0);
        this.buffers.set(cue, buffer);
      }
      this.context = context;
    } catch {
      this.failed = true;
    }
  }

  play(cue: Cue): void {
    const context = this.context;
    const buffer = this.buffers.get(cue);
    if (!context || !buffer) return;
    // Autoplay policy: a context can start suspended and needs a nudge.
    if (context.state === 'suspended') void context.resume();
    const source = context.createBufferSource();
    source.buffer = buffer;
    source.connect(context.destination);
    source.start();
  }

  stopAll(): void {
    // Cues are short and one-shot; closing the context is the only silence.
    void this.context?.suspend();
  }
}
