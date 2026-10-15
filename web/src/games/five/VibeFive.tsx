import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import BackToGames from '../../hub/BackToGames';
import { SupportButton } from '../../hub/Support';
import HowToPlay, { HowToPlayLink, type HowToPlayContent } from '../../hub/HowToPlay';
import { ALL_PACK_IDS, PACKS, countIn, type PackId } from './packs';
import {
  advance,
  initialState,
  primaryButtonTitle,
  primaryHint,
  primaryAction,
  progressAt,
  promptKey,
  loadSeen,
  saveSeen,
  remainingAt,
  resetToReady,
  shuffled,
  statusBadge,
  type Cue,
  type FiveState,
  type Phase,
} from './model';
import { Sound } from './sound';
import { GAMES, trackGameFinish, trackGameStart } from '../../analytics';
import './VibeFive.css';

/**
 * Vibe Five on the web — the pass-the-device game.
 *
 * There is no shared game here and there is not meant to be: the whole thing is
 * one device handed round a table, which is why it is the only game in the suite
 * with no database behind it.
 *
 * Flow: **START** reveals a category and the clock waits → **START** again sets
 * five seconds running → the buzzer, or **Done!** to stop early → **NEXT**.
 */

const SOUND_KEY = 'vibefive.sound';
const HAPTICS_KEY = 'vibefive.haptics';
const PACKS_KEY = 'vibefive.packs';

function loadPacks(): PackId[] {
  try {
    const stored = JSON.parse(localStorage.getItem(PACKS_KEY) ?? 'null');
    if (Array.isArray(stored)) {
      const valid = stored.filter((id): id is PackId => ALL_PACK_IDS.includes(id));
      if (valid.length > 0) return valid;
    }
  } catch {
    // A corrupt value is not worth crashing over; fall back to everything.
  }
  return [...ALL_PACK_IDS];
}

function loadFlag(key: string, fallback: boolean): boolean {
  const stored = localStorage.getItem(key);
  return stored == null ? fallback : stored === 'true';
}

/**
 * One round is one `game_start` and one `game_finish`, whichever way the state
 * machine got there.
 *
 * Reported from the single place state changes rather than from the button, so
 * that a round ended by the ticker is counted the same as one ended by a tap —
 * and so nothing is counted twice. Five has no winner, only whether the table
 * beat the clock, which is what separates the two endings.
 */
function reportRound(previous: FiveState, next: FiveState): void {
  if (previous.phase !== 'running' && next.phase === 'running') {
    trackGameStart(GAMES.five, { mode: 'solo', round: next.roundNumber });
    return;
  }
  if (next.phase === previous.phase) return;

  const mode = 'solo' as const;
  const round = next.roundNumber;
  if (next.phase === 'stopped') {
    trackGameFinish(GAMES.five, { mode, outcome: 'won', round });
  } else if (next.phase === 'buzzed') {
    trackGameFinish(GAMES.five, { mode, outcome: 'lost', round });
  }
}

/** The instructions, in this game's own words and with its own live counts. */
const categoryCount = countIn(ALL_PACK_IDS);

const FIVE_INSTRUCTIONS: HowToPlayContent = {
  name: 'Vibe Five',
  intro:
    'A category, five seconds, and one device passed round the table. Name three things that fit before the buzzer.',
  sections: [
    {
      title: 'The category waits for you',
      body: 'Press **START** and the category fills the screen with a GET READY badge. No timer is running and none is shown, so read it out, explain it, and argue about it for as long as you like.',
    },
    {
      title: 'Then the clock',
      body: 'Press **START** again when the table is ready. The dial appears and drains from five to zero, with a tick for each of the last three seconds. The dial appearing is the signal that time is running.',
    },
    {
      title: 'How a round ends',
      body: 'Either the clock runs out — the buzzer sounds and the screen flashes red — or the player presses **Done!** to end it early. Done! is deliberately silent, because the buzzer means the clock beat you. Either way the dial freezes on the time that was left.',
    },
  ],
  bullets: [
    { lead: 'START', text: 'Deals a category. Nothing is running yet.' },
    { lead: 'Done!', text: 'Ends the round early. Silent, so the buzzer keeps its meaning.' },
    { lead: 'NEXT', text: 'Deals a fresh category and waits for you to start the clock again.' },
    {
      lead: 'Packs',
      text: `${categoryCount} categories across ${ALL_PACK_IDS.length} packs, switched on and off in Game Setup. Only the packs you leave on go into the deck, and no category comes round twice until the pool runs out.`,
    },
  ],
};

