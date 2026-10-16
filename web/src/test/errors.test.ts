import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';

/**
 * Crash reporting.
 *
 * This is the one feature with no user: nobody sees it work, and nobody
 * complains when it doesn't. Worse, a mistake here is loud in the other
 * direction — a reporter that fires on every frame fills the issue tracker with
 * thousands of copies of one bug and buries the real reports. So the tests care
 * most about the two things that keep it quiet: sending each distinct failure
 * once, and stopping after a handful.
 */

const { sent, sendFeedback } = vi.hoisted(() => {
  const sent: { text: string; source: string; kind?: string }[] = [];
  return {
    sent,
    sendFeedback: vi.fn(async (feedback: unknown) => {
      sent.push(feedback as { text: string; source: string; kind?: string });
    }),
  };
});

// Mocked so importing the reporter does not pull in Firebase, and so the tests
// can watch what would have been posted.
vi.mock('../games/feedback', () => ({
  sendFeedback,
  FeedbackError: class FeedbackError extends Error {},
}));

/**
 * A fresh copy of the module.
 *
 * The reporter remembers what it has already sent — that is the whole point —
 * so leaving that memory in place between tests would hide exactly the bug it
 * exists to prevent.
 */
async function fresh() {
  vi.resetModules();
  return import('../errors');
}

/** Lets the `void sendFeedback(...)` inside `reportCrash` run. */
function flush() {
  return new Promise((resolve) => setTimeout(resolve, 0));
}

/** Just the fields the reporter reads off an event. */
interface CapturedEvent {
  error?: unknown;
  message?: string;
  reason?: unknown;
  target?: { tagName: string; src?: string } | null;
}

type Handler = (event: CapturedEvent) => void;

/**
 * Installs the handlers and hands them back.
 *
 * Dispatching through the mocked window would leave handlers behind for the
 * next test to trip over, so the listeners are captured instead.
 */
async function install() {
  const handlers: Record<string, Handler> = {};
  vi.spyOn(window, 'addEventListener').mockImplementation(
    (type: string, listener: EventListenerOrEventListenerObject) => {
      handlers[type] = listener as unknown as Handler;
    },
  );
  const { installCrashReporting } = await fresh();
  installCrashReporting();
  return handlers;
}

beforeEach(() => {
  vi.restoreAllMocks();
  sendFeedback.mockReset();
  sendFeedback.mockImplementation(async (feedback: unknown) => {
    sent.push(feedback as { text: string; source: string; kind?: string });
  });
  sent.length = 0;
  window.history.replaceState({}, '', '/');
});

afterEach(() => {
  vi.restoreAllMocks();
});

describe('formatReport', () => {
  it('leads with the message and records where it happened', async () => {
    const { formatReport } = await fresh();
    window.history.replaceState({}, '', '/trio?game=abc12345');

    const report = formatReport({ message: 'TypeError: boom', kind: 'error' });
    const lines = report.split('\n');

    expect(lines[0]).toBe('TypeError: boom');
    expect(report).toContain('Page: /trio?game=abc12345');
    expect(report).toContain('Browser: Mozilla/5.0 (Test)');
  });

  it('keeps enough of a stack to be useful and no more', async () => {
    const { formatReport } = await fresh();
    const stack = ['Error: boom', ...Array.from({ length: 40 }, (_, i) => `  at frame${i}`)].join('\n');

    const report = formatReport({ message: 'Error: boom', stack, kind: 'error' });

    expect(report).toContain('at frame0');
    expect(report).toContain('at frame6');
    expect(report).not.toContain('at frame7');
  });

  it('says so when a failure arrived without a message', async () => {
    const { formatReport } = await fresh();
    const report = formatReport({ message: '   ', kind: 'error' });
    expect(report).toContain('An error with no message');
  });

  it('names the thing that failed when it was not the page', async () => {
    const { formatReport } = await fresh();
    const report = formatReport({
      message: 'Failed to load',
      kind: 'error',
      origin: '<img> https://play.vibegames.party/cards/12.png',
    });
    expect(report).toContain('Source: <img> https://play.vibegames.party/cards/12.png');
  });

  it('stays inside the length the inbox will accept', async () => {
    const { formatReport } = await fresh();
    const report = formatReport({ message: 'x'.repeat(5000), kind: 'error' });
    expect(report.length).toBeLessThanOrEqual(2000);
  });
});

