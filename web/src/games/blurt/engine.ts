import { SeededGenerator, shuffle } from '../../lib/seeded';
import { PACK_ORDER, PACK_WORDS } from './words.generated';

/**
 * The rules of Similar Vibe, in the browser.
 *
 * Every one of these mirrors `BlurtEngine.swift`, and has to: a room stores a
 * seed and a round and nothing else about the words, so the browser and the
 * phone must lay out the identical deck. `web/src/test/blurtEngine.test.ts`
 * checks this against fixtures dumped from Swift rather than trusting it.
 *
 * The scoring is the whole game, and it is deliberately not "points for
 * guessing": the team that is *not* holding the word takes the point when the
 * clock stops, so describing earns nothing and only passes the risk on.
 */

export type Team = 1 | 2;

/** Both teams, in the order they are drawn. */
export const TEAMS: Team[] = [1, 2];

/** First to this many takes the game. */
export const TARGET = 7;

/**
 * Two on each side, so there is always somebody to describe to and somebody on
 * the other team to catch you doing it.
 */
export const MINIMUM_PER_TEAM = 2;
export const MINIMUM_PLAYERS = MINIMUM_PER_TEAM * 2;

export function teamTitle(team: Team): string {
  return team === 1 ? 'Team One' : 'Team Two';
}

export function other(team: Team): Team {
  return team === 1 ? 2 : 1;
}

/**
 * How long a round lasts, and how the end of it is signalled.
 *
 * Mirrors `BlurtTiming`. A round is a **random** 50–70 seconds rather than a
 * length the table chose: a known length gets counted down out loud, and a table
 * watching the same number arrive together all stop together.
 *
 * So there is no number on screen, and the bar is spent *before* the round is —
 * it fills by the time the last 15% begins, so its end is not the round's end.
 * What the last 15% has instead is a bar that changes colour and pulses, which
 * cannot be counted.
 *
 * All of this is pinned against the Swift model by `engine.fixtures.json`, so
 * keep the arithmetic in the same order as well as the same shape.
 */
export const SHORTEST_SECONDS = 50;
export const LONGEST_SECONDS = 70;

/** The last of the round, as a fraction, where the hurry begins. */
export const TAIL_FRACTION = 0.15;

export const STEADY_INTERVAL = 1.0;
export const URGENT_INTERVAL = 0.17;
export const STEADY_VOLUME = 0.28;
export const URGENT_VOLUME = 1.0;

/** A fresh round length. Drawn by whichever phone starts the round. */
export function randomTurnSeconds(): number {
  return SHORTEST_SECONDS + Math.floor(Math.random() * (LONGEST_SECONDS - SHORTEST_SECONDS + 1));
}

/** How close to the end: 0 for the whole of the first 85%, 1 at the buzzer. */
export function urgency(remaining: number, total: number): number {
  if (!(total > 0)) return 0;
  const fraction = remaining / total;
  if (fraction >= TAIL_FRACTION) return 0;
  return Math.min(1, Math.max(0, (TAIL_FRACTION - fraction) / TAIL_FRACTION));
}

/**
 * How much of the bar is filled: 0 at the start, 1 from the moment the last 15%
 * begins. The divisor is what stops the bar being a countdown.
 */
export function barFill(remaining: number, total: number): number {
  if (!(total > 0)) return 0;
  const elapsed = 1 - remaining / total;
  return Math.min(1, Math.max(0, elapsed / (1 - TAIL_FRACTION)));
}

/** How long to wait before the next tick, at this urgency. */
export function tickInterval(urgencyValue: number): number {
  return (
    STEADY_INTERVAL +
    (URGENT_INTERVAL - STEADY_INTERVAL) * Math.min(1, Math.max(0, urgencyValue))
  );
}

/** How loud the next tick is, at this urgency. Unused in the browser, which has
 * no sound here, but pinned by the fixtures so the two models cannot drift. */
export function tickVolume(urgencyValue: number): number {
  return (
    STEADY_VOLUME + (URGENT_VOLUME - STEADY_VOLUME) * Math.min(1, Math.max(0, urgencyValue))
  );
}

/** When every tick of a round falls, and how loud each one is. */
export function tickSchedule(total: number): { at: number; volume: number }[] {
  if (!(total > 0)) return [];
  const schedule: { at: number; volume: number }[] = [];
  let elapsed = 0;

  for (;;) {
    const u = urgency(total - elapsed, total);
    elapsed += tickInterval(u);
    if (elapsed >= total) break;
    schedule.push({ at: elapsed, volume: tickVolume(u) });
  }
  return schedule;
}

/** A themed bundle of things to describe. */
export function packIds(): string[] {
  return [...PACK_ORDER];
}

export function isPackId(id: string): boolean {
  return PACK_ORDER.includes(id);
}

/**
 * Every word in the chosen packs, in pack order.
 *
 * Pack order rather than the order they were ticked in: the deck has to come
 * out the same on every device, and two people ticking the same boxes in a
 * different order is not a difference worth having. An empty selection is what
 * a corrupt read looks like rather than a choice, so it means everything.
 */
export function wordsIn(packs: readonly string[]): string[] {
  const chosen = packs.length === 0 ? new Set(PACK_ORDER) : new Set(packs);
  return PACK_ORDER.filter((id) => chosen.has(id)).flatMap((id) => PACK_WORDS[id] ?? []);
}

/**
 * The room's deck — one per room, walked from start to finish across as many
 * games as the table plays.
 *
 * There is deliberately no per-round deck. Shuffling afresh for each game only
 * looks random: ten words out of a few hundred twice shares one or two, which
 * is often enough to notice.
 */
