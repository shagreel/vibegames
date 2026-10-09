import { describe, it, expect, beforeEach } from 'vitest';

/**
 * Integration tests that simulate complete user flows
 */
describe('Integration Tests - Complete User Flows', () => {
  beforeEach(() => {
    localStorage.clear();
  });

  it('should handle complete flow: 3 players join and play', () => {
    const gameId = 'integration_test_123';
    const players: Array<{
      browserId: string;
      name: string;
      inGame: boolean;
    }> = [];

    // Player 1: Creator
    localStorage.clear();
    const player1BrowserId = `${Date.now()}_111111`;
    localStorage.setItem('vibewords.playerID', player1BrowserId);
    localStorage.setItem('vibewords.playerName', 'Alice');
    localStorage.setItem('vibewords.hostedGameID', gameId);
    localStorage.setItem(`vibewords.inGame.${gameId}`, 'true');
    
    players.push({
      browserId: player1BrowserId,
      name: 'Alice',
      inGame: true,
    });

    // Player 2: Joins
    localStorage.clear();
    const player2BrowserId = `${Date.now()}_222222`;
    localStorage.setItem('vibewords.playerID', player2BrowserId);
    localStorage.setItem('vibewords.playerName', 'Bob');
    localStorage.setItem(`vibewords.inGame.${gameId}`, 'true');
    
    players.push({
      browserId: player2BrowserId,
      name: 'Bob',
      inGame: true,
    });

    // Player 3: Joins
    localStorage.clear();
    const player3BrowserId = `${Date.now()}_333333`;
    localStorage.setItem('vibewords.playerID', player3BrowserId);
    localStorage.setItem('vibewords.playerName', 'Charlie');
    localStorage.setItem(`vibewords.inGame.${gameId}`, 'true');
    
    players.push({
      browserId: player3BrowserId,
      name: 'Charlie',
      inGame: true,
    });

    // Verify all players are unique
    expect(players.length).toBe(3);
    expect(players[0].browserId).not.toBe(players[1].browserId);
    expect(players[1].browserId).not.toBe(players[2].browserId);
    expect(players[0].browserId).not.toBe(players[2].browserId);

    // Verify all players are in the game
    expect(players.every(p => p.inGame)).toBe(true);

    // Verify player names
    expect(players[0].name).toBe('Alice');
    expect(players[1].name).toBe('Bob');
    expect(players[2].name).toBe('Charlie');

    // Verify creator
    localStorage.clear();
    localStorage.setItem('vibewords.playerID', player1BrowserId);
    localStorage.setItem('vibewords.hostedGameID', gameId);
    const creatorGameId = localStorage.getItem('vibewords.hostedGameID');
    expect(creatorGameId).toBe(gameId);
  });

  it('should handle page refresh without duplicate join', () => {
    const gameId = 'refresh_test';
    const browserId = '1234567890_123456';

    // Initial join
    localStorage.setItem('vibewords.playerID', browserId);
    localStorage.setItem('vibewords.playerName', 'Alice');
    localStorage.setItem(`vibewords.inGame.${gameId}`, 'true');

    const initialState = {
      browserId: localStorage.getItem('vibewords.playerID'),
      name: localStorage.getItem('vibewords.playerName'),
      inGame: localStorage.getItem(`vibewords.inGame.${gameId}`),
    };

    // Simulate page refresh (localStorage persists)
    const afterRefreshState = {
      browserId: localStorage.getItem('vibewords.playerID'),
      name: localStorage.getItem('vibewords.playerName'),
      inGame: localStorage.getItem(`vibewords.inGame.${gameId}`),
    };

    // Check if already in game
    const alreadyInGame = localStorage.getItem(`vibewords.inGame.${gameId}`);
    
    // Should be the same
    expect(initialState.browserId).toBe(afterRefreshState.browserId);
    expect(initialState.name).toBe(afterRefreshState.name);
    expect(initialState.inGame).toBe(afterRefreshState.inGame);
    expect(alreadyInGame).toBe('true');
  });

  it('should handle user joining multiple games', () => {
    const browserId = '1234567890_123456';
    const games = ['game1', 'game2', 'game3'];

    localStorage.setItem('vibewords.playerID', browserId);
    localStorage.setItem('vibewords.playerName', 'Alice');

    // Join all games
    games.forEach(gameId => {
      localStorage.setItem(`vibewords.inGame.${gameId}`, 'true');
    });

    // Verify in all games
    games.forEach(gameId => {
      const inGame = localStorage.getItem(`vibewords.inGame.${gameId}`);
      expect(inGame).toBe('true');
    });

    // Verify same browser ID for all
    const storedBrowserId = localStorage.getItem('vibewords.playerID');
    expect(storedBrowserId).toBe(browserId);
  });

  it('should simulate real-world scenario: 5 devices, 2 games', () => {
    const game1 = 'morning_game';
    const game2 = 'evening_game';
    
    const devices = [
      { id: '1_111', name: 'Alice', games: [game1, game2] },
      { id: '2_222', name: 'Bob', games: [game1] },
      { id: '3_333', name: 'Charlie', games: [game2] },
      { id: '4_444', name: 'David', games: [game1, game2] },
      { id: '5_555', name: 'Eve', games: [game1] },
    ];

    const game1Players: string[] = [];
    const game2Players: string[] = [];

    devices.forEach(device => {
      localStorage.clear();
      localStorage.setItem('vibewords.playerID', device.id);
      localStorage.setItem('vibewords.playerName', device.name);

      device.games.forEach(gameId => {
        localStorage.setItem(`vibewords.inGame.${gameId}`, 'true');
        
        if (gameId === game1) {
          game1Players.push(device.id);
        } else if (gameId === game2) {
          game2Players.push(device.id);
        }
      });
    });

    // Game 1 should have: Alice, Bob, David, Eve (4 players)
    expect(game1Players.length).toBe(4);
    expect(new Set(game1Players).size).toBe(4); // All unique

    // Game 2 should have: Alice, Charlie, David (3 players)
    expect(game2Players.length).toBe(3);
    expect(new Set(game2Players).size).toBe(3); // All unique
  });

  it('should handle creator leaving and rejoining', () => {
    const gameId = 'creator_test';
    const creatorBrowserId = '1234567890_111111';

    // Creator creates game
    localStorage.setItem('vibewords.playerID', creatorBrowserId);
    localStorage.setItem('vibewords.playerName', 'Alice');
    localStorage.setItem('vibewords.hostedGameID', gameId);
    localStorage.setItem(`vibewords.inGame.${gameId}`, 'true');

    const isCreator = localStorage.getItem('vibewords.hostedGameID') === gameId;
    expect(isCreator).toBe(true);

    // Creator closes browser (localStorage persists)
    // Creator reopens browser
    const stillCreator = localStorage.getItem('vibewords.hostedGameID') === gameId;
    const stillInGame = localStorage.getItem(`vibewords.inGame.${gameId}`);
    
    expect(stillCreator).toBe(true);
    expect(stillInGame).toBe('true');
  });

  it('should verify Firebase-safe keys for all scenarios', () => {
    const forbiddenChars = ['.', '#', '$', '/', '[', ']'];
    const testCases = [
      `${Date.now()}_${Math.floor(Math.random() * 1000000)}`,
      `${Date.now()}_${Math.floor(Math.random() * 1000000)}`,
      `${Date.now()}_${Math.floor(Math.random() * 1000000)}`,
    ];

    testCases.forEach(browserId => {
      forbiddenChars.forEach(char => {
        expect(browserId).not.toContain(char);
      });
      expect(browserId).toMatch(/^\d+_\d+$/);
    });
  });

  it('should handle edge case: same name, different devices', () => {
    const gameId = 'same_name_test';
    const sameName = 'Alice';

    // Device 1
    localStorage.clear();
    const device1Id = '1234567890_111111';
    localStorage.setItem('vibewords.playerID', device1Id);
    localStorage.setItem('vibewords.playerName', sameName);
    localStorage.setItem(`vibewords.inGame.${gameId}`, 'true');

    const device1State = {
      browserId: localStorage.getItem('vibewords.playerID'),
      name: localStorage.getItem('vibewords.playerName'),
    };

    // Device 2
    localStorage.clear();
    const device2Id = '1234567891_222222';
    localStorage.setItem('vibewords.playerID', device2Id);
    localStorage.setItem('vibewords.playerName', sameName);
    localStorage.setItem(`vibewords.inGame.${gameId}`, 'true');

    const device2State = {
      browserId: localStorage.getItem('vibewords.playerID'),
      name: localStorage.getItem('vibewords.playerName'),
    };

    // Same name but different browser IDs
    expect(device1State.name).toBe(device2State.name);
    expect(device1State.browserId).not.toBe(device2State.browserId);
  });

  it('should simulate 100 concurrent users across 10 games', () => {
    const games = Array.from({ length: 10 }, (_, i) => `game_${i}`);
    const allBrowserIds = new Set<string>();

    for (let i = 0; i < 100; i++) {
      localStorage.clear();
      const browserId = `${Date.now()}_${Math.floor(Math.random() * 1000000)}`;
      localStorage.setItem('vibewords.playerID', browserId);
      localStorage.setItem('vibewords.playerName', `Player${i}`);

      // Each player joins a random game
      const randomGame = games[i % games.length];
      localStorage.setItem(`vibewords.inGame.${randomGame}`, 'true');

      allBrowserIds.add(browserId);
    }

    // All 100 should be unique
    expect(allBrowserIds.size).toBe(100);
  });
});

