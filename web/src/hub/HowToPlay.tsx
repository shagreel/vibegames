import type { ReactNode } from 'react';
import './HowToPlay.css';

/**
 * The "how to play" page, shared by every game.
 *
 * The five games used to explain themselves in five different places — a page in
 * Vibe Trio, a wall of prose in the Vibe Blurt lobby, one line under the buttons
 * in Vibe Words. They are all one page behind one link now, and this decides
 * what that page looks like.
 *
 * Each game supplies its own words, because the counts in them have to come from
 * that game's own data rather than being typed out twice.
 */
export interface HowToPlaySection {
  title: string;
  /** `**bold**` is understood; nothing else is. */
  body: string;
}

export interface HowToPlayContent {
  name: string;
  intro: string;
  sections: HowToPlaySection[];
  bullets: { lead: string; text: string }[];
}

function HowToPlay({ content, onClose }: { content: HowToPlayContent; onClose: () => void }) {
  return (
    <div className="howto">
      <header className="howto__header">
        <button type="button" className="back-to-games" onClick={onClose} aria-label="Back">
          <svg viewBox="0 0 24 24" aria-hidden="true">
            <path d="M15.5 4.2 7.7 12l7.8 7.8" />
          </svg>
          <span>Back</span>
        </button>
        <div className="howto__titles">
          <h1>How to play</h1>
          <p>{content.name}</p>
        </div>
      </header>

      <div className="howto__body">
        <p className="howto__intro">{emphasised(content.intro)}</p>

        {content.sections.map((section) => (
          <section key={section.title} className="howto__section">
            <h2>{section.title}</h2>
            <p>{emphasised(section.body)}</p>
          </section>
        ))}

        {content.bullets.length > 0 && (
          <section className="howto__section">
            <h2>Playing</h2>
            <ul className="howto__bullets">
              {content.bullets.map((bullet) => (
                <li key={bullet.lead}>
                  <strong>{bullet.lead}</strong> — {emphasised(bullet.text)}
                </li>
              ))}
            </ul>
          </section>
        )}
      </div>
    </div>
  );
}

/**
 * The same opener on every main page.
 *
 * Plain text rather than a card: three of the four are on a lobby that is
 * already a column of cards, and one is a game in progress, so the quiet version
 * is the one that suits all of them.
 */
export function HowToPlayLink({ onClick }: { onClick: () => void }) {
  return (
    <button type="button" className="howto__link" onClick={onClick}>
      How to play
    </button>
  );
}

/** `**bold**` and nothing else — enough for a rule, without a markdown library. */
function emphasised(text: string): ReactNode[] {
  return text.split(/(\*\*[^*]+\*\*)/g).map((part, index) =>
    part.startsWith('**') && part.endsWith('**') ? (
      <strong key={index}>{part.slice(2, -2)}</strong>
    ) : (
      <span key={index}>{part}</span>
    ),
  );
}

export default HowToPlay;
