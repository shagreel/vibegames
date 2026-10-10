import { useState, useEffect, useCallback, useRef } from 'react';
import { ref, onValue, set, get, onDisconnect } from 'firebase/database';
import { database } from '../../firebase';
import { VALID_WORDS, ANSWER_WORDS } from './wordList';
import BackToGames from '../../hub/BackToGames';
import { SupportButton } from '../../hub/Support';
import { GAMES, trackGameFinish, trackGameStart, trackShare } from '../../analytics';
import './VibeWords.css';

type LetterState = 'correct' | 'present' | 'absent' | 'empty' | 'current';

interface Cell {
  letter: string;
  state: LetterState;
}

const WORD_LENGTH = 5;
const MAX_GUESSES = 6;

function VibeWords() {
  const [answer, setAnswer] = useState('');
  const [guesses, setGuesses] = useState<string[]>([]);
  const [currentGuess, setCurrentGuess] = useState('');
  const [gameOver, setGameOver] = useState(false);
  const [won, setWon] = useState(false);
  const [message, setMessage] = useState('');
  const [shake, setShake] = useState(false);
  const [shareMessage, setShareMessage] = useState('');
  const [playerName, setPlayerName] = useState('');
  const [nameSubmitted, setNameSubmitted] = useState(false);
  const [winner, setWinner] = useState<{ name: string; timestamp: number } | null>(null);
  const [gameId, setGameId] = useState<string | null>(null);
  const [isCreator, setIsCreator] = useState(false);
  const [gameStarted, setGameStarted] = useState(false);
  const [gameExists, setGameExists] = useState(false);
  const [restartTime, setRestartTime] = useState<number | null>(null);
  const [countdown, setCountdown] = useState<number | null>(null);
  const [playerCount, setPlayerCount] = useState(0);
  const [playerAddedToGame, setPlayerAddedToGame] = useState(false);

  // Track previous answer to detect word changes
  const previousAnswerRef = useRef<string>('');

  // Initialize game
  useEffect(() => {
    // Check for query parameter, or generate a new game ID
    const urlParams = new URLSearchParams(window.location.search);
    let currentGameId = urlParams.get('game');

    if (!currentGameId) {
      // Generate a new game ID
      currentGameId = Math.random().toString(36).substring(2, 10);
      // Update URL without reloading the page
      const newUrl = `${window.location.pathname}?game=${currentGameId}`;
      window.history.replaceState({}, '', newUrl);
    }

    setGameId(currentGameId);

    // Word will be set by Firebase listener when game is loaded
    // or by the creator when they create the game

    // Load player name from localStorage
    const savedName = localStorage.getItem('vibewords.playerName');
    if (savedName) {
      setPlayerName(savedName);
      setNameSubmitted(true);
    }
  }, []);

  // Listen for game state and winner updates when in a shared game
  useEffect(() => {
    if (!gameId) {
      // Solo game - always started
      setGameStarted(true);
      return;
    }

    // Listen for game existence (so we know when someone creates it)
    const gameRef = ref(database, `games/${gameId}`);
    const gameExistsUnsubscribe = onValue(gameRef, (snapshot) => {
      if (snapshot.exists()) {
        setGameExists(true);

        // Check if current user is the creator
        const creatorId = localStorage.getItem('vibewords.hostedGameID');
        if (creatorId === gameId) {
          setIsCreator(true);
        }
      } else {
        setGameExists(false);
      }
    });

    // Listen for the word (so all players have the same word)
    const wordRef = ref(database, `games/${gameId}/word`);
    const wordUnsubscribe = onValue(wordRef, (snapshot) => {
      const word = snapshot.val();
      if (word) {
        const newWord = word.toUpperCase();

        // If the word changed (and we had a previous word), it means the game restarted
        // Clear the board to prevent showing old guesses with new word hints
        if (previousAnswerRef.current && previousAnswerRef.current !== newWord) {
          setGuesses([]);
          setCurrentGuess('');
          setMessage('');
          setShareMessage('');
          setGameOver(false);
          setWon(false);
        }

        if (previousAnswerRef.current !== newWord) {
          // A word nobody had seen before is a round beginning — for the
          // creator whose game it is and for everyone who followed the link
          // alike. Skipped when the same word arrives twice, which is what a
          // reconnection looks like, and what React's development double-mount
          // would otherwise turn into two counts.
          trackGameStart(GAMES.words, { mode: gameId ? 'shared' : 'solo' });
        }

        previousAnswerRef.current = newWord;
        setAnswer(newWord);
      }
    });

    // Listen for game started status
    const startedRef = ref(database, `games/${gameId}/started`);
    const startedUnsubscribe = onValue(startedRef, (snapshot) => {
      const started = snapshot.val();
      setGameStarted(started === true);
    });

    // Listen for winner updates
    const winnerRef = ref(database, `games/${gameId}/winner`);
    const winnerUnsubscribe = onValue(winnerRef, (snapshot) => {
      const data = snapshot.val();
      setWinner(data); // Set to data (which could be null after reset)
    });

    // Listen for restart time
    const restartRef = ref(database, `games/${gameId}/restartTime`);
    const restartUnsubscribe = onValue(restartRef, (snapshot) => {
      const time = snapshot.val();
      setRestartTime(time);
    });

    // Listen for player count
    const playersRef = ref(database, `games/${gameId}/players`);
    const playersUnsubscribe = onValue(playersRef, (snapshot) => {
      const players = snapshot.val();
      if (players) {
        const count = Object.keys(players).length;
        setPlayerCount(count);
      } else {
        setPlayerCount(0);
      }
    });

    return () => {
      gameExistsUnsubscribe();
      wordUnsubscribe();
      startedUnsubscribe();
      winnerUnsubscribe();
      restartUnsubscribe();
      playersUnsubscribe();
    };
  }, [gameId]);

  // Add player to game when game exists and name is submitted
  useEffect(() => {
    const addPlayerToGame = async () => {
      if (gameId && gameExists && nameSubmitted && playerName.trim() && !playerAddedToGame) {
        // Get or create a unique browser ID for this player
        let browserId = localStorage.getItem('vibewords.playerID');
        if (!browserId) {
          browserId = `${Date.now()}_${Math.floor(Math.random() * 1000000)}`;
          localStorage.setItem('vibewords.playerID', browserId);
        }

        const playerRef = ref(database, `games/${gameId}/players/${browserId}`);

        // Check if this player actually exists in Firebase (not just localStorage)
        // This handles the case where player left and is rejoining
        const playerSnapshot = await get(playerRef);

        if (playerSnapshot.exists()) {
          // Player already in Firebase, just set up disconnect handler
          setPlayerAddedToGame(true);
          onDisconnect(playerRef).remove();
          return;
        }

        // Player not in Firebase, add them
        try {
          await set(playerRef, {
            name: playerName.trim(),
            joinedAt: Date.now()
          });

          // Set up automatic removal when player disconnects
          // This works even if browser crashes or network drops
          onDisconnect(playerRef).remove();

          // Mark that this browser has joined this game
          const playerGameKey = `vibewords.inGame.${gameId}`;
          localStorage.setItem(playerGameKey, 'true');
          setPlayerAddedToGame(true);
        } catch (error) {
          console.error('Error adding player:', error);
        }
      }
    };

    addPlayerToGame();
  }, [gameId, gameExists, nameSubmitted, playerName, playerAddedToGame]);

  // Countdown timer effect
  useEffect(() => {
    if (!restartTime) {
      setCountdown(null);
      return;
    }

    let hasCleared = false;
    const currentGameId = gameId; // Capture gameId at the time effect runs

    const updateCountdown = async () => {
      const now = Date.now();
      const secondsLeft = Math.ceil((restartTime - now) / 1000);

      if (secondsLeft <= 0) {
        // Time to restart! This happens for ALL players
        setCountdown(null);

        // Reset the game board for this player
        setGuesses([]);
        setCurrentGuess('');
        setMessage('');
        setShareMessage('');

        // Reset game state so players can play again
        setGameOver(false);
        setWon(false);

        // Clear the restart time in Firebase so countdown doesn't keep running
        // Only do this once to avoid race conditions
        if (currentGameId && !hasCleared) {
          hasCleared = true;
          const restartRef = ref(database, `games/${currentGameId}/restartTime`);
          await set(restartRef, null);
        }

        // Word will be set by whoever clicked "Play Again"
        // All players will get the new word from the Firebase listener
      } else {
        setCountdown(secondsLeft);
      }
    };

    updateCountdown();
    const interval = setInterval(updateCountdown, 100);

    return () => clearInterval(interval);
  }, [restartTime]);

  // Get letter state for a specific guess
  const getLetterState = (letter: string, index: number, guess: string): LetterState => {
    const answerLetters = answer.split('');
    const guessLetters = guess.split('');

    // Correct position
    if (guessLetters[index] === answerLetters[index]) {
      return 'correct';
    }

    // Letter exists but wrong position
    // Count how many of this letter are in the answer
    const letterCount = answerLetters.filter(l => l === letter).length;
    // Count how many correct positions we have for this letter
    const correctCount = guessLetters.filter((l, i) => l === letter && l === answerLetters[i]).length;
    // Count how many of this letter appear before this index in the guess
    const beforeCount = guessLetters.slice(0, index).filter(l => l === letter && answerLetters[guessLetters.indexOf(l)] !== l).length;

    if (answerLetters.includes(letter) && beforeCount < (letterCount - correctCount)) {
      return 'present';
    }

    return 'absent';
  };

  // Get keyboard key state
  const getKeyState = (key: string): LetterState => {
    let state: LetterState = 'empty';
    
    guesses.forEach(guess => {
      guess.split('').forEach((letter, index) => {
        if (letter === key) {
          const letterState = getLetterState(letter, index, guess);
          if (letterState === 'correct') {
            state = 'correct';
          } else if (letterState === 'present' && state !== 'correct') {
            state = 'present';
          } else if (letterState === 'absent' && state === 'empty') {
            state = 'absent';
          }
        }
      });
    });

    return state;
  };

  // A round ends when this player runs out of guesses, or when they solve it,
  // or when somebody else solves it first — which arrives over the wire and so
  // has to be watched rather than logged where the guess was judged. Keyed on
  // the word, so a rematch (a new word) is counted and a repeat is not.
  const roundOver = gameOver || (winner !== null && winner.name !== playerName);
  const reportedWord = useRef<string | null>(null);
  useEffect(() => {
    if (!roundOver || !answer || reportedWord.current === answer) return;
    reportedWord.current = answer;
    trackGameFinish(GAMES.words, {
      mode: gameId ? 'shared' : 'solo',
      outcome: won ? 'won' : 'lost',
      score: guesses.length,
    });
  }, [roundOver, answer, gameId, won, guesses.length]);

  // Handle key press
  const handleKeyPress = useCallback((key: string) => {
    // Disable keyboard if game is over, not started, or name not submitted
    // Players can keep playing even after someone wins (until Play Again is clicked)
    if (gameOver || !gameStarted || !nameSubmitted) return;

    if (key === 'ENTER') {
      if (currentGuess.length !== WORD_LENGTH) {
        setMessage('Not enough letters');
        setShake(true);
        setTimeout(() => setShake(false), 500);
        return;
      }

      if (!VALID_WORDS.includes(currentGuess.toUpperCase())) {
        setMessage('Not in word list');
        setShake(true);
        setTimeout(() => setShake(false), 500);
        return;
      }

      const newGuesses = [...guesses, currentGuess];
      setGuesses(newGuesses);
      setCurrentGuess('');
      setMessage('');

      if (currentGuess === answer) {
        setWon(true);
        setGameOver(true);
        setMessage('Congratulations! 🎉');

        // Record winner in Firebase if in a shared game
        if (gameId && playerName) {
          const winnerRef = ref(database, `games/${gameId}/winner`);
          // Only set if no winner exists yet
          get(winnerRef).then((snapshot) => {
            if (!snapshot.exists()) {
              set(winnerRef, {
                name: playerName,
                timestamp: Date.now()
              });
            }
          });
        }
      } else if (newGuesses.length === MAX_GUESSES) {
        setGameOver(true);
        setMessage(`Game Over! The word was ${answer}`);
      }
    } else if (key === 'BACKSPACE') {
      setCurrentGuess(currentGuess.slice(0, -1));
      setMessage('');
    } else if (currentGuess.length < WORD_LENGTH && /^[A-Z]$/.test(key)) {
      setCurrentGuess(currentGuess + key);
      setMessage('');
    }
  }, [currentGuess, guesses, gameOver, gameStarted, nameSubmitted, answer, gameId, playerName]);

  // Keyboard event listener
  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      // Ignore if typing in an input field
      const target = e.target as HTMLElement;
      if (target.tagName === 'INPUT' || target.tagName === 'TEXTAREA') {
        return;
      }

      if (e.ctrlKey || e.metaKey || e.altKey) return;

      const key = e.key.toUpperCase();
      if (key === 'ENTER' || key === 'BACKSPACE') {
        e.preventDefault();
        handleKeyPress(key);
      } else if (/^[A-Z]$/.test(key)) {
        e.preventDefault();
        handleKeyPress(key);
      }
    };

    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [handleKeyPress]);

  // Build grid
  const grid: Cell[][] = [];
  for (let i = 0; i < MAX_GUESSES; i++) {
    const row: Cell[] = [];
    const guess = guesses[i];
    const isCurrentRow = i === guesses.length && !gameOver;

    for (let j = 0; j < WORD_LENGTH; j++) {
      if (guess) {
        const letter = guess[j];
        const state = getLetterState(letter, j, guess);
        row.push({ letter, state });
      } else if (isCurrentRow && currentGuess[j]) {
        row.push({ letter: currentGuess[j], state: 'current' });
      } else {
        row.push({ letter: '', state: 'empty' });
      }
    }
    grid.push(row);
  }

  // Keyboard layout
  const keyboardRows = [
    ['Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P'],
    ['A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L'],
    ['ENTER', 'Z', 'X', 'C', 'V', 'B', 'N', 'M', 'BACKSPACE']
  ];

  const getNewWord = () => {
    // Use cryptographically secure random number generator
    // This makes it much harder to predict the word
    const randomValues = new Uint32Array(1);
    crypto.getRandomValues(randomValues);
    const index = randomValues[0] % ANSWER_WORDS.length;
    return ANSWER_WORDS[index];
  };

  const resetGame = () => {
    const selectedWord = getNewWord();

    setAnswer(selectedWord.toUpperCase());
    setGuesses([]);
    setCurrentGuess('');
    setGameOver(false);
    setWon(false);
    setMessage('');
    setShareMessage('');
    setWinner(null);
  };

  const handlePlayAgain = async () => {
    // For shared games, only allow restart if game is over (won or lost)
    if (gameId && !gameOver) return;

    // For solo games, only allow restart if game is actually over
    if (!gameId && !gameOver) return;

    if (gameId) {
      // For shared games, whoever clicks "Play Again" sets the new word
      const selectedWord = getNewWord();

      // Update word in Firebase (all players will get it via listener)
      // The word listener will clear boards when it detects a word change
      const wordRef = ref(database, `games/${gameId}/word`);
      await set(wordRef, selectedWord.toUpperCase());

      // Reset winner for new game (if there was one)
      const winnerRef = ref(database, `games/${gameId}/winner`);
      await set(winnerRef, null);

      // Set a restart time 10 seconds from now
      const restartAt = Date.now() + 10000; // 10 seconds
      const restartRef = ref(database, `games/${gameId}/restartTime`);
      await set(restartRef, restartAt);
    } else {
      // For solo games, restart immediately
      resetGame();
    }
  };

  const handleNameSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (playerName.trim()) {
      localStorage.setItem('vibewords.playerName', playerName.trim());
      setNameSubmitted(true);
      // Player will be added to game by the useEffect when gameExists becomes true
    }
  };

  const handleCreateGame = async () => {
    if (!gameId || !playerName.trim()) return;

    // Select a word for this game
    const selectedWord = getNewWord();

    // Get or create a unique browser ID for this player
    let browserId = localStorage.getItem('vibewords.playerID');
    if (!browserId) {
      browserId = `${Date.now()}_${Math.floor(Math.random() * 1000000)}`;
      localStorage.setItem('vibewords.playerID', browserId);
    }

    // Create the game in Firebase with the word AND add creator as first player
    const gameRef = ref(database, `games/${gameId}`);
    await set(gameRef, {
      word: selectedWord.toUpperCase(),
      creator: playerName.trim(),
      started: false,
      createdAt: Date.now(),
      players: {
        [browserId]: {
          name: playerName.trim(),
          joinedAt: Date.now()
        }
      }
    });

    // Set up disconnect handler for creator
    const playerRef = ref(database, `games/${gameId}/players/${browserId}`);
    onDisconnect(playerRef).remove();

    // Mark that this browser has joined this game
    const playerGameKey = `vibewords.inGame.${gameId}`;
    localStorage.setItem(playerGameKey, 'true');

    // Set the answer locally
    setAnswer(selectedWord.toUpperCase());

    // Mark this user as creator in localStorage
    localStorage.setItem('vibewords.hostedGameID', gameId);
    setIsCreator(true);
    setGameExists(true);
    setPlayerAddedToGame(true); // Creator is now added as a player
  };

  const handleStartGame = async () => {
    if (!gameId || !isCreator) return;

    const startedRef = ref(database, `games/${gameId}/started`);
    await set(startedRef, true);
    setGameStarted(true);
  };

  const shareGame = async () => {
    if (!gameId) return;

    // If game doesn't exist yet, create it first
    if (!gameExists && playerName.trim()) {
      await handleCreateGame();
    }

    const shareUrl = `${window.location.origin}${window.location.pathname}?game=${gameId}`;

    // Sharing the invite is the growth loop, so it is counted — this is the
    // only multiplayer game in the suite where somebody has to recruit someone.
    trackShare(GAMES.words, 'game');

    // Copy to clipboard
    navigator.clipboard.writeText(shareUrl).then(() => {
      setShareMessage('Link copied! Share it with friends.');
      setTimeout(() => setShareMessage(''), 3000);
    }).catch(() => {
      setShareMessage('Failed to copy. URL: ' + shareUrl);
      setTimeout(() => setShareMessage(''), 5000);
    });
  };

  return (
    <div className="vibewords-container">
      <header className="vibewords-header">
        <BackToGames />
        <div className="vibewords-header__corner">
          <SupportButton game="words" />
        </div>
        <h1>VibeWords</h1>
        {playerCount > 0 && (
          <div className="player-count">
            👥 {playerCount} {playerCount === 1 ? 'player' : 'players'}
          </div>
        )}
      </header>

      <div className="game-content">
        {/* Name input */}
        {!nameSubmitted && (
          <div className="name-input-container">
            <form onSubmit={handleNameSubmit} className="name-form">
              <input
                type="text"
                value={playerName}
                onChange={(e) => setPlayerName(e.target.value)}
                placeholder="Enter your name"
                className="name-input"
                maxLength={20}
                autoFocus
              />
              <button type="submit" className="name-submit-button">
                Continue
              </button>
            </form>
            <p className="name-hint">Enter your name so others know who won!</p>
          </div>
        )}

        {/* Create game button - shown when game doesn't exist yet */}
        {nameSubmitted && !gameExists && (
          <div className="start-game-container">
            <p className="start-game-message">
              Create a game to get started!
            </p>
            <div className="button-row">
              <button onClick={handleCreateGame} className="start-game-button">
                🎮 Create Game
              </button>
              <button onClick={shareGame} className="copy-link-button" title="Copy game link">
                <span className="copy-icon"></span>
              </button>
            </div>
          </div>
        )}

        {/* Start game button for creator */}
        {nameSubmitted && isCreator && gameExists && !gameStarted && (
          <div className="start-game-container">
            <p className="start-game-message">
              You created this game! Click start when everyone has joined.
            </p>
            <div className="button-row">
              <button onClick={handleStartGame} className="start-game-button">
                🚀 Start Game
              </button>
              <button onClick={shareGame} className="copy-link-button" title="Copy game link">
                <span className="copy-icon"></span>
              </button>
            </div>
          </div>
        )}

        {/* Waiting for game to start */}
        {nameSubmitted && !isCreator && gameExists && !gameStarted && (
          <div className="waiting-container">
            <p className="waiting-message">
              ⏳ Waiting for the game creator to start the game...
            </p>
          </div>
        )}

        {/* Countdown for restart */}
        {countdown !== null && (
          <div className="countdown-container">
            <p className="countdown-message">
              New game starting in...
            </p>
            <div className="countdown-number">
              {countdown}
            </div>
          </div>
        )}

        {/* Winner announcement */}
        {winner && winner.name !== playerName && !countdown && (
          <div className="winner-announcement">
            🏆 {winner.name} won this game!
          </div>
        )}

        {message && !countdown && (
          <div className={`message ${won ? 'success' : ''}`}>
            {message}
          </div>
        )}

        {shareMessage && (
          <div className="message share-message">
            {shareMessage}
          </div>
        )}

        <div className={`grid ${shake ? 'shake' : ''}`}>
          {grid.map((row, i) => (
            <div key={i} className="grid-row">
              {row.map((cell, j) => (
                <div
                  key={j}
                  className={`cell ${cell.state} ${cell.letter ? 'filled' : ''}`}
                  style={{
                    animationDelay: cell.state !== 'empty' && cell.state !== 'current' 
                      ? `${j * 0.1}s` 
                      : '0s'
                  }}
                >
                  {cell.letter}
                </div>
              ))}
            </div>
          ))}
        </div>

        <div className="keyboard">
          {keyboardRows.map((row, i) => (
            <div key={i} className="keyboard-row">
              {row.map((key) => (
                <button
                  key={key}
                  className={`key ${getKeyState(key)} ${key.length > 1 ? 'wide' : ''}`}
                  onClick={() => handleKeyPress(key)}
                >
                  {key === 'BACKSPACE' ? '⌫' : key}
                </button>
              ))}
            </div>
          ))}
        </div>

        <div className="button-container">
          {!countdown && winner !== null && (
            <button className="reset-button" onClick={handlePlayAgain}>
              Play Again
            </button>
          )}
        </div>
      </div>
    </div>
  );
}

export default VibeWords;

