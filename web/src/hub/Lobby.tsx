import type { ReactNode } from 'react';
import { HowToPlayLink } from './HowToPlay';

/**
 * The screen every game opens on: play on this device, or start a room and let
 * other people in.
 *
 * Trio and Sudoku each had their own copy of this — the same blurb, the same two
 * choices, the same join field, the same link to the rules — and Word Vibe had
 * none at all, which is exactly the kind of drift two copies produce. The shell
 * is here once; what goes *between* the blurb and the join field is the game's
 * own: Sudoku's difficulty picker, Word Vibe's two cards, Trio's two cards.
 *
 * `prefix` is the game's own name for its classes (`trio__lobby`), so the CSS
 * each game already has keeps working and this changes nothing on screen. The
 * two shared pieces — the card and the join form — are in `index.css`.
 */
export function Lobby({
  prefix,
  blurb,
  joinCode,
  joinError,
  onJoinCode,
  onJoin,
  onRules,
  children,
}: {
  /** The game's class prefix: `trio`, `sudoku`, `words`. */
  prefix: string;
  blurb: string;
  joinCode: string;
  joinError: string;
  onJoinCode: (code: string) => void;
  onJoin: (code: string) => void;
  onRules: () => void;
  /** The game's own choices: solo, and how it is set up. */
  children: ReactNode;
}) {
  return (
    <div className="game-lobby" data-game={prefix}>
      <p className="game-lobby__blurb">{blurb}</p>

      {children}

      <form
        className="game-lobby__join"
        onSubmit={(event) => {
          event.preventDefault();
          onJoin(joinCode);
        }}
      >
        <label htmlFor={`${prefix}-join`}>Join with a code</label>
        <div className="game-lobby__join-row">
          <input
            id={`${prefix}-join`}
            value={joinCode}
            onChange={(event) => onJoinCode(event.target.value)}
            placeholder="cars feed"
            autoComplete="off"
            autoCapitalize="none"
            spellCheck={false}
          />
          <button type="submit" disabled={!joinCode.trim()}>
            Join
          </button>
        </div>
        {joinError && <p className="game-lobby__join-error">{joinError}</p>}
      </form>

      <HowToPlayLink onClick={onRules} />
    </div>
  );
}

/**
 * One of the lobby's choices: a title and a line about it.
 *
 * The same shape in every game, because they are the same kind of thing — a
 * thing you can do, and why you would.
 */
export function LobbyCard({
  title,
  blurb,
  onClick,
  alt = false,
}: {
  title: string;
  blurb: string;
  onClick: () => void;
  /** The quieter of two sibling choices. */
  alt?: boolean;
}) {
  return (
    <button type="button" className="lobby-card" data-alt={alt} onClick={onClick}>
      <strong>{title}</strong>
      <span>{blurb}</span>
    </button>
  );
}
