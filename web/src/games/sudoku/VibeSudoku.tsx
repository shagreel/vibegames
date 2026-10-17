import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import HowToPlay, { type HowToPlayContent } from '../../hub/HowToPlay';
import { Lobby as SharedLobby, LobbyCard } from '../../hub/Lobby';
import { SupportButton } from '../../hub/Support';
import { GameHeader } from '../../hub/GameHeader';
import {
  GameSettings,
  SettingsButton,
  SettingsSection,
  SettingsToggle,
} from '../../hub/GameSettings';
import { GameMessage } from '../../hub/GameMessage';
import { GameCodeBadge } from '../../hub/GameCodeBadge';
import { RoundOver, RoundOverChoices } from '../../hub/RoundOver';
import { GAMES, trackGameFinish, trackGameStart, trackShare } from '../../analytics';
import { MAX_NAME_LENGTH, isHosting, hostedGame, playerId, playerName, setPlayerName } from '../../identity';
import {
  CELL_COUNT,
  NOTE_LIMITS,
  NOTE_LIMIT_KEY,
  type NoteLimit,
  DIFFICULTIES,
  boxOf,
  columnOf,
  conflictsIn,
  isComplete,
  rowOf,
  type Difficulty,
  type SudokuPuzzle,
} from './puzzle';
import { puzzle as generate } from './generator';
import {
  EMPTY_SNAPSHOT,
  beginRestart,
  clearRestartTime,
  createGame,
  joinGame,
  makeGameCode,
  observeGame,
  recordWinner,
  startGame,
  type SudokuSnapshot,
} from './service';
import { displayGameCode, normaliseGameCode } from '../../lib/gameCode';
import './VibeSudoku.css';

/**
 * Number Vibe on the web, solo or raced.
 *
 * A shared game stores only a seed, so every device builds the identical board
 * from it and the answer is never in the database for a client to read. That is
 * also why the generator had to be ported exactly: a browser and a phone that
 * carved differently would be racing different puzzles.
 */

type Screen = 'lobby' | 'game';

/** The instructions, in this game's own words. */
const SUDOKU_INSTRUCTIONS: HowToPlayContent = {
  name: 'Number Vibe',
  intro:
    'Fill the 9x9 grid so every row, every column and every 3x3 box holds 1 to 9. Play solo, or race friends on an identical board.',
  sections: [
    {
      title: 'Difficulty means something',
      body: 'Easy, Medium and Hard are graded by the technique a puzzle actually needs, not by how many clues it has — so Hard is hard rather than merely sparse. If you host a race, guests play whatever difficulty you picked, so everybody gets the same board.',
    },
    {
      title: 'If you get stuck',
      body: '**Notes** lets you pencil candidates into a square. Anything that clashes with a number in the same row, column or box is highlighted, so a mistake shows up before it spreads.',
    },
  ],
  bullets: [
    { lead: 'Solo', text: 'An endless supply of boards, at the difficulty you choose.' },
    { lead: 'Race', text: 'Everyone gets the same board. First to fill it wins.' },
    {
      lead: 'Nothing is stored',
      text: 'A puzzle is a pure function of its seed, so a shared game sends one number instead of a grid — and the solution is never written anywhere.',
    },
  ],
};