function VibeFive() {
  const [enabled, setEnabled] = useState<PackId[]>(loadPacks);
  const [soundOn, setSoundOn] = useState(() => loadFlag(SOUND_KEY, true));
  const [hapticsOn, setHapticsOn] = useState(() => loadFlag(HAPTICS_KEY, true));

  // Prompts already dealt to this player, kept across games and launches so a
  // second game does not deal the first one's cards again. Held in state purely
  // for the lazy initialiser — it is never rendered, so it is only ever read and
  // written in place.
  const [seen] = useState(() => loadSeen());
  const [state, setState] = useState<FiveState>(() => initialState(loadPacks(), seen));
  const [now, setNow] = useState(() => Date.now());
  const [settingsOpen, setSettingsOpen] = useState(false);
  const [rulesOpen, setRulesOpen] = useState(false);

  // The interval reads the live state from here, so it is never working from a
  // stale closure — and side effects stay out of the state updater, which React
  // would otherwise run twice in development.
  const stateRef = useRef(state);
  const sound = useRef(new Sound());

  const apply = useCallback((next: FiveState) => {
    const previous = stateRef.current;
    stateRef.current = next;
    setState(next);
    reportRound(previous, next);
  }, []);

  const playCue = useCallback(
    (cue: Cue) => {
      if (soundOn) sound.current.play(cue);
      if (!hapticsOn || !navigator.vibrate) return;
      if (cue === 'tick') navigator.vibrate(12);
      if (cue === 'buzzer') navigator.vibrate([0, 90, 60, 140]);
      if (cue === 'start') navigator.vibrate(20);
    },
    [soundOn, hapticsOn],
  );

  // Remember every card as it is dealt, so the next game can avoid it.
  useEffect(() => {
    const drawn = state.category;
    if (!drawn) return;
    const key = promptKey(drawn);
    if (seen.has(key)) return;
    seen.add(key);
    saveSeen(seen);
  }, [state.category, seen]);

  // MARK: - The clock

  useEffect(() => {
    if (state.phase !== 'running') return;

    const timer = window.setInterval(() => {
      const at = Date.now();
      const { state: next, cues } = advance(stateRef.current, at);
      if (next !== stateRef.current) apply(next);
      setNow(at);
      for (const cue of cues) playCue(cue);
    }, 50);

    return () => window.clearInterval(timer);
  }, [state.phase, apply, playCue]);

  // MARK: - Settings

  const toggleSound = () => {
    const next = !soundOn;
    setSoundOn(next);
    localStorage.setItem(SOUND_KEY, String(next));
    if (next) sound.current.warmUp();
  };

  const toggleHaptics = () => {
    const next = !hapticsOn;
    setHapticsOn(next);
    localStorage.setItem(HAPTICS_KEY, String(next));
  };

  const setPacks = (next: PackId[]) => {
    setEnabled(next);
    localStorage.setItem(PACKS_KEY, JSON.stringify(next));
    // The deck is rebuilt from the new pool, so a disabled pack stops appearing
    // straight away rather than after the current deck runs out.
    apply({ ...resetToReady(stateRef.current), deck: shuffled(next, null, seen), deckIndex: 0 });
  };

  const togglePack = (id: PackId) => {
    if (enabled.includes(id)) {
      // Never let the player strand themselves with zero prompts.
      if (enabled.length <= 1) return;
      setPacks(enabled.filter((each) => each !== id));
    } else {
      setPacks([...enabled, id]);
    }
  };

  const toggleAll = () => {
    setPacks(enabled.length === ALL_PACK_IDS.length ? [ALL_PACK_IDS[0]] : [...ALL_PACK_IDS]);
  };

  // MARK: - Play

  const onPrimary = () => {
    sound.current.warmUp(); // Browsers need a gesture before audio will start.
    const { state: next, cues } = primaryAction(stateRef.current, enabled, Date.now(), seen);
    apply(next);
    for (const cue of cues) playCue(cue);
  };

  const remaining = remainingAt(state, now);
  const progress = progressAt(state, now);

  if (rulesOpen) return <HowToPlay content={FIVE_INSTRUCTIONS} onClose={() => setRulesOpen(false)} />;

  return (
    <div className="five" data-phase={state.phase}>
      <div className="five__progress" aria-hidden="true">
        <span style={{ width: `${Math.max(0, Math.min(1, progress)) * 100}%` }} />
      </div>

      <header className="five__header">
        <BackToGames />
        <div className="five__titles">
          <h1>Vibe Five</h1>
          <p>{state.roundNumber === 0 ? 'Ready to play' : `Round ${state.roundNumber}`}</p>
        </div>
        <div className="five__corner">
          <SupportButton game="five" />
          <button
            type="button"
            className="five__settings-button"
            onClick={() => setSettingsOpen(true)}
            aria-label="Game settings"
          >
            <svg viewBox="0 0 24 24" aria-hidden="true">
              <path d="M3 6h18M3 12h18M3 18h18" />
              <circle cx="8" cy="6" r="2.4" />
              <circle cx="16" cy="12" r="2.4" />
              <circle cx="10" cy="18" r="2.4" />
            </svg>
          </button>
        </div>
      </header>

      <CategoryCard state={state} />

      {/* No dial while the category is being read: nothing on screen should
          read as a countdown, and the card gets the room instead. The dial
          appearing is itself the signal that the clock has started. */}
      {state.phase !== 'revealed' && (
        <CountdownRing phase={state.phase} remaining={remaining} progress={progress} />
      )}

      <button
        type="button"
        className="five__primary"
        onClick={onPrimary}
        aria-label={primaryButtonTitle(state)}
        title={primaryHint(state)}
      >
        {primaryButtonTitle(state)}
      </button>

      <HowToPlayLink onClick={() => setRulesOpen(true)} />

      {/* The red wash when the clock beats you. Rendered only while buzzed, so
          the one-shot animation replays each time the buzzer fires, and no
          state or timer is needed to take it away again. */}
      {state.phase === 'buzzed' && <div className="five__flash" aria-hidden="true" />}

      {settingsOpen && (
        <Settings
          enabled={enabled}
          soundOn={soundOn}
          hapticsOn={hapticsOn}
          onToggleSound={toggleSound}
          onToggleHaptics={toggleHaptics}
          onTogglePack={togglePack}
          onToggleAll={toggleAll}
          onClose={() => setSettingsOpen(false)}
        />
      )}
    </div>
  );
}

