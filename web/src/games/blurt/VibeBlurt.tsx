import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import BackToGames from '../../hub/BackToGames';
import { SupportButton } from '../../hub/Support';
import { hostedGame, isHosting, playerId, playerName, setPlayerName } from '../../identity';
import { GAMES, trackGameFinish, trackGameStart } from '../../analytics';
import { shortId } from '../../lib/shortId';
import { displayGameCode, makeGameCode, normaliseGameCode } from '../../lib/gameCode';
import {
  LONGEST_SECONDS,
  MINIMUM_PLAYERS,
  SHORTEST_SECONDS,
  TARGET,
  TEAMS,
  barFill,
  holderFor,
  namesOn,
  randomTurnSeconds,
  shuffled,
  teamTitle,
  urgency as urgencyAt,
  wordAt,
  type Team,
} from './engine';
import {
  EMPTY_SNAPSHOT,
  assignTeam,
  beginTurn,
  createGame,
  endTurn,
  joinGame,
  observeGame,
  passWord,
  playAgain,
  playScore,
  startGame,
  updateSettings,
  winningTeam,
  type BlurtSnapshot,
} from './service';
import { PACKS, PACK_ORDER, PACK_WORDS } from './words.generated';
import HowToPlay, { HowToPlayLink, type HowToPlayContent } from '../../hub/HowToPlay';
import './VibeBlurt.css';

/**
 * Similar Vibe on the web.
 *
 * Everyone is on their own phone in one room. Two teams; one person at a time is
 * handed a word and has to get their team to say it without saying it themselves.
 * Nobody scores for guessing — the point goes to whichever team is *not* holding
 * the word when the clock stops, which is what makes it a race to get rid of it.
 *
 * The word never reaches the other screens. It is not hidden in the payload: the
 * room stores a seed and how far into the deck the game has got, every device
 * derives the same deck from those, and only the describer's screen renders the
 * current entry.
 */

const PACKS_KEY = 'blurt.packs';

function loadPacks(): string[] {
  try {
    const stored = JSON.parse(localStorage.getItem(PACKS_KEY) ?? 'null');
    if (Array.isArray(stored)) {
      const valid = stored.filter((id: unknown): id is string =>
        typeof id === 'string' && PACK_ORDER.includes(id),
      );
      if (valid.length > 0) return valid;
    }
  } catch {
    // A corrupt value is not worth crashing a game over.
  }
  return [...PACK_ORDER];
}

/** The instructions, in this game's own words and with its own live counts. */
const BLURT_INSTRUCTIONS: HowToPlayContent = {
  name: 'Similar Vibe',
  intro:
    'Two teams, a phone each, and a word nobody wants to be holding. Describe it without saying it, and get rid of it before the clock stops.',
  sections: [
    {
      title: 'The word is a hot potato',
      body: 'One person is shown a word and describes it; their team-mates guess. Get it right and the word passes to somebody on the **other** team. The clock does not stop or reset — it belongs to the round, not to the word.',
    },
    {
      title: 'Nobody can count the clock down',
      body: `A round lasts a random ${SHORTEST_SECONDS} to ${LONGEST_SECONDS} seconds and there is no number on screen. The ticking stays steady and then hurries and grows louder as the end approaches.`,
    },
    {
      title: 'The other team is watching',
      body: 'The team **not** holding the word can see it, and has one big red BUZZ button. If the describer says the word, or any part of it, they press it — and they take the point instead.',
    },
  ],
  bullets: [
    {
      lead: `${MINIMUM_PLAYERS} people`,
      text: 'Two on each side at least. The app splits the room into teams at random.',
    },
    {
      lead: 'Scoring',
      text: 'Nobody scores for guessing. The point goes to the team that was not holding the word when the clock stopped — or to the team that caught a blurt.',
    },
    { lead: `First to ${TARGET}`, text: 'Wins the game.' },
    {
      lead: 'Words',
      text: `${PACK_ORDER.reduce((total, id) => total + PACK_WORDS[id].length, 0)} to describe across ${PACK_ORDER.length} packs, chosen before the game starts.`,
    },
  ],
};

