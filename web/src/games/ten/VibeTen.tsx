import { useEffect, useMemo, useRef, useState } from 'react';
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
import { SoloResume } from '../../hub/SoloResume';
import { clearSolo, loadSolo, saveSolo, savedSolo, type SavedSolo } from '../../hub/soloProgress';
import { RoundOver } from '../../hub/RoundOver';
import { GAMES, trackGameFinish, trackGameStart, trackShare } from '../../analytics';
import { MAX_NAME_LENGTH, isHosting, hostedGame, playerId, playerName, setPlayerName } from '../../identity';
import { makeGameCode, normaliseGameCode } from '../../lib/gameCode';
import {
  COLUMNS,
  MODE_LABELS,
  ROWS,
  ROWS_PER_ADD_OPTIONS,
  ROW_OPTIONS,
  addRow,
  availableMatches,
  canAddRow,
  cellAt,
  isCleared,
  newBoard,
  remaining,
  roomForRows,
  take,
  type Position,
  type TenBoard,
  type TenCell,
  type TenMode,
} from './engine';
import {
  EMPTY_SNAPSHOT,
  beginRestart,
  createGame,
  joinGame,
  observeGame,
  randomSeed,
  rank,
  recordScore,
  removePresence,
  startGame,
  type TenSnapshot,
  type TenStanding,
} from './service';
import './VibeTen.css';

/**
 * Vibe Ten on the web, solo or as a room.
 *
 * A room stores one seed, so every client deals the identical board and then
 * plays its own game: a pair taken here cannot appear on anybody else's board.
 * Only the scores travel, one write each.
 */

const TEN_INSTRUCTIONS: HowToPlayContent = {
  name: 'Vibe Ten',
  intro:
    'Take pairs of digits off the board until nothing pairs any more. Clear every digit and you have cleared the board.',
  sections: [
    {
      title: 'What pairs',
      body: 'Two digits pair if they are **equal** or **add up to ten** — 1 with 9, 2 with 8, 3 with 7, 4 with 6, 5 with 5. They have to be on the same row, column or diagonal with nothing in between: neighbours count, and so does a line with only gaps in it.',
    },
    {
      title: 'How the board is dealt',
      body: "The digits are dealt in valid pairs — some are two of the same number, some add up to ten — and then the digits are shuffled and laid out across the board. So the board is a real mix, and a round can open up or run out of moves: clearing every digit is the aim, not a promise.",
    },
    {
      title: 'The board hangs from the top',
      body: 'The digits hang from the top row, and a gap closes **upward**: take a pair and the digits below it rise into the space. Every take changes what is next to what, which is half the game.',
    },
    {
      title: 'Rows that join up',
      body: 'One setting lets the rows read end to end: the last square of a row is next to the first of the row below, so a 5 at the end of one row matches a 5 at the start of the next — and, if the square between them has already been taken, the one after that. In a room it is part of the host\'s rules.',
    },
    {
      title: 'Dim mode',
      body: 'In the settings, **Dim** leaves a taken pair on the board, greyed out, instead of removing it. A dimmed digit counts as gone: it cannot be picked again, and a pair can be made straight across it. When every digit in a row is dimmed the whole row clears at once and everything below it rises one row. Choose it on the start screen: a game in play keeps the setting it started with, and in a room it is part of the host\'s rules.',
    },
    {
      title: "The board's size",
      body: 'The board is **nine columns** wide and starts with **twelve to eighteen rows** of digits. It always has room for eighteen: the rows beneath the start are where fresh rows grow into, and fewer starting rows means bigger digits. Choose the starting rows on the start screen; once a game is under way the board keeps them, and a room plays the start the host dealt.',
    },
    {
      title: 'New rows',
      body: 'You can hang fresh rows under the board — solo or in a room — but only while the bottom row of the grid is empty. A button appears on that empty row when there is room: a press adds one to four rows, as the settings choose. The board always has room for eighteen rows; when it is full and nothing pairs, the round is over.',
    },
    {
      title: 'Playing as a room',
      body: "Everyone gets the identical board, dealt from a seed and played by the host's rules — the starting rows, whether the rows join end to end and how a taken pair leaves the board — and plays their own copy at their own pace. The first person to clear the board wins. One point a pair is the running total behind the race.",
    },
  ],
  bullets: [
    { lead: 'Solo', text: 'A fresh board whenever you want one, and a new row whenever the top of the grid is free.' },
    { lead: 'Room', text: 'The same board for everyone. First to clear it wins.' },
  ],
};