function VibeSudoku() {
  const [rulesOpen, setRulesOpen] = useState(false);
  const id = useMemo(() => playerId(), []);

  const [name, setName] = useState(() => playerName());
  const [askingForName, setAskingForName] = useState(false);
  const pendingAction = useRef<(() => void) | null>(null);

  const [difficulty, setDifficulty] = useState<Difficulty>('easy');
  const [gameId, setGameId] = useState<string | null>(null);
  const [isHost, setIsHost] = useState(false);
  const [joinCode, setJoinCode] = useState('');
  const [joinError, setJoinError] = useState('');
  const [snapshot, setSnapshot] = useState<SudokuSnapshot>(EMPTY_SNAPSHOT);

  const [soloSeed, setSoloSeed] = useState<number | null>(null);
  const [values, setValues] = useState<number[]>(() => new Array(CELL_COUNT).fill(0));
  const [notes, setNotes] = useState<Set<number>[]>(() =>
    Array.from({ length: CELL_COUNT }, () => new Set<number>()),
  );
  const [selected, setSelected] = useState<number | null>(null);
  const [noteMode, setNoteMode] = useState(false);
  const [settingsOpen, setSettingsOpen] = useState(false);
  const [noteLimit, setNoteLimit] = useState<NoteLimit>(() => {
    const saved = Number(localStorage.getItem(NOTE_LIMIT_KEY));
    return (NOTE_LIMITS as readonly number[]).includes(saved) ? (saved as NoteLimit) : 4;
  });
  const [solved, setSolved] = useState(false);
  const [elapsed, setElapsed] = useState(0);
  const [countdown, setCountdown] = useState<number | null>(null);
  const [notice, setNotice] = useState('');

  const seed = gameId ? snapshot.seed : soloSeed;

  // Building a puzzle is expensive, so it happens once per seed rather than on
  // every render — a plain call in the component body would carve a new board
  // for each keystroke.
  const puzzle: SudokuPuzzle | null = useMemo(() => {
    if (seed == null) return null;
    const chosen = gameId ? snapshot.difficulty : difficulty;
    return generate(seed, chosen);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [seed, gameId, gameId ? snapshot.difficulty : difficulty]);

  // Starting a round lays the givens down and clears everything else.
  const previousSeed = useRef<number | null>(null);
  useEffect(() => {
    if (!puzzle || seed == null) return;
    if (previousSeed.current === seed) return;
    previousSeed.current = seed;
    setValues([...puzzle.givens]);
    setNotes(Array.from({ length: CELL_COUNT }, () => new Set<number>()));
    setSelected(null);
    setSolved(false);
    setElapsed(0);

    // The seed is the round. A solo game, a shared game starting and a rematch
    // all arrive here, and the guard above already stops React's development
    // double-invoke from counting any of them twice.
    trackGameStart(GAMES.sudoku, {
      mode: gameId ? 'shared' : 'solo',
      grade: puzzle.difficulty,
    });
  }, [puzzle, seed, gameId]);

  // MARK: - The game id in the URL

  /**
   * Arriving on a shared link is still joining.
   *
   * Setting the game id alone put the player in the game but not on the list —
   * they could see the board and nobody could see them, which is exactly what a
   * shared link is for.
   */
  const arrivedByLink = useRef(false);
  useEffect(() => {
    const typed = new URLSearchParams(window.location.search).get('game');
    if (!typed || arrivedByLink.current) return;
    // A code in a link may have been retyped by hand rather than copied.
    const wanted = normaliseGameCode(typed);
    if (!wanted) return;
    arrivedByLink.current = true;

    setGameId(wanted);
    setIsHost(isHosting(wanted));
    withName(() => {
      void joinGame(wanted, id, playerName())
        .then(() => {
          setIsHost(isHosting(wanted));
          setGameId(wanted);
        })
        .catch(() => {
          setGameId(null);
          setJoinError('No game with that code');
          window.history.replaceState({}, '', '/sudoku');
        });
    });
    // Runs once, on arrival; `withName` handles a missing name by asking.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  useEffect(() => {
    if (!gameId) return;
    return observeGame(gameId, setSnapshot);
  }, [gameId]);

  // MARK: - Clock

  useEffect(() => {
    if (!puzzle || solved) return;
    const started = Date.now() - elapsed * 1000;
    const timer = window.setInterval(() => setElapsed((Date.now() - started) / 1000), 500);
    return () => window.clearInterval(timer);
    // Restarting the timer on every elapsed tick would be wrong; it is keyed to
    // the puzzle instead.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [puzzle, solved]);

  useEffect(() => {
    if (snapshot.restartTime == null) {
      setCountdown(null);
      return;
    }
    const tick = () => {
      const left = Math.ceil((snapshot.restartTime! - Date.now()) / 1000);
      if (left <= 0) {
        setCountdown(null);
        setSolved(false);
        if (gameId) void clearRestartTime(gameId).catch(() => undefined);
      } else {
        setCountdown(left);
      }
    };
    tick();
    const timer = window.setInterval(tick, 200);
    return () => window.clearInterval(timer);
  }, [snapshot.restartTime, gameId]);

  // MARK: - Acting

  const withName = useCallback(
    (action: () => void) => {
      if (name) {
        action();
        return;
      }
      pendingAction.current = action;
      setAskingForName(true);
    },
    [name],
  );

  const submitName = (chosen: string | null) => {
    setAskingForName(false);
    if (chosen) {
      setPlayerName(chosen);
      setName(chosen);
    }
    const action = pendingAction.current;
    pendingAction.current = null;
    action?.();
  };

  const playSolo = () => {
    setSoloSeed(randomSeed());
    setValues(new Array(CELL_COUNT).fill(0));
    setNotes(Array.from({ length: CELL_COUNT }, () => new Set<number>()));
    setSelected(null);
    setSolved(false);
    previousSeed.current = null;
  };

  const createShared = () =>
    withName(() => {
      const newId = makeGameCode();
      const newSeed = randomSeed();
      hostedGame(newId);
      setIsHost(true);
      setGameId(newId);
      window.history.replaceState({}, '', `/sudoku?game=${newId}`);
      previousSeed.current = null;
      void createGame(newId, newSeed, difficulty, playerName(), id).catch(() =>
        setNotice('Could not create the game'),
      );
    });

  const join = (code: string) =>
    withName(() => {
      const wanted = normaliseGameCode(code);
      if (!wanted) return;
      setJoinError('');
      void joinGame(wanted, id, name)
        .then(() => {
          setIsHost(isHosting(wanted));
          setGameId(wanted);
          window.history.replaceState({}, '', `/sudoku?game=${wanted}`);
        })
        .catch(() => setJoinError('No game with that code'));
    });

  const leave = () => {
    setGameId(null);
    setSnapshot(EMPTY_SNAPSHOT);
    setSoloSeed(null);
    setSelected(null);
    setNotice('');
    setJoinError('');
    setJoinCode('');
    previousSeed.current = null;
    window.history.replaceState({}, '', '/sudoku');
  };

  // MARK: - Playing

  const waitingForHost = gameId !== null && snapshot.seed !== null && !snapshot.started;
  const canPlay = puzzle !== null && !solved && !waitingForHost;

  const conflicting = useMemo(() => conflictsIn(values), [values]);
  const filled = useMemo(() => values.filter((v) => v !== 0).length, [values]);

  const checkCompletion = useCallback(
    (next: number[]) => {
      if (!isComplete(next)) return;
      setSolved(true);
      if (gameId) void recordWinner(gameId, name).catch(() => undefined);
    },
    [gameId, name],
  );

  const enter = useCallback(
    (digit: number) => {
      if (!canPlay || selected === null || !puzzle) return;
      if (puzzle.givens[selected] !== 0) return;

      if (noteMode) {
        // Four at most, and shown as four big numbers: a phone-sized cell cannot
        // show nine marks anybody can read, and an unreadable note is worse than
        // no note. Removing one is always allowed.
        const held = notes[selected];
        if (!held.has(digit) && held.size >= noteLimit) {
          setNotice(`Notes hold ${noteLimit} numbers.`);
          return;
        }
        setNotes((current) => {
          const next = [...current];
          const set = new Set(next[selected]);
          if (set.has(digit)) set.delete(digit);
          else set.add(digit);
          next[selected] = set;
          return next;
        });
        return;
      }

      const next = [...values];
      // Tapping the same digit again clears the cell: the quickest way to undo.
      next[selected] = next[selected] === digit ? 0 : digit;
      setValues(next);
      setNotes((current) => {
        const updated = [...current];
        updated[selected] = new Set();
        if (next[selected] !== 0) {
          // Filling a cell clears that digit from its peers' notes.
          for (let other = 0; other < CELL_COUNT; other += 1) {
            if (
              rowOf(other) === rowOf(selected) ||
              columnOf(other) === columnOf(selected) ||
              boxOf(other) === boxOf(selected)
            ) {
              const set = new Set(updated[other]);
              set.delete(digit);
              updated[other] = set;
            }
          }
        }
        return updated;
      });
      checkCompletion(next);
    },
    [canPlay, selected, puzzle, noteMode, noteLimit, values, notes, checkCompletion],
  );

  /// Change how many marks a cell holds.
  ///
  /// Going from nine to four has to deal with cells that already hold more: the
  /// lowest marks are kept, because those are the ones somebody wrote first.
  const changeNoteLimit = useCallback((next: NoteLimit) => {
    setNoteLimit(next);
    localStorage.setItem(NOTE_LIMIT_KEY, String(next));
    setNotes((current) => current.map((set) => new Set([...set].sort((a, b) => a - b).slice(0, next))));
  }, []);

  const erase = useCallback(() => {
    if (!canPlay || selected === null || !puzzle) return;
    if (puzzle.givens[selected] !== 0) return;
    const next = [...values];
    next[selected] = 0;
    setValues(next);
    setNotes((current) => {
      const updated = [...current];
      updated[selected] = new Set();
      return updated;
    });
  }, [canPlay, selected, puzzle, values]);

  // A physical keyboard, for anyone playing on a laptop.
  useEffect(() => {
    const onKey = (event: KeyboardEvent) => {
      const target = event.target as HTMLElement | null;
      if (target && ['INPUT', 'TEXTAREA'].includes(target.tagName)) return;
      if (/^[1-9]$/.test(event.key)) {
        event.preventDefault();
        enter(Number(event.key));
      } else if (event.key === 'Backspace' || event.key === 'Delete' || event.key === '0') {
        event.preventDefault();
        erase();
      } else if (event.key.toLowerCase() === 'n') {
        setNoteMode((on) => !on);
      }
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [enter, erase]);

  const playAgain = () => {
    setSolved(false);
    setSelected(null);
    previousSeed.current = null;
    if (!gameId) {
      playSolo();
      return;
    }
    void beginRestart(gameId, randomSeed()).catch(() =>
      setNotice('Could not start the next round'),
    );
  };

  // MARK: - Rendering

  const roundOver = solved || (snapshot.winner !== null && snapshot.winner.name !== name);
  const screen: Screen = puzzle && (!gameId || snapshot.seed !== null) ? 'game' : 'lobby';

  // Sudoku has a win and no loss of its own: you either finish the grid or
  // somebody finishes theirs first. Either way it is one transition out of play,
  // reported once per seed.
  const reportedFinish = useRef<number | null>(null);
  useEffect(() => {
    if (!roundOver || seed == null || reportedFinish.current === seed) return;
    reportedFinish.current = seed;
    trackGameFinish(GAMES.sudoku, {
      mode: gameId ? 'shared' : 'solo',
      outcome: solved ? 'won' : 'lost',
      seconds: Math.round(elapsed),
    });
  }, [roundOver, seed, gameId, solved, elapsed]);

  if (rulesOpen) return <HowToPlay content={SUDOKU_INSTRUCTIONS} onClose={() => setRulesOpen(false)} />;

  return (
    <div className="sudoku">
      <GameHeader
        prefix="sudoku"
        title="Number Vibe"
        subtitle={
          screen === 'game' && puzzle
            ? subtitle(gameId, snapshot, filled, elapsed, difficulty)
            : undefined
        }
      >
        <SupportButton game="sudoku" />
        <SettingsButton prefix="sudoku" onClick={() => setSettingsOpen(true)} />
        {screen === 'game' && gameId && (
          <button type="button" className="sudoku__leave" onClick={leave}>
            Leave
          </button>
        )}
      </GameHeader>

      <GameMessage text={notice || null} tone={notice ? 'warn' : 'info'} />

      {screen === 'lobby' ? (
        <Lobby
          difficulty={difficulty}
          joinCode={joinCode}
          joinError={joinError}
          onDifficulty={setDifficulty}
          onJoinCode={setJoinCode}
          onJoin={join}
          onSolo={playSolo}
          onCreate={createShared}
          onRules={() => setRulesOpen(true)}
        />
      ) : waitingForHost ? (
        <Waiting
          gameId={gameId!}
          snapshot={snapshot}
          isHost={isHost}
          onStart={() => void startGame(gameId!)}
        />
      ) : (
        puzzle && (
          <>
            <Board
              puzzle={puzzle}
              values={values}
              notes={notes}
              noteLimit={noteLimit}
              selected={selected}
              conflicting={conflicting}
              faceDown={waitingForHost}
              onSelect={(index) => setSelected((current) => (current === index ? null : index))}
            />

            <Keypad
              disabled={!canPlay}
              noteMode={noteMode}
              onDigit={enter}
              onErase={erase}
              onToggleNotes={() => setNoteMode((on) => !on)}
            />
          </>
        )
      )}

      {roundOver && screen === 'game' && (
        <RoundOver
          title={
            solved
              ? gameId
                ? 'You finished it!'
                : 'Solved!'
              : `${snapshot.winner?.name ?? 'Someone'} finished first`
          }
          detail={`${filled} of ${CELL_COUNT} · ${formatElapsed(elapsed)}`}
          onPrimary={playAgain}
        >
          {/* Choosing the next board's difficulty belongs here, where you are
              about to start it, rather than only in the lobby. A shared board
              is the host's choice, so this is solo only. */}
          {!gameId && (
            <RoundOverChoices
              label="Difficulty for the next board"
              options={DIFFICULTIES}
              value={difficulty}
              onChange={(id) => setDifficulty(id as Difficulty)}
            />
          )}
        </RoundOver>
      )}

      {countdown !== null && (
        <div className="sudoku__countdown">
          <span>Next board in</span>
          <strong>{countdown}</strong>
        </div>
      )}

      {askingForName && <NamePrompt onSubmit={submitName} />}

      {settingsOpen && (
        <GameSettings prefix="sudoku" onClose={() => setSettingsOpen(false)}>
          <SettingsSection title="Notes per square">
            {/* A switch rather than two rows: the choice is one thing with two
                states, and the rows took a third of the sheet. */}
            <SettingsToggle
              label="Nine marks per square"
              note="Off draws four big ones. On draws every candidate, three by three."
              on={noteLimit === 9}
              onChange={(on) => changeNoteLimit(on ? 9 : 4)}
            />
          </SettingsSection>
        </GameSettings>
      )}
    </div>
  );
}

function randomSeed(): number {
  const values = new Uint32Array(1);
  crypto.getRandomValues(values);
  return values[0];
}

function subtitle(
  gameId: string | null,
  snapshot: SudokuSnapshot,
  filled: number,
  elapsed: number,
  difficulty: Difficulty,
): string {
  const parts: string[] = [];
  if (gameId) parts.push(`${snapshot.players.length} ${snapshot.players.length === 1 ? 'player' : 'players'}`);
  parts.push(snapshot.difficulty ?? difficulty);
  parts.push(`${filled}/${CELL_COUNT}`);
  parts.push(formatElapsed(elapsed));
  if (gameId) parts.push(`code ${displayGameCode(gameId)}`);
  return parts.join(' · ');
}

function formatElapsed(seconds: number): string {
  const total = Math.floor(seconds);
  return `${Math.floor(total / 60)}:${String(total % 60).padStart(2, '0')}`;
}

// MARK: - Board

function Board(props: {
  puzzle: SudokuPuzzle;
  values: number[];
  notes: Set<number>[];
  noteLimit: NoteLimit;
  selected: number | null;
  conflicting: Set<number>;
  faceDown: boolean;
  onSelect: (index: number) => void;
}) {
  return (
    <div className="sudoku__board" role="grid" aria-label="Sudoku board">
      {Array.from({ length: CELL_COUNT }, (_, index) => {
        const given = props.puzzle.givens[index] !== 0;
        // With four, the marks themselves in order — four big numbers. With
        // nine, every digit in its own fixed square, which is how pencil marks
        // are read on paper.
        const marks = [...(props.notes[index] ?? [])].sort((a, b) => a - b);
        const slots = props.noteLimit === 9 ? [1, 2, 3, 4, 5, 6, 7, 8, 9] : [0, 1, 2, 3];
        const value = props.values[index];
        const isSelected = props.selected === index;
        const inConflict = props.conflicting.has(index);
        const sameValue =
          value !== 0 && props.selected !== null && props.values[props.selected] === value;

        return (
          <button
            key={index}
            type="button"
            role="gridcell"
            className="sudoku__cell"
            data-given={given}
            data-selected={isSelected}
            data-conflict={inConflict}
            data-same={sameValue && !isSelected}
            /* The heavier box borders are drawn from the index, so the grid
               needs no nested elements to get its 3x3 divisions. */
            data-right={columnOf(index) % 3 === 2 && columnOf(index) !== 8}
            data-bottom={rowOf(index) % 3 === 2 && rowOf(index) !== 8}
            onClick={() => props.onSelect(index)}
            disabled={props.faceDown}
            aria-label={`Row ${rowOf(index) + 1} column ${columnOf(index) + 1}${
              value !== 0 ? `, ${value}` : ', empty'
            }${given ? ', given' : ''}`}
          >
            {props.faceDown ? (
              ''
            ) : value !== 0 ? (
              <span className="sudoku__value">{value}</span>
            ) : (
              <span className="sudoku__notes" data-limit={props.noteLimit} aria-hidden="true">
                {slots.map((slot, position) => (
                  <span key={slot}>
                    {props.noteLimit === 9
                      ? props.notes[index]?.has(slot)
                        ? slot
                        : ''
                      : (marks[position] ?? '')}
                  </span>
                ))}
              </span>
            )}
          </button>
        );
      })}
    </div>
  );
}

// MARK: - Keypad

function Keypad(props: {
  disabled: boolean;
  noteMode: boolean;
  onDigit: (digit: number) => void;
  onErase: () => void;
  onToggleNotes: () => void;
}) {
  return (
    <div className="sudoku__keypad">
      {[1, 2, 3, 4, 5, 6, 7, 8, 9].map((digit) => (
        <button
          key={digit}
          type="button"
          className="sudoku__key"
          onClick={() => props.onDigit(digit)}
          disabled={props.disabled}
          aria-label={`Enter ${digit}`}
        >
          {digit}
        </button>
      ))}
      <div className="sudoku__keypad-row">
        <button
          type="button"
          className="sudoku__tool"
          data-on={props.noteMode}
          onClick={props.onToggleNotes}
          disabled={props.disabled}
          aria-pressed={props.noteMode}
        >
          Notes
        </button>
        <button
          type="button"
          className="sudoku__tool"
          onClick={props.onErase}
          disabled={props.disabled}
          aria-label="Erase"
        >
          Erase
        </button>
      </div>
    </div>
  );
}

// MARK: - Lobby

function Lobby(props: {
  difficulty: Difficulty;
  joinCode: string;
  joinError: string;
  onDifficulty: (difficulty: Difficulty) => void;
  onJoinCode: (code: string) => void;
  onJoin: (code: string) => void;
  onSolo: () => void;
  onCreate: () => void;
  onRules: () => void;
}) {
  return (
    <SharedLobby
      prefix="sudoku"
      blurb="Proper Sudoku. Play Easy, Medium or Hard on your own — or race the room on the same board."
      joinCode={props.joinCode}
      joinError={props.joinError}
      onJoinCode={props.onJoinCode}
      onJoin={props.onJoin}
      onRules={props.onRules}
    >
      {/* The one game that asks how hard before it deals. It keeps its own
          picker, and the two choices under it are the shared cards. */}
      <div className="sudoku__difficulties">
        {DIFFICULTIES.map((option) => (
          <button
            key={option.id}
            type="button"
            className="sudoku__difficulty"
            data-on={props.difficulty === option.id}
            onClick={() => props.onDifficulty(option.id)}
            aria-pressed={props.difficulty === option.id}
          >
            <strong>{option.title}</strong>
            <span>{option.blurb}</span>
          </button>
        ))}
      </div>

      <LobbyCard
        title="Play on this device"
        blurb="A board to yourself, at the pace you like"
        onClick={props.onSolo}
      />
      <LobbyCard
        title="Race your friends"
        blurb="The same board for everyone. First to finish takes it."
        onClick={props.onCreate}
        alt
      />
    </SharedLobby>
  );
}

// MARK: - Waiting room

function Waiting(props: {
  gameId: string;
  snapshot: SudokuSnapshot;
  isHost: boolean;
  onStart: () => void;
}) {
  return (
    <div className="sudoku__waiting">
      <GameCodeBadge code={props.gameId}
                     size="inline"
                     className="sudoku__code"
                     hint="Everyone else: Number Vibe → Join with a code" />
      <p className="sudoku__waiting-text">
        {props.isHost
          ? `Everyone races the same ${props.snapshot.difficulty} board. Start when they have joined.`
          : `Waiting for ${props.snapshot.creator ?? 'the host'} to start…`}
      </p>
      <p className="sudoku__players">
        {props.snapshot.players.map((player) => player.name).join(', ') || 'Nobody yet'}
      </p>
      {props.isHost && (
        <button type="button" className="sudoku__start" onClick={props.onStart}>
          Start game
        </button>
      )}
      <button
        type="button"
        className="sudoku__link"
        onClick={() => {
          trackShare(GAMES.sudoku, 'game');
          void navigator.clipboard.writeText(`${window.location.origin}/sudoku?game=${props.gameId}`);
        }}
      >
        Copy the link
      </button>
    </div>
  );
}

// MARK: - Name prompt

function NamePrompt({ onSubmit }: { onSubmit: (name: string | null) => void }) {
  const [draft, setDraft] = useState('');
  const trimmed = draft.trim();

  return (
    <div className="sudoku__overlay">
      <form
        className="sudoku__name-card"
        onSubmit={(event) => {
          event.preventDefault();
          if (trimmed) onSubmit(trimmed);
        }}
      >
        <h2>What should we call you?</h2>
        <p>So everyone can see who finished first.</p>
        <input
          value={draft}
          onChange={(event) => setDraft(event.target.value)}
          placeholder="Your name"
          maxLength={MAX_NAME_LENGTH}
          autoFocus
          autoComplete="off"
        />
        <button type="submit" className="sudoku__start" disabled={!trimmed}>
          Save
        </button>
        <button type="button" className="sudoku__link" onClick={() => onSubmit(null)}>
          Not now
        </button>
      </form>
    </div>
  );
}

export default VibeSudoku;
