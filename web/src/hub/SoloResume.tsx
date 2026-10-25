import type { SavedSolo } from './soloProgress';

/**
 * The question a solo game asks when there is already one saved in this browser.
 *
 * One dialog, the same words in every game: what is waiting, and the two things
 * a player might want — carry on, or start again. Cancel is there because
 * tapping "Play on this device" by mistake should not discard anything.
 */
export function SoloResume({
  saved,
  onContinue,
  onNewGame,
  onCancel,
}: {
  saved: SavedSolo;
  onContinue: () => void;
  onNewGame: () => void;
  onCancel: () => void;
}) {
  return (
    <div
      className="game-sheet-overlay"
      role="dialog"
      aria-label="A game is in progress"
      onClick={(event) => {
        if (event.target === event.currentTarget) onCancel();
      }}
    >
      <div className="game-sheet solo-resume">
        <h2>A game is in progress</h2>
        <p className="solo-resume__summary">{saved.summary}</p>
        <button type="button" className="solo-resume__primary" onClick={onContinue}>
          Continue
        </button>
        <button type="button" className="solo-resume__secondary" onClick={onNewGame}>
          New game
        </button>
        <button type="button" className="game-sheet__done solo-resume__cancel" onClick={onCancel}>
          Cancel
        </button>
      </div>
    </div>
  );
}
