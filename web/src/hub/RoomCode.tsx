import { useState } from 'react';
import { trackShare, type GameName } from '../analytics';
import { displayGameCode } from '../lib/gameCode';

/**
 * The room's code, in the header of every game you can be in a room in.
 *
 * It used to live only on the screens the *creator* saw: the waiting room's
 * badge, or a copy button beside the start button. Everybody else could join and
 * then had no way to read the code out — which is the note this answers ("I'm on
 * the web. I didn't start the game. I can't see the code to help others join. It's
 * not in the header."). The code is in the header now, on the same terms for
 * everyone, and it opens something big enough to read across a table.
 */

/**
 * The way in, in the corner of the header: a person with a plus, because the
 * sliders already mean settings everywhere else in the suite.
 */
export function RoomCodeButton({ onClick }: { onClick: () => void }) {
  return (
    <button
      type="button"
      className="game-header-code"
      onClick={onClick}
      aria-label="Game code"
    >
      <svg viewBox="0 0 24 24" aria-hidden="true">
        <circle cx="9" cy="8" r="3.2" />
        <path d="M3.5 19c0-3 2.5-5 5.5-5s5.5 2 5.5 5" />
        <path d="M17 8v6M14 11h6" />
      </svg>
    </button>
  );
}

/**
 * The code itself: large, and a button that puts the invite link on the
 * clipboard, because reading a code out and sending one are the two things
 * anybody does with it.
 */
export function RoomCodeSheet({
  code,
  game,
  onClose,
}: {
  code: string;
  /** For the share count: which game's invite this is. */
  game?: GameName;
  onClose: () => void;
}) {
  const [copied, setCopied] = useState(false);
  const inviteUrl = `${window.location.origin}${window.location.pathname}?game=${code}`;

  return (
    <div
      className="game-sheet-overlay"
      role="dialog"
      aria-label="Game code"
      onClick={(event) => {
        if (event.target === event.currentTarget) onClose();
      }}
    >
      <div className="game-sheet room-code">
        <h2>Game code</h2>
        <p className="room-code__value">{displayGameCode(code)}</p>
        <p className="room-code__hint">
          Read it out, or send the link. Anyone with it can join.
        </p>
        <button
          type="button"
          className="room-code__copy"
          onClick={() => {
            trackShare(game, 'game');
            navigator.clipboard.writeText(inviteUrl).then(
              () => setCopied(true),
              () => {
                // A browser that will not copy still gets the link on screen.
                setCopied(false);
              },
            );
          }}
        >
          {copied ? 'Link copied' : 'Copy the link'}
        </button>
        <p className="room-code__link">{inviteUrl}</p>
        <button type="button" className="game-sheet__done" onClick={onClose}>
          Done
        </button>
      </div>
    </div>
  );
}