/** The properties, kept per device: a room's board is everybody's, but these
    are how this player likes to play it. */
const MODE_KEY = 'vibegames.ten.mode';
/** The starting rows. The key predates the board being able to grow. */
const ROWS_KEY = 'vibegames.ten.rows';
const ROWS_PER_ADD_KEY = 'vibegames.ten.rowsPerAdd';
const WRAP_ROWS_KEY = 'vibegames.ten.wrapRows';

function savedMode(): TenMode {
  return localStorage.getItem(MODE_KEY) === 'dim' ? 'dim' : 'remove';
}

function savedRows(): number {
  const saved = Number(localStorage.getItem(ROWS_KEY));
  return (ROW_OPTIONS as readonly number[]).includes(saved) ? saved : ROWS;
}

function savedRowsPerAdd(): number {
  const saved = Number(localStorage.getItem(ROWS_PER_ADD_KEY));
  return (ROWS_PER_ADD_OPTIONS as readonly number[]).includes(saved)
    ? saved
    : ROWS_PER_ADD_OPTIONS[0];
}

function savedWrapRows(): boolean {
  return localStorage.getItem(WRAP_ROWS_KEY) === 'true';
}

/** The game a solo board is, well enough to put it back: the cells, the score
    and the rule it was being played by. */
interface TenSaved {
  seed: number;
  /** Kept for a game saved before the board became always nine columns. */
  columns: number;
  /** The board's capacity. Saves made before the board could grow used this as
      the start too, which is why `startRows` is optional. */
  rows: number;
  startRows?: number;
  wrapRows: boolean;
  stacks: TenCell[][];
  score: number;
  finished: boolean;
  cleared: boolean;
  mode: TenMode;
}

