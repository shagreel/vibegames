# The daily cleanup

Deletes game rooms that are more than a day old, once a day, from Cloud
Functions. This exists because nothing else can:

- **The app cannot.** The database rules hand out writes to whoever gets there
  first and never a delete, deliberately: one phone must not be able to wipe a
  game out from under everybody else. `firebase/database.rules.json` is where
  that is decided, and it is the reason this is a server-side job.
- **The Realtime Database cannot.** It has no expiry of its own — Firestore has
  TTL policies, RTDB has nothing — so a room stays until something removes it.

Left alone, the rooms simply accumulate. The first run of this job found 695 of
them and deleted 363.

## What it deletes

A room is old once it is a day old, judged by the time it was created:

| Tree | Game | Where the time lives |
| --- | --- | --- |
| `games` | Vibe Words | `createdAt` |
| `sudoku` | Vibe Sudoku | `createdAt` |
| `trio` | Vibe Trio | `meta/createdAt` |
| `blurt` | Vibe Blurt | `meta/createdAt` |

**A room whose creation time cannot be read is kept.** An unreadable shape is far
more likely to be a schema change than rubbish, and deleting on a misread is the
one mistake here that cannot be undone.

The rule itself is in `prune.js` and is tested by `prune.test.js` — no database,
no credential, no deploy:

```sh
cd functions && npm test
```

## The twin in `Tools/`

`Tools/prune_games.py` does the same job from a command line, as you, with your
own credentials. It reports rather than deletes unless it is given `--apply`, and
it takes `--hours` and `--keep CODE`:

```sh
python3 Tools/prune_games.py                  # what would go
python3 Tools/prune_games.py --apply          # do it
```

Two implementations, one rule — worth knowing about, because they can drift. The
function covers the four trees above; so does the script.

## Deploying

```sh
cd functions
npm install
firebase deploy --only functions
```

The first deploy enables the APIs it needs (Cloud Functions, Cloud Build, Cloud
Run, Artifact Registry, Eventarc, Pub/Sub, Cloud Scheduler), which is why the
project has to be on the Blaze plan: scheduled functions have no free tier.

Wrangling the local CLI install and its config directory, as the other deploys in
this repository do:

```sh
cd functions
XDG_CONFIG_HOME=$PWD/../.build/fbconfig \
  ../.build/fbcli/node_modules/.bin/firebase deploy --only functions
```

The schedule is **03:00 America/Denver**, named rather than a UTC offset so it
does not drift across daylight saving. The Cloud Scheduler job is called
`firebase-schedule-pruneGames-us-central1`.

## Running it outside the schedule

Firing the scheduler job is the honest test — it goes through the same path the
03:00 run does:

```sh
curl -X POST -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  "https://cloudscheduler.googleapis.com/v1/projects/vibe-words-party/locations/us-central1/jobs/firebase-schedule-pruneGames-us-central1:run"
```

The trigger returns `200` as soon as the run is *queued*, which is worth knowing:
a `200` says nothing about whether the function worked. The function's own log
does — `firebase functions:log --only pruneGames`, or Cloud Logging. An
invocation that fails inside the container is logged as an error and the
scheduler's attempt shows `{"code": 13}`.

That is exactly how the first version of this shipped: `admin.database is not a
function`. `firebase-admin` 14 dropped the namespaced API and the call fails at
run time rather than at deploy time, so the function deployed cleanly, ran daily,
and did nothing. The modular `getDatabase()` is what is in there now.