// MARK: - The card

function CategoryCard({ state }: { state: FiveState }) {
  const badge = statusBadge(state);

  return (
    <div className="five__card" data-phase={state.phase}>
      {state.phase === 'ready' ? (
        <div className="five__ready">
          <span className="five__ready-mark" aria-hidden="true">
            5
          </span>
          <strong>Tap START to reveal a category</strong>
          <span>Read it out, then start the clock when you are ready</span>
        </div>
      ) : (
        <p className="five__category" aria-label={`Category: ${state.category?.text ?? ''}`}>
          {state.category?.text}
        </p>
      )}

      {badge && (
        <span className="five__badge" data-tone={badge.tone}>
          {badge.title}
        </span>
      )}
    </div>
  );
}

// MARK: - The dial

function CountdownRing({
  phase,
  remaining,
  progress,
}: {
  phase: Phase;
  remaining: number;
  progress: number;
}) {
  const size = 176;
  const stroke = size * 0.085;
  const radius = (size - stroke) / 2;
  const circumference = 2 * Math.PI * radius;
  const display = Math.max(0, Math.ceil(remaining - 0.0001));

  const tone =
    phase === 'buzzed' ? 'danger' : phase === 'stopped' ? 'go' : urgency(progress);
  const urgent = phase === 'running' && progress > 0 && progress <= 0.4;

  return (
    <div
      className="five__ring"
      data-tone={tone}
      data-urgent={urgent}
      role="img"
      aria-label={
        phase === 'buzzed'
          ? 'Time is up'
          : phase === 'stopped'
            ? `Stopped with ${display} seconds left`
            : `${display} seconds remaining`
      }
    >
      <svg width={size} height={size} viewBox={`0 0 ${size} ${size}`}>
        <circle
          cx={size / 2}
          cy={size / 2}
          r={radius}
          fill="none"
          stroke="rgba(255,255,255,0.12)"
          strokeWidth={stroke}
        />
        {/* Hidden at rest so the round line cap does not leave a stray dot. */}
        {progress > 0.004 && (
          <circle
            className="five__ring-arc"
            cx={size / 2}
            cy={size / 2}
            r={radius}
            fill="none"
            stroke="currentColor"
            strokeWidth={stroke}
            strokeLinecap="round"
            strokeDasharray={circumference}
            strokeDashoffset={circumference * (1 - Math.min(1, progress))}
            transform={`rotate(-90 ${size / 2} ${size / 2})`}
          />
        )}
      </svg>
      <div className="five__ring-text">
        <strong>{display}</strong>
        <span>{phase === 'stopped' ? 'LEFT' : phase === 'buzzed' ? 'TIME' : 'SECONDS'}</span>
      </div>
    </div>
  );
}

