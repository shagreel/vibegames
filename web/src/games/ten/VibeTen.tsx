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
  COLUMN_OPTIONS,
  MODE_LABELS,
  ROWS,
  ROWS_PER_ADD_OPTIONS,
  ROW_OPTIONS,
  START_FILL_LABELS,
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
  type TenStartFill,
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
      title: 'The board hangs from the top',
      body: 'The digits hang from the top row, and a gap closes **upward**: take a pair and the digits below it rise into the space. Every take changes what is next to what, which is half the game.',
    },
    {
      title: 'Rows that join up',
      body: 'One setting lets the rows read end to end: the last square of a row is next to the first of the row below, so a 5 at the end of one row matches a 5 at the start of the next — and, if the square between them has already been taken, the one after that.',
    },
    {
      title: 'Dim mode',
      body: 'In the settings, **Dim** leaves a taken pair on the board, greyed out, instead of removing it. A dimmed digit counts as gone: it cannot be picked again, and a pair can be made straight across it. When every digit in a row is dimmed the whole row clears at once and everything below it rises one row. Choose it on the start screen: a game in play keeps the setting it started with.',
    },
    {
      title: "The board's size",
      body: 'On the start screen the grid can be **six to nine columns** and **twelve to eighteen rows**, the full board by default: fewer squares means bigger digits, and the grid always fills the screen. Once a game is under way the board keeps its shape, and a room plays the shape the host dealt so everybody\'s board matches.',
    },
    {
      title: 'New rows, solo',
      body: 'Playing alone, you can hang fresh rows under the board — but only while the bottom row of the grid is empty. A button appears on that empty row when there is room: a press adds one to four rows, as you choose in the settings, and a board can start a third full to leave room for them. It is a solo-only button: in a room everybody plays the board they were dealt.',
    },
    {
      title: 'Playing as a room',
      body: 'Everyone gets the identical board, dealt from a seed, and plays their own copy at their own pace. One point a pair. When everybody has run out of moves the most pairs wins, and a tie goes to whoever ran out first.',
    },
  ],
  bullets: [
    { lead: 'Solo', text: 'A fresh board whenever you want one, and a new row whenever the top of the grid is free.' },
    { lead: 'Room', text: 'The same board for everyone. Most pairs wins.' },
  ],
};

/** The properties, kept per device: a room's board is everybody's, but these
    are how this player likes to play it. */
const MODE_KEY = 'vibegames.ten.mode';
const ADD_ROW_KEY = 'vibegames.ten.addRow';
const COLUMNS_KEY = 'vibegames.ten.columns';
const ROWS_KEY = 'vibegames.ten.rows';
const START_FILL_KEY = 'vibegames.ten.startFill';
const ROWS_PER_ADD_KEY = 'vibegames.ten.rowsPerAdd';
const WRAP_ROWS_KEY = 'vibegames.ten.wrapRows';

function savedMode(): TenMode {
  return localStorage.getItem(MODE_KEY) === 'dim' ? 'dim' : 'remove';
}

function savedAddRow(): boolean {
  return localStorage.getItem(ADD_ROW_KEY) !== 'false';
}

/** The board's shape: one of the four in each direction, or the full board. */
function savedColumns(): number {
  const saved = Number(localStorage.getItem(COLUMNS_KEY));
  return (COLUMN_OPTIONS as readonly number[]).includes(saved) ? saved : COLUMNS;
}

function savedRows(): number {
  const saved = Number(localStorage.getItem(ROWS_KEY));
  return (ROW_OPTIONS as readonly number[]).includes(saved) ? saved : ROWS;
}

