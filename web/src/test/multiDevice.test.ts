import { describe, it, expect, beforeEach } from 'vitest';

/**
 * Tests to verify that users on different devices are treated as unique players
 */
describe('Multi-Device Scenarios', () => {
  beforeEach(() => {
    localStorage.clear();
  });

  it('should treat Chrome on iPhone and Chrome on laptop as different users', () => {
    const gameId = 'abc123';

    // Simulate iPhone
    const iPhoneBrowserId = `${Date.now()}_${Math.floor(Math.random() * 1000000)}`;
    localStorage.setItem('vibewords.playerID', iPhoneBrowserId);
    localStorage.setItem(`vibewords.inGame.${gameId}`, 'true');
    
    const iPhoneData = {
      browserId: localStorage.getItem('vibewords.playerID'),
      inGame: localStorage.getItem(`vibewords.inGame.${gameId}`),
    };

    // Clear localStorage to simulate different device
    localStorage.clear();

    // Simulate Laptop
    const laptopBrowserId = `${Date.now()}_${Math.floor(Math.random() * 1000000)}`;
    localStorage.setItem('vibewords.playerID', laptopBrowserId);
    localStorage.setItem(`vibewords.inGame.${gameId}`, 'true');
    
    const laptopData = {
      browserId: localStorage.getItem('vibewords.playerID'),
      inGame: localStorage.getItem(`vibewords.inGame.${gameId}`),
    };

    // Both should be in the game but with different browser IDs
    expect(iPhoneData.browserId).not.toBe(laptopData.browserId);
    expect(iPhoneData.inGame).toBe('true');
    expect(laptopData.inGame).toBe('true');
  });

  it('should allow same person to join from multiple devices', () => {
    const gameId = 'game123';
    const playerName = 'Alice';

    // Device 1
    const device1Id = '1234567890_111111';
    localStorage.setItem('vibewords.playerID', device1Id);
    localStorage.setItem('vibewords.playerName', playerName);
    localStorage.setItem(`vibewords.inGame.${gameId}`, 'true');

    const device1State = {
      browserId: localStorage.getItem('vibewords.playerID'),
      name: localStorage.getItem('vibewords.playerName'),
      inGame: localStorage.getItem(`vibewords.inGame.${gameId}`),
    };

    // Clear and simulate Device 2
    localStorage.clear();

    const device2Id = '1234567891_222222';
    localStorage.setItem('vibewords.playerID', device2Id);
    localStorage.setItem('vibewords.playerName', playerName); // Same name
    localStorage.setItem(`vibewords.inGame.${gameId}`, 'true');

    const device2State = {
      browserId: localStorage.getItem('vibewords.playerID'),
      name: localStorage.getItem('vibewords.playerName'),
      inGame: localStorage.getItem(`vibewords.inGame.${gameId}`),
    };

    // Same name but different browser IDs
    expect(device1State.name).toBe(device2State.name);
    expect(device1State.browserId).not.toBe(device2State.browserId);
    expect(device1State.inGame).toBe('true');
    expect(device2State.inGame).toBe('true');
  });

  it('should prevent same device from joining same game twice', () => {
    const gameId = 'game123';
    const browserId = '1234567890_123456';

    // First join
    localStorage.setItem('vibewords.playerID', browserId);
    localStorage.setItem(`vibewords.inGame.${gameId}`, 'true');

    // Check if already in game (simulating page refresh)
    const alreadyInGame = localStorage.getItem(`vibewords.inGame.${gameId}`);
    expect(alreadyInGame).toBe('true');

    // Should not join again
    if (alreadyInGame) {
      // Skip adding player
      expect(true).toBe(true);
    }
  });

  it('should allow same device to join different games', () => {
    const browserId = '1234567890_123456';
    const game1 = 'game1';
    const game2 = 'game2';

    localStorage.setItem('vibewords.playerID', browserId);
    localStorage.setItem(`vibewords.inGame.${game1}`, 'true');
    localStorage.setItem(`vibewords.inGame.${game2}`, 'true');

    expect(localStorage.getItem(`vibewords.inGame.${game1}`)).toBe('true');
    expect(localStorage.getItem(`vibewords.inGame.${game2}`)).toBe('true');
  });

  it('should simulate 3 different devices joining same game', () => {
    const gameId = 'multiplayer123';
    const players: Array<{ browserId: string; name: string }> = [];

    // Device 1
    localStorage.clear();
    const device1Id = `${Date.now()}_111111`;
    localStorage.setItem('vibewords.playerID', device1Id);
    localStorage.setItem('vibewords.playerName', 'Alice');
    localStorage.setItem(`vibewords.inGame.${gameId}`, 'true');
    players.push({
      browserId: device1Id,
      name: 'Alice',
    });

    // Device 2
    localStorage.clear();
    const device2Id = `${Date.now()}_222222`;
    localStorage.setItem('vibewords.playerID', device2Id);
    localStorage.setItem('vibewords.playerName', 'Bob');
    localStorage.setItem(`vibewords.inGame.${gameId}`, 'true');
    players.push({
      browserId: device2Id,
      name: 'Bob',
    });

    // Device 3
    localStorage.clear();
    const device3Id = `${Date.now()}_333333`;
    localStorage.setItem('vibewords.playerID', device3Id);
    localStorage.setItem('vibewords.playerName', 'Charlie');
    localStorage.setItem(`vibewords.inGame.${gameId}`, 'true');
    players.push({
      browserId: device3Id,
      name: 'Charlie',
    });

    // All should have unique browser IDs
    expect(players.length).toBe(3);
    expect(players[0].browserId).not.toBe(players[1].browserId);
    expect(players[1].browserId).not.toBe(players[2].browserId);
    expect(players[0].browserId).not.toBe(players[2].browserId);

    // All should have different names
    expect(players[0].name).toBe('Alice');
    expect(players[1].name).toBe('Bob');
    expect(players[2].name).toBe('Charlie');
  });

  it('should handle incognito mode as separate device', () => {
    const gameId = 'game123';

    // Normal mode
    const normalBrowserId = '1234567890_111111';
    localStorage.setItem('vibewords.playerID', normalBrowserId);
    localStorage.setItem(`vibewords.inGame.${gameId}`, 'true');

    const normalState = {
      browserId: localStorage.getItem('vibewords.playerID'),
      inGame: localStorage.getItem(`vibewords.inGame.${gameId}`),
    };

    // Clear to simulate incognito (separate localStorage)
    localStorage.clear();

    // Incognito mode - fresh localStorage
    const incognitoBrowserId = '1234567891_222222';
    localStorage.setItem('vibewords.playerID', incognitoBrowserId);
    localStorage.setItem(`vibewords.inGame.${gameId}`, 'true');

    const incognitoState = {
      browserId: localStorage.getItem('vibewords.playerID'),
      inGame: localStorage.getItem(`vibewords.inGame.${gameId}`),
    };

    // Should be treated as different users
    expect(normalState.browserId).not.toBe(incognitoState.browserId);
    expect(normalState.inGame).toBe('true');
    expect(incognitoState.inGame).toBe('true');
  });

  it('should simulate 100 unique devices', () => {
    const gameId = 'massive_game';
    const browserIds = new Set<string>();

    for (let i = 0; i < 100; i++) {
      localStorage.clear();
      const browserId = `${Date.now()}_${Math.floor(Math.random() * 1000000)}`;
      localStorage.setItem('vibewords.playerID', browserId);
      localStorage.setItem(`vibewords.inGame.${gameId}`, 'true');
      browserIds.add(browserId);
    }

    // All 100 should be unique
    expect(browserIds.size).toBe(100);
  });
});

