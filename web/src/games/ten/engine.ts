import { SeededGenerator, shuffle } from '../../lib/seeded';

/**
 * The Vibe Ten board: nine columns of digits, packed at the bottom.
 *
 * A column is a plain array, bottom first, which is the whole of the gravity
 * rule: take a digit out and the ones above are already one place lower. There
 * are never gaps inside a column.
 *
 * Mirrors `VibeTenBoard.swift`, including the deal: the digits are shuffled with
 * the same SplitMix64 generator the app uses, so a room's seed gives both
 * clients the identical 162 digits and neither can see the other's board.
 */

/** The board a game is dealt with unless another shape is asked for. Columns
    run 6–9 and rows 12–18: every shape fills the screen with bigger digits. */
export const COLUMNS = 9;
export const ROWS = 18;
export const COLUMN_OPTIONS = [6, 7, 8, 9] as const;
export const ROW_OPTIONS = [12, 14, 16, 18] as const;
/** One press of the new-row offer adds this many rows, at most. */
export const ROWS_PER_ADD_OPTIONS = [1, 2, 3, 4] as const;

/** How hard a board is to take apart. */
export type TenDifficulty = 'easy' | 'medium' | 'hard';

export const DIFFICULTIES: TenDifficulty[] = ['easy', 'medium', 'hard'];

export const DIFFICULTY_LABELS: Record<TenDifficulty, { title: string; blurb: string }> = {
  easy: { title: 'Easy', blurb: 'Every pair starts side by side: a gentle board.' },
  medium: {
    title: 'Medium',
    blurb: 'Some pairs start two or three squares apart, with other digits between them.',
  },
  hard: {
    title: 'Hard',
    blurb:
      'Whole rows are nested: the pair at the edge of a row only comes together once the digits either side of it are gone.',
  },
};

/** The widest run of columns a row's pairs are nested across. */
const BLOCK_SIZE: Record<TenDifficulty, number> = { easy: 2, medium: 4, hard: 64 };

/** One pair, and where it was placed — the reverse of a take. */
export interface DealStep {
  readonly first: Position;
  readonly second: Position;
  readonly firstValue: number;
  readonly secondValue: number;
}

/** How much of the grid a game starts with. */
export type TenStartFill = 'full' | 'third';

export const START_FILL_LABELS: Record<TenStartFill, { title: string; blurb: string }> = {
  full: { title: 'Full', blurb: 'The whole grid, as it has always been.' },
  third: {
    title: 'One third',
    blurb: 'A third of the rows to start with, and room below for the new rows to fill.',
  },
};

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
  /** How hard it was to take apart. Part of the deal, like the seed. */
  readonly difficulty: TenDifficulty;
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
 * Deals a board, and records how it was made.
 *
 * A random shuffle of the right digits is a board with a random chance of being
 * finishable — usually none. So the board is built the other way round: pairs are
 * placed one at a time, each where it can be seen, and the order they are placed
 * in, read backwards, is a solution. The difficulty changes where a pair ends up:
 * the pairs of a row are nested inside one another, so an outer pair is only
 * uncovered once the row's inner pairs have gone.
 *
 * The recipe has to match `VibeTenBoard.plan` exactly — same generator, same five
 * groups, same draws in the same order — because a room's board comes back from
 * one seed. `board.fixtures.json` pins it.
 */
