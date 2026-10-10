import { push, ref, set } from 'firebase/database';
import { database } from '../firebase';

/**
 * Sending feedback from inside the app.
 *
 * Nobody playing these games has a GitHub account, and asking them to make one
 * to report a bug means the bug never gets reported. So the app posts to an
 * inbox in the database — a write-only node anyone can add to — and a scheduled
 * GitHub Action drains it into issues on the repository.
 *
 * There is no token here and none anywhere else. That is the whole reason for
 * the two-step: a token in a client is a token anyone can read out of it.
 */

const MAX_LENGTH = 2000;

export interface Feedback {
  text: string;
  /** Which app it came from; the rules accept only these two. */
  source: 'ios' | 'web';
  /** Which game they were in, when that is known. */
  game?: string;
  /** A person's note, or something the browser threw on its own. */
  kind?: 'feedback' | 'crash';
}

export class FeedbackError extends Error {}

/**
 * Posts the feedback and resolves once the database has it.
 *
 * Rejects rather than failing quietly: "Sent, thank you" for a message that
 * went nowhere is worse than an error, because the person then believes they
 * have been heard.
 */
export async function sendFeedback(feedback: Feedback): Promise<void> {
  const text = feedback.text.trim();
  if (text.length < 4) {
    throw new FeedbackError('Please write a little more.');
  }
  if (text.length > MAX_LENGTH) {
    throw new FeedbackError(`Please keep it under ${MAX_LENGTH} characters.`);
  }

  // Push rather than a timestamp: two people writing at the same moment must
  // not land on the same key.
  const entry = push(ref(database, 'feedback'));
  await set(entry, {
    text,
    source: feedback.source,
    createdAt: Date.now(),
    ...(feedback.game ? { game: feedback.game } : {}),
    ...(feedback.kind ? { kind: feedback.kind } : {}),
  });
}
