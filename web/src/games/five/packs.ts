import { PROMPTS } from './prompts.generated';

/**
 * The eleven themed packs, and the pool of prompts they add up to.
 *
 * This mirrors `CategoryPack.swift`. The prompts themselves are generated from
 * the Swift source (`Tools/make_web_packs.py`) so the app and the browser offer
 * the same categories and cannot drift apart.
 */

export const PACK_IDS = [
  'everyday',
  'food',
  'animals',
  'movies',
  'music',
  'tv',
  'travel',
  'sports',
  'games',
  'people',
  'random',
] as const;

export type PackId = (typeof PACK_IDS)[number];

export interface Pack {
  id: PackId;
  title: string;
  /** Stands in for the SF Symbol the app uses. */
  emoji: string;
  blurb: string;
}

export const PACKS: Pack[] = [
  { id: 'everyday', title: 'Everyday Life', emoji: '🏠', blurb: 'Kitchens, pockets and junk drawers' },
  { id: 'food', title: 'Food & Drink', emoji: '🍴', blurb: 'Meals, snacks and ingredients' },
  { id: 'animals', title: 'Animals & Nature', emoji: '🐾', blurb: 'Creatures, weather and the outdoors' },
  { id: 'movies', title: 'Movies & Cinema', emoji: '🎬', blurb: 'Films, genres and cinema trips' },
  { id: 'music', title: 'Music', emoji: '🎵', blurb: 'Songs, artists and instruments' },
  { id: 'tv', title: 'TV & Streaming', emoji: '📺', blurb: 'Shows, series and streaming' },
  { id: 'travel', title: 'Places & Travel', emoji: '✈️', blurb: 'Cities, trips and packing lists' },
  { id: 'sports', title: 'Sports', emoji: '🏃', blurb: 'Athletes, matches and the gym' },
  { id: 'games', title: 'Games & Play', emoji: '🎮', blurb: 'Boards, cards, consoles and toys' },
  { id: 'people', title: 'People & Jobs', emoji: '👥', blurb: 'Jobs, habits and awkward moments' },
  { id: 'random', title: 'Random & Silly', emoji: '✨', blurb: 'Daft debates and silly what-ifs' },
];

export const ALL_PACK_IDS: PackId[] = [...PACK_IDS];

export interface VibeCategory {
  text: string;
  pack: PackId;
}

export function packById(id: PackId): Pack {
  return PACKS.find((pack) => pack.id === id) ?? PACKS[0];
}

/** Every prompt in the enabled packs, ready to be shuffled into a deck. */
export function categoriesIn(enabled: readonly PackId[]): VibeCategory[] {
  const wanted = enabled.length > 0 ? enabled : ALL_PACK_IDS;
  const categories: VibeCategory[] = [];
  for (const id of PACK_IDS) {
    if (!wanted.includes(id)) continue;
    for (const text of PROMPTS[id] ?? []) categories.push({ text, pack: id });
  }
  return categories;
}

/** How many prompts are in play, without building them. */
export function countIn(enabled: readonly PackId[]): number {
  const wanted = enabled.length > 0 ? enabled : ALL_PACK_IDS;
  return PACK_IDS.reduce(
    (total, id) => (wanted.includes(id) ? total + (PROMPTS[id]?.length ?? 0) : total),
    0,
  );
}
