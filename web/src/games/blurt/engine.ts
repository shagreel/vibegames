import { SeededGenerator, shuffle } from '../../lib/seeded';
import { PACK_ORDER, PACK_WORDS } from './words.generated';

/**
 * The rules of Vibe Blurt, in the browser.
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
 * How long a turn lasts, chosen in the lobby.
 *
 * Mirrors `BlurtDuration`. A table of adults and a table with a nine-year-old
 * want very different amounts of the same game.
 */
export interface DurationOption {
  seconds: number;
  title: string;
  blurb: string;
}

export const DURATIONS: DurationOption[] = [
  { seconds: 30, title: '30 seconds', blurb: 'Frantic. Words come round again.' },
  { seconds: 60, title: '1 minute', blurb: 'The one the box would have picked.' },
  { seconds: 90, title: '90 seconds', blurb: 'Room to think, and to get stuck.' },
  { seconds: 120, title: '2 minutes', blurb: 'For a big table and slow clues.' },
];

export const DEFAULT_SECONDS = 60;

/** Anything unexpected from the database becomes the nearest one offered. */
export function nearestDuration(seconds: number): DurationOption {
  return DURATIONS.reduce((best, option) =>
    Math.abs(option.seconds - seconds) < Math.abs(best.seconds - seconds) ? option : best,
  );
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
 * looks random: 10 words out of 300 twice shares a word every third game or so,
 * which is often enough to notice.
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
): string | null {
  if (members.length === 0) return null;
  const within = (Math.floor(turn / 2) + offset) % members.length;
  return members[within];
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
