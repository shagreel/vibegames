import { useState } from 'react';
import { navigate } from '../router';
import { GAMES } from './catalog';
import { SupportButton } from './Support';
import { GameSettings, SettingsButton } from './GameSettings';
import './Hub.css';

function Hub() {
  const [settingsOpen, setSettingsOpen] = useState(false);

  return (
    <div className="hub">
      <div className="hub__inner">
        <header className="hub__header">
          <div className="hub__title-row">
            <h1>Vibe Games</h1>
            {/* The menu has settings of its own now: your name and whether the
                games are light or dark, which are the two things that are not
                about any one game. */}
            <span className="hub__actions">
              <SettingsButton prefix="hub" onClick={() => setSettingsOpen(true)} />
              <SupportButton />
            </span>
          </div>
          <p>Quick party games. Grab a phone, pass it round.</p>
        </header>

        {settingsOpen && (
          <GameSettings prefix="hub" onClose={() => setSettingsOpen(false)} />
        )}

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
    </div>
  );
}

export default Hub;
