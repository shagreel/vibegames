import { useEffect, useState, type ReactNode } from 'react';
import { playerName, setPlayerName } from '../identity';
import {
  subscribeTheme,
  setThemePreference,
  themePreference,
  type ThemePreference,
} from '../theme';

/**
 * The settings sheet every game opens, and the parts of it that are the same
 * everywhere.
 *
 * Two things belong to the whole suite rather than to one game: what you are
 * called, and whether the display is light or dark. Both were reachable only
 * from the menu, or not at all — a player who wanted either from inside a game
 * had to leave it. They are at the top of every game's settings now, and each
 * game puts its own controls underneath (`children`).
 *
 * The name is written as it is typed rather than on the way out, so it is
 * already in force if the sheet is dismissed by tapping the scrim. An empty
 * field does not erase the name: a player clearing the box to retype has not
 * asked to become nobody.
 */

const THEME_CHOICES: { id: ThemePreference; label: string; note: string }[] = [
  { id: 'system', label: 'System', note: 'Follow the device' },
  { id: 'light', label: 'Light', note: 'Always light' },
  { id: 'dark', label: 'Dark', note: 'Always dark' },
];

/**
 * The way into the sheet, in the corner of every game's header.
 *
 * One glyph for one idea: Vibe Five had the sliders, Similar Vibe spent a while
 * using them for "game code" as well, and Number Vibe had a settings key on its
 * keypad instead. Every game has the same button in the same corner now.
 */
export function SettingsButton({
  prefix,
  onClick,
}: {
  prefix: string;
  onClick: () => void;
}) {
  return (
    <button
      type="button"
      className={`${prefix}__settings-button game-settings-button`}
      onClick={onClick}
      aria-label="Game settings"
    >
      <svg viewBox="0 0 24 24" aria-hidden="true">
        <path d="M3 6h18M3 12h18M3 18h18" />
        <circle cx="8" cy="6" r="2.4" />
        <circle cx="16" cy="12" r="2.4" />
        <circle cx="10" cy="18" r="2.4" />
      </svg>
    </button>
  );
}

export function GameSettings({
  prefix,
  onClose,
  children,
}: {
  /** The game's class prefix, for the accent on the sheet's controls. */
  prefix: string;
  onClose: () => void;
  /** The game's own settings, in its own order. */
  children?: ReactNode;
}) {
  const [name, setName] = useState(() => playerName());
  const [theme, setTheme] = useState<ThemePreference>(() => themePreference());

  // The appearance can also change under us — a device that turns dark at
  // sunset while the sheet is open — so the chosen segment follows the value
  // rather than holding its own copy.
  useEffect(() => subscribeTheme(() => setTheme(themePreference())), []);

  return (
    <div
      className="game-sheet-overlay"
      data-game={prefix}
      role="dialog"
      aria-label="Game settings"
    >
      <div className="game-sheet">
        <h2>Game settings</h2>

        <h3>Your name</h3>
        <input
          className="game-sheet__field"
          type="text"
          value={name}
          placeholder="Your name"
          aria-label="Your name"
          autoComplete="off"
          onChange={(event) => {
            setName(event.target.value);
            const trimmed = event.target.value.trim();
            if (trimmed) setPlayerName(trimmed);
          }}
        />
        <p>Shown to everyone in a game you play together.</p>

        <h3>Appearance</h3>
        <div className="game-sheet__choices" role="group" aria-label="Appearance">
          {THEME_CHOICES.map((choice) => (
            <button
              key={choice.id}
              type="button"
              className="game-sheet__choice"
              data-on={theme === choice.id}
              aria-pressed={theme === choice.id}
              title={choice.note}
              onClick={() => {
                setThemePreference(choice.id);
                setTheme(choice.id);
              }}
            >
              {choice.label}
            </button>
          ))}
        </div>

        {children}

        <button type="button" className="game-sheet__done" onClick={onClose}>
          Done
        </button>
      </div>
    </div>
  );
}

/** A heading over one of the game's own groups of settings. */
export function SettingsSection({
  title,
  note,
  children,
}: {
  title: string;
  note?: string;
  /** A section can be a heading and an explanation with no control, as Similar
      Vibe's turn length is: the length is the game's, not a choice. */
  children?: ReactNode;
}) {
  return (
    <>
      <h3>{title}</h3>
      {note && <p>{note}</p>}
      {children}
    </>
  );
}

/**
 * One on/off setting, as a switch.
 *
 * Two mutually exclusive choices were two rows of the sheet — Number Vibe's
 * four or nine marks took as much room as a list of packs — and a switch says
 * the same thing in one.
 */
export function SettingsToggle({
  label,
  note,
  on,
  onChange,
}: {
  label: string;
  note?: string;
  on: boolean;
  onChange: (on: boolean) => void;
}) {
  return (
    <div className="game-sheet__row">
      <span className="game-sheet__row-text">
        <strong>{label}</strong>
        {note && <span>{note}</span>}
      </span>
      <button
        type="button"
        className="game-sheet__switch"
        role="switch"
        aria-checked={on}
        aria-label={label}
        data-on={on}
        onClick={() => onChange(!on)}
      >
        <span className="game-sheet__knob" aria-hidden="true" />
      </button>
    </div>
  );
}
