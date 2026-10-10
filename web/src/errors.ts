import { sendFeedback } from './games/feedback';

/**
 * Uncaught errors in the browser, sent the same way feedback is.
 *
 * A crash is the one failure nobody can report: the page stops working, so
 * there is no form left to type in. This catches what escapes — a render that
 * throws, a promise nobody handled — and posts it to the same inbox, where the
 * scheduled Action turns it into an issue.
 *
 * Deliberately quiet and bounded. A loop that throws on every frame would
 * otherwise post thousands of reports, so each distinct error is sent once and
 * a session stops after a handful.
 */

const MAX_REPORTS_PER_SESSION = 5;
const MAX_LENGTH = 2000;

export interface CrashDetails {
  message: string;
  stack?: string;
  /** Where it happened, when it is not the page itself. */
  origin?: string;
  kind: 'error' | 'unhandledrejection';
}

/** The whole report as one note, since that is what the issue body wants. */
export function formatReport(details: CrashDetails): string {
  const lines = [details.message.trim() || 'An error with no message'];

  if (details.stack) {
    // The top of the stack is the part worth reading; the rest is noise from
    // minified bundles and rarely fits anyway.
    lines.push('', ...details.stack.split('\n').slice(0, 8).map((line) => line.trim()));
  }

  lines.push('', `Page: ${window.location.pathname}${window.location.search}`);
  if (details.origin) lines.push(`Source: ${details.origin}`);
  lines.push(`Browser: ${navigator.userAgent}`);

  return lines.join('\n').slice(0, MAX_LENGTH);
}

function describe(error: unknown): CrashDetails {
  if (error instanceof Error) {
    return { message: `${error.name}: ${error.message}`, stack: error.stack, kind: 'error' };
  }
  if (typeof error === 'string') {
    return { message: error, kind: 'error' };
  }
  try {
    return { message: JSON.stringify(error), kind: 'error' };
  } catch {
    return { message: String(error), kind: 'error' };
  }
}

let sent = 0;
const seen = new Set<string>();

export function reportCrash(details: CrashDetails): void {
  const report = formatReport(details);
  // Keyed on the first line, so the same exception at a hundred moments is one
  // report rather than a hundred.
  const key = report.split('\n')[0];
  if (seen.has(key) || sent >= MAX_REPORTS_PER_SESSION) return;
  seen.add(key);
  sent += 1;

  void sendFeedback({ text: report, source: 'web', kind: 'crash' }).catch(() => {
    // Nothing to do: this is already the failure path, and complaining about it
    // would be a crash reporter crashing.
  });
}

/** Installs the handlers. Called once, from the entry point. */
export function installCrashReporting(): void {
  window.addEventListener('error', (event) => {
    // A resource that failed to load reports here too, with no error object.
    const target = event.target as HTMLElement | null;
    const fromResource = target && target !== (window as unknown as HTMLElement);

    reportCrash({
      ...describe(event.error ?? event.message),
      kind: 'error',
      origin: fromResource ? `<${target.tagName.toLowerCase()}> ${(target as HTMLImageElement).src ?? ''}` : undefined,
    });
  });

  window.addEventListener('unhandledrejection', (event) => {
    reportCrash({ ...describe(event.reason), kind: 'unhandledrejection' });
  });
}