export function plan(
  seed: number,
  columns: number,
  rows: number,
  difficulty: TenDifficulty,
): { steps: DealStep[]; stacks: TenCell[][] } {
  const generator = new SeededGenerator(seed);

  // How many pairs of each kind. A fives-pair puts two 5s on the board and every
  // other pair puts one of each digit, so the fives need half as many pairs as
  // the others to keep the digits even.
  const pairs = Math.floor((columns * rows) / 2);
  const fivePairs = Math.floor((2 * pairs + 9) / 18);
  const otherPairs = pairs - fivePairs;

  const order = [0, 1, 2, 3];
  shuffle(order, generator);
  const groupPairs = [0, 0, 0, 0].map(() => Math.floor(otherPairs / 4));
  for (let index = 0; index < otherPairs % 4; index += 1) groupPairs[order[index]] += 1;

  const deck: [number, number][] = [];
  for (let group = 0; group < 5; group += 1) {
    if (group === 4) {
      for (let index = 0; index < fivePairs; index += 1) deck.push([5, 5]);
      continue;
    }
    const count = groupPairs[group];
    const low = group + 1;
    const high = 10 - low;
    // Equal pairs are kept rare: a run of them reads as a column of one digit,
    // which is not a dealt board.
    const equal = generator.nextBounded(Math.min(2, Math.floor(count / 2)) + 1);
    for (let index = 0; index < equal; index += 1) deck.push([low, low]);
    for (let index = 0; index < equal; index += 1) deck.push([high, high]);
    for (let index = 0; index < count - 2 * equal; index += 1) deck.push([low, high]);
  }
  shuffle(deck, generator);

  const stacks: TenCell[][] = Array.from({ length: columns }, () => []);
  const steps: DealStep[] = [];
  let nextPair = 0;

  const takePair = (): [number, number] => {
    const pair = deck[nextPair];
    nextPair += 1;
    return generator.nextBounded(2) === 1 ? [pair[1], pair[0]] : pair;
  };

  const place = (value: number, column: number, row: number) => {
    stacks[column].splice(Math.min(row, stacks[column].length), 0, cell(value));
  };

  for (let row = 0; row < rows; row += 1) {
    // A column that already has this row's digit took a vertical pair from the
    // row above; it comes back a row later.
    const available: number[] = [];
    for (let column = 0; column < columns; column += 1) {
      if (stacks[column].length === row) available.push(column);
    }
    let vertical: number | null = null;
    // An odd row of columns leaves one over, which goes down instead of across.
    // It is always the last column, so the squares left to pair stay one
    // unbroken run.
    if (available.length % 2 === 1) vertical = available.pop() ?? null;

    // The row's pairs, outermost first inside each block.
    let cursor = 0;
    while (cursor < available.length) {
      const size = Math.min(BLOCK_SIZE[difficulty], available.length - cursor);
      const block = available.slice(cursor, cursor + size);
      cursor += size;
      let low = 0;
      let high = block.length - 1;
      while (low < high) {
        const first = block[low];
        const second = block[high];
        low += 1;
        high -= 1;
        const digits = takePair();
        place(digits[0], first, row);
        place(digits[1], second, row);
        steps.push({
          first: { column: first, row },
          second: { column: second, row },
          firstValue: digits[0],
          secondValue: digits[1],
        });
      }
    }

    // The vertical pair goes last, so it never blocks its own row.
    if (vertical !== null) {
      const digits = takePair();
      place(digits[0], vertical, row);
      place(digits[1], vertical, row + 1);
      steps.push({
        first: { column: vertical, row },
        second: { column: vertical, row: row + 1 },
        firstValue: digits[0],
        secondValue: digits[1],
      });
    }
  }

  return { steps, stacks };
}

/**
 * The board a game is dealt: the plan's squares, trimmed to `startRows` so a
 * part-filled board is the top of the same deal hanging from the top of the grid.
 */
export function newBoard(
  seed: number,
  columns = COLUMNS,
  rows = ROWS,
  startRows = rows,
  wrapRows = false,
  difficulty: TenDifficulty = 'medium',
): TenBoard {
  const { stacks } = plan(seed, columns, rows, difficulty);
  // A part-filled board keeps whole pairs off the top, so it is clearable the
  // same way the full board is.
  let kept = Math.max(1, Math.min(rows, startRows));
  if (kept % 2 === 1) kept = Math.max(2, kept - 1);
  return {
    seed,
    columns,
    rows,
    wrapRows,
    difficulty,
    stacks: stacks.map((column) => column.slice(0, kept)),
  };
}

export function boardFromStacks(
  stacks: number[][],
  seed = 0,
  shape: {
    columns?: number;
    rows?: number;
    wrapRows?: boolean;
    difficulty?: TenDifficulty;
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
    difficulty: shape.difficulty ?? 'medium',
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
