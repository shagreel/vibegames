import { Fragment, type ReactNode } from 'react';
import { displayGameCode } from '../lib/gameCode';

/**
 * A shared game's code, shown as a code.
 *
 * It read `Code TRAM PUFF` in one line, which is three four-letter words in a
 * row — the owner's note. So the code is a caption over a box, and the two
 * halves sit apart inside it with a dot between them: one code, in two words.
 *
 * The spoken label keeps the plain form (`Game code TRAM PUFF`, no dot), because
 * a code is read out and typed from memory, and every helper that parses one out
 * of a label splits on spaces.
 *
 * The game's own class goes on the words, so the harnesses that read a code off
 * the screen keep finding the same element.
 */
export function GameCodeBadge({
  code,
  size = 'prominent',
  hint,
  className,
  identifier,
}: {
  /** The code as it is stored: `tram-puff`. */
  code: string;
  size?: 'prominent' | 'inline';
  hint?: ReactNode;
  /** The game's own class for the value, e.g. `blurt__code-value`. */
  className?: string;
  identifier?: string;
}) {
  const display = displayGameCode(code);
  const words = display.split(' ').filter(Boolean);

  return (
    <div className="game-code" data-size={size}>
      <span className="game-code__caption">Game code</span>
      <strong
        className={`game-code__words${className ? ` ${className}` : ''}`}
        aria-label={`Game code ${words.join(' ')}`}
        data-identifier={identifier}
      >
        <span aria-hidden="true">
          {words.map((word, index) => (
            <Fragment key={`${word}-${index}`}>
              {index > 0 && <span className="game-code__dot">·</span>}
              <span className="game-code__word">{word}</span>
            </Fragment>
          ))}
        </span>
      </strong>
      {hint && <span className="game-code__hint">{hint}</span>}
    </div>
  );
}
