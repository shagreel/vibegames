import { SeededGenerator, shuffle } from '../../lib/seeded';
import { CARD_BY_ID, DECK, isTrio, type TrioCard } from './cards';

/** The cards on the table, and the rules for keeping play possible. */
export interface TrioTable {
  /** Cards face up. Starts at 12 and grows by 3 whenever the table has no trio. */
  readonly visible: readonly TrioCard[];
  /** Cards still to come, in the order they will appear. */
  readonly remaining: readonly TrioCard[];
  readonly triosTaken: number;
  readonly extraDeals: number;
}

export const INITIAL_DEAL = 12;

export function newTable(seed: number): TrioTable {
  const deck = [...DECK];
  shuffle(deck, new SeededGenerator(seed));

  return ensurePlayable({
    visible: deck.slice(0, INITIAL_DEAL),
    remaining: deck.slice(INITIAL_DEAL),
    triosTaken: 0,
    extraDeals: 0,
  });
}

/** Deals three more while the table has no trio but the deck still has cards. */
function ensurePlayable(table: TrioTable): TrioTable {
  let visible = [...table.visible];
  let remaining = [...table.remaining];
  let extraDeals = table.extraDeals;

  while (remaining.length > 0 && !hasTrioAmong(visible)) {
    const take = Math.min(3, remaining.length);
    visible = [...visible, ...remaining.slice(0, take)];
    remaining = remaining.slice(take);
    extraDeals += 1;
  }

  return { ...table, visible, remaining, extraDeals };
}

function hasTrioAmong(cards: readonly TrioCard[]): boolean {
  for (let i = 0; i < cards.length - 2; i += 1) {
    for (let j = i + 1; j < cards.length - 1; j += 1) {
      for (let k = j + 1; k < cards.length; k += 1) {
        if (isTrio(cards[i], cards[j], cards[k])) return true;
      }
    }
  }
  return false;
}

/** The first trio on the table, as indices, or null. */
export function firstTrio(cards: readonly TrioCard[]): [number, number, number] | null {
  for (let i = 0; i < cards.length - 2; i += 1) {
    for (let j = i + 1; j < cards.length - 1; j += 1) {
      for (let k = j + 1; k < cards.length; k += 1) {
        if (isTrio(cards[i], cards[j], cards[k])) return [i, j, k];
      }
    }
  }
  return null;
}

/** Whether the three cards at these indices form a trio, without taking them. */
export function wouldFormTrioAt(table: TrioTable, indices: readonly number[]): boolean {
  if (
    indices.length !== 3 ||
    new Set(indices).size !== 3 ||
    !indices.every((index) => index >= 0 && index < table.visible.length)
  ) {
    return false;
  }
  const [a, b, c] = indices.map((index) => table.visible[index]);
  return isTrio(a, b, c);
}

/**
 * Whether the three *named cards* form a trio and are all still face up.
 *
 * Named by id, not by position. This is the distinction that produced a real bug
 * on iOS: a shared game talks in card ids, and an id means a different thing on
 * every device, so asking this the index way silently answers a different
 * question and refuses every claim.
 */
export function wouldFormTrioByIds(table: TrioTable, ids: readonly number[]): boolean {
  return takeByIds(table, ids) !== null;
}

/**
 * Takes the trio at these indices. Returns the new table, or null if the three
 * cards are not a trio or are not there.
 */
export function takeAt(table: TrioTable, indices: readonly number[]): TrioTable | null {
  if (!wouldFormTrioAt(table, indices)) return null;

  const visible = [...table.visible];
  const remaining = [...table.remaining];

  // Descending, so each removal cannot shift the indices still to come.
  for (const index of [...indices].sort((a, b) => b - a)) {
    if (remaining.length === 0) {
      visible.splice(index, 1);
    } else {
      visible[index] = remaining.shift()!;
    }
  }

  return ensurePlayable({
    visible,
    remaining,
    triosTaken: table.triosTaken + 1,
    extraDeals: table.extraDeals,
  });
}

/**
 * Takes the trio named by card id. Returns the new table, or null if any of the
 * cards has already gone — which is how a take that lost a race shows up.
 */
export function takeByIds(table: TrioTable, ids: readonly number[]): TrioTable | null {
  if (ids.length !== 3 || new Set(ids).size !== 3) return null;

  const indices: number[] = [];
  for (const id of ids) {
    const index = table.visible.findIndex((card) => card.id === id);
    if (index === -1) return null;
    indices.push(index);
  }
  return takeAt(table, indices);
}

/**
 * The table a shared game is looking at, rebuilt from the seed and the takes the
 * server accepted, in the order it accepted them.
 *
 * Every device runs this over the same inputs and lands on the same table, so
 * nothing about the board is ever sent.
 */
export function replay(seed: number, takes: readonly (readonly number[])[]): TrioTable {
  let table = newTable(seed);
  for (const ids of takes) {
    const next = takeByIds(table, ids);
    // A take that cannot be applied is one the server would have refused; skip
    // it rather than throwing a board away over bad data.
    if (next) table = next;
  }
  return table;
}

/** Over when the deck is spent and nothing left on the table completes a trio. */
export function isFinished(table: TrioTable): boolean {
  return table.remaining.length === 0 && !hasTrioAmong(table.visible);
}

/** The cards in `visible` that belong to at least one trio. */
export function trioCardIds(table: TrioTable): Set<number> {
  const ids = new Set<number>();
  for (const [i, j, k] of allTrios(table.visible)) {
    ids.add(table.visible[i].id);
    ids.add(table.visible[j].id);
    ids.add(table.visible[k].id);
  }
  return ids;
}

function allTrios(cards: readonly TrioCard[]): [number, number, number][] {
  const found: [number, number, number][] = [];
  for (let i = 0; i < cards.length - 2; i += 1) {
    for (let j = i + 1; j < cards.length - 1; j += 1) {
      for (let k = j + 1; k < cards.length; k += 1) {
        if (isTrio(cards[i], cards[j], cards[k])) found.push([i, j, k]);
      }
    }
  }
  return found;
}

/** Convenience for the tests and the hint: a card by id. */
export { CARD_BY_ID, SeededGenerator, shuffle };
