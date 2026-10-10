import { describe, it, expect, beforeEach, vi } from 'vitest';
import { Sound } from '../games/five/sound';

/**
 * The game ships no audio, so every sound is arithmetic. That is exactly the
 * kind of code that fails silently — a NaN sample or an empty buffer just means
 * "no sound", with nothing in the console to say why — so the synthesis is
 * checked here against a stand-in AudioContext.
 */

const SAMPLE_RATE = 44100;

class FakeBuffer {
  static built: { length: number; samples: Float32Array }[] = [];
  length: number;
  samples: Float32Array | null = null;

  constructor(length: number) {
    this.length = length;
  }

  copyToChannel(samples: Float32Array) {
    this.samples = samples;
    FakeBuffer.built.push({ length: this.length, samples });
  }
}

const started: unknown[] = [];

class FakeContext {
  state = 'running';
  destination = {};
  options: { sampleRate?: number } | undefined;
  constructor(options?: { sampleRate?: number }) {
    this.options = options;
  }
  createBuffer(_channels: number, length: number) {
    return new FakeBuffer(length);
  }
  createBufferSource() {
    const source = { buffer: null as unknown, connect: vi.fn(), start: vi.fn() };
    started.push(source);
    return source;
  }
  resume() {
    return Promise.resolve();
  }
  suspend() {
    return Promise.resolve();
  }
}

function installAudio() {
  Object.defineProperty(globalThis, 'window', {
    value: { ...(globalThis as { window?: object }).window, AudioContext: FakeContext },
    configurable: true,
    writable: true,
  });
}

describe('the synthesised cues', () => {
  beforeEach(() => {
    FakeBuffer.built = [];
    started.length = 0;
    installAudio();
  });

  it('builds all three cues at the right lengths', () => {
    const sound = new Sound();
    sound.warmUp();

    expect(FakeBuffer.built.map((b) => b.length)).toEqual([
      Math.floor(SAMPLE_RATE * 0.3), // start
      Math.floor(SAMPLE_RATE * 0.08), // tick
      Math.floor(SAMPLE_RATE * 1.05), // buzzer
    ]);
  });

  it('produces real, in-range audio rather than silence or NaN', () => {
    const sound = new Sound();
    sound.warmUp();

    for (const [index, buffer] of FakeBuffer.built.entries()) {
      const samples = buffer.samples!;
      expect(samples, `buffer ${index} was never filled`).not.toBeNull();
      expect(samples.every(Number.isFinite), `buffer ${index} has a NaN`).toBe(true);

      const peak = Math.max(...samples.map(Math.abs));
      expect(peak).toBeGreaterThan(0.05); // audible
      expect(peak).toBeLessThanOrEqual(1); // never clips

      const energy = samples.reduce((sum, s) => sum + s * s, 0) / samples.length;
      expect(energy, `buffer ${index} is silent`).toBeGreaterThan(1e-4);
    }
  });

  it('smooths the square waves rather than leaving digital edges', () => {
    // The buzzer is stacked square waves; without the low-pass every sample
    // would swing the full range and it would hiss.
    const sound = new Sound();
    sound.warmUp();

    const buzzer = FakeBuffer.built[2].samples!;
    let biggestJump = 0;
    for (let i = 1; i < buzzer.length; i += 1) {
      biggestJump = Math.max(biggestJump, Math.abs(buzzer[i] - buzzer[i - 1]));
    }
    expect(biggestJump).toBeLessThan(0.5);
  });

  it('fades the buzzer out rather than cutting it off', () => {
    const sound = new Sound();
    sound.warmUp();

    const buzzer = FakeBuffer.built[2].samples!;
    const tail = buzzer.slice(buzzer.length - 200);
    const peakTail = Math.max(...tail.map(Math.abs));
    const peakMiddle = Math.max(...buzzer.slice(1000, 1200).map(Math.abs));
    expect(peakTail).toBeLessThan(peakMiddle * 0.2);
  });

  it('does nothing at all when the browser has no audio', () => {
    Object.defineProperty(globalThis, 'window', {
      value: { ...(globalThis as { window?: object }).window, AudioContext: undefined },
      configurable: true,
      writable: true,
    });
    const sound = new Sound();

    expect(() => {
      sound.warmUp();
      sound.play('buzzer');
      sound.play('tick');
    }).not.toThrow();
    expect(FakeBuffer.built).toHaveLength(0);
  });

  it('survives a cue it never managed to build', () => {
    const sound = new Sound();
    expect(() => sound.play('tick')).not.toThrow(); // no warmUp at all
  });

  it('plays a cue after warming up', () => {
    const sound = new Sound();
    sound.warmUp();
    sound.play('start');
    expect(started).toHaveLength(1);
  });
});
