/**
 * A short, game-scoped id for a player.
 *
 * The global id is long, and it is paid on every presence entry and every move,
 * so each game uses an eight-character id derived from the pair instead.
 * Different games give different ids and the global identity is untouched.
 *
 * Shared rather than copied per game, for the same reason the seeded generator
 * is: two implementations of a hash are two implementations that can disagree,
 * and a disagreement here shows up as two players who cannot see each other.
 * It matches `ShortID.swift` on the phone so both clients agree in a shared
 * game.
 */
export function shortId(playerId: string, gameId: string): string {
  // FNV-1a, 64-bit, in BigInt so the whole thing is exact — a 32-bit hash would
  // start colliding at a few tens of thousands of players and silently merge two
  // people's scores.
  let hash = 0xcbf29ce484222325n;
  const bytes = new TextEncoder().encode(`${playerId}|${gameId}`);
  for (const byte of bytes) {
    hash ^= BigInt(byte);
    hash = (hash * 0x00000100000001b3n) & 0xffffffffffffffffn;
  }
  return hash.toString(16).padStart(16, '0').slice(-8);
}