function VibeTen() {
  const [rulesOpen, setRulesOpen] = useState(false);
  const id = useMemo(() => playerId(), []);

  const [, setName] = useState(() => playerName());
  const [askingForName, setAskingForName] = useState(false);
  const pendingAction = useRef<(() => void) | null>(null);

  const [gameId, setGameId] = useState<string | null>(null);
  const [isHost, setIsHost] = useState(false);
  const [joinCode, setJoinCode] = useState('');
  const [joinError, setJoinError] = useState('');
  const [snapshot, setSnapshot] = useState<TenSnapshot>(EMPTY_SNAPSHOT);

  const [soloSeed, setSoloSeed] = useState<number | null>(null);
  const [board, setBoard] = useState<TenBoard | null>(null);
  const [selected, setSelected] = useState<Position | null>(null);
  const [score, setScore] = useState(0);
  const [finished, setFinished] = useState(false);
  const [cleared, setCleared] = useState(false);
  const [notice, setNotice] = useState('');
  const [settingsOpen, setSettingsOpen] = useState(false);
  const [mode, setMode] = useState<TenMode>(savedMode);
  /** How many rows the board starts with; it always has room for eighteen. */
  const [rows, setRows] = useState(savedRows);
  /** A solo board already saved in this browser, waiting to be continued. */
  const [savedResume, setSavedResume] = useState<SavedSolo | null>(null);
  const [rowsPerAdd, setRowsPerAdd] = useState(savedRowsPerAdd);
  const [wrapRows, setWrapRows] = useState(savedWrapRows);

  const seed = gameId ? snapshot.seed : soloSeed;
  const waitingForHost = Boolean(gameId) && !snapshot.started;
  const canPlay = board !== null && !finished && !waitingForHost;

  /** The rules in play: the room's when playing in one — the host chose them
      when the room was made — otherwise this device's choices. */
  const shownMode = gameId ? snapshot.mode : mode;
  const shownWrapRows = gameId ? snapshot.wrapRows : wrapRows;
  const shownRows = gameId ? snapshot.rows : rows;
  const shownRowsPerAdd = gameId ? snapshot.rowsPerAdd : rowsPerAdd;

  // The board is a pure function of the seed: dealt once, then held in state so
  // tapping can take pairs out of it.
  const dealtSeed = useRef<number | null>(null);
  useEffect(() => {
    if (seed == null || dealtSeed.current === seed) return;
    dealtSeed.current = seed;
    // The rows are the host's in a room and this player's solo; the columns are
    // always nine.
    setBoard(
      gameId
        ? newBoard(seed, COLUMNS, snapshot.rows, snapshot.wrapRows)
        : newBoard(seed, COLUMNS, rows, wrapRows),
    );
    setSelected(null);
    setScore(0);
    setFinished(false);
    setCleared(false);
    setNotice('');
    trackGameStart(GAMES.ten, { mode: gameId ? 'shared' : 'solo' });
    // The shape is read as the board is dealt, like the mode: changing it must
    // not re-deal a board somebody is in the middle of.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [seed, gameId]);

  // A solo board is kept as it changes, so leaving the screen — or the browser —
  // does not end the game. A finished board is not something to come back to.
  useEffect(() => {
    if (gameId || !board) return;
    if (finished) {
      clearSolo('ten');
      return;
    }
    const savedBoard: TenSaved = {
      seed: board.seed,
      columns: board.columns,
      rows: board.rows,
      startRows: rows,
      wrapRows: board.wrapRows,
      stacks: board.stacks.map((column) => column.map((entry) => ({ ...entry }))),
      score,
      finished,
      cleared,
      mode,
    };
    saveSolo('ten', savedBoard, `${score} pair${score === 1 ? '' : 's'} taken · ${remaining(board)} digits left`);
  }, [gameId, board, score, finished, cleared, mode]);

  // A room's scores and roster, live. Only the seed rebuilds the board.
  useEffect(() => {
    if (!gameId) return;
    return observeGame(gameId, setSnapshot);
  }, [gameId]);

  // Arriving on a link: the code in the address is the room to join.
  useEffect(() => {
    const wanted = normaliseGameCode(new URLSearchParams(window.location.search).get('game') ?? '');
    if (!wanted || gameId) return;
    withName(() => {
      void joinGame(wanted, id, playerName())
        .then(() => {
          setIsHost(isHosting(wanted));
          setGameId(wanted);
          window.history.replaceState({}, '', `/ten?game=${wanted}`);
        })
        .catch(() => setJoinError('No game with that code'));
    });
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // Leaving the room — Back, or off to the menu — takes this player off the
  // roster now, and stops the board counting towards the old room.
  useEffect(() => {
    if (!gameId) return undefined;
    return () => removePresence(gameId, id);
  }, [gameId, id]);

  // Report the score when the board is over, once.
  const reported = useRef<string | null>(null);
  useEffect(() => {
    if (!finished || !gameId) return;
    const key = `${gameId}:${seed}:${score}`;
    if (reported.current === key) return;
    reported.current = key;
    trackGameFinish(GAMES.ten, {
      mode: 'shared',
      outcome: cleared ? 'won' : 'completed',
      seconds: 0,
    });
  }, [finished, gameId, seed, score, cleared]);

  const standings: TenStanding[] = useMemo(() => {
    return rank(
      Object.entries(snapshot.players).map(([player, playerLabel]) => ({
        id: player,
        name: playerLabel,
        score: snapshot.scores[player]?.score ?? 0,
        finishedAt: snapshot.scores[player]?.finishedAt ?? null,
        clearedAt: snapshot.scores[player]?.clearedAt ?? null,
      })),
    );
  }, [snapshot]);

  /** The first player to clear the board, once there is one. */
  const roomWinner = useMemo(() => {
    const cleared = standings.filter((standing) => standing.clearedAt !== null);
    if (cleared.length === 0) return null;
    const earliest = Math.min(...cleared.map((standing) => standing.clearedAt as number));
    return cleared.find((standing) => standing.clearedAt === earliest) ?? null;
  }, [standings]);
  const amITheWinner = roomWinner !== null && roomWinner.id === id;
  const everyoneFinished = Object.keys(snapshot.players).length > 0
    && Object.keys(snapshot.players).every((player) => {
      const record = snapshot.scores[player];
      return record !== undefined && (record.finishedAt !== null || record.clearedAt !== null);
    });

  // A clear ends the round for the room: the first one wins, and everybody
  // else's board stops.
  useEffect(() => {
    if (!gameId || finished) return;
    if (roomWinner && roomWinner.id !== id) {
      setFinished(true);
      setSelected(null);
      // The room should know this player is out of the round too, not still
      // "playing" in the standings.
      void recordScore(gameId, id, score, Date.now(), null).catch(() => undefined);
    }
  }, [gameId, finished, roomWinner, id, score]);

  function withName(action: () => void) {
    if (playerName().trim()) {
      action();
      return;
    }
    pendingAction.current = action;
    setAskingForName(true);
  }

  function submitName(chosen: string | null) {
    setAskingForName(false);
    if (chosen) {
      setPlayerName(chosen);
      setName(chosen);
    }
    const action = pendingAction.current;
    pendingAction.current = null;
    action?.();
  }

  /** From the start screen: continue the board saved here, or ask what to do. */
  function requestSolo() {
    const saved = savedSolo('ten');
    if (saved) {
      setSavedResume(saved);
      return;
    }
    solo();
  }

  /** Picks the saved board back up, exactly as it was left. */
  function resumeSolo() {
    const saved = loadSolo<TenSaved>('ten');
    setSavedResume(null);
    if (!saved) {
      solo();
      return;
    }
    const data = saved.payload;
    setGameId(null);
    setIsHost(false);
    dealtSeed.current = data.seed;
    setSoloSeed(data.seed);
    setBoard({
      seed: data.seed,
      columns: data.columns ?? COLUMNS,
      rows: ROWS,
      wrapRows: data.wrapRows,
      stacks: data.stacks,
    });
    // The saved board comes with the rules it was dealt by, and they become the
    // choices for the next one.
    setMode(data.mode);
    setWrapRows(data.wrapRows);
    setRows(data.startRows
      ?? ((ROW_OPTIONS as readonly number[]).includes(data.rows) ? data.rows : ROWS));
    setScore(data.score);
    setFinished(data.finished);
    setCleared(data.cleared);
    setSelected(null);
    setNotice('');
    window.history.replaceState({}, '', '/ten');
  }

  function solo() {
    clearSolo('ten');
    setGameId(null);
    setIsHost(false);
    setSelected(null);
    setSoloSeed(randomSeed());
    window.history.replaceState({}, '', '/ten');
  }

  function create() {
    withName(() => {
      const newId = makeGameCode();
      const newSeed = randomSeed();
      void createGame(newId, newSeed, rows, rowsPerAdd, wrapRows, mode, playerName(), id)
        .then(() => {
          hostedGame(newId);
          setIsHost(true);
          setGameId(newId);
          window.history.replaceState({}, '', `/ten?game=${newId}`);
        })
        .catch(() => setJoinError('Could not start a game. Check your connection.'));
    });
  }

  function join(code: string) {
    const wanted = normaliseGameCode(code);
    if (!wanted) return;
    withName(() => {
      void joinGame(wanted, id, playerName())
        .then(() => {
          setIsHost(isHosting(wanted));
          setGameId(wanted);
          window.history.replaceState({}, '', `/ten?game=${wanted}`);
        })
        .catch(() => setJoinError('No game with that code'));
    });
  }

  function leave() {
    if (gameId) removePresence(gameId, id);
    setGameId(null);
    setIsHost(false);
    setBoard(null);
    setSoloSeed(null);
    setSelected(null);
    setScore(0);
    setFinished(false);
    setCleared(false);
    setJoinCode('');
    setJoinError('');
    window.history.replaceState({}, '', '/ten');
  }

  function tapCell(position: Position) {
    if (!canPlay || !board) return;
    if (!selected) {
      setSelected(position);
      return;
    }
    if (selected.column === position.column && selected.row === position.row) {
      setSelected(null);
      return;
    }

    const moved = take(board, selected, position, shownMode);
    if (!moved) {
      setSelected(position);
      setNotice("Those two don't pair.");
      return;
    }

    const next = moved.board;
    const taken = score + 1;
    setBoard(next);
    setScore(taken);
    setSelected(null);
    setNotice('');

    // Clearing wins. Running out of moves only loses once there is no room for
    // a new row either; while the grid has space, the board is one to grow.
    const wonNow = isCleared(next);
    const over = wonNow || (!availableMatches(next).length && !canAddRow(next));
    if (over) {
      setFinished(true);
      setCleared(wonNow);
    }

    if (gameId) {
      const at = Date.now();
      void recordScore(gameId, id, taken, over ? at : null, wonNow ? at : null).catch(() =>
        setNotice('Could not tell the room that one.'),
      );
    }
  }

  /** Hangs fresh rows under the digits: as many as a press deals, or as many
      as the grid still has room for. Solo or in a room — each player's board
      grows on their own device. */
  function dealRow() {
    if (!board || !canPlay) return;
    let next = board;
    const wanted = Math.min(shownRowsPerAdd, roomForRows(next));
    for (let index = 0; index < wanted; index += 1) {
      const digits = Array.from({ length: next.columns }, () => 1 + Math.floor(Math.random() * 9));
      const moved = addRow(next, digits);
      if (!moved) break;
      next = moved;
    }
    if (next === board) return;
    setBoard(next);
    setSelected(null);
    setNotice('');

    // The new rows may still leave nothing to take, and if they filled the
    // last of the room then the round is over.
    if (!availableMatches(next).length && !canAddRow(next)) {
      setFinished(true);
      setCleared(false);
      if (gameId) {
        void recordScore(gameId, id, score, Date.now(), null).catch(() =>
          setNotice('Could not tell the room that one.'),
        );
      }
    }
  }

  function chooseMode(next: TenMode) {
    setMode(next);
    localStorage.setItem(MODE_KEY, next);
  }

  /** The shape is a choice for a new game, not for one under way. */
  const shapeLocked = board !== null;

  /** The pair setting is a choice for a new game too. In a room it belongs to
      the host, who chose it when the room was made, so it is not this player's
      to change. The new-row switch is not locked at all — it is an offer that
      comes and goes during play. */
  const modeLocked = Boolean(gameId) || (board !== null && !finished && !waitingForHost);

  /** How many rows a press deals is a choice for a new game; in a room it is
      the host's rule. */
  const rowSupplyEditable = !gameId && !modeLocked;

  function chooseRows(next: number) {
    setRows(next);
    localStorage.setItem(ROWS_KEY, String(next));
  }

  function chooseRowsPerAdd(next: number) {
    setRowsPerAdd(next);
    localStorage.setItem(ROWS_PER_ADD_KEY, String(next));
  }

  function chooseWrapRows(on: boolean) {
    setWrapRows(on);
    localStorage.setItem(WRAP_ROWS_KEY, String(on));
  }

  function playAgain() {
    if (!gameId) {
      solo();
      return;
    }
    void beginRestart(gameId, randomSeed()).catch(() => setNotice('Could not deal another board.'));
  }

  if (rulesOpen) return <HowToPlay content={TEN_INSTRUCTIONS} onClose={() => setRulesOpen(false)} />;

  const roundOverTitle = roundOverTitleFor({
    cleared, gameId, roomWinner, amITheWinner, everyoneFinished,
  });

  const subtitle = !board
    ? undefined
    : gameId
      ? `${Object.keys(snapshot.players).length} player${Object.keys(snapshot.players).length === 1 ? '' : 's'} · ${score} ${score === 1 ? 'pair' : 'pairs'}`
      : `Solo · ${score} ${score === 1 ? 'pair' : 'pairs'} · ${availableMatches(board).length} left to take`;

  return (
    <div className="ten">
      <GameHeader
        prefix="ten"
        title="Vibe Ten"
        subtitle={subtitle}
        onBack={gameId && !waitingForHost ? leave : undefined}
        backLabel="Leave game"
        code={gameId}
      >
        <SupportButton game={GAMES.ten} />
        <SettingsButton prefix="ten" onClick={() => setSettingsOpen(true)} />
      </GameHeader>

      <GameMessage text={notice || null} tone="warn" />

      {!board ? (
        <SharedLobby
          prefix="ten"
          blurb="Pair the digits, drop the ones above, clear the board."
          joinCode={joinCode}
          joinError={joinError}
          onJoinCode={setJoinCode}
          onJoin={join}
          onRules={() => setRulesOpen(true)}
        >
          <LobbyCard
            title="Play on this device"
            blurb="A board of your own, no connection needed"
            onClick={requestSolo}
          />
          <LobbyCard
            title="Play with others"
            blurb="The same board for everyone. First to clear it wins."
            onClick={create}
            alt
          />
        </SharedLobby>
      ) : waitingForHost ? (
        <Waiting
          gameId={gameId!}
          snapshot={snapshot}
          isHost={isHost}
          onStart={() => void startGame(gameId!)}
        />
      ) : (
        <div className="ten__game">
          {gameId && !finished && standings.length > 0 && (
            <p className="ten__scoreline">
              {standings.map((standing) => (
                <span key={standing.id}
                      data-done={standing.finishedAt !== null || standing.clearedAt !== null}>
                  {standing.name} <strong>{standing.score}</strong>
                  {standing.clearedAt !== null && <span aria-label="cleared"> ✓</span>}
                </span>
              ))}
            </p>
          )}

          <Board
            board={board}
            selected={selected}
            onTap={tapCell}
            disabled={!canPlay}
            onAddRow={!finished && canAddRow(board) ? dealRow : undefined}
            rowsPerAdd={shownRowsPerAdd}
          />

          {finished && (
            <RoundOver
              title={roundOverTitle}
              detail={detailFor({
                cleared, score, gameId, roomWinner, amITheWinner, everyoneFinished,
              })}
              onPrimary={playAgain}
            >
              {gameId && standings.length > 0 && (
                <ol className="ten__standings">
                  {standings.map((standing) => (
                    <li key={standing.id}
                        data-playing={standing.finishedAt === null && standing.clearedAt === null}>
                      <span>{standing.name}</span>
                      <strong>{standing.score}</strong>
                      {standing.clearedAt !== null && <em>cleared</em>}
                    </li>
                  ))}
                </ol>
              )}
            </RoundOver>
          )}
        </div>
      )}

      {askingForName && <NamePrompt onSubmit={submitName} />}

      {savedResume && (
        <SoloResume
          saved={savedResume}
          onContinue={resumeSolo}
          onNewGame={() => {
            setSavedResume(null);
            solo();
          }}
          onCancel={() => setSavedResume(null)}
        />
      )}

      {settingsOpen && (
        <GameSettings prefix="ten" onClose={() => setSettingsOpen(false)}>
          <SettingsSection
            title="The board"
            note={
              shapeLocked
                ? 'The board is set for this game. Leave it, and choose the starting rows on the start screen before the next one.'
                : 'Nine columns, always. Choose how many rows start full; the board has room for eighteen.'
            }
          >
            <p className="ten__setting-label">Start with</p>
            <div className="game-sheet__choices" role="group" aria-label="Rows">
              {ROW_OPTIONS.map((choice) => (
                <button
                  key={choice}
                  type="button"
                  className="game-sheet__choice"
                  data-on={shownRows === choice}
                  aria-pressed={shownRows === choice}
                  disabled={shapeLocked}
                  onClick={() => chooseRows(choice)}
                >
                  {choice}
                </button>
              ))}
            </div>

            <p className="ten__setting-label">Rows per press</p>
            <div className="game-sheet__choices" role="group" aria-label="Rows per press">
              {ROWS_PER_ADD_OPTIONS.map((choice) => (
                <button
                  key={choice}
                  type="button"
                  className="game-sheet__choice"
                  data-on={shownRowsPerAdd === choice}
                  aria-pressed={shownRowsPerAdd === choice}
                  disabled={!rowSupplyEditable}
                  onClick={() => chooseRowsPerAdd(choice)}
                >
                  {choice}
                </button>
              ))}
            </div>
            <p>
              How many rows a press of the new-row offer hangs under the board.
              In a room it is the host's rule.
            </p>
          </SettingsSection>

          <SettingsSection
            title="When a pair is matched"
            note={
              modeLocked
                ? gameId
                  ? "In a room the host's rules are the game's rules. This room is playing the way it was created."
                  : 'This game is using the setting it started with. Leave it to choose again.'
                : 'Choose it before you start. Pairs taken in Dim mode stay on the board.'
            }
          >
            <div className="game-sheet__choices" role="group" aria-label="When a pair is matched">
              {(Object.keys(MODE_LABELS) as TenMode[]).map((choice) => (
                <button
                  key={choice}
                  type="button"
                  className="game-sheet__choice"
                  data-on={shownMode === choice}
                  aria-pressed={shownMode === choice}
                  disabled={modeLocked}
                  onClick={() => chooseMode(choice)}
                >
                  {MODE_LABELS[choice].title}
                </button>
              ))}
            </div>
            <p>{MODE_LABELS[shownMode].blurb}</p>
            <SettingsToggle
              label="Rows join end to end"
              note="The last square of a row is next to the first of the row below"
              on={shownWrapRows}
              onChange={chooseWrapRows}
              disabled={modeLocked}
            />
          </SettingsSection>

          <SettingsSection title="Adding rows">
            <p>
              When the bottom row of the grid is empty, a button appears there to
              hang fresh rows underneath. Every game offers it — solo or in a room —
              up to eighteen rows. When the grid is full and nothing pairs, the
              round is over.
            </p>
          </SettingsSection>
        </GameSettings>
      )}
    </div>
  );
}

/** What the panel says over the result. */
function roundOverTitleFor(props: {
  cleared: boolean;
  gameId: string | null;
  roomWinner: TenStanding | null;
  amITheWinner: boolean;
  everyoneFinished: boolean;
}): string {
  if (props.gameId && props.roomWinner) {
    return props.amITheWinner ? 'Cleared it!' : `${props.roomWinner.name} cleared it first`;
  }
  if (props.cleared) return 'Cleared it!';
  if (props.gameId && props.everyoneFinished) return 'No one cleared it';
  return 'No moves left';
}

/** And what the panel says under the title. */
function detailFor(props: {
  cleared: boolean;
  score: number;
  gameId: string | null;
  roomWinner: TenStanding | null;
  amITheWinner: boolean;
  everyoneFinished: boolean;
}): string {
  const pairs = `${props.score} ${props.score === 1 ? 'pair' : 'pairs'}`;
  if (props.gameId) {
    if (props.roomWinner) {
      return props.amITheWinner
        ? `You cleared the board first. ${pairs} taken.`
        : `${props.roomWinner.name} cleared the board first. ${pairs} taken.`;
    }
    if (props.everyoneFinished) return `${pairs} taken, and nobody cleared the board.`;
    return `${pairs} taken. The room is still playing.`;
  }
  return props.cleared
    ? `Every digit gone. ${pairs} taken.`
    : `${pairs} taken, with no pairs left and no room for a new row.`;
}

function Board(props: {
  board: TenBoard;
  selected: Position | null;
  onTap: (position: Position) => void;
  disabled: boolean;
  /** Set when the empty bottom row should carry the new-row button. */
  onAddRow?: () => void;
  /** How many rows one press deals, for the button's words. */
  rowsPerAdd?: number;
}) {
  // Row 0 is the top row: the board hangs from the top, so a gap closes upward.
  const rowNumbers = Array.from({ length: props.board.rows }, (_, index) => index);
  return (
    <div
      className="ten__board-wrap"
      style={{
        // The grid's shape, for the CSS: fewer columns and rows means bigger
        // squares, still filling the width it is given.
        ['--ten-columns' as string]: props.board.columns,
        ['--ten-rows' as string]: props.board.rows,
      } as React.CSSProperties}
    >
      <div className="ten__board" role="grid" aria-label="Vibe Ten board">
        {rowNumbers.map((row) =>
          Array.from({ length: props.board.columns }, (_, column) => {
            const position = { column, row };
            const entry = cellAt(props.board, position);
            if (!entry) {
              return <span key={`${column}-${row}`} className="ten__gap" aria-hidden="true" />;
            }
            const label = `Column ${column + 1} row ${row + 1}: ${entry.value}`;
            if (entry.dimmed) {
              // Taken in dim mode: still there to read, clearly out of play.
              return (
                <span
                  key={`${column}-${row}`}
                  className="ten__cell"
                  data-dimmed="true"
                  role="gridcell"
                  aria-label={`${label}, taken`}
                >
                  {entry.value}
                </span>
              );
            }
            const isSelected = props.selected?.column === column && props.selected.row === row;
            return (
              <button
                key={`${column}-${row}`}
                type="button"
                className="ten__cell"
                data-selected={isSelected}
                disabled={props.disabled}
                onClick={() => props.onTap(position)}
                aria-label={label}
                aria-pressed={isSelected}
              >
                {entry.value}
              </button>
            );
          }),
        )}
      </div>

      {/* The top row is dead space while it is empty, so the offer to push a
          fresh row in lives there rather than in a strip of its own. */}
      {props.onAddRow && (
        <button
          type="button"
          className="ten__add-row"
          onClick={props.onAddRow}
          aria-label={
            (props.rowsPerAdd ?? 1) === 1
              ? 'Add a row at the bottom'
              : `Add ${props.rowsPerAdd} rows at the bottom`
          }
        >
          <span aria-hidden="true">＋</span>{' '}
          {(props.rowsPerAdd ?? 1) === 1 ? 'Add a row' : `Add ${props.rowsPerAdd} rows`}
        </button>
      )}
    </div>
  );
}

function Waiting(props: {
  gameId: string;
  snapshot: TenSnapshot;
  isHost: boolean;
  onStart: () => void;
}) {
  return (
    <div className="ten__waiting">
      <GameCodeBadge
        code={props.gameId}
        size="inline"
        className="ten__code"
        hint="Everyone else: Vibe Ten → Join with a code"
      />
      <p className="ten__waiting-text">
        {props.isHost
          ? 'Start when everyone has joined. Everyone plays the same board.'
          : `Waiting for ${props.snapshot.creator ?? 'the host'} to start…`}
      </p>
      <p className="ten__players">
        {Object.values(props.snapshot.players).join(' · ')}
      </p>
      {props.isHost && (
        <button type="button" className="ten__start" onClick={props.onStart}>
          Start
        </button>
      )}
      <button
        type="button"
        className="ten__link"
        onClick={() => {
          trackShare(GAMES.ten, 'game');
          void navigator.clipboard.writeText(
            `${window.location.origin}/ten?game=${props.gameId}`,
          );
        }}
      >
        Copy the link
      </button>
    </div>
  );
}

function NamePrompt({ onSubmit }: { onSubmit: (name: string | null) => void }) {
  const [draft, setDraft] = useState('');
  const trimmed = draft.trim();

  return (
    <div className="ten__overlay">
      <form
        className="ten__name-card"
        onSubmit={(event) => {
          event.preventDefault();
          if (trimmed) onSubmit(trimmed);
        }}
      >
        <h2>What should we call you?</h2>
        <p>So the others in the room know whose score is whose.</p>
        <input
          value={draft}
          onChange={(event) => setDraft(event.target.value)}
          placeholder="Your name"
          maxLength={MAX_NAME_LENGTH}
          autoFocus
          autoComplete="off"
        />
        <button type="submit" className="ten__start" disabled={!trimmed}>
          Save
        </button>
        <button type="button" className="ten__link" onClick={() => onSubmit(null)}>
          Not now
        </button>
      </form>
    </div>
  );
}

export default VibeTen;
