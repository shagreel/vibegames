import { describe, expect, it } from 'vitest';
import { rank, snapshotFrom, type TenStanding } from '../games/ten/service';

/**
 * The room's rule, away from the screen: the first player to clear the board
 * wins, and the pairs are the running total behind that.
 */

const standing = (
  name: string,
  score: number,
  clearedAt: number | null = null,
  finishedAt: number | null = null,
): TenStanding => ({ id: name, name, score, finishedAt, clearedAt });

describe('the room rule', () => {
  it('puts the first clear first', () => {
    const ranked = rank([
      standing('Sam', 20, 200),
      standing('Alex', 5, 100),
      standing('Kit', 30),
    ]);
    expect(ranked.map((entry) => entry.name)).toEqual(['Alex', 'Sam', 'Kit']);
  });

  it('falls back to the pairs when nobody has cleared', () => {
    const ranked = rank([
      standing('Sam', 12, null, 300),
      standing('Alex', 20, null, 500),
      standing('Kit', 20),
    ]);
    expect(ranked.map((entry) => entry.name)).toEqual(['Alex', 'Kit', 'Sam']);
  });

  it('reads the rows per press and the clears out of the room', () => {
    const plain = snapshotFrom({ meta: { seed: 1 } });
    expect(plain.rowsPerAdd).toBe(1);
    expect(plain.rows).toBe(18);

    const room = snapshotFrom({
      meta: { seed: 1, rows: 12, rowsPerAdd: 3, wrap: true, mode: 'dim' },
      players: { me: { name: 'Me' } },
      scores: { me: { score: 4, finishedAt: 500, clearedAt: 500 } },
    });
    expect(room.rows).toBe(12);
    expect(room.rowsPerAdd).toBe(3);
    expect(room.wrapRows).toBe(true);
    expect(room.mode).toBe('dim');
    expect(room.scores.me.clearedAt).toBe(500);

    const nonsense = snapshotFrom({ meta: { seed: 1, rowsPerAdd: 9 } });
    expect(nonsense.rowsPerAdd, 'a press can only add one to four rows').toBe(1);
  });
});