function savedStartFill(): TenStartFill {
  return localStorage.getItem(START_FILL_KEY) === 'third' ? 'third' : 'full';
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
  columns: number;
  rows: number;
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
  const [finishedAt, setFinishedAt] = useState<number | null>(null);
  const [notice, setNotice] = useState('');
  const [settingsOpen, setSettingsOpen] = useState(false);
  const [mode, setMode] = useState<TenMode>(savedMode);
  const [addRowEnabled, setAddRowEnabled] = useState(savedAddRow);
  const [columns, setColumns] = useState(savedColumns);
  const [rows, setRows] = useState(savedRows);
  /** A solo board already saved in this browser, waiting to be continued. */
  const [savedResume, setSavedResume] = useState<SavedSolo | null>(null);
  const [startFill, setStartFill] = useState<TenStartFill>(savedStartFill);
  const [rowsPerAdd, setRowsPerAdd] = useState(savedRowsPerAdd);
  const [wrapRows, setWrapRows] = useState(savedWrapRows);

  const seed = gameId ? snapshot.seed : soloSeed;
  const waitingForHost = Boolean(gameId) && !snapshot.started;
  const canPlay = board !== null && !finished && !waitingForHost;

  // The board is a pure function of the seed: dealt once, then held in state so
  // tapping can take pairs out of it.
  const dealtSeed = useRef<number | null>(null);
  useEffect(() => {
    if (seed == null || dealtSeed.current === seed) return;
    dealtSeed.current = seed;
    // A room's board is the shape the host dealt; a solo board is this
    // player's choice. A third-filled board goes with the new-row offer, and a
    // room always starts full so everybody's board is the same size.
    const startRows = !gameId && addRowEnabled && startFill === 'third'
      ? Math.max(1, Math.floor(rows / 3))
      : rows;
    setBoard(
      gameId
        ? newBoard(seed, snapshot.columns, snapshot.rows, snapshot.rows, wrapRows)
        : newBoard(seed, columns, rows, startRows, wrapRows),
    );
    setSelected(null);
    setScore(0);
    setFinished(false);
    setCleared(false);
    setFinishedAt(null);
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
      })),
    );
  }, [snapshot]);

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
      columns: data.columns,
      rows: data.rows,
      wrapRows: data.wrapRows,
      stacks: data.stacks,
    });
    setMode(data.mode);
    setScore(data.score);
    setFinished(data.finished);
    setCleared(data.cleared);
    setSelected(null);
    setFinishedAt(null);
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
      void createGame(newId, newSeed, columns, rows, playerName(), id)
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

    const moved = take(board, selected, position, mode);
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

    const over = isCleared(next) || availableMatches(next).length === 0;
    if (over) {
      setFinished(true);
      setCleared(isCleared(next));
      setFinishedAt(Date.now());
    }

    if (gameId) {
      void recordScore(gameId, id, taken, over ? Date.now() : null).catch(() =>
        setNotice('Could not tell the room that one.'),
      );
    }
  }

  /** Hangs fresh rows under the digits: as many as a press deals, or as many
      as the grid still has room for. */
  function dealRow() {
    if (!board || !canPlay) return;
    let next = board;
    const wanted = Math.min(rowsPerAdd, roomForRows(next));
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
  }

  function chooseMode(next: TenMode) {
    setMode(next);
    localStorage.setItem(MODE_KEY, next);
  }

  function chooseAddRow(on: boolean) {
    setAddRowEnabled(on);
    localStorage.setItem(ADD_ROW_KEY, String(on));
  }

  /** The shape is a choice for a new game, not for one under way. */
  const shapeLocked = board !== null;

  /** The pair setting is a choice for a new game too, with two differences: a
      room waiting for its host has not begun, so the choice is still there, and
      a finished round counts as over. The new-row switch is not locked at all —
      it is an offer that comes and goes during play. */
  const modeLocked = board !== null && !finished && !waitingForHost;

  /** The fill and the rows a press deals are solo choices, and only with the
      new-row offer on: the rows are what fills a part-filled board. */
  const rowSupplyEditable = !gameId && !modeLocked && addRowEnabled;

  function chooseColumns(next: number) {
    setColumns(next);
    localStorage.setItem(COLUMNS_KEY, String(next));
  }

  function chooseRows(next: number) {
    setRows(next);
    localStorage.setItem(ROWS_KEY, String(next));
  }

  function chooseStartFill(next: TenStartFill) {
    setStartFill(next);
    localStorage.setItem(START_FILL_KEY, next);
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
            blurb="The same board for everyone. Most pairs wins."
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
                <span key={standing.id} data-done={standing.finishedAt !== null}>
                  {standing.name} <strong>{standing.score}</strong>
                </span>
              ))}
            </p>
          )}

          <Board
            board={board}
            selected={selected}
            onTap={tapCell}
            disabled={!canPlay}
            onAddRow={
              !gameId && !finished && addRowEnabled && canAddRow(board) ? dealRow : undefined
            }
            rowsPerAdd={rowsPerAdd}
          />

          {finished && (
            <RoundOver
              title={cleared ? 'Cleared it!' : 'No moves left'}
              detail={detailFor({ cleared, score, gameId, standings, finishedAt })}
              onPrimary={playAgain}
            >
              {gameId && standings.length > 0 && (
                <ol className="ten__standings">
                  {standings.map((standing) => (
                    <li key={standing.id} data-playing={standing.finishedAt === null}>
                      <span>{standing.name}</span>
                      <strong>{standing.score}</strong>
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
                ? 'The board is set for this game. Leave it, and choose a size on the start screen before the next one.'
                : 'Fewer columns and rows means bigger digits. Choose it before you start; in a room everybody plays the shape the host dealt.'
            }
          >
            <p className="ten__setting-label">Start with</p>
            <div className="game-sheet__choices" role="group" aria-label="Start with">
              {(['full', 'third'] as TenStartFill[]).map((choice) => (
                <button
                  key={choice}
                  type="button"
                  className="game-sheet__choice"
                  data-on={startFill === choice}
                  aria-pressed={startFill === choice}
                  disabled={!rowSupplyEditable}
                  onClick={() => chooseStartFill(choice)}
                >
                  {START_FILL_LABELS[choice].title}
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
                  data-on={rowsPerAdd === choice}
                  aria-pressed={rowsPerAdd === choice}
                  disabled={!rowSupplyEditable}
                  onClick={() => chooseRowsPerAdd(choice)}
                >
                  {choice}
                </button>
              ))}
            </div>

            <p className="ten__setting-label">Columns</p>
            <div className="game-sheet__choices" role="group" aria-label="Columns">
              {COLUMN_OPTIONS.map((choice) => (
                <button
                  key={choice}
                  type="button"
                  className="game-sheet__choice"
                  data-on={columns === choice}
                  aria-pressed={columns === choice}
                  disabled={shapeLocked}
                  onClick={() => chooseColumns(choice)}
                >
                  {choice}
                </button>
              ))}
            </div>
            <p className="ten__setting-label">Rows</p>
            <div className="game-sheet__choices" role="group" aria-label="Rows">
              {ROW_OPTIONS.map((choice) => (
                <button
                  key={choice}
                  type="button"
                  className="game-sheet__choice"
                  data-on={rows === choice}
                  aria-pressed={rows === choice}
                  disabled={shapeLocked}
                  onClick={() => chooseRows(choice)}
                >
                  {choice}
                </button>
              ))}
            </div>
          </SettingsSection>

          <SettingsSection
            title="When a pair is matched"
            note={
              modeLocked
                ? 'This game is using the setting it started with. Leave it to choose again.'
                : 'Choose it before you start. Pairs taken in Dim mode stay on the board.'
            }
          >
            <div className="game-sheet__choices" role="group" aria-label="When a pair is matched">
              {(Object.keys(MODE_LABELS) as TenMode[]).map((choice) => (
                <button
                  key={choice}
                  type="button"
                  className="game-sheet__choice"
                  data-on={mode === choice}
                  aria-pressed={mode === choice}
                  disabled={modeLocked}
                  onClick={() => chooseMode(choice)}
                >
                  {MODE_LABELS[choice].title}
                </button>
              ))}
            </div>
            <p>{MODE_LABELS[mode].blurb}</p>
            <SettingsToggle
              label="Rows join end to end"
              note="The last square of a row is next to the first of the row below"
              on={wrapRows}
              onChange={chooseWrapRows}
              disabled={modeLocked}
            />
          </SettingsSection>

          <SettingsSection title="Adding rows">
            <SettingsToggle
              label="Offer a new row"
              note="Solo games only: the button on the empty bottom row hangs fresh rows underneath"
              on={addRowEnabled}
              onChange={chooseAddRow}
            />
          </SettingsSection>
        </GameSettings>
      )}
    </div>
  );
}

/** What the panel says under the result. */
function detailFor(props: {
  cleared: boolean;
  score: number;
  gameId: string | null;
  standings: TenStanding[];
  finishedAt: number | null;
}): string {
  const pairs = `${props.score} ${props.score === 1 ? 'pair' : 'pairs'}`;
  if (props.gameId) {
    const leader = props.standings[0];
    if (!leader) return `${pairs} taken.`;
    return `${leader.name} wins with ${leader.score}.`;
  }
  return props.cleared
    ? `Every digit gone. ${pairs} taken.`
    : `${pairs} taken, and nothing left that pairs.`;
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