function VibeBlurt() {
  const id = useMemo(() => playerId(), []);

  const [name, setName] = useState(() => playerName());
  const [askingForName, setAskingForName] = useState(false);
  // The name is passed *into* the action rather than read from state by the
  // closure: an action parked here was created on a render where `name` was
  // still empty, so reading it back after the prompt would send a blank name
  // and the rules would refuse the write.
  const pendingAction = useRef<((who: string) => void) | null>(null);

  // Read from the URL once, at first render, rather than in an effect: arriving
  // on a shared link should not paint the lobby for a frame before the game.
  const [gameId, setGameId] = useState<string | null>(() => arrivedAt());
  const [isHost, setIsHost] = useState(() => {
    const wanted = arrivedAt();
    return wanted ? isHosting(wanted) : false;
  });
  const [joinCode, setJoinCode] = useState('');
  const [joinError, setJoinError] = useState('');
  const [snapshot, setSnapshot] = useState<BlurtSnapshot>(EMPTY_SNAPSHOT);

  const [now, setNow] = useState(() => Date.now());
  const [showSettings, setShowSettings] = useState(false);
  const [showCode, setShowCode] = useState(false);
  const [rulesOpen, setRulesOpen] = useState(false);
  const [packs, setPacks] = useState<string[]>(loadPacks);

  const myShortId = gameId ? shortId(id, gameId) : null;
  const play = snapshot.play;
  const myTeam: Team | null = myShortId ? (snapshot.teams[myShortId] ?? null) : null;
  const winner = winningTeam(play);
  /**
   * Who is actually holding the word.
   *
   * The round writes down a describer when it starts, and a phone that leaves
   * afterwards does not rewrite it — so the round can be pointing at somebody who
   * is not in the room. Their own team-mates would be told that person is
   * describing to them, and the other team told to watch for them: a round nobody
   * can play, with nothing to end it early but the clock.
   *
   * `holderFor` resolves it on every snapshot instead — the named describer while
   * they are here, and the rotation's choice among the people still here once they
   * have gone, which is the same rule that walks the turn on at the end of a
   * round. The app resolves it to the same person.
   */
  const holder =
    play !== null && snapshot.seed !== null
      ? holderFor(play, { players: snapshot.players, teams: snapshot.teams }, snapshot.seed)
      : (play?.describer ?? null);
  const isDescriber = holder !== null && myShortId !== null && holder === myShortId;
  /**
   * What to call them in a sentence. Empty only when the whole of the describing
   * side has gone, so nothing gets named that is not in the room.
   */
  const holderName = holder !== null ? (snapshot.players[holder] ?? '') : '';
  /** The person this round was dealt to has left the room. */
  const describerHasLeft =
    play !== null && !play.finished && play.describer !== '' && snapshot.players[play.describer] === undefined;
  /**
   * Whether this phone can start the round that is waiting. Normally the
   * describer's own; when they have gone it is the next person on their team,
   * because nothing is running yet and no clock will ever end a round that
   * nobody can start.
   */
  const canStartRound =
    play !== null &&
    !play.finished &&
    play.state !== 'running' &&
    myShortId !== null &&
    (play.describer === myShortId ||
      (describerHasLeft && myTeam !== null && myTeam === play.team));
  /** The team that is not holding the word: they see it, and they get BUZZ. */
  const onBuzzTeam = play !== null && myTeam !== null && myTeam !== play.team;

  // MARK: - Joining

  useEffect(() => {
    if (!gameId) return;
    return observeGame(gameId, id, name, setSnapshot);
    // `name` is a dependency because the presence listener carries it: somebody
    // who types their name at the prompt lands here afterwards, and the observer
    // has to be rebuilt with it or every reconnect re-announces an empty name,
    // which the rules refuse without saying so.
  }, [gameId, id, name]);

  const requireName = useCallback(
    (action: (who: string) => void) => {
      if (!name) {
        pendingAction.current = action;
        setAskingForName(true);
        return;
      }
      action(name);
    },
    [name],
  );

  const submitName = (chosen: string | null) => {
    setAskingForName(false);
    const who = chosen ?? name;
    if (chosen) {
      setPlayerName(chosen);
      setName(chosen);
    }
    const action = pendingAction.current;
    pendingAction.current = null;
    action?.(who);
  };

  // Somebody who followed a link has a code but is not in the room yet, and may
  // not have a name either. Registering them is what puts them on the roster —
  // without it they would watch a game they could not join.
  const arrivalHandled = useRef(false);
  useEffect(() => {
    if (arrivalHandled.current || !gameId) return;
    arrivalHandled.current = true;
    const register = (who: string) => {
      void joinGame(gameId, id, who).catch(() =>
        setJoinError('That game could not be joined. Check the code.'),
      );
    };
    if (name) register(name);
    // Opening the name prompt is a state change from an effect, which the rule
    // rightly mistrusts in general. It is the point here: the effect exists to
    // react to arriving with a code, and the only thing it can do about a player
    // who has no name is ask for one.
    // eslint-disable-next-line react-hooks/set-state-in-effect
    else requireName(register);
  }, [gameId, name, id, requireName]);

  // Somebody who arrived after the start — or whose phone slept through it —
  // needs a team before they can play. Asked once, not on every snapshot.
  const askedForTeam = useRef(false);
  useEffect(() => {
    if (!gameId || !snapshot.started || !myShortId) return;
    if (snapshot.teams[myShortId] || askedForTeam.current) return;
    askedForTeam.current = true;
    void assignTeam(gameId, id);
  }, [gameId, snapshot.started, snapshot.teams, myShortId, id]);

  // MARK: - The clock

  const endingTurn = useRef(-1);
  useEffect(() => {
    if (play?.state !== 'running') return;
    const timer = window.setInterval(() => setNow(Date.now()), 250);
    return () => window.clearInterval(timer);
  }, [play?.state]);

  useEffect(() => {
    if (!gameId || play?.state !== 'running' || play.endsAt === null) return;
    if (now < play.endsAt || endingTurn.current === play.turn) return;
    // Any phone can call time, and the transaction decides which of them
    // counted — so the turn still ends if the describer's app has gone to sleep.
    endingTurn.current = play.turn;
    void endTurn(gameId, 'time');
  }, [gameId, play?.state, play?.endsAt, play?.turn, now]);

  // MARK: - Being caught

  // The phone of whoever is holding the word buzzes when the other team catches
  // them: they are mid-sentence and not looking at their screen. Tracked from
  // the *last running* snapshot rather than the ended one, because the service
  // moves the rotation on behind the result — the ended snapshot already names
  // the next person, so asking it who was holding the word gives the wrong
  // answer.
  const wasHolding = useRef(false);
  useEffect(() => {
    if (!play) return;
    if (play.state === 'running') {
      // The *resolved* holder rather than the name written on the round: the word
      // can have moved to somebody else when the named describer left, and that
      // person is the one who needs the buzz.
      wasHolding.current = holder === myShortId;
      return;
    }
    if (play.state === 'ended' && play.reason === 'blurt' && wasHolding.current) {
      wasHolding.current = false;
      navigator.vibrate?.([0, 90, 60, 140]);
    }
  }, [play, myShortId, holder]);

  // MARK: - Analytics

  const reportedTurn = useRef<number | null>(null);
  useEffect(() => {
    if (!play) return;
    if (play.state === 'running' && reportedTurn.current !== play.turn) {
      reportedTurn.current = play.turn;
      trackGameStart(GAMES.blurt, { mode: 'shared', round: play.turn + 1 });
    }
  }, [play]);

  useEffect(() => {
    if (!winner || !play) return;
    trackGameFinish(GAMES.blurt, {
      mode: 'shared',
      outcome: 'completed',
      score: playScore(play, winner),
    });
  }, [winner, play]);

  // MARK: - Playing

  const create = () =>
    requireName((who) => {
      const newId = makeGameCode();
      const seed = randomSeed();
      void createGame(newId, seed, who, id, packs)
        .then(() => {
          hostedGame(newId);
          window.history.replaceState({}, '', `/blurt?game=${newId}`);
          setGameId(newId);
          setIsHost(true);
        })
        .catch(() => setJoinError('Could not start a game. Check your connection.'));
    });

  const join = () => {
    const code = normaliseGameCode(joinCode);
    if (!code) return;
    requireName((who) => {
      void joinGame(code, id, who)
        .then(() => {
          window.history.replaceState({}, '', `/blurt?game=${code}`);
          setGameId(code);
          setIsHost(isHosting(code));
        })
        .catch(() => setJoinError('That code did not work. Check it and try again.'));
    });
  };

  const leave = () => {
    window.history.replaceState({}, '', '/blurt');
    setGameId(null);
    setSnapshot(EMPTY_SNAPSHOT);
    setJoinError('');
    askedForTeam.current = false;
    endingTurn.current = -1;
    reportedTurn.current = null;
  };

  const changeSettings = (nextPacks: string[]) => {
    setPacks(nextPacks);
    localStorage.setItem(PACKS_KEY, JSON.stringify(nextPacks));
    if (gameId && isHost && !snapshot.started) void updateSettings(gameId, nextPacks);
  };

  const playerCount = Object.keys(snapshot.players).length;
  const startHint =
    playerCount >= MINIMUM_PLAYERS
      ? 'Teams are picked at random, so nobody can argue.'
      : `You need ${MINIMUM_PLAYERS} people — two on each team. ${
          MINIMUM_PLAYERS - playerCount
        } more to go.`;
  const allPacksOn = snapshot.packs.length === PACK_ORDER.length;

  // Derived, never stored.
  // One deck per room, walked across however many games the table plays.
  const deck = useMemo(
    () => (snapshot.seed === null ? [] : shuffled(snapshot.seed, snapshot.packs)),
    [snapshot.seed, snapshot.packs],
  );
  const currentWord = play ? wordAt(play.word, deck) : '';

  // There is deliberately no seconds-left: a round is a random 50-70 seconds so
  // that nobody can count it down. These two are what the bar is drawn from.
  const running = play?.state === 'running' && play.endsAt !== null && play.startedAt !== null;
  const total = running ? (play.endsAt as number) - (play.startedAt as number) : 0;
  const remaining = running ? (play.endsAt as number) - now : 0;
  const fill = running ? barFill(remaining, total) : 0;
  const urgent = running && urgencyAt(remaining, total) > 0;

  // MARK: - Screens

  if (rulesOpen) return <HowToPlay content={BLURT_INSTRUCTIONS} onClose={() => setRulesOpen(false)} />;

  if (!gameId) {
    return (
      <div className="blurt">
        <BlurtHeader onLeave={null} gameId={null} />
        <div className="blurt__lobby">
          <button type="button" className="blurt__primary" onClick={create}>
            Start a game
          </button>

          <div className="blurt__join">
            <label htmlFor="blurt-code">Join with a code</label>
            <div className="blurt__join-row">
              <input
                id="blurt-code"
                value={joinCode}
                onChange={(event) => setJoinCode(event.target.value)}
                placeholder="cars feed"
                maxLength={12}
                autoComplete="off"
                autoCapitalize="none"
              />
              <button type="button" onClick={join} disabled={!joinCode.trim()}>
                Join
              </button>
            </div>
            {joinError && <p className="blurt__error">{joinError}</p>}
          </div>

          <HowToPlayLink onClick={() => setRulesOpen(true)} />
        </div>
        {askingForName && <NamePrompt onSubmit={submitName} />}
      </div>
    );
  }

  if (!snapshot.started || !play) {
    return (
      <div className="blurt">
        <BlurtHeader onLeave={leave} gameId={gameId} />
        <div className="blurt__lobby">
          <div className="blurt__code">
            <span className="blurt__code-label">Read this out</span>
            <strong className="blurt__code-value">{displayGameCode(gameId)}</strong>
            <span className="blurt__code-hint">
              Everyone else: Similar Vibe → Join with a code
            </span>
          </div>

          <section className="blurt__panel">
            <h2>In the room ({Object.keys(snapshot.players).length})</h2>
            <ul className="blurt__roster">
              {Object.entries(snapshot.players)
                .sort((a, b) => a[1].localeCompare(b[1]))
                .map(([playerId_, playerName_]) => (
                  <li key={playerId_}>
                    <span className={playerId_ === myShortId ? 'is-me' : ''}>{playerName_}</span>
                    {playerId_ === myShortId && <em>you</em>}
                  </li>
                ))}
            </ul>
          </section>

          <button
            type="button"
            className="blurt__settings"
            onClick={() => isHost && setShowSettings(true)}
            disabled={!isHost}
          >
            <span>Settings</span>
            <span className="blurt__settings-value">
              {allPacksOn ? `all ${PACK_ORDER.length} packs` : `${snapshot.packs.length} of ${PACK_ORDER.length} packs`}
            </span>
          </button>

          {isHost ? (
            <>
              <button
                type="button"
                className="blurt__primary"
                onClick={() => void startGame(gameId, snapshot.seed ?? randomSeed())}
                disabled={Object.keys(snapshot.players).length < MINIMUM_PLAYERS}
              >
                Start
              </button>
              <p className="blurt__hint">{startHint}</p>
            </>
          ) : (
            <p className="blurt__hint">Waiting for {snapshot.creator ?? 'the host'} to start.</p>
          )}
        </div>

        {showSettings && (
          <SettingsSheet
            packs={snapshot.packs}
            editable={isHost && !snapshot.started}
            onChange={changeSettings}
            onClose={() => setShowSettings(false)}
          />
        )}
        {askingForName && <NamePrompt onSubmit={submitName} />}
      </div>
    );
  }

  return (
    <div className="blurt">
      <BlurtHeader onLeave={leave} gameId={gameId} onShowCode={() => setShowCode(true)} />

      {/* The names matter as much as the scores: with four people passing one
          word around, the first thing anybody asks is which side they are on. */}
      <div className="blurt__scores">
        {TEAMS.map((team) => {
          const names = namesOn(snapshot, team);
          return (
            <div
              key={team}
              className={`blurt__score blurt__score--${team}${myTeam === team ? ' is-mine' : ''}`}
            >
              <span>{teamTitle(team)}</span>
              <strong>{playScore(play, team)}</strong>
              {/* Nothing at all once a side has emptied out, rather than an empty
                  line where the names used to be. */}
              {names.length > 0 && <em className="blurt__score-names">{names.join(', ')}</em>}
              {myTeam === team && <em className="blurt__score-mine">Your team</em>}
            </div>
          );
        })}
      </div>

      {play.state === 'ended' && (
        <p className={`blurt__result blurt__result--${play.scorer ?? 1}`}>
          {play.scorer ? teamTitle(play.scorer) : 'Nobody'} takes the point —{' '}
          {play.reason === 'blurt' ? 'caught a blurt' : 'the clock ran out'}
        </p>
      )}

      {running && (
        // No number, by design: a random 50-70 second round cannot be counted
        // down, and the bar is spent before the round is, so its end is not the
        // buzzer either. What says "nearly" is the colour and the pulse.
        <div className="blurt__clock" data-ends-at={play.endsAt} data-started-at={play.startedAt}>
          <div className="blurt__bar">
            <div
              className={`blurt__bar-fill blurt__bar-fill--${play.team}${urgent ? ' is-urgent' : ''}`}
              style={{ width: `${fill * 100}%` }}
            />
          </div>
        </div>
      )}

      {winner !== null ? (
        <div className="blurt__finished">
          <h2>{teamTitle(winner)} wins</h2>
          <p>
            {play.one} – {play.two}
          </p>
          <button
            type="button"
            className="blurt__primary"
            onClick={() => void playAgain(gameId)}
          >
            Play again
          </button>
        </div>
      ) : play.state === 'running' ? (
        isDescriber ? (
          <div className="blurt__describer">
            <span className="blurt__word-label">Your word — don&rsquo;t say it</span>
            <strong className="blurt__word">{currentWord}</strong>
            <button type="button" className="blurt__primary" onClick={() => void passWord(gameId)}>
              Got it — pass it on
            </button>
            <p className="blurt__hint">The word goes to the other team. The clock keeps running.</p>
          </div>
        ) : onBuzzTeam ? (
          /* The other team is shown the word, which is the whole reason the
             BUZZ is worth having: catching somebody saying it is a judgement
             they can actually make, not a guess from one word of a sentence. */
          <div className="blurt__buzz-team">
            <span className="blurt__word-label">Watch for it</span>
            <strong className="blurt__watched-word">{currentWord}</strong>
            {/* The rule, said as a rule and with the name in it: the button is
                only for one thing, and it is easy to press out of excitement.
                The name is the resolved holder, so it is always somebody in the
                room; it is empty in exactly one case, where the whole of the
                describing side has gone and there is nobody to name. */}
            <p className="blurt__buzz-rule">
              {holderName
                ? `Watch close — if ${holderName} says the word above, buzz them!`
                : 'Watch close — if they say the word above, buzz them!'}
            </p>
            <button type="button" className="blurt__buzz" onClick={() => void endTurn(gameId, 'blurt')}>
              <strong>BUZZ</strong>
            </button>
            <p className="blurt__hint">Saying any part of it counts too.</p>
          </div>
        ) : (
          /* The holding team's other members: guessing, and the one screen in
             the room the word must never reach. */
          <div className="blurt__guessing">
            <span className="blurt__word-label">Guess it</span>
            {/* Only ever shown to the holding team, which has somebody in it, so
                the holder always has a name here. */}
            <h2>{holderName || 'Your team-mate'} is describing a word to you</h2>
            {/* The headline says what is happening; this says what to do about
                it, in the team's own colour so it reads as your job. */}
            <strong className={`blurt__guessing-call blurt__my-team--${myTeam ?? 1}`}>
              Shout it out!
            </strong>
            <p>
              Get it right and the word passes to the other team — the clock keeps running.
            </p>
          </div>
        )
      ) : (
        <div className="blurt__handover">
          <span className={`blurt__team-tag blurt__team-tag--${play.team}`}>
            {teamTitle(play.team)}
          </span>
          {/* No "left" branch: the name is the resolved holder, so it is always
              somebody in the room. The line below says what to do about a
              describer who walked out. */}
          <h2>
            {isDescriber ? "You're up" : holderName ? `${holderName} is up` : 'Nobody is left to describe'}
          </h2>
          {/* Which side *you* are on, said outright. The scoreboard shows it,
              but this is the screen everyone looks at between rounds. */}
          {myTeam !== null && (
            <p className={`blurt__my-team blurt__my-team--${myTeam}`}>
              You&rsquo;re on {teamTitle(myTeam)} — {myTeam === play.team ? 'guessing' : 'watching'}
            </p>
          )}
          <p>
            {isDescriber
              ? 'Hold the phone so only you can see it, then start the clock.'
              : canStartRound
                ? 'They have left the room, and nothing is running yet. Anyone on their team can take the round.'
                : holderName
                  ? `Pass the phone to ${holderName}. Everyone else, watch for the word.`
                  : 'Nobody on that side is in the room, so there is no round to take.'}
          </p>
          {canStartRound && (
            <button
              type="button"
              className="blurt__primary"
              onClick={() => void beginTurn(gameId, randomTurnSeconds(), myShortId ?? '')}
            >
              Start the clock
            </button>
          )}
        </div>
      )}

      {showCode && <CodeSheet gameId={gameId} onClose={() => setShowCode(false)} />}
      {askingForName && <NamePrompt onSubmit={submitName} />}
    </div>
  );
}

