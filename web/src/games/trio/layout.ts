/**
 * How the cards are arranged so that every one of them is on screen at once.
 *
 * The board used to be three across inside a scroll view, which on the largest
 * screen showed the fewest cards. A trio is a puzzle about the whole table at
 * once — scrolling to see the rest of it is a different, worse game — so the
 * table is fitted to the room it has: every arrangement from one column to one
 * per card is measured, and the one leaving the cards biggest wins.
 *
 * This is the same arithmetic as `TrioBoardLayout.swift`, so a phone and a
 * browser lay the same table out the same way.
 */

/** Width divided by height: the cards are slightly taller than they are wide. */
export const CARD_ASPECT = 900 / 1153;

export const BOARD_SPACING = 8;

/**
 * Arrangements within this much of each other are a tie, and the one with fewer
 * columns takes it — three across is the shape the game was designed around.
 */
const TIE = 1;

export interface BoardLayout {
  columns: number;
  rows: number;
  cardWidth: number;
}

export function fitBoard(
  count: number,
  width: number,
  height: number,
  spacing: number = BOARD_SPACING,
): BoardLayout {
  if (count <= 0) return { columns: 1, rows: 0, cardWidth: 0 };
  if (width <= 0 || height <= 0) return { columns: count, rows: 1, cardWidth: 0 };

  let best: BoardLayout | null = null;

  for (let columns = 1; columns <= count; columns += 1) {
    const rows = Math.ceil(count / columns);
    const cellWidth = (width - spacing * (columns - 1)) / columns;
    const cellHeight = (height - spacing * (rows - 1)) / rows;
    if (cellWidth <= 0 || cellHeight <= 0) continue;

    // Cards are taller than they are wide, so the row height usually limits
    // them — but a short, wide window flips that round.
    const cardWidth = Math.min(cellWidth, cellHeight * CARD_ASPECT);
    if (best && cardWidth <= best.cardWidth + TIE) continue;
    best = { columns, rows, cardWidth };
  }

  return best ?? { columns: count, rows: 1, cardWidth: 0 };
}

/** Card indices by row, so a last row that does not fill can be centred. */
export function rowsOfIndices(count: number, columns: number): number[][] {
  const rows: number[][] = [];
  for (let start = 0; start < count; start += columns) {
    rows.push(Array.from({ length: Math.min(columns, count - start) }, (_, i) => start + i));
  }
  return rows;
}
