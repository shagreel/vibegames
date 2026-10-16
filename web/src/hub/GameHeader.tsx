import type { ReactNode } from 'react';
import BackToGames from './BackToGames';

/**
 * The strip across the top of every game: where you came from, what you are
 * playing, and the controls for it.
 *
 * The five games each had their own copy of this markup and their own copy of
 * its CSS — five paddings, three border colours, two title sizes, a title that
 * was not uppercase and a heart that sat in the middle of the screen because
 * nothing pushed the corner right. The styles were unified first; this is the
 * markup following them, so the next game gets all of it for free.
 *
 * What each game keeps is its **controls**: `children` go in the corner, in the
 * order the game wants them, after the heart. The heart is first because it is
 * the one thing that is the same everywhere, and the layout puts the corner hard
 * right, so the heart never moves between screens.
 *
 * Nothing here uses a transform, deliberately: a transform anywhere around the
 * heart becomes the containing block for `position: fixed`, which is how the
 * support panel once ended up laid out inside a 40x40 box.
 */
export function GameHeader({
  prefix,
  title,
  subtitle,
  onBack,
  backLabel,
  children,
}: {
  /** The game's class prefix: `five`, `words`, `sudoku`, `trio`, `blurt`. */
  prefix: string;
  title: string;
  subtitle?: string;
  /**
   * When the way out is not "back to the games" — leaving a room you are in —
   * give the handler and the label for it.
   */
  onBack?: () => void;
  backLabel?: string;
  /** The game's own controls: settings, the code, sharing, leaving. */
  children?: ReactNode;
}) {
  return (
    <header className={`${prefix}__header game-header`}>
      {onBack ? (
        <button
          type="button"
          className={`${prefix}__back`}
          onClick={onBack}
          aria-label={backLabel ?? 'Leave game'}
        >
          ‹
        </button>
      ) : (
        <BackToGames />
      )}

      <div className={`${prefix}__titles game-header__title`}>
        <h1>{title}</h1>
        {subtitle && <p>{subtitle}</p>}
      </div>

      <div className={`${prefix}__corner game-header__corner`}>{children}</div>
    </header>
  );
}
