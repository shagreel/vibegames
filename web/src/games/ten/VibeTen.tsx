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
import { RoundOver } from '../../hub/RoundOver';
import { GAMES, trackGameFinish, trackGameStart, trackShare } from '../../analytics';
import { MAX_NAME_LENGTH, isHosting, hostedGame, playerId, playerName, setPlayerName } from '../../identity';
import { makeGameCode, normaliseGameCode } from '../../lib/gameCode';
import {
  COLUMNS,
  COLUMN_OPTIONS,
  MODE_LABELS,
  ROWS,
  ROW_OPTIONS,
  addRow,
  availableMatches,
  canAddRow,
  cellAt,
  isCleared,
  newBoard,
  take,
  type Position,
  type TenBoard,
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
      title: 'The board falls',
      body: 'Taking a pair leaves a hole, and the digits above drop into it. Every take changes what is next to what, which is half the game.',
    },
    {
      title: 'Dim mode',
      body: 'In the settings, **Dim** leaves a taken pair on the board, greyed out, instead of removing it. A dimmed digit counts as gone: it cannot be picked again, and a pair can be made straight across it. When every digit in a row is dimmed the whole row clears at once and everything above drops one row. Choose it on the start screen: a game in play keeps the setting it started with.',
    },
    {
      title: "The board's size",
      body: 'On the start screen the grid can be **six to nine columns** and **twelve to eighteen rows**, the full board by default: fewer squares means bigger digits, and the grid always fills the screen. Once a game is under way the board keeps its shape, and a room plays the shape the host dealt so everybody\'s board matches.',
    },
    {
      title: 'A new row, solo',
      body: 'Playing alone, you can push a fresh row in at the bottom — but only while the top row of the grid is empty. A button appears in that empty row when there is room: tap it and the new digits arrive underneath, with everything else moving up one. It is a solo-only button: in a room everybody plays the board they were dealt.',
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
    // player's choice.
    setBoard(gameId ? newBoard(seed, snapshot.columns, snapshot.rows) : newBoard(seed, columns, rows));
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

  function solo() {
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

  /** Pushes a fresh row in at the bottom, when the top of the grid is free. */
  function dealRow() {
    if (!board || !canPlay) return;
    const digits = Array.from({ length: board.columns }, () => 1 + Math.floor(Math.random() * 9));
    const next = addRow(board, digits);
    if (!next) return;
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

  /** So is the pair setting, with two differences: a room waiting for its host
      has not begun, so the choice is still there, and a finished round counts as
      over. The new-row switch is not locked at all — it is an offer that comes
      and goes during play. */
  const modeLocked = board !== null && !finished && !waitingForHost;

  function chooseColumns(next: number) {
    setColumns(next);
    localStorage.setItem(COLUMNS_KEY, String(next));
  }

  function chooseRows(next: number) {
    setRows(next);
    localStorage.setItem(ROWS_KEY, String(next));
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
            onClick={solo}
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
          </SettingsSection>

          <SettingsSection title="Adding rows">
            <SettingsToggle
              label="Offer a new row"
              note="Solo games only: a button on the empty top row pushes a fresh row in at the bottom"
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
  /** Set when the empty top row should carry the new-row button. */
  onAddRow?: () => void;
}) {
  const rowNumbers = Array.from({ length: props.board.rows },
                                 (_, index) => props.board.rows - 1 - index);
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
        <button type="button" className="ten__add-row" onClick={props.onAddRow}>
          <span aria-hidden="true">＋</span> Add a row
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
