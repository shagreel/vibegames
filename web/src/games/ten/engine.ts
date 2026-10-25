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
    blurb:
      'Pairs are nested across a row, down a column, corner to corner, or round the join between two rows.',
  },
  hard: {
    title: 'Hard',
    blurb:
      'Whole rows and whole columns are nested: the pair at the edge of a band only comes together once the digits around it are gone.',
  },
};

/** How one band of rows is filled.
 *
 * `sideBySide` is Easy: adjacent pairs along each row. The rest are nested along
 * the four lines a pair can be found on — a row, a column, a diagonal, or, when
 * the rows join end to end, round the join — so a harder board can need a column
 * cleared before a row.
 */
export type TenBandPattern = 'sideBySide' | 'rows' | 'columns' | 'diagonals' | 'wrap';

/** A block of rows and the way it is filled. A pair never spans two bands, so
 * every band can be cleared on its own. */
export interface TenBand {
  readonly start: number;
  readonly height: number;
  readonly pattern: TenBandPattern;
}

/** A pair at the rows and columns it will occupy in the finished board. */
interface DealTarget {
  readonly first: Position;
  readonly second: Position;
}

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
 * finishable — usually none. So the board is built the other way round: the grid
 * is cut into bands of rows, each band is filled with pairs nested along its own
 * lines, and the pairs are placed one at a time in an order where each can be
 * seen. Read backwards, the placements are a way to clear the board.
 *
 * The recipe has to match `VibeTenBoard.plan` exactly — same generator, same
 * draws in the same order — because a room's board comes back from one seed.
 * `board.fixtures.json` pins it.
 */
export function plan(
  seed: number,
  columns: number,
  rows: number,
  difficulty: TenDifficulty,
  wrapRows = false,
): { steps: DealStep[]; stacks: TenCell[][]; bandEnds: number[] } {
  const generator = new SeededGenerator(seed);

  const heights = bandHeights(rows, difficulty, wrapRows, generator);
  const patterns = bandPatterns(heights, difficulty, wrapRows, generator);
  let start = 0;
  const bands: TenBand[] = heights.map((height, index) => {
    const band: TenBand = { start, height, pattern: patterns[index] };
    start += height;
    return band;
  });

  const deck = makeDeck(Math.floor((columns * rows) / 2), generator);

  // The pairs of every band, in placing order. Bands are dealt top to bottom, so
  // clearing the finished board runs bottom to top: nothing below a band is left
  // to move it, and a band comes apart from the inside out.
  const targets = bands.flatMap((band) => targetsFor(band, columns));

  const columnsCells: { row: number; cell: TenCell }[][] = Array.from(
    { length: columns },
    () => [],
  );
  const steps: DealStep[] = [];
  let nextPair = 0;

  const takePair = (): [number, number] => {
    const pair = deck[nextPair];
    nextPair += 1;
    return generator.nextBounded(2) === 1 ? [pair[1], pair[0]] : [pair[0], pair[1]];
  };

  /** Puts one digit into its column in front of every digit that will end up
   * below it, and says which row it landed in. The digits already there were
   * placed earlier, so they end up below: that is how a pair laid down first
   * ends up outside the pairs placed after it. */
  const place = (value: number, target: Position): Position => {
    let index = 0;
    while (
      index < columnsCells[target.column].length &&
      columnsCells[target.column][index].row < target.row
    ) {
      index += 1;
    }
    columnsCells[target.column].splice(index, 0, { row: target.row, cell: cell(value) });
    return { column: target.column, row: index };
  };

  for (const target of targets) {
    const digits = takePair();
    // The upper square of a pair goes in first when they share a column, so the
    // lower one lands underneath it.
    const firstIsUpper = target.first.row <= target.second.row;
    const upper = firstIsUpper ? target.first : target.second;
    const lower = firstIsUpper ? target.second : target.first;
    const upperValue = firstIsUpper ? digits[0] : digits[1];
    const lowerValue = firstIsUpper ? digits[1] : digits[0];
    const placedUpper = place(upperValue, upper);
    const placedLower = place(lowerValue, lower);
    steps.push({
      first: placedUpper,
      second: placedLower,
      firstValue: upperValue,
      secondValue: lowerValue,
    });
  }

  return {
    steps,
    stacks: columnsCells.map((column) => column.map((entry) => entry.cell)),
    bandEnds: bands.map((band) => band.start + band.height),
  };
}

