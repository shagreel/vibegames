import { useCallback, useEffect, useLayoutEffect, useMemo, useRef, useState } from 'react';
import { artworkPath, spokenDescription, type TrioCard } from './cards';
import { GAMES, trackGameFinish, trackGameStart, trackShare } from '../../analytics';
import { firstTrio, isFinished, replay, takeAt, type TrioTable } from './engine';
import { BOARD_SPACING, CARD_ASPECT, fitBoard, rowsOfIndices } from './layout';
import {
  EMPTY_SNAPSHOT,
  beginRestart,
  claimTrio,
  clearRestartTime,
  createGame,
  joinGame,
  makeGameCode,
  nameOf,
  observeGame,
  randomSeed,
  scoresFrom,
  setHints,
  shortId,
  startGame,
  type TrioSnapshot,
} from './service';
import { displayGameCode, normaliseGameCode } from '../../lib/gameCode';
import { MAX_NAME_LENGTH, isHosting, hostedGame, playerId, playerName, setPlayerName } from '../../identity';
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
import { RoundOver } from '../../hub/RoundOver';
import './VibeTrio.css';

/**
 * Vibe Pairings on the web, solo or as a race on one shared table.
 *
 * A shared game sends a seed and the list of cards already taken, and nothing
 * else: every device replays those into the identical table, so a trio taken by
 * anybody disappears for everybody, in place, without a board being transmitted.
 */

/**
 * How long a departing card's ghost stays on the board, in milliseconds.
 *
 * Slightly longer than the `trio-card-out` animation in `VibeTrio.css`, so the
 * element is removed after it has finished rather than mid-fade. A card leaving
 * and another arriving is the moment a table either sees that its trio has gone
 * or does not, so the pair take a full second on purpose.
 */
const GHOST_MS = 1050;

type Screen = 'lobby' | 'game';

interface Pending {
  ids: number[];
}