function urgency(progress: number): string {
  if (progress >= 0.6) return 'calm';
  if (progress >= 0.3) return 'warn';
  return 'danger';
}

// MARK: - Settings

function Settings(props: {
  enabled: PackId[];
  soundOn: boolean;
  hapticsOn: boolean;
  onToggleSound: () => void;
  onToggleHaptics: () => void;
  onTogglePack: (id: PackId) => void;
  onToggleAll: () => void;
  onClose: () => void;
}) {
  const all = props.enabled.length === ALL_PACK_IDS.length;
  const active = useMemo(() => countIn(props.enabled), [props.enabled]);

  return (
    <div className="five__overlay" role="dialog" aria-label="Game settings">
      <div className="five__settings">
        <header>
          <h2>Game setup</h2>
          <button type="button" onClick={props.onClose} aria-label="Done">
            Done
          </button>
        </header>

        <div className="five__switches">
          <label>
            <input type="checkbox" checked={props.soundOn} onChange={props.onToggleSound} />
            <span>Sound</span>
          </label>
          <label>
            <input type="checkbox" checked={props.hapticsOn} onChange={props.onToggleHaptics} />
            <span>Vibration</span>
          </label>
        </div>

        <div className="five__packs-head">
          <span>{active.toLocaleString()} categories in play</span>
          <button type="button" onClick={props.onToggleAll}>
            {all ? 'Select one' : 'Select all'}
          </button>
        </div>

        <ul className="five__packs">
          {PACKS.map((pack) => {
            const on = props.enabled.includes(pack.id);
            return (
              <li key={pack.id}>
                <button
                  type="button"
                  className="five__pack"
                  data-on={on}
                  onClick={() => props.onTogglePack(pack.id)}
                  aria-pressed={on}
                  /* The last enabled pack cannot be switched off — a game with
                     no categories has nothing to deal. */
                  disabled={on && props.enabled.length <= 1}
                >
                  <span className="five__pack-emoji" aria-hidden="true">
                    {pack.emoji}
                  </span>
                  <span className="five__pack-text">
                    <strong>{pack.title}</strong>
                    <span>{pack.blurb}</span>
                  </span>
                  <span className="five__pack-count">{countIn([pack.id])}</span>
                </button>
              </li>
            );
          })}
        </ul>
      </div>
    </div>
  );
}

export default VibeFive;
