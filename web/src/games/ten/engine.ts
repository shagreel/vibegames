import { SeededGenerator, shuffle } from '../../lib/seeded';

/**
 * The Vibe Ten board: nine columns of digits, hanging from the top.
 *
 * A column is a plain array, top first, which is the whole of the gravity rule:
 * take a digit out and the ones below it are already one place higher. There are
 * never gaps inside a column.
 *
 * Mirrors `VibeTenBoard.swift`, including the deal: a set of valid pairs is
 * drawn and then their digits are shuffled onto the board with the same
 * SplitMix64 generator the app uses, so a room's seed gives both clients the
 * identical digits and neither can see the other's board.
 */

/** The board is always nine columns; only the rows are a choice. */
export const COLUMNS = 9;
export const ROWS = 18;
export const ROW_OPTIONS = [12, 14, 16, 18] as const;
/** One press of the new-row offer adds this many rows, at most. */
export const ROWS_PER_ADD_OPTIONS = [1, 2, 3, 4] as const;

/** Every unordered pair the deal can draw from: two of the same number, or two
 * that add to ten. A pair of fives is both, so it is listed once. */
export const PAIR_OPTIONS: readonly (readonly [number, number])[] = [
  [1, 1], [2, 2], [3, 3], [4, 4], [5, 5], [6, 6], [7, 7], [8, 8], [9, 9],
  [1, 9], [2, 8], [3, 7], [4, 6],
];

export interface Position {
  readonly column: number;
  readonly row: number;
}

/**
 * How a taken pair leaves the board.
 *
 * `remove`: the two digits go and everything below rises into the gap.
 * `dim`: the digits stay, greyed out, and count as gone for the rules — a row
 * whose every digit is dimmed clears at once and everything below rises a row.
 */
export type TenMode = 'remove' | 'dim';

export const MODE_LABELS: Record<TenMode, { title: string; blurb: string }> = {
  remove: {
    title: 'Remove',
    blurb: 'A matched pair disappears and the digits above fall into the gap.',
  },
  dim: {
    title: 'Dim',
    blurb:
      'A matched pair dims and stays put. Dimmed digits are treated as empty, so a pair can be made across them. When every digit in a row is dimmed the row clears and everything below it rises one row.',
  },
};

/** One digit on the board. */
export interface TenCell {
  readonly value: number;
  /** Taken in dim mode: still drawn, but gone for the rules. */
  readonly dimmed: boolean;
}

export interface TenBoard {
  readonly seed: number;
  /** How many columns and rows: a room is dealt from the seed *and* these. */
  readonly columns: number;
  readonly rows: number;
  /** Whether the end of a row joins the start of the next. */
  readonly wrapRows: boolean;
  /** The columns, each top-first: the board hangs from the top. */
  readonly stacks: readonly (readonly TenCell[])[];
}

/** What a match did, for the screen to animate or count. */
export interface TenMove {
  /** Rows cleared in dim mode because every digit in them was dimmed. */
  readonly rowsCleared: readonly number[];
}

const cell = (value: number): TenCell => ({ value, dimmed: false });

/**
 * The pairs a board is dealt from, before their digits are shuffled onto it.
 * Each one is a pair the rules can take: equal, or adding to ten.
 */
export function pairChoices(seed: number, count: number): [number, number][] {
  const generator = new SeededGenerator(seed);
  const pairs: [number, number][] = [];
  for (let index = 0; index < count; index += 1) {
    const pair = PAIR_OPTIONS[generator.nextBounded(PAIR_OPTIONS.length)];
    pairs.push([pair[0], pair[1]]);
  }
  return pairs;
}

/**
 * The digits, drawn as valid pairs and then laid out at random.
 *
 * The recipe has to match `VibeTenBoard.deal` exactly — same generator, same
 * draws in the same order — because a room's board comes back from one seed.
 * `board.fixtures.json` pins it.
 */
export function deal(seed: number, columns: number, rows: number): TenCell[][] {
  const generator = new SeededGenerator(seed);
  const pairCount = Math.floor((columns * rows) / 2);
  const digits: number[] = [];
  for (let index = 0; index < pairCount; index += 1) {
    const pair = PAIR_OPTIONS[generator.nextBounded(PAIR_OPTIONS.length)];
    digits.push(pair[0], pair[1]);
  }
  shuffle(digits, generator);
  return Array.from({ length: columns }, (_, column) =>
    Array.from({ length: rows }, (_, row) => cell(digits[column * rows + row])),
  );
}

