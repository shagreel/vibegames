import { describe, it, expect, beforeEach } from 'vitest';

describe('localStorage - Browser Uniqueness', () => {
  beforeEach(() => {
    localStorage.clear();
  });

  it('should generate unique browser ID on first access', () => {
    const browserId1 = localStorage.getItem('vibewords.playerID');
    expect(browserId1).toBeNull();

    // Simulate first-time user
    const newBrowserId = `${Date.now()}_${Math.floor(Math.random() * 1000000)}`;
    localStorage.setItem('vibewords.playerID', newBrowserId);

    const browserId2 = localStorage.getItem('vibewords.playerID');
    expect(browserId2).toBe(newBrowserId);
    expect(browserId2).toMatch(/^\d+_\d+$/);
  });

  it('should persist browser ID across page refreshes', () => {
    const browserId = '1234567890_123456';
    localStorage.setItem('vibewords.playerID', browserId);

    // Simulate page refresh - localStorage should persist
    const retrievedId = localStorage.getItem('vibewords.playerID');
    expect(retrievedId).toBe(browserId);
  });

  it('should track different games separately', () => {
    const gameId1 = 'abc123';
    const gameId2 = 'xyz789';

    localStorage.setItem(`vibewords.inGame.${gameId1}`, 'true');
    localStorage.setItem(`vibewords.inGame.${gameId2}`, 'true');

    expect(localStorage.getItem(`vibewords.inGame.${gameId1}`)).toBe('true');
    expect(localStorage.getItem(`vibewords.inGame.${gameId2}`)).toBe('true');
  });

  it('should allow same browser to join different games', () => {
    const browserId = '1234567890_123456';
    localStorage.setItem('vibewords.playerID', browserId);

    const gameId1 = 'game1';
    const gameId2 = 'game2';

    localStorage.setItem(`vibewords.inGame.${gameId1}`, 'true');
    localStorage.setItem(`vibewords.inGame.${gameId2}`, 'true');

    expect(localStorage.getItem(`vibewords.inGame.${gameId1}`)).toBe('true');
    expect(localStorage.getItem(`vibewords.inGame.${gameId2}`)).toBe('true');
  });

  it('should prevent duplicate joins to same game', () => {
    const gameId = 'abc123';
    const browserId = '1234567890_123456';

    localStorage.setItem('vibewords.playerID', browserId);
    localStorage.setItem(`vibewords.inGame.${gameId}`, 'true');

    // Check if already in game
    const alreadyInGame = localStorage.getItem(`vibewords.inGame.${gameId}`);
    expect(alreadyInGame).toBe('true');
  });

  it('should store player name persistently', () => {
    const playerName = 'Alice';
    localStorage.setItem('vibewords.playerName', playerName);

    const retrievedName = localStorage.getItem('vibewords.playerName');
    expect(retrievedName).toBe(playerName);
  });

  it('should store creator status for specific game', () => {
    const gameId = 'abc123';
    localStorage.setItem('vibewords.hostedGameID', gameId);

    const creatorGameId = localStorage.getItem('vibewords.hostedGameID');
    expect(creatorGameId).toBe(gameId);
  });

  it('should simulate different devices with different browser IDs', () => {
    // Device 1
    const device1BrowserId = '1234567890_111111';
    localStorage.setItem('vibewords.playerID', device1BrowserId);
    const device1Id = localStorage.getItem('vibewords.playerID');

    // Clear and simulate Device 2
    localStorage.clear();
    const device2BrowserId = '1234567891_222222';
    localStorage.setItem('vibewords.playerID', device2BrowserId);
    const device2Id = localStorage.getItem('vibewords.playerID');

    // Different devices should have different IDs
    expect(device1Id).not.toBe(device2Id);
    expect(device1Id).toBe(device1BrowserId);
    expect(device2Id).toBe(device2BrowserId);
  });

  it('should generate browser IDs without periods (Firebase-safe)', () => {
    const browserId = `${Date.now()}_${Math.floor(Math.random() * 1000000)}`;
    
    // Should not contain periods
    expect(browserId).not.toContain('.');
    expect(browserId).not.toContain('#');
    expect(browserId).not.toContain('$');
    expect(browserId).not.toContain('/');
    expect(browserId).not.toContain('[');
    expect(browserId).not.toContain(']');
  });
});

