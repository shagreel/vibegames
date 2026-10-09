/**
 * The 81-card deck and the trio rule.
 *
 * A card varies along four features, three options each, so there are 3^4 = 81.
 * Three cards make a trio when every feature is *either the same on all three or
 * different on all three* — two matching and a third odd is not a trio.
 *
 * This mirrors `TrioCard.swift`. The option order is load-bearing: a card's id is
 * its position in this ordering, and the artwork files are numbered from it, so
 * changing an order here renames 81 files and desyncs every game in progress.
 */

export const PLATTER_SLUGS = ['circle', 'hexagon', 'rectangle'] as const;
export const PLATTER_SPOKEN = [
  'round walnut platter',
  'bamboo hexagon platter',
  'slate rectangle platter',
] as const;

export const CHEESE_SLUGS = ['swiss', 'gouda', 'brie'] as const;
export const CHEESE_SPOKEN = ['swiss wedge', 'gouda cubes', 'brie round'] as const;

export const MEAT_SLUGS = ['prosciutto', 'salami', 'turkey'] as const;
export const MEAT_SPOKEN = ['prosciutto ribbon', 'salami stack', 'turkey roll-up'] as const;

export const GARNISH_SLUGS = ['grapes', 'strawberry', 'pear'] as const;
export const GARNISH_SPOKEN = ['purple grapes', 'red strawberry', 'pear slices'] as const;

export interface TrioCard {
  /** 0…80, unique, and the same number the artwork uses. */
  readonly id: number;
  readonly base: number;
  readonly cheese: number;
  readonly meat: number;
  readonly garnish: number;
}

/** Every card, in id order: the garnish varies fastest, then meat, cheese, base. */
export const DECK: readonly TrioCard[] = (() => {
  const cards: TrioCard[] = [];
  for (let base = 0; base < 3; base += 1) {
    for (let cheese = 0; cheese < 3; cheese += 1) {
      for (let meat = 0; meat < 3; meat += 1) {
        for (let garnish = 0; garnish < 3; garnish += 1) {
          cards.push({
            id: ((base * 3 + cheese) * 3 + meat) * 3 + garnish,
            base,
            cheese,
            meat,
            garnish,
          });
        }
      }
    }
  }
  return cards;
})();

/** Look a card up by id, which is all a shared game ever sends. */
export const CARD_BY_ID: readonly TrioCard[] = (() => {
  const byId: TrioCard[] = new Array(81);
  for (const card of DECK) byId[card.id] = card;
  return byId;
})();

function sameOrAllDifferent(a: number, b: number, c: number): boolean {
  return (a === b && b === c) || (a !== b && b !== c && a !== c);
}

export function isTrio(first: TrioCard, second: TrioCard, third: TrioCard): boolean {
  return (
    sameOrAllDifferent(first.base, second.base, third.base) &&
    sameOrAllDifferent(first.cheese, second.cheese, third.cheese) &&
    sameOrAllDifferent(first.meat, second.meat, third.meat) &&
    sameOrAllDifferent(first.garnish, second.garnish, third.garnish)
  );
}

/**
 * The card that completes a trio with these two.
 *
 * Every pair has exactly one completion, which is what stops a trio ever being
 * ambiguous.
 */
export function completingCard(first: TrioCard, second: TrioCard): TrioCard {
  const complete = (a: number, b: number) =>
    a === b ? a : 3 - a - b; // 0+1+2 = 3, so the missing option is 3 - a - b
  return cardOf(
    complete(first.base, second.base),
    complete(first.cheese, second.cheese),
    complete(first.meat, second.meat),
    complete(first.garnish, second.garnish),
  );
}

export function cardOf(base: number, cheese: number, meat: number, garnish: number): TrioCard {
  return CARD_BY_ID[((base * 3 + cheese) * 3 + meat) * 3 + garnish];
}

/** Indices of every trio among the given cards. */
export function allTrios(cards: readonly TrioCard[]): [number, number, number][] {
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

export function hasTrio(cards: readonly TrioCard[]): boolean {
  return allTrios(cards).length > 0;
}

/** The file name under `public/cards/`, derived rather than kept in a second list. */
export function imageName(card: TrioCard): string {
  const number = String(card.id + 1).padStart(2, '0');
  return `card-${number}_${PLATTER_SLUGS[card.base]}_${CHEESE_SLUGS[card.cheese]}_${MEAT_SLUGS[card.meat]}_${GARNISH_SLUGS[card.garnish]}`;
}

export function artworkPath(card: TrioCard): string {
  return `/cards/${imageName(card)}.png`;
}

/** Read aloud by a screen reader, and read back by the tests. */
export function spokenDescription(card: TrioCard): string {
  return [
    PLATTER_SPOKEN[card.base],
    CHEESE_SPOKEN[card.cheese],
    MEAT_SPOKEN[card.meat],
    GARNISH_SPOKEN[card.garnish],
  ].join(', ');
}
