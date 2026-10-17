import { createPortal } from 'react-dom';

/**
 * A message that appears over the game rather than in it.
 *
 * Every game has one: "Not in word list", "Notes hold four numbers", "That code
 * does not look right". Each of them used to sit in the flow, above the board —
 * so the board moved, and with it the keyboard, and a player typing had to
 * re-find the keys mid-word. This is the fix, once: a toast under the header
 * that costs the layout nothing.
 *
 * It is rendered into `document.body` on purpose. `position: fixed` resolves
 * against the nearest ancestor with a transform, and a game that grows one
 * around its header would drag the toast into a box — the support panel learned
 * that the expensive way. A portal cannot be caught out that way, and the
 * keyframes below animate opacity only for the same reason.
 */
export function GameMessage({
  text,
  tone = 'info',
}: {
  /** The message, or nothing. Callers keep their own state and timers. */
  text: string | null;
  /** Green for something achieved, amber for something refused. */
  tone?: 'info' | 'good' | 'warn';
}) {
  if (!text) return null;

  return createPortal(
    <div className="game-message" data-tone={tone} role="status" aria-live="polite">
      <span className="game-message__text">{text}</span>
    </div>,
    document.body,
  );
}
