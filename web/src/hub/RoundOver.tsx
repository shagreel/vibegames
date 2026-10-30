import type { ReactNode } from 'react';

/**
 * The end of a round, in the same shape everywhere.
 *
 * Four games had four ways of saying it and one had no way at all: Number Vibe
 * had a trophy panel, Vibe Pairings a standings list with a button under it,
 * Similar Vibe a score line, and Word Vibe a message with no way to start
 * another round. What they have in common is the thing that matters — a title, a
 * line of detail, and one clear button — so that is here, and each game passes
 * what only it has (`children`) and its own words.
 *
 * The button is full width on purpose. The one thing a player wants at this
 * moment should not be a small target in a corner.
 */
export function RoundOver({
  title,
  detail,
  primaryLabel = 'Play again',
  onPrimary,
  secondaryLabel,
  onSecondary,
  children,
}: {
  title: string;
  detail?: string;
  primaryLabel?: string;
  onPrimary: () => void;
  /** A second way out, when a game has one: retry the same board, say. */
  secondaryLabel?: string;
  onSecondary?: () => void;
  /** The game's own extras: its standings, its score line, the next difficulty. */
  children?: ReactNode;
}) {
  return (
    <section className="round-over" aria-label={title}>
      <h2 className="round-over__title">{title}</h2>
      {detail && <p className="round-over__detail">{detail}</p>}
      {children}
      <button type="button" className="round-over__primary" onClick={onPrimary}>
        {primaryLabel}
      </button>
      {secondaryLabel && onSecondary && (
        <button type="button" className="round-over__secondary" onClick={onSecondary}>
          {secondaryLabel}
        </button>
      )}
    </section>
  );
}

/**
 * A row of choices inside {@link RoundOver} — Number Vibe's difficulty for the
 * next board, when there is one to choose.
 */
export function RoundOverChoices({
  label,
  options,
  value,
  onChange,
}: {
  label: string;
  options: { id: string; title: string }[];
  value: string;
  onChange: (id: string) => void;
}) {
  return (
    <div className="round-over__choices" role="group" aria-label={label}>
      {options.map((option) => (
        <button
          key={option.id}
          type="button"
          className="round-over__choice"
          data-on={value === option.id}
          aria-pressed={value === option.id}
          onClick={() => onChange(option.id)}
        >
          {option.title}
        </button>
      ))}
    </div>
  );
}