/** The bands a full board is dealt in.
 *
 * Easy and Medium are two rows at a time. Hard is taller, so a pair can be
 * nested down a column as well as across a row, and it opens with a two-row band
 * of diagonals — and, when the rows join, one of wrap pairs — so those lines are
 * always part of the puzzle.
 */
export function bandHeights(
  rows: number,
  difficulty: TenDifficulty,
  wrapRows: boolean,
  generator: SeededGenerator,
): number[] {
  if (rows <= 2) return [rows];
  if (difficulty !== 'hard') {
    return Array.from({ length: Math.floor(rows / 2) }, () => 2);
  }
  const heights: number[] = [];
  let remaining = rows;
  // A deep band first, then the two-row ones: that puts a band boundary at four
  // and at six rows, which is where a third of every shape falls, so "start with
  // one third" keeps a whole band instead of dropping to the first two rows.
  heights.push(4);
  remaining -= 4;
  if (wrapRows) {
    heights.push(2);
    remaining -= 2;
  }
  heights.push(2);
  remaining -= 2;
  while (remaining > 0) {
    const options = [4, 6, 8].filter(
      (height) => height <= remaining && (remaining - height === 0 || remaining - height >= 4),
    );
    let height: number;
    if (options.length === 0) {
      height = remaining;
    } else if (options.length === 1) {
      height = options[0];
    } else {
      height = options[generator.nextBounded(options.length)];
    }
    heights.push(height);
    remaining -= height;
  }
  return heights;
}

function bandPatterns(
  heights: number[],
  difficulty: TenDifficulty,
  wrapRows: boolean,
  generator: SeededGenerator,
): TenBandPattern[] {
  if (difficulty === 'easy') return heights.map(() => 'sideBySide');
  if (difficulty === 'medium') {
    return heights.map((_, index) => {
      if (index === 0) return wrapRows ? 'wrap' : 'diagonals';
      return randomPattern(wrapRows, generator);
    });
  }
  const patterns: TenBandPattern[] = [];
  let sawTwoRow = false;
  let sawTall = false;
  heights.forEach((height) => {
    if (height === 2) {
      patterns.push(wrapRows && !sawTwoRow ? 'wrap' : 'diagonals');
      sawTwoRow = true;
      return;
    }
    // Tall bands are whole rows or whole columns, and they alternate so a hard
    // board is not all one line.
    if (sawTall) {
      patterns.push(patterns[patterns.length - 1] === 'columns' ? 'rows' : 'columns');
    } else {
      patterns.push(generator.nextBounded(2) === 1 ? 'columns' : 'rows');
      sawTall = true;
    }
  });
  return patterns;
}

/** A pattern for a two-row Medium band: mostly rows, some columns and
 * diagonals, and the join when the rules allow it. */
function randomPattern(wrapRows: boolean, generator: SeededGenerator): TenBandPattern {
  const choices: TenBandPattern[] = [
    'rows',
    'rows',
    'rows',
    'columns',
    'columns',
    'diagonals',
    'diagonals',
  ];
  if (wrapRows) choices.push('wrap', 'wrap');
  return choices[generator.nextBounded(choices.length)];
}

/** The digits a board is dealt from.
 *
 * Balanced so every digit appears about as often as every other, and with both
 * kinds of pair guaranteed: some equal pairs (two of a number) and plenty that
 * add to ten. A pair of fives is both, so it gets its own smaller share of the
 * deck.
 */