// MARK: - Pieces

function BlurtHeader({
  onLeave,
  gameId,
  onShowCode,
}: {
  onLeave: (() => void) | null;
  gameId: string | null;
  onShowCode?: (() => void) | null;
}) {
  return (
    <header className="blurt__header">
      {onLeave ? (
        <button type="button" className="blurt__back" onClick={onLeave} aria-label="Leave game">
          ‹
        </button>
      ) : (
        <BackToGames />
      )}
      <div className="blurt__titles">
        <strong>Similar Vibe</strong>
        <span>{gameId ? `First to ${TARGET}` : "Describe it. Don't say it."}</span>
      </div>
      {/* The code, once the game is under way. It used to be out of reach from
          the board entirely: the big card only lives in the lobby and the join
          field only exists before a game starts. A late arrival is normal here
          — they get put on the smaller team and play carries on — so the code
          has to be readable from the scoreboard. */}
      {onShowCode && (
        <button
          type="button"
          className="blurt__code-button"
          onClick={onShowCode}
          aria-label="Game code"
        >
          <svg viewBox="0 0 24 24" aria-hidden="true">
            <path d="M4 7h8M18 7h2M4 17h2M12 17h8" />
            <circle cx="15" cy="7" r="2.2" />
            <circle cx="9" cy="17" r="2.2" />
          </svg>
        </button>
      )}
      <SupportButton game="blurt" />
    </header>
  );
}