export function shuffled(seed: number, packs: readonly string[]): string[] {
  const generator = new SeededGenerator(seed >>> 0);
  const deck = wordsIn(packs);
  shuffle(deck, generator);
  return deck;
}

/** The word for a turn. Wraps, so a long game cannot run out mid-turn. */
export function wordAt(index: number, deck: readonly string[]): string {
  if (deck.length === 0) return '';
  const wrapped = ((index % deck.length) + deck.length) % deck.length;
  return deck[wrapped];
}

// MARK: - Teams

/**
 * Splits a roster into two teams, as evenly as the numbers allow.
 *
 * Sorted before shuffling, so the same room and the same seed always splits the
 * same way whatever order people arrived in.
 */
export function split(players: readonly string[], seed: number): Record<string, Team> {
  const generator = new SeededGenerator(seed);
  const order = [...players].sort();
  shuffle(order, generator);

  const teams: Record<string, Team> = {};
  order.forEach((player, index) => {
    teams[player] = index % 2 === 0 ? 1 : 2;
  });
  return teams;
}

export function membersOf(team: Team, teams: Record<string, Team>): string[] {
  return Object.keys(teams)
    .filter((player) => teams[player] === team)
    .sort();
}

/**
 * The two parts of a room these name helpers need, named structurally so the
 * engine does not have to know the service's snapshot — and so this stays
 * testable without dragging in Firebase.
 */
export interface Roster {
  players: Record<string, string>;
  teams: Record<string, Team>;
}

/**
 * One team's players, by name, as they should be shown.
 *
 * Only the people who are actually in the room. A team slot deliberately
 * outlives the player sitting in it — that is what puts somebody back on their
 * own side when they return — so the slot list is not the roster. This used to
 * fall back to "Someone" for a slot nobody was in, which put a line in the
 * scoreboard for a person who was not there. The rotation has always skipped
 * them; the scoreboard does now too, which is what the app's `names(on:)` has
 * always done.
 */
export function namesOn(roster: Roster, team: Team): string[] {
  return membersOf(team, roster.teams)
    .map((player) => roster.players[player])
    .filter((name) => Boolean(name));
}

/** Turns alternate, and team one has the first one. */
export function describingTeam(turn: number): Team {
  return turn % 2 === 0 ? 1 : 2;
}

/**
 * Where each team starts in its own rotation.
 *
 * Drawn from the seed so the first describer is random, but drawn in a fixed
 * order — team one, then team two — so every device walks the generator the
 * same way.
 */
export function describerOffsets(
  oneMembers: number,
  twoMembers: number,
  seed: number,
): { one: number; two: number } {
  const generator = new SeededGenerator(seed);
  const one = generator.nextBounded(Math.max(1, oneMembers));
  const two = generator.nextBounded(Math.max(1, twoMembers));
  return { one, two };
}

/**
 * Whose screen shows the word.
 *
 * `turn` counts turns from zero across the whole game, so a team's own count is
 * half of it.
 */
export function describerFor(
  members: readonly string[],
  turn: number,
  offset: number,
  present?: ReadonlySet<string>,
): string | null {
  // `present` narrows the rotation to the people actually in the room. The team
  // list outlives any particular phone — that is what lets somebody who drops
  // out come back to the same side — so whoever is missing is taken *out* of the
  // order rather than stood in for. Walking forward to the next person instead
  // looks equivalent and is not: the stand-in also holds the turn after, so they
  // describe twice in a row.
  const roster = present ? members.filter((member) => present.has(member)) : members;
  if (roster.length === 0) return null;
  return roster[(Math.floor(turn / 2) + offset) % roster.length];
}

/**
 * Who is actually holding the word.
 *
 * Normally the person the turn was written down for. When that phone has left,
 * the round does not carry on around them: the word moves to whoever the rotation
 * names among the people still here — the same rule that walks the turn on at the
 * end of a round, so the missing player is taken out of the order rather than
 * described around.
 *
 * Leaving the word with somebody who has gone is not a small thing. The other
 * team is shown the word and told to watch for a person who is not in the room;
 * the describer's own team-mates are told that person is describing to them.
 * Nobody can play that round, nothing ends it early, and the clock runs down on a
 * turn that was never taken. A player out of the room is out of the game until
 * they come back.
 *
 * `null` only when the describing team has nobody left in the room at all.
 *
 * Matches `BlurtRules.holder` in Swift, and checked against it by the fixtures.
 */
export function holderFor(
  play: { describer: string; team: Team; turn: number },
  roster: Roster,
  seed: number,
): string | null {
  // A present player is one with an entry in the roster, whatever they are
  // called — the same thing the Swift engine means by its `present` set.
  if (roster.players[play.describer] !== undefined) return play.describer;

  const offsets = describerOffsets(
    membersOf(1, roster.teams).length,
    membersOf(2, roster.teams).length,
    seed,
  );
  return describerFor(
    membersOf(play.team, roster.teams),
    play.turn,
    play.team === 1 ? offsets.one : offsets.two,
    new Set(Object.keys(roster.players)),
  );
}

/** The team that takes the point — never the one that was describing. */
export function scoringTeam(describing: Team): Team {
  return other(describing);
}

/** First to the target wins, or null while the game is still going. */
export function winner(one: number, two: number, target: number = TARGET): Team | null {
  if (one >= target) return 1;
  if (two >= target) return 2;
  return null;
}