export function makeDeck(pairs: number, generator: SeededGenerator): [number, number][] {
  // A fives-pair puts two 5s on the board and every other pair puts one of each
  // digit, so the fives need half as many pairs as the others to keep the digits
  // even.
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
    if (count < 3) {
      for (let index = 0; index < Math.max(0, count); index += 1) deck.push([low, high]);
      continue;
    }
    // At least one equal pair, and at least one that adds to ten: the board is
    // the game, and both kinds of pair are the game.
    const most = Math.min(2, Math.floor((count - 1) / 2));
    const equal = most === 1 ? 1 : 1 + generator.nextBounded(most);
    for (let index = 0; index < equal; index += 1) deck.push([low, low]);
    for (let index = 0; index < equal; index += 1) deck.push([high, high]);
    for (let index = 0; index < count - 2 * equal; index += 1) deck.push([low, high]);
  }
  shuffle(deck, generator);
  return deck;
}

/** The pairs of a band, in placing order: outermost first, so every pair can
 * see itself when it arrives and the pairs that cover it arrive later. */
function targetsFor(band: TenBand, columns: number): DealTarget[] {
  const targets: DealTarget[] = [];
  const top = band.start;
  const bottom = band.start + band.height - 1;
  const add = (first: Position, second: Position) => targets.push({ first, second });

  switch (band.pattern) {
    case 'sideBySide': {
      const last = columns - (columns % 2 === 0 ? 1 : 2);
      for (let row = top; row <= bottom; row += 1) {
        for (let column = 0; column < last; column += 2) {
          add({ column, row }, { column: column + 1, row });
        }
      }
      if (columns % 2 === 1) {
        add({ column: columns - 1, row: top }, { column: columns - 1, row: bottom });
      }
      break;
    }
    case 'rows': {
      const last = columns - (columns % 2 === 0 ? 1 : 2);
      for (let row = top; row <= bottom; row += 1) {
        let low = 0;
        let high = last;
        while (low < high) {
          add({ column: low, row }, { column: high, row });
          low += 1;
          high -= 1;
        }
      }
      if (columns % 2 === 1) {
        // The odd column left over by every row is nested down the band.
        let low = top;
        let high = bottom;
        while (low < high) {
          add({ column: columns - 1, row: low }, { column: columns - 1, row: high });
          low += 1;
          high -= 1;
        }
      }
      break;
    }
    case 'columns': {
      for (let column = 0; column < columns; column += 1) {
        let low = top;
        let high = bottom;
        while (low < high) {
          add({ column, row: low }, { column, row: high });
          low += 1;
          high -= 1;
        }
      }
      break;
    }
    case 'diagonals': {
      let column = 0;
      while (column + 1 < columns) {
        add({ column, row: top }, { column: column + 1, row: bottom });
        add({ column, row: bottom }, { column: column + 1, row: top });
        column += 2;
      }
      if (column < columns) add({ column, row: top }, { column, row: bottom });
      break;
    }
    case 'wrap': {
      // The two ends of the join. The pair that runs the whole way round is
      // placed first and ends up outermost; the pair that owns the join itself
      // goes next; the columns between them are filled with vertical pairs,
      // which end up inside both. So the finished band is a long wrap pair
      // holding a short wrap pair holding the middle.
      if (columns > 2) {
        add({ column: 0, row: top }, { column: columns - 1, row: bottom });
        add({ column: columns - 1, row: top }, { column: 0, row: bottom });
        for (let column = 1; column < columns - 1; column += 1) {
          add({ column, row: top }, { column, row: bottom });
        }
      } else {
        add({ column: 0, row: top }, { column: columns - 1, row: bottom });
      }
      break;
    }
    default:
      break;
  }

  return targets;
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
  const { stacks, bandEnds } = plan(seed, columns, rows, difficulty, wrapRows);
  // A part-filled board keeps whole bands off the top, so every pair it holds is
  // still whole and it is clearable the same way the full board is.
  const wanted = Math.max(1, Math.min(rows, startRows));
  const kept = [...bandEnds].reverse().find((end) => end <= wanted) ?? bandEnds[0] ?? wanted;
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