/**
 * The board a game is dealt.
 *
 * The deal is two steps: a set of valid pairs — two of the same number or two
 * that add to ten — enough to fill the grid, and then those digits shuffled and
 * laid out. It makes a board that reads as dealt rather than sorted; it does not
 * promise a way through, so a round can end with no moves left instead of a
 * cleared board.
 */
export function newBoard(
  seed: number,
  columns = COLUMNS,
  rows = ROWS,
  wrapRows = false,
): TenBoard {
  return {
    seed,
    columns,
    rows,
    wrapRows,
    stacks: deal(seed, columns, rows),
  };
}

export function boardFromStacks(
  stacks: number[][],
  seed = 0,
  shape: {
    columns?: number;
    rows?: number;
    wrapRows?: boolean;
  } = {},
): TenBoard {
  const columns = shape.columns ?? COLUMNS;
  const rows = shape.rows ?? ROWS;
  const filled = stacks.slice(0, columns).map((column) => column.slice(0, rows).map(cell));
  while (filled.length < columns) filled.push([]);
  return {
    seed,
    columns,
    rows,
    wrapRows: shape.wrapRows ?? false,
    stacks: filled,
  };
}

/** The digits in the shape the fixture and the app use. */
export function values(board: TenBoard): number[][] {
  return board.stacks.map((column) => column.map((entry) => entry.value));
}

export function heightOf(board: TenBoard, column: number): number {
  return board.stacks[column]?.length ?? 0;
}

export function cellAt(board: TenBoard, position: Position): TenCell | null {
  const stack = board.stacks[position.column];
  if (!stack || position.row < 0 || position.row >= stack.length) return null;
  return stack[position.row];
}

export function valueAt(board: TenBoard, position: Position): number | null {
  return cellAt(board, position)?.value ?? null;
}

/** Dimmed digits count as gone: they cannot be picked, nor block a line. */
export function isDimmed(board: TenBoard, position: Position): boolean {
  return cellAt(board, position)?.dimmed ?? true;
}

/** The digits still in play. */
export function remaining(board: TenBoard): number {
  return board.stacks.reduce(
    (total, column) => total + column.filter((entry) => !entry.dimmed).length,
    0,
  );
}

export function isCleared(board: TenBoard): boolean {
  return board.stacks.every((column) => column.length === 0);
}

/** Every digit that can still be picked, column by column from the bottom. */
export function cells(board: TenBoard): { position: Position; value: number }[] {
  const out: { position: Position; value: number }[] = [];
  board.stacks.forEach((column, columnIndex) => {
    column.forEach((entry, row) => {
      if (!entry.dimmed) out.push({ position: { column: columnIndex, row }, value: entry.value });
    });
  });
  return out;
}

/** Whether a row exists and every digit in it has been taken. */
export function isRowComplete(board: TenBoard, row: number): boolean {
  if (board.stacks.length === 0) return false;
  return board.stacks.every((column) => row >= 0 && row < column.length && column[row].dimmed);
}

/** Two digits pair when they are equal or add up to ten. */
export function valuesPair(a: number, b: number): boolean {
  return a === b || a + b === 10;
}

/**
 * Whether a pair can be taken: the digits pair, and they sit on the same row,
 * column or diagonal with nothing between them. Dimmed digits are missing, so a
 * line can pass straight through them.
 */
export function canMatch(board: TenBoard, a: Position, b: Position): boolean {
  if (a.column === b.column && a.row === b.row) return false;
  const first = cellAt(board, a);
  const second = cellAt(board, b);
  if (!first || !second || first.dimmed || second.dimmed) return false;
  if (!valuesPair(first.value, second.value)) return false;
  if (hasClearLine(board, a, b)) return true;
  if (!board.wrapRows) return false;
  return hasClearWrapLine(board, a, b);
}

/**
 * The rows read end to end: from a square in one row the line runs to the end
 * of that row, wraps round to the start of the next, and carries on. Everything
 * it passes through has to be empty or already taken, which is what lets the
 * last square of a row pair with the first of the next — or, past a taken
 * square, with the second of the next.
 */
