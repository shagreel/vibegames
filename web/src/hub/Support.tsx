import { useState } from 'react';

/**
 * Saying thanks.
 *
 * The games are free and stay free, so the only thing here is a thank-you — but
 * it should be easy to act on: a link, the handle written out for anyone who
 * would rather type it, and a copy button for the case where the link opens the
 * wrong app.
 */

export const VENMO_HANDLE = '@chill-gelato';

const VENMO_URL = 'https://venmo.com/u/chill-gelato';
const FEEDBACK_URL = 'https://github.com/shagreel/vibegames/issues';
const PLAY_URL = 'https://play.vibegames.party';

function Heart() {
  return (
    <svg className="support-heart" viewBox="0 0 24 24" aria-hidden="true">
      <path d="M12 20.3 4.2 12.6a4.6 4.6 0 0 1 0-6.6 4.8 4.8 0 0 1 6.7 0l1.1 1.1 1.1-1.1a4.8 4.8 0 0 1 6.7 0 4.6 4.6 0 0 1 0 6.6z" />
    </svg>
  );
}

export function SupportPanel({ onClose }: { onClose: () => void }) {
  const [copied, setCopied] = useState(false);
  const [shared, setShared] = useState(false);

  const share = () => {
    void navigator.clipboard.writeText(PLAY_URL).then(() => {
      setShared(true);
      window.setTimeout(() => setShared(false), 2000);
    });
  };

  const copy = () => {
    void navigator.clipboard.writeText(VENMO_HANDLE).then(() => {
      setCopied(true);
      window.setTimeout(() => setCopied(false), 2000);
    });
  };

  return (
    <div className="support-overlay" role="dialog" aria-label="Support Vibe Games">
      <div className="support-panel">
        <button type="button" className="support-close" onClick={onClose} aria-label="Close">
          ×
        </button>

        <span className="support-heart support-heart--large">
          <Heart />
        </span>

        <h2>Made with love</h2>
        <p className="support-blurb">
          I built these four games for my own family. We play them in the evenings — it is how we
          wind down together and stay close — and I wanted to share that with other families.
        </p>
        <p className="support-blurb">
          Every game is free. Nothing to unlock, no adverts, no account. If you would like to say
          thanks, I would love to hear what you think of them, or you could buy my family a treat to
          help cover what it costs to keep them running.
        </p>

        <div className="support-actions">
          <a className="support-row" href={VENMO_URL} target="_blank" rel="noopener noreferrer">
            <span className="support-row__icon support-row__icon--venmo" aria-hidden="true">
              🎁
            </span>
            <span className="support-row__text">
              <strong>Buy us a treat</strong>
              <span>Venmo {VENMO_HANDLE}</span>
            </span>
            <span className="support-row__arrow" aria-hidden="true">
              ↗
            </span>
          </a>

          <a className="support-row" href={FEEDBACK_URL} target="_blank" rel="noopener noreferrer">
            <span className="support-row__icon support-row__icon--feedback" aria-hidden="true">
              💬
            </span>
            <span className="support-row__text">
              <strong>Tell me what you think</strong>
              <span>Ideas, bugs, or a game you would like next</span>
            </span>
            <span className="support-row__arrow" aria-hidden="true">
              ↗
            </span>
          </a>

          <button type="button" className="support-row" onClick={share}>
            <span className="support-row__icon support-row__icon--share" aria-hidden="true">
              💛
            </span>
            <span className="support-row__text">
              <strong>{shared ? 'Link copied' : 'Share it with another family'}</strong>
              <span>They can play in a browser tonight, free</span>
            </span>
            <span className="support-row__arrow" aria-hidden="true">
              {shared ? '✓' : '↗'}
            </span>
          </button>
        </div>

        <button type="button" className="support-copy" onClick={copy}>
          {copied ? 'Copied' : 'Copy the Venmo handle'}
        </button>

        <p className="support-foot">Nothing here is expected. The games are free either way.</p>
      </div>
    </div>
  );
}