function SettingsSheet({
  packs,
  editable,
  onChange,
  onClose,
}: {
  packs: string[];
  editable: boolean;
  onChange: (packs: string[]) => void;
  onClose: () => void;
}) {
  const chosen = new Set(packs);
  const wordCount = PACK_ORDER.filter((id) => chosen.has(id)).reduce(
    (total, id) => total + PACK_WORDS[id].length,
    0,
  );

  return (
    <div className="blurt__overlay" role="dialog" aria-label="Game settings">
      <div className="blurt__sheet">
        <h2>Game settings</h2>

        <h3>Turn length</h3>
        <p className="blurt__hint">
          Somewhere between {SHORTEST_SECONDS} and {LONGEST_SECONDS} seconds, and not the same
          twice. Nobody knows which, so nobody can count it down — the bar changes colour and
          starts pulsing when it is nearly over.
        </p>

        <h3>Words</h3>
        {PACK_ORDER.map((packId) => (
          <button
            key={packId}
            type="button"
            className={`blurt__option${chosen.has(packId) ? ' is-on' : ''}`}
            onClick={() => {
              if (!editable) return;
              const next = new Set(chosen);
              if (next.has(packId)) {
                // Leaving nothing ticked would deal an empty deck.
                if (next.size <= 1) return;
                next.delete(packId);
              } else {
                next.add(packId);
              }
              onChange([...next]);
            }}
            disabled={!editable}
          >
            <strong>{PACKS[packId].title}</strong>
            <span>{PACKS[packId].blurb}</span>
            <em>{chosen.has(packId) ? '✓' : ''}</em>
          </button>
        ))}
        <p className="blurt__hint">{wordCount} words in the deck</p>

        <p className="blurt__hint">
          {editable
            ? 'Everyone in the room gets these, so you will all be describing the same things.'
            : 'Only the host can change these, and only before the game starts.'}
        </p>

        <button type="button" className="blurt__primary" onClick={onClose}>
          Done
        </button>
      </div>
    </div>
  );
}

