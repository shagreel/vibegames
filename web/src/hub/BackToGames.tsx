import { navigate } from '../router';

/**
 * The way back to the menu, on every game screen.
 *
 * Each game is a path now, so the browser's own back button works — but a shared
 * game link drops someone straight into a grid with no context, and on a phone
 * there is no visible back button at all.
 */
function BackToGames() {
  return (
    <button
      type="button"
      className="back-to-games"
      onClick={() => navigate('/')}
      aria-label="Back to games"
    >
      <svg viewBox="0 0 24 24" aria-hidden="true">
        <path d="M15.5 4.2 7.7 12l7.8 7.8" />
      </svg>
      <span>Games</span>
    </button>
  );
}

export default BackToGames;
