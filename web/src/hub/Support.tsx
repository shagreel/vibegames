import { useState } from 'react';
import { FeedbackError, sendFeedback } from '../games/feedback';

/**
 * Saying thanks, and saying what is wrong.
 *
 * The heart sits in the corner of every screen, so this opens over whatever
 * someone is doing rather than making them go and find it. Feedback posts to an
 * inbox in the database and a scheduled Action turns it into an issue on the
 * repository — nobody needs a GitHub account, and there is no token in here to
 * be read out.
 */

export const VENMO_HANDLE = '@chill-gelato';

const VENMO_URL = 'https://venmo.com/u/chill-gelato';
const PLAY_URL = 'https://play.vibegames.party';

/** Names the game a note came from, so the issue arrives with some context. */
const GAME_TITLES: Record<string, string> = {
  five: 'Vibe Five',
  words: 'Vibe Words',
  sudoku: 'Vibe Sudoku',
  trio: 'Vibe Trio',
};

function Heart() {
  return (
    <svg className="support-heart" viewBox="0 0 24 24" aria-hidden="true">
      <path d="M12 20.3 4.2 12.6a4.6 4.6 0 0 1 0-6.6 4.8 4.8 0 0 1 6.7 0l1.1 1.1 1.1-1.1a4.8 4.8 0 0 1 6.7 0 4.6 4.6 0 0 1 0 6.6z" />
    </svg>
  );
}

/**
 * The heart in the corner, and the panel behind it.
 *
 * One component, so every screen gets the same thing and the panel cannot drift
 * between them.
 */
export function SupportButton({ game }: { game?: string }) {
  const [open, setOpen] = useState(false);
  const title = game ? GAME_TITLES[game] : undefined;

  return (
    <>
      <button
        type="button"
        className="hub__heart"
        onClick={() => setOpen(true)}
        aria-label="Support Vibe Games"
      >
        <Heart />
      </button>
      {open && <SupportPanel game={title} onClose={() => setOpen(false)} />}
    </>
  );
}

export function SupportPanel({ game, onClose }: { game?: string; onClose: () => void }) {
  const [copied, setCopied] = useState(false);
  const [shared, setShared] = useState(false);

  const copy = () => {
    void navigator.clipboard.writeText(VENMO_HANDLE).then(() => {
      setCopied(true);
      window.setTimeout(() => setCopied(false), 2000);
    });
  };

  const share = () => {
    void navigator.clipboard.writeText(PLAY_URL).then(() => {
      setShared(true);
      window.setTimeout(() => setShared(false), 2000);
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

        <FeedbackForm game={game} />

        <details className="support-more">
          <summary>Other ways to help</summary>

          <p className="support-blurb">
            Every game is free. Nothing to unlock, no adverts, no account. If you would like to say
            thanks, you could buy my family a treat to help cover what it costs to keep them
            running.
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
        </details>

        <p className="support-foot">Nothing here is expected. The games are free either way.</p>
      </div>
    </div>
  );
}

/**
 * The form.
 *
 * One box and a send button, deliberately: anything more would be a form to
 * fill in rather than a message to leave.
 */
function FeedbackForm({ game }: { game?: string }) {
  const [text, setText] = useState('');
  const [sending, setSending] = useState(false);
  const [sent, setSent] = useState(false);
  const [problem, setProblem] = useState('');

  const send = async () => {
    setSending(true);
    setProblem('');
    try {
      await sendFeedback({ text, source: 'web', game: game?.toLowerCase().replace(/^vibe /, '') });
      setSent(true);
    } catch (error) {
      setProblem(
        error instanceof FeedbackError
          ? error.message
          : 'That did not go through. Please try again in a moment.',
      );
    } finally {
      setSending(false);
    }
  };

  if (sent) {
    return (
      <div className="feedback feedback--sent">
        <strong>Thank you — that has gone straight to me.</strong>
        <span>I read everything, even when I cannot reply to it.</span>
      </div>
    );
  }

  return (
    <div className="feedback">
      <label htmlFor="feedback-text">Tell me what you think, or what is not working</label>
      <textarea
        id="feedback-text"
        value={text}
        onChange={(event) => setText(event.target.value)}
        placeholder="Ideas, bugs, a game you would like next — anything at all."
        maxLength={2000}
        rows={4}
        disabled={sending}
      />
      {problem && <p className="feedback__problem">{problem}</p>}
      <button
        type="button"
        className="support-copy feedback__send"
        onClick={() => void send()}
        disabled={text.trim().length < 4 || sending}
      >
        {sending ? 'Sending…' : 'Send'}
      </button>
      <p className="feedback__note">
        No account, no email address, nothing to sign up for — it reaches me as a note
        {game ? ` about ${game}` : ''}.
      </p>
    </div>
  );
}