export function hasClearWrapLine(board: TenBoard, a: Position, b: Position): boolean {
  const upper = a.row < b.row ? a : b;
  const lower = a.row < b.row ? b : a;
  if (lower.row !== upper.row + 1) return false;

  for (let column = upper.column + 1; column < board.columns; column += 1) {
    const entry = cellAt(board, { column, row: upper.row });
    if (entry && !entry.dimmed) return false;
  }
  for (let column = 0; column < lower.column; column += 1) {
    const entry = cellAt(board, { column, row: lower.row });
    if (entry && !entry.dimmed) return false;
  }
  return true;
}

export function hasClearLine(board: TenBoard, a: Position, b: Position): boolean {
  const down = b.row - a.row;
  const across = b.column - a.column;
  const steps = Math.max(Math.abs(down), Math.abs(across));
  if (steps === 0) return false;
  if (!(down === 0 || across === 0 || Math.abs(down) === Math.abs(across))) return false;

  const stepDown = down / steps;
  const stepAcross = across / steps;
  for (let step = 1; step < steps; step += 1) {
    const between = {
      column: a.column + step * stepAcross,
      row: a.row + step * stepDown,
    };
    const entry = cellAt(board, between);
    if (entry && !entry.dimmed) return false;
  }
  return true;
}

/** Every pair that can be taken right now. */
export function availableMatches(board: TenBoard): [Position, Position][] {
  const all = cells(board);
  const matches: [Position, Position][] = [];
  for (let first = 0; first < all.length; first += 1) {
    for (let second = first + 1; second < all.length; second += 1) {
      if (canMatch(board, all[first].position, all[second].position)) {
        matches.push([all[first].position, all[second].position]);
      }
    }
  }
  return matches;
}

export function hasMoves(board: TenBoard): boolean {
  return availableMatches(board).length > 0;
}

/** Takes a pair the way the chosen mode says to. */
export function take(
  board: TenBoard,
  a: Position,
  b: Position,
  mode: TenMode,
): { board: TenBoard; move: TenMove } | null {
  if (!canMatch(board, a, b)) return null;
  const stacks = board.stacks.map((column) => [...column]);

  if (mode === 'remove') {
    const ordered = [a, b].sort((first, second) => second.row - first.row);
    for (const position of ordered) {
      if (position.row < 0 || position.row >= stacks[position.column].length) continue;
      stacks[position.column].splice(position.row, 1);
    }
    return { board: { ...board, stacks }, move: { rowsCleared: [] } };
  }

  for (const position of [a, b]) {
    const entry = stacks[position.column]?.[position.row];
    if (!entry) continue;
    stacks[position.column][position.row] = { value: entry.value, dimmed: true };
  }

  // A row clears once every digit in it has been taken. Clearing is a cascade:
  // a row dropping onto another finished row clears that one too, which is the
  // same board as clearing both at once.
  const rowsCleared: number[] = [];
  let row = 0;
  for (;;) {
    const tallest = stacks.reduce((most, column) => Math.max(most, column.length), 0);
    if (row >= tallest) break;
    if (!isRowComplete({ ...board, stacks }, row)) {
      row += 1;
      continue;
    }
    stacks.forEach((column) => {
      if (row < column.length) column.splice(row, 1);
    });
    rowsCleared.push(row);
    // No increment: the row above has just dropped into this one.
  }

  return { board: { ...board, stacks }, move: { rowsCleared } };
}

/** Takes a pair off the board, dropping whatever was above it. */
export function remove(board: TenBoard, a: Position, b: Position): TenBoard | null {
  return take(board, a, b, 'remove')?.board ?? null;
}

/**
 * Rows can be added only while the bottom of the grid is free: the board hangs
 * from the top, so the empty space is underneath it.
 */
export function canAddRow(board: TenBoard): boolean {
  return board.stacks.every((column) => column.length < board.rows);
}

/** How many rows would fit under the digits as they are. */
export function roomForRows(board: TenBoard): number {
  const tallest = board.stacks.reduce((most, column) => Math.max(most, column.length), 0);
  return Math.max(0, board.rows - tallest);
}

/** Hangs a fresh row under the digits. Nothing else moves. */
export function addRow(board: TenBoard, digits: number[]): TenBoard | null {
  if (!canAddRow(board) || digits.length < board.columns) return null;
  const stacks = board.stacks.map((column, index) => [...column, cell(digits[index])]);
  return { ...board, stacks };
}
