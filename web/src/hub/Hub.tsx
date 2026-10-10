import { useState } from 'react';
import { navigate } from '../router';
import { GAMES } from './catalog';
import { SupportPanel } from './Support';
import './Hub.css';

function Hub() {
  const [showingSupport, setShowingSupport] = useState(false);

  return (
    <div className="hub">
      <div className="hub__inner">
        <header className="hub__header">
          <div className="hub__title-row">
            <h1>Vibe Games</h1>
            {/* The app puts this beside its settings gear; the menu has no
                settings, so it sits where the gear would. */}
            <button
              type="button"
              className="hub__heart"
              onClick={() => setShowingSupport(true)}
              aria-label="Support Vibe Games"
            >
              <svg viewBox="0 0 24 24" aria-hidden="true">
                <path d="M12 20.3 4.2 12.6a4.6 4.6 0 0 1 0-6.6 4.8 4.8 0 0 1 6.7 0l1.1 1.1 1.1-1.1a4.8 4.8 0 0 1 6.7 0 4.6 4.6 0 0 1 0 6.6z" />
              </svg>
            </button>
          </div>
          <p>Quick party games. Grab a phone, pass it round.</p>
        </header>

        <ul className="hub__games">
          {GAMES.map((game) => (
            <li key={game.id}>
              <button
                type="button"
                className="card"
                data-available={game.available}
                style={
                  {
                    '--a': game.accent[0],
                    '--b': game.accent[1],
                  } as React.CSSProperties
                }
                onClick={() => game.available && navigate(game.path)}
                disabled={!game.available}
                aria-label={
                  game.available ? game.title : `${game.title}, coming soon`
                }
              >
                <span className="card__icon">{game.symbol}</span>
                <span className="card__text">
                  <span className="card__title">
                    {game.title}
                    {!game.available && <em className="card__soon">Soon</em>}
                  </span>
                  <span className="card__tagline">{game.tagline}</span>
                </span>
                {game.available && (
                  <span className="card__play" aria-hidden="true">
                    <svg viewBox="0 0 24 24">
                      <path d="M8 5.5v13l11-6.5z" />
                    </svg>
                  </span>
                )}
              </button>
            </li>
          ))}
        </ul>

        <footer className="hub__footer">
          <a href="https://vibegames.party">About Vibe Games</a>
        </footer>
      </div>

      {showingSupport && <SupportPanel onClose={() => setShowingSupport(false)} />}
    </div>
  );
}

export default Hub;