describe('reportCrash', () => {
  it('sends one report however many times the same failure repeats', async () => {
    const { reportCrash } = await fresh();
    for (let i = 0; i < 20; i += 1) {
      reportCrash({ message: 'TypeError: boom', kind: 'error' });
    }
    await flush();

    expect(sendFeedback).toHaveBeenCalledTimes(1);
    expect(sent[0]).toMatchObject({ source: 'web', kind: 'crash' });
  });

  it('sends different failures separately', async () => {
    const { reportCrash } = await fresh();
    reportCrash({ message: 'Error: one', kind: 'error' });
    reportCrash({ message: 'Error: two', kind: 'error' });
    reportCrash({ message: 'Error: three', kind: 'error' });
    await flush();

    expect(sendFeedback).toHaveBeenCalledTimes(3);
  });

  it('stops after five distinct failures in a session', async () => {
    const { reportCrash } = await fresh();
    for (let i = 0; i < 12; i += 1) {
      reportCrash({ message: `Error: number ${i}`, kind: 'error' });
    }
    await flush();

    expect(sendFeedback).toHaveBeenCalledTimes(5);
    expect(sent[4].text).toContain('Error: number 4');
  });

  it('is silent when the report itself cannot be sent', async () => {
    sendFeedback.mockRejectedValueOnce(new Error('offline'));
    const { reportCrash } = await fresh();
    reportCrash({ message: 'Error: boom', kind: 'error' });
    // An unhandled rejection here would fail the run.
    await flush();
    expect(sendFeedback).toHaveBeenCalledTimes(1);
  });
});

describe('installCrashReporting', () => {
  it('catches a throw that escaped', async () => {
    const handlers = await install();
    handlers.error({ error: new TypeError('cards is not iterable'), message: 'Uncaught TypeError' });
    await flush();

    expect(sendFeedback).toHaveBeenCalledTimes(1);
    expect(sent[0].text).toContain('TypeError: cards is not iterable');
  });

  it('catches a promise nobody handled', async () => {
    const handlers = await install();
    handlers.unhandledrejection({ reason: new Error('Could not reach the game service') });
    await flush();

    expect(sendFeedback).toHaveBeenCalledTimes(1);
    expect(sent[0].text).toContain('Error: Could not reach the game service');
  });

  it('ignores a throw from a script somebody injected into the page', async () => {
    const handlers = await install();

    const injected = new Error('Cannot read properties of undefined');
    injected.stack =
      'TypeError: Cannot read properties of undefined\n    at name (<anonymous>:3:43)';
    handlers.error({ error: injected, message: injected.message });
    await flush();

    // A diagnostic script of mine reached the feedback inbox this way: an
    // injected script's stack says `<anonymous>` and nothing else.
    expect(sendFeedback).not.toHaveBeenCalled();
  });

  it('still reports something when the event carries no error object', async () => {
    // This is how a browser reports a failure inside a cross-origin script: a
    // message and nothing else. Thin, but the page and browser still help.
    const handlers = await install();
    handlers.error({ message: 'Script error.' });
    await flush();

    expect(sent[0].text).toContain('Script error.');
    expect(sent[0].text).toContain('Page: /');
  });

  it('names the element when a resource failed to load', async () => {
    const handlers = await install();
    handlers.error({
      target: { tagName: 'IMG', src: 'https://play.vibegames.party/cards/12.png' },
      message: '',
    });
    await flush();

    expect(sent[0].text).toContain('Source: <img> https://play.vibegames.party/cards/12.png');
  });
});