/** The code on its own, for a game already in progress. */
function CodeSheet({ gameId, onClose }: { gameId: string; onClose: () => void }) {
  const [copied, setCopied] = useState(false);
  const inviteUrl = `${window.location.origin}${window.location.pathname}?game=${gameId}`;

  return (
    <div className="blurt__overlay" role="dialog" aria-label="Game code">
      <div className="blurt__sheet">
        <h2>Game code</h2>
        <p className="blurt__code-value">{displayGameCode(gameId)}</p>
        <p className="blurt__hint">
          Read it out. Anyone who joins now goes on the smaller team, and the game carries on.
        </p>
        <button
          type="button"
          className="blurt__primary"
          onClick={() => {
            void navigator.clipboard
              .writeText(inviteUrl)
              .then(() => setCopied(true))
              .catch(() => setCopied(false));
          }}
        >
          {copied ? 'Link copied' : 'Copy invite link'}
        </button>
        <button type="button" className="blurt__skip" onClick={onClose}>
          Done
        </button>
      </div>
    </div>
  );
}

function NamePrompt({ onSubmit }: { onSubmit: (name: string | null) => void }) {
  const [draft, setDraft] = useState('');
  const trimmed = draft.trim();

  return (
    <div className="blurt__overlay">
      <form
        className="blurt__sheet"
        onSubmit={(event) => {
          event.preventDefault();
          if (trimmed) onSubmit(trimmed);
        }}
      >
        <h2>What should we call you?</h2>
        <p>So your team knows who is describing.</p>
        <input
          value={draft}
          onChange={(event) => setDraft(event.target.value)}
          placeholder="Your name"
          maxLength={24}
          autoFocus
          autoComplete="off"
        />
        <button type="submit" className="blurt__primary" disabled={!trimmed}>
          Save
        </button>
        <button type="button" className="blurt__skip" onClick={() => onSubmit(null)}>
          Not now
        </button>
      </form>
    </div>
  );
}

// MARK: - Small helpers

/** The game code in the link, if somebody arrived on one. */
function arrivedAt(): string | null {
  const typed = new URLSearchParams(window.location.search).get('game');
  // A code in a link may have been retyped by hand rather than copied.
  return (typed && normaliseGameCode(typed)) || null;
}

function randomSeed(): number {
  const values = new Uint32Array(1);
  crypto.getRandomValues(values);
  return values[0];
}

export default VibeBlurt;