function VibeTrio() {
  const id = useMemo(() => playerId(), []);

  const [name, setName] = useState(() => playerName());
  const [askingForName, setAskingForName] = useState(false);
  const pendingAction = useRef<(() => void) | null>(null);

  const [gameId, setGameId] = useState<string | null>(null);
  const [isHost, setIsHost] = useState(false);
  const [joinCode, setJoinCode] = useState('');
  const [joinError, setJoinError] = useState('');
  const [snapshot, setSnapshot] = useState<TrioSnapshot>(EMPTY_SNAPSHOT);

  const [soloSeed, setSoloSeed] = useState<number | null>(null);
  const [soloTakes, setSoloTakes] = useState<number[][]>([]);
  const [pending, setPending] = useState<Pending[]>([]);

  const [selected, setSelected] = useState<number[]>([]);
  const [rejected, setRejected] = useState<number[]>([]);
  const [notice, setNotice] = useState('');
  const [elapsed, setElapsed] = useState(0);
  const [countdown, setCountdown] = useState<number | null>(null);
  const [showRules, setShowRules] = useState(false);
  /** The settings sheet: the player's name, the appearance, and nothing else
      yet — Vibe Pairings has no choices of its own. */
  const [settingsOpen, setSettingsOpen] = useState(false);

  const seed = gameId ? snapshot.seed : soloSeed;

  // The board is derived, never stored. Three sources of takes feed it: the
  // server's accepted ones, this device's optimistic ones still in flight, and —
  // in solo — the local list.
  const takes = useMemo(
    () =>
      gameId
        ? [...snapshot.takes.map((take) => take.cardIds), ...pending.map((p) => p.ids)]
        : soloTakes,
    [gameId, snapshot.takes, pending, soloTakes],
  );

  const takesKey = takes.map((ids) => ids.join(',')).join('|');
  const table = useMemo(
    () => (seed == null ? null : replay(seed, takes)),
    // takesKey stands in for the array, which is a new object every render.
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [seed, takesKey],
  );

  const finished = table ? isFinished(table) : false;
  const myTakes = gameId
    ? (scoresFrom(snapshot).get(shortId(id, gameId)) ?? 0)
    : (table?.triosTaken ?? 0);

  // MARK: - The game id in the URL

  useEffect(() => {
    const typed = new URLSearchParams(window.location.search).get('game');
    if (!typed) return;
    // A code in a link may have been retyped by hand rather than copied.
    const wanted = normaliseGameCode(typed);
    if (!wanted) return;
    setGameId(wanted);
    setIsHost(isHosting(wanted));
  }, []);

  // MARK: - Watching a shared game

  useEffect(() => {
    if (!gameId) return;
    const unsubscribe = observeGame(gameId, id, setSnapshot);
    return unsubscribe;
  }, [gameId, id]);

  // Takes the server has accepted are no longer optimistic.
  useEffect(() => {
    if (!gameId || pending.length === 0) return;
    const confirmed = new Set(snapshot.takes.map((take) => take.cardIds.join(',')));
    const remaining = pending.filter((p) => !confirmed.has(p.ids.join(',')));
    if (remaining.length !== pending.length) setPending(remaining);
  }, [gameId, snapshot.takes, pending]);

  // A fresh round: clear everything that belonged to the last one.
  const previousSeed = useRef<number | null>(null);
  useEffect(() => {
    if (seed == null || previousSeed.current === seed) return;
    previousSeed.current = seed;
    setPending([]);
    setSelected([]);
    setRejected([]);
    setNotice('');
    setElapsed(0);

    // A new seed *is* a new round, for solo and for a shared game alike, and
    // this effect is already guarded against React running it twice in
    // development — which is exactly the guard a counter needs.
    trackGameStart(GAMES.trio, { mode: gameId ? 'shared' : 'solo' });
  }, [seed, gameId]);

  // The deck running out is the only ending Trio has, and it is derived rather
  // than set: the last take may well have been somebody else's, arriving over
  // the wire. So the finish is reported on the transition, once per seed.
  const reportedFinish = useRef<number | null>(null);
  useEffect(() => {
    if (!finished || seed == null || reportedFinish.current === seed) return;
    reportedFinish.current = seed;
    trackGameFinish(GAMES.trio, {
      mode: gameId ? 'shared' : 'solo',
      outcome: 'completed',
      score: myTakes,
      seconds: Math.round(elapsed),
    });
  }, [finished, seed, gameId, myTakes, elapsed]);

  // MARK: - Clocks

  useEffect(() => {
    if (seed == null || finished) return;
    const started = Date.now();
    const timer = window.setInterval(() => setElapsed((Date.now() - started) / 1000), 500);
    return () => window.clearInterval(timer);
  }, [seed, finished]);

  useEffect(() => {
    if (snapshot.restartTime == null) {
      setCountdown(null);
      return;
    }
    const tick = () => {
      const secondsLeft = Math.ceil((snapshot.restartTime! - Date.now()) / 1000);
      if (secondsLeft <= 0) {
        setCountdown(null);
        if (gameId) void clearRestartTime(gameId).catch(() => undefined);
      } else {
        setCountdown(secondsLeft);
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
    setSoloTakes([]);
    setSelected([]);
    setRejected([]);
  };

  const createShared = () =>
    withName(() => {
      const newId = makeGameCode();
      const newSeed = randomSeed();
      hostedGame(newId);
      setIsHost(true);
      setGameId(newId);
      window.history.replaceState({}, '', `/trio?game=${newId}`);
      // The observer will fill in the snapshot; nothing waits on this write.
      void createGame(newId, newSeed, playerName(), id).catch((error) =>
        setNotice(error instanceof Error ? error.message : 'Could not create the game'),
      );
    });

  const join = (code: string) =>
    withName(() => {
      // Heard across a room and typed from memory, so it arrives however it arrives.
      const wanted = normaliseGameCode(code);
      if (!wanted) return;
      setJoinError('');
      void joinGame(wanted, id)
        .then(() => {
          setIsHost(isHosting(wanted));
          setGameId(wanted);
          window.history.replaceState({}, '', `/trio?game=${wanted}`);
        })
        .catch(() => setJoinError('No game with that code'));
    });

  const leave = () => {
    setGameId(null);
    setSnapshot(EMPTY_SNAPSHOT);
    setSoloSeed(null);
    setSoloTakes([]);
    setPending([]);
    setSelected([]);
    setRejected([]);
    setNotice('');
    setJoinError('');
    setJoinCode('');
    window.history.replaceState({}, '', '/trio');
  };

  const judge = useCallback(
    (picked: number[]) => {
      if (!table || seed == null) return;

      const indices = picked
        .map((cardId) => table.visible.findIndex((card) => card.id === cardId))
        .filter((index) => index >= 0);

      if (indices.length !== 3 || !takeAt(table, indices)) {
        setRejected(picked);
        window.setTimeout(() => {
          setRejected([]);
          setSelected([]);
        }, 700);
        return;
      }

      const ids = [...picked].sort((a, b) => a - b);
      setSelected([]);
      setRejected([]);

      if (!gameId) {
        setSoloTakes((current) => [...current, ids]);
        return;
      }

      // Take it here and now — the cards go the instant they are spotted, not a
      // round trip later — then let the server decide who really got them.
      setPending((current) => [...current, { ids }]);
      void claimTrio(gameId, seed, ids, id, playerName()).then((outcome) => {
        if (outcome === 'won') return; // The next snapshot carries it.
        setPending((current) => current.filter((p) => p.ids.join(',') !== ids.join(',')));
        setNotice(
          outcome === 'taken'
            ? 'Someone got there first!'
            : 'Could not reach the game. Check your connection.',
        );
        window.setTimeout(() => setNotice(''), 2500);
      });
    },
    [table, seed, gameId, id],
  );

  const tapCard = (cardId: number) => {
    if (!table || finished || (gameId !== null && !snapshot.started)) return;

    if (selected.includes(cardId)) {
      setSelected((current) => current.filter((each) => each !== cardId));
      setRejected([]);
      return;
    }
    if (selected.length >= 3) return;

    const next = [...selected, cardId];
    setSelected(next);
    if (next.length === 3) judge(next);
  };

  const hint = () => {
    if (!table || gameId) return;
    const trio = firstTrio(table.visible);
    if (!trio) return;
    setRejected([]);
    setSelected([table.visible[trio[0]].id]);
  };

  const playAgain = () => {
    setSelected([]);
    setRejected([]);
    if (!gameId) {
      playSolo();
      return;
    }
    void beginRestart(gameId, randomSeed()).catch(() => undefined);
  };

  // MARK: - Rendering

  const waitingForHost = gameId !== null && snapshot.seed !== null && !snapshot.started;
  const screen: Screen = table && (!gameId || snapshot.seed !== null) ? 'game' : 'lobby';

  if (showRules) {
    return <Rules onClose={() => setShowRules(false)} />;
  }

  return (
    <div className="trio">
      <GameHeader
        prefix="trio"
        title="Vibe Pairings"
        subtitle={
          screen === 'game' && table
            ? subtitle(table, gameId, snapshot, myTakes, elapsed)
            : undefined
        }
      >
        <SupportButton game="trio" />
        <SettingsButton prefix="trio" onClick={() => setSettingsOpen(true)} />
        {screen === 'game' && gameId && (
          <button type="button" className="trio__leave" onClick={leave}>
            Leave
          </button>
        )}
      </GameHeader>

      <GameMessage text={notice || null} tone={notice ? 'warn' : 'info'} />

      {settingsOpen && (
        <GameSettings prefix="trio" onClose={() => setSettingsOpen(false)}>
          {gameId && (
            <SettingsSection
              title="Hints"
              note={
                isHost && !snapshot.started
                  ? 'Everyone plays the same way: a race with hints is a different game, so this is for the whole room.'
                  : 'Only the host can change this, and only before the start.'
              }
            >
              {/* A guest sees the setting, not a control: the answer is the
                  room's, and it is read-only for anybody who did not set it. */}
              {isHost && !snapshot.started ? (
                <SettingsToggle
                  label="Hints in this race"
                  note="On gives every player the Hint button"
                  on={snapshot.hints}
                  onChange={(on) => {
                    if (gameId) void setHints(gameId, on).catch(() => undefined);
                  }}
                />
              ) : (
                <div className="game-sheet__row">
                  <span className="game-sheet__row-text">
                    <strong>Hints in this race</strong>
                    <span>{snapshot.hints ? 'On, for everybody' : 'Off, for everybody'}</span>
                  </span>
                </div>
              )}
            </SettingsSection>
          )}
        </GameSettings>
      )}

      {screen === 'lobby' ? (
        <Lobby
          joinCode={joinCode}
          joinError={joinError}
          onJoinCode={setJoinCode}
          onJoin={join}
          onSolo={playSolo}
          onCreate={createShared}
          onRules={() => setShowRules(true)}
        />
      ) : waitingForHost ? (
        <Waiting
          gameId={gameId!}
          snapshot={snapshot}
          isHost={isHost}
          onStart={() => void startGame(gameId!)}
        />
      ) : (
        table && (
          <Board
            table={table}
            selected={selected}
            rejected={rejected}
            finished={finished}
            faceDown={waitingForHost}
            solo={gameId === null}
            snapshot={snapshot}
            gameId={gameId}
            playerId={id}
            myTakes={myTakes}
            elapsed={elapsed}
            onTap={tapCard}
            onHint={hint}
            onPlayAgain={playAgain}
          />
        )
      )}

      {countdown !== null && (
        <div className="trio__countdown">
          <span>Next deal in</span>
          <strong>{countdown}</strong>
        </div>
      )}

      {askingForName && <NamePrompt onSubmit={submitName} />}
    </div>
  );
}

function subtitle(
  table: TrioTable,
  gameId: string | null,
  snapshot: TrioSnapshot,
  myTakes: number,
  elapsed: number,
): string {
  const parts: string[] = [];
  if (gameId) {
    parts.push(`${snapshot.playerCount} ${snapshot.playerCount === 1 ? 'player' : 'players'}`);
  }
  parts.push(`${myTakes} ${myTakes === 1 ? 'good pairing' : 'good pairings'}`);
  parts.push(formatElapsed(elapsed));
  if (gameId) parts.push(`code ${displayGameCode(gameId)}`);
  void table;
  return parts.join(' · ');
}

function formatElapsed(seconds: number): string {
  const total = Math.floor(seconds);
  return `${Math.floor(total / 60)}:${String(total % 60).padStart(2, '0')}`;
}

// MARK: - Lobby

function Lobby(props: {
  joinCode: string;
  joinError: string;
  onJoinCode: (code: string) => void;
  onJoin: (code: string) => void;
  onSolo: () => void;
  onCreate: () => void;
  onRules: () => void;
}) {
  return (
    <SharedLobby
      prefix="trio"
      blurb="Three cards. Every feature the same on all three, or different on all three."
      joinCode={props.joinCode}
      joinError={props.joinError}
      onJoinCode={props.onJoinCode}
      onJoin={props.onJoin}
      onRules={props.onRules}
    >
      <LobbyCard
        title="Play on this device"
        blurb="Clear the whole deck at your own pace"
        onClick={props.onSolo}
      />
      <LobbyCard
        title="Race your friends"
        blurb="One table of cards. Take a good pairing before anyone else does."
        onClick={props.onCreate}
        alt
      />
    </SharedLobby>
  );
}

// MARK: - Waiting room

function Waiting(props: {
  gameId: string;
  snapshot: TrioSnapshot;
  isHost: boolean;
  onStart: () => void;
}) {
  return (
    <div className="trio__waiting">
      <p className="trio__code">Code {displayGameCode(props.gameId)}</p>
      <p className="trio__waiting-text">
        {props.isHost
          ? 'Start when everyone has joined. Clear the deck together — the first to spot a good pairing takes it.'
          : `Waiting for ${props.snapshot.creator ?? 'the host'} to start…`}
      </p>
      <p className="trio__players">
        {props.snapshot.playerCount} {props.snapshot.playerCount === 1 ? 'player' : 'players'} here
      </p>
      {props.isHost && (
        <button type="button" className="trio__start" onClick={props.onStart}>
          Start game
        </button>
      )}
      <button
        type="button"
        className="trio__link"
        onClick={() => {
          trackShare(GAMES.trio, 'game');
          const url = `${window.location.origin}/trio?game=${props.gameId}`;
          void navigator.clipboard.writeText(url);
        }}
      >
        Copy the link
      </button>
    </div>
  );
}

// MARK: - Board

function Board(props: {
  table: TrioTable;
  selected: number[];
  rejected: number[];
  finished: boolean;
  faceDown: boolean;
  solo: boolean;
  snapshot: TrioSnapshot;
  gameId: string | null;
  playerId: string;
  myTakes: number;
  elapsed: number;
  onTap: (cardId: number) => void;
  onHint: () => void;
  onPlayAgain: () => void;
}) {
  const ref = useRef<HTMLDivElement>(null);
  const [size, setSize] = useState({ width: 0, height: 0 });

  useLayoutEffect(() => {
    const element = ref.current;
    if (!element) return;
    const measure = () => {
      const rect = element.getBoundingClientRect();
      setSize({ width: rect.width, height: rect.height });
    };
    measure();
    const observer = new ResizeObserver(measure);
    observer.observe(element);
    return () => observer.disconnect();
  }, [props.finished]);

  /**
   * Cards that have just left the table.
   *
   * A take replaces cards where they stand — the board never reshuffles, by
   * design — so without this the three cards simply became three different
   * pictures between one frame and the next, and in a race that is the whole
   * point of the game going past unnoticed.
   */
  const visible = props.table.visible;
  const previousVisible = useRef<readonly TrioCard[] | null>(null);
  const [leaving, setLeaving] = useState<{ key: string; index: number; card: TrioCard }[]>([]);
  const ghostId = useRef(0);
  const ghostTimers = useRef<number[]>([]);

  useEffect(() => {
    const before = previousVisible.current;
    previousVisible.current = visible;
    // The opening deal has nothing leaving it.
    if (!before) return;

    const departed: { key: string; index: number; card: TrioCard }[] = [];
    before.forEach((card, index) => {
      const now = visible[index];
      if (!now || now.id !== card.id) {
        ghostId.current += 1;
        departed.push({ key: `ghost-${ghostId.current}`, index, card });
      }
    });
    if (departed.length === 0) return;

    // The extra render is the feature: React cannot animate an element it has
    // already forgotten, so the cards that just left are held for one animation
    // and then dropped. This is the "synchronise with an external system" case
    // the rule is not aimed at, and the alternative — cloning nodes into the
    // DOM by hand — would be worse.
    // eslint-disable-next-line react-hooks/set-state-in-effect
    setLeaving((current) => [...current, ...departed]);
    // Each ghost keeps its own timer rather than one shared one, so a second
    // take arriving mid-animation cannot cancel the first lot's removal and
    // strand them on the board.
    ghostTimers.current.push(
      window.setTimeout(() => {
        setLeaving((current) => current.filter((ghost) => !departed.includes(ghost)));
      }, GHOST_MS),
    );
  }, [visible]);

  useEffect(() => () => ghostTimers.current.forEach(window.clearTimeout), []);

  if (props.finished) {
    return <Leaderboard {...props} />;
  }

  const layout = fitBoard(visible.length, size.width, size.height, BOARD_SPACING);
  const cardHeight = layout.cardWidth / CARD_ASPECT;

  return (
    <div className="trio__board-area">
      <div className="trio__board" ref={ref} data-cards={visible.length}>
        {rowsOfIndices(visible.length, layout.columns).map((row, rowIndex) => (
          <div className="trio__row" key={rowIndex} style={{ gap: BOARD_SPACING }}>
            {row.map((index) => {
              const card = visible[index];
              const state = props.rejected.includes(card.id)
                ? 'rejected'
                : props.selected.includes(card.id)
                  ? 'selected'
                  : 'idle';
              return (
                /* The slot is keyed by the card, so a card that merely moves
                   keeps its element and does not replay the arrival animation —
                   only a genuinely new card does. */
                <div
                  className="trio__slot"
                  key={card.id}
                  style={{ width: layout.cardWidth, height: cardHeight }}
                >
                  <button
                    type="button"
                    className="trio-card"
                    data-state={state}
                    style={{ '--slot': index } as React.CSSProperties}
                    onClick={() => props.onTap(card.id)}
                    disabled={props.faceDown}
                    aria-label={spokenDescription(card)}
                    aria-pressed={state === 'selected'}
                  >
                    {props.faceDown ? (
                      <span className="trio-card__back" aria-hidden="true" />
                    ) : (
                      <img src={artworkPath(card)} alt="" draggable={false} />
                    )}
                  </button>

                  {/* The card that was here a moment ago, on its way out. */}
                  {leaving
                    .filter((ghost) => ghost.index === index)
                    .map((ghost) => (
                      <span className="trio__ghost" key={ghost.key} aria-hidden="true">
                        <img src={artworkPath(ghost.card)} alt="" draggable={false} />
                      </span>
                    ))}
                </div>
              );
            })}
          </div>
        ))}
      </div>

      <div className="trio__bottom">
        {props.solo || props.snapshot.hints ? (
          <button type="button" className="trio__hint" onClick={props.onHint}>
            Hint
          </button>
        ) : (
          <span className="trio__hint trio__hint--off">Race — no hints</span>
        )}
        <span className="trio__deck">{props.table.remaining.length} left in the deck</span>
      </div>
    </div>
  );
}

// MARK: - Leaderboard

function Leaderboard(props: {
  snapshot: TrioSnapshot;
  gameId: string | null;
  playerId: string;
  myTakes: number;
  elapsed: number;
  onPlayAgain: () => void;
}) {
  const rows = props.gameId
    ? [...scoresFrom(props.snapshot).entries()]
        .map(([by, score]) => ({ by, score, name: nameOf(props.snapshot, by) ?? 'Player' }))
        .sort((a, b) => (a.score !== b.score ? b.score - a.score : a.name.localeCompare(b.name)))
    : props.myTakes > 0
      ? [{ by: 'solo', score: props.myTakes, name: 'You' }]
      : [];

  const mine = props.gameId ? shortId(props.playerId, props.gameId) : 'solo';
  const best = rows[0]?.score ?? 0;
  const leaders = rows.filter((row) => row.score === best);

  const title = !props.gameId
    ? 'Deck cleared'
    : leaders.length === 0
      ? 'Nobody scored'
      : leaders.length === 1
        ? leaders[0].by === mine
          ? 'You win!'
          : `${leaders[0].name} wins`
        : `Tie at ${best}`;

  return (
    <RoundOver
      title={title}
      detail={
        props.gameId
          ? `${formatElapsed(props.elapsed)} · ${props.snapshot.playerCount} ${props.snapshot.playerCount === 1 ? 'player' : 'players'}`
          : `${props.myTakes} ${props.myTakes === 1 ? 'good pairing' : 'good pairings'} in ${formatElapsed(props.elapsed)}`
      }
      onPrimary={props.onPlayAgain}
    >
      {rows.length > 0 && (
        <ol className="trio__standings">
          {rows.map((row, index) => (
            <li key={row.by} className={row.by === mine ? 'is-me' : undefined}>
              <span className="trio__rank">{index + 1}</span>
              <span className="trio__standing-name">{row.name}</span>
              {row.score === best && best > 0 && <span aria-hidden="true">🏆</span>}
              <span className="trio__score">{row.score}</span>
            </li>
          ))}
        </ol>
      )}
    </RoundOver>
  );
}

// MARK: - Instructions

/** The instructions, in this game's own words. */
const TRIO_INSTRUCTIONS: HowToPlayContent = {
  name: 'Vibe Pairings',
  intro: 'Twelve charcuterie boards are dealt face up. Your job is to find three of them that make a good pairing.',
  sections: [
    {
      title: "What's on a board",
      body: 'Every board has four features, and each one comes three ways. **Platter**: round walnut, bamboo hexagon, slate rectangle. **Cheese**: swiss wedge, gouda cubes, brie round. **Meat**: prosciutto ribbon, salami stack, turkey roll-up. **Garnish**: purple grapes, red strawberry, pear slices.',
    },
    {
      title: 'The rule',
      body: 'Three cards make a good pairing when every one of those four features is **either the same on all three or different on all three**. Two matching and a third odd is not a good pairing — that is exactly the mistake the game is built to punish.',
    },
  ],
  bullets: [
    { lead: 'Solo', text: 'Clear the whole deck at your own pace. Stuck? **Hint** picks out one card of a good pairing — the other two are still yours to find.' },
    { lead: 'Race', text: 'Everyone shares one table, so a good pairing taken by anybody is gone for everybody. The winner is whoever has taken the most when the deck runs out. The host decides whether the table has hints.' },
    { lead: 'Wrong three', text: 'They flash red and nothing moves. Look again — the cards stay put.' },
  ],
};

function Rules({ onClose }: { onClose: () => void }) {
  // The same page component as every other game. Trio's rules used to be the
  // only ones written out by hand, which is how the five of them drifted apart.
  return <HowToPlay content={TRIO_INSTRUCTIONS} onClose={onClose} />;
}

// MARK: - Name prompt

function NamePrompt({ onSubmit }: { onSubmit: (name: string | null) => void }) {
  const [draft, setDraft] = useState('');
  const trimmed = draft.trim();

  return (
    <div className="trio__overlay">
      <form
        className="trio__name-card"
        onSubmit={(event) => {
          event.preventDefault();
          if (trimmed) onSubmit(trimmed);
        }}
      >
        <h2>What should we call you?</h2>
        <p>So everyone knows who spotted it first.</p>
        <input
          value={draft}
          onChange={(event) => setDraft(event.target.value)}
          placeholder="Your name"
          maxLength={MAX_NAME_LENGTH}
          autoFocus
          autoComplete="off"
        />
        <button type="submit" className="trio__start" disabled={!trimmed}>
          Save
        </button>
        <button type="button" className="trio__link" onClick={() => onSubmit(null)}>
          Not now
        </button>
      </form>
    </div>
  );
}

export default VibeTrio;
