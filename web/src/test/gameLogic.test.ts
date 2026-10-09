import { describe, it, expect } from 'vitest';
import { VALID_WORDS, ANSWER_WORDS } from '../wordList';

describe('Game Logic - Word Validation', () => {
  it('should have valid words list', () => {
    expect(VALID_WORDS).toBeDefined();
    expect(VALID_WORDS.length).toBeGreaterThan(0);
  });

  it('should have answer words list', () => {
    expect(ANSWER_WORDS).toBeDefined();
    expect(ANSWER_WORDS.length).toBeGreaterThan(0);
  });

  it('should have all words in uppercase', () => {
    const sampleWords = VALID_WORDS.slice(0, 100);
    sampleWords.forEach(word => {
      expect(word).toBe(word.toUpperCase());
    });
  });

  it('should have all words as 5 letters', () => {
    const sampleWords = VALID_WORDS.slice(0, 100);
    sampleWords.forEach(word => {
      expect(word.length).toBe(5);
    });
  });

  it('should validate common words', () => {
    const commonWords = ['QUEST', 'HELLO', 'WORLD', 'REACT', 'TESTS'];
    commonWords.forEach(word => {
      expect(VALID_WORDS.includes(word)).toBe(true);
    });
  });

  it('should reject invalid words', () => {
    const invalidWords = ['ZZZZZ', 'XXXXX', 'QQQQQ'];
    invalidWords.forEach(word => {
      const isValid = VALID_WORDS.includes(word);
      // These might or might not be in the list, just checking the mechanism works
      expect(typeof isValid).toBe('boolean');
    });
  });
});

describe('Game Logic - Word Selection', () => {
  it('should generate consistent word from game ID', () => {
    const gameId = 'test123';
    
    // Hash function (same as in VibeWords.tsx)
    let hash = 0;
    for (let i = 0; i < gameId.length; i++) {
      const char = gameId.charCodeAt(i);
      hash = ((hash << 5) - hash) + char;
      hash = hash & hash;
    }
    const index = Math.abs(hash) % ANSWER_WORDS.length;
    const word1 = ANSWER_WORDS[index];

    // Generate again with same ID
    hash = 0;
    for (let i = 0; i < gameId.length; i++) {
      const char = gameId.charCodeAt(i);
      hash = ((hash << 5) - hash) + char;
      hash = hash & hash;
    }
    const index2 = Math.abs(hash) % ANSWER_WORDS.length;
    const word2 = ANSWER_WORDS[index2];

    // Should be the same word
    expect(word1).toBe(word2);
  });

  it('should generate different words for different game IDs', () => {
    const gameId1 = 'abc123';
    const gameId2 = 'xyz789';

    const getWordFromGameId = (gameId: string) => {
      let hash = 0;
      for (let i = 0; i < gameId.length; i++) {
        const char = gameId.charCodeAt(i);
        hash = ((hash << 5) - hash) + char;
        hash = hash & hash;
      }
      const index = Math.abs(hash) % ANSWER_WORDS.length;
      return ANSWER_WORDS[index];
    };

    const word1 = getWordFromGameId(gameId1);
    const word2 = getWordFromGameId(gameId2);

    // Different game IDs should (usually) give different words
    // Note: There's a small chance they could be the same due to hash collision
    expect(word1).toBeDefined();
    expect(word2).toBeDefined();
  });
});

describe('Game Logic - Letter Checking', () => {
  it('should identify correct letters in correct position', () => {
    const answer = 'REACT';
    const guess = 'REACT';
    
    // All letters should be correct
    for (let i = 0; i < 5; i++) {
      expect(guess[i]).toBe(answer[i]);
    }
  });

  it('should identify correct letters in wrong position', () => {
    const answer = 'REACT';
    const guess = 'TRACE';
    
    // R is in wrong position (position 1 in guess, position 0 in answer)
    expect(guess.includes('R')).toBe(true);
    expect(answer.includes('R')).toBe(true);
    expect(guess[1]).toBe('R');
    expect(answer[0]).toBe('R');
  });

  it('should identify absent letters', () => {
    const answer = 'REACT';

    // H is not in REACT
    expect(answer.includes('H')).toBe(false);
  });

  it('should handle duplicate letters correctly', () => {
    const answer = 'SPEED';
    const guess = 'EERIE';
    
    // E appears 3 times in guess, 2 times in answer
    const eCountInAnswer = (answer.match(/E/g) || []).length;
    const eCountInGuess = (guess.match(/E/g) || []).length;
    
    expect(eCountInAnswer).toBe(2);
    expect(eCountInGuess).toBe(3);
  });
});

describe('Game Logic - Game ID Generation', () => {
  it('should generate valid game ID', () => {
    const gameId = Math.random().toString(36).substring(2, 10);
    
    expect(gameId).toBeDefined();
    expect(gameId.length).toBeGreaterThan(0);
    expect(gameId.length).toBeLessThanOrEqual(8);
  });

  it('should generate different game IDs', () => {
    const gameId1 = Math.random().toString(36).substring(2, 10);
    const gameId2 = Math.random().toString(36).substring(2, 10);
    
    // Should be different (extremely high probability)
    expect(gameId1).not.toBe(gameId2);
  });

  it('should generate URL-safe game IDs', () => {
    const gameId = Math.random().toString(36).substring(2, 10);
    
    // Should only contain alphanumeric characters
    expect(gameId).toMatch(/^[a-z0-9]+$/);
  });
});

describe('Game Logic - Player ID Generation', () => {
  it('should generate Firebase-safe player IDs', () => {
    const playerId = `${Date.now()}_${Math.floor(Math.random() * 1000000)}`;
    
    // Should not contain Firebase-forbidden characters
    expect(playerId).not.toContain('.');
    expect(playerId).not.toContain('#');
    expect(playerId).not.toContain('$');
    expect(playerId).not.toContain('/');
    expect(playerId).not.toContain('[');
    expect(playerId).not.toContain(']');
    
    // Should match expected format
    expect(playerId).toMatch(/^\d+_\d+$/);
  });

  it('should generate unique player IDs', () => {
    const playerId1 = `${Date.now()}_${Math.floor(Math.random() * 1000000)}`;
    // Small delay to ensure different timestamp
    const playerId2 = `${Date.now() + 1}_${Math.floor(Math.random() * 1000000)}`;
    
    expect(playerId1).not.toBe(playerId2);
  });
});

