import type { ReactElement } from 'react';

/**
 * The menu at play.vibegames.party.
 *
 * This used to be Word Vibe and nothing else, because Word Vibe was the only
 * game with a web version — going to play. and getting a word grid was the whole
 * of the site. It is a menu now, and each game is a path.
 */
export interface GameEntry {
  id: string;
  path: string;
  title: string;
  tagline: string;
  /** Two hex stops, matching the app's gradients and the landing page. */
  accent: [string, string];
  /** Inline SVG so the icon needs no asset and can wear the gradient. */
  symbol: ReactElement;
  available: boolean;
}

const IconFive = (
  <svg viewBox="0 0 24 24" aria-hidden="true">
    <path d="M12 3.4 14.6 9l6.1.8-4.5 4.2 1.2 6-5.4-3-5.4 3 1.2-6L3.3 9.8 9.4 9z" />
  </svg>
);

const IconWords = (
  <svg viewBox="0 0 24 24" aria-hidden="true">
    <path d="M2.5 8h3.4v8H2.5zM7 8h3.4v8H7zM11.5 8h3.4v8h-3.4zM16 8h3.4v8H16z" />
    <path d="M6 4h12v2.4H6z" opacity="0.55" />
  </svg>
);

const IconSudoku = (
  <svg viewBox="0 0 24 24" aria-hidden="true">
    <path d="M3 3h6v6H3zM10.5 3h3v6h-3zM15 3h6v6h-6zM3 10.5h6v3H3zM10.5 10.5h3v3h-3zM15 10.5h6v3h-6zM3 15h6v6H3zM10.5 15h3v6h-3zM15 15h6v6h-6z" />
  </svg>
);

const IconTrio = (
  <svg viewBox="0 0 24 24" aria-hidden="true">
    <path d="M4 4h7v7H4zM13 4h7v7h-7zM4 13h7v7H4z" />
    <circle cx="16.5" cy="16.5" r="3.6" />
  </svg>
);

const IconTen = (
  <svg viewBox="0 0 24 24" aria-hidden="true">
    <path d="M4 3h6v6H4zM4 11h6v6H4zM12 3h6v6h-6zM12 11h6v6h-6zM8 19h8v2H8z" opacity="0.9" />
  </svg>
);

const IconBlurt = (
  <svg viewBox="0 0 24 24" aria-hidden="true">
    <path d="M3 5.5h12.5a2 2 0 0 1 2 2v5a2 2 0 0 1-2 2H9l-4 3v-3H5a2 2 0 0 1-2-2v-5a2 2 0 0 1 2-2z" />
    <path d="M18.6 3.2 21 5.6l-1.7 1.7-2.4-2.4z" opacity="0.55" />
  </svg>
);

export const GAMES: GameEntry[] = [
  {
    id: 'five',
    path: '/five',
    title: 'Vibe Five',
    tagline: 'Name three things before the buzzer.',
    accent: ['#ff4757', '#ff8c33'],
    symbol: IconFive,
    available: true,
  },
  {
    id: 'words',
    path: '/words',
    title: 'Word Vibe',
    tagline: 'Guess the five-letter word. First to solve wins.',
    accent: ['#21b8a8', '#4585f5'],
    symbol: IconWords,
    available: true,
  },
  {
    id: 'sudoku',
    path: '/sudoku',
    title: 'Number Vibe',
    tagline: 'Fill the grid. Race your friends to it.',
    accent: ['#8549f0', '#db54c2'],
    symbol: IconSudoku,
    available: true,
  },
  {
    id: 'trio',
    path: '/trio',
    title: 'Vibe Pairings',
    tagline: 'Three cards where every feature matches or differs.',
    accent: ['#f7b929', '#85d647'],
    symbol: IconTrio,
    available: true,
  },
  {
    id: 'ten',
    path: '/ten',
    title: 'Vibe Ten',
    tagline: 'Pair the digits. Clear the board. First to clear it wins.',
    accent: ['#2a8cf2', '#4dd9e6'],
    symbol: IconTen,
    available: true,
  },
  {
    id: 'blurt',
    path: '/blurt',
    title: 'Similar Vibe',
    tagline: "Describe it. Don't say it. Two teams, one word.",
    accent: ['#f54d6b', '#fd8c3d'],
    symbol: IconBlurt,
    available: true,
  },
];
