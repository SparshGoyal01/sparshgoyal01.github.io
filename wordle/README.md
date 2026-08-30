# Word Master Wordle

A small daily word game. Four grids — **5×5, 6×6, 7×7, 8×8** (an *N*-letter word in *N*
guesses) — one shared word per grid per day, a clock that runs while you play, and a
**today's leaderboard** ranked by fewest guesses, then fastest time.

Single file, no build step. `index.html` + the word lists in `words/`.

### Flow

Three views, hash-routed so reloads and back/forward work:

1. **`#home`** — enter your name, pick a grid, read the rules, hit **PLAY**.
2. **`#play/<n>`** — the grid opens and the timer starts. Play until you solve it or run
   out of guesses; the clock stops and you're taken to the result.
3. **`#result/<n>`** — your result banner, today's leaderboard (per-grid + an Overall
   tab), and a **Try other levels** section with the grids you haven't played yet today.

One attempt per grid per day. Finished grids show your score on the home screen and are
locked; an unfinished game resumes where you left off (timer included).

---

## Run locally

The page loads the word lists with `<script src>`, so it needs to be served over HTTP
(opening `index.html` as a `file://` works in some browsers but not all).

```bash
# any static server, from this folder:
python3 -m http.server 8777      # then open http://localhost:8777
# or:  npx serve .
```

## Deploy

It's already in the portfolio repo, so GitHub Pages serves it at
`https://<user>.github.io/wordle/` once Pages is enabled for the repo. Nothing to build.

---

## Leaderboard (Firebase)

**Configured and live** — project `brain-games-wordle`, Realtime Database in
`asia-southeast1`. The web config in `index.html` (`FIREBASE_CONFIG`) is public by
design; the data is protected by `firebase-rules.json` (published), which allows public
reads of `leaderboard/<day>` and a **write-once**, shape-validated create at
`leaderboard/<day>/<level>/<playerId>` — no edits or deletes. Clear the board from the
console **Data** tab if you ever need to.

If Firebase is ever unreachable or `FIREBASE_CONFIG` is blanked back to `REPLACE_ME`,
the game still plays fine — the leaderboard just falls back to **you only**
(`localStorage`).

To rebuild it elsewhere: create a project → **Build → Realtime Database → Create
database** (locked mode) → **Project settings → Your apps → Web** → paste the config
into `FIREBASE_CONFIG` (the game auto-detects real values via `FIREBASE_READY`) → paste
`firebase-rules.json` into **Rules** and publish.

### Data shape

```
leaderboard/
  2026-08-30/            # local calendar day
    5/                   # grid size
      p_ab12cd34: { name, attempts, timeMs, won, ts }
```

One row per device per grid per day, written once when the game ends.

### Notes / caveats

- **Identity is a display name only**, stored on the device — no login. Two devices =
  two rows. Names aren't unique.
- The game is **client-side**, so the leaderboard is honour-system. The daily answers
  file is ROT13'd so you can't read today's word by glancing at `words/answers-*.js`,
  but a determined player can still dig it out of the running page. Fine for playing
  with people you know.
- "Today" is the player's **local** calendar date. Players in the same timezone see the
  same word and share a board.

---

## Word lists

| file | contents |
|------|----------|
| `words/answers-N.js` | curated common *N*-letter words, ROT13'd — the daily solutions |
| `words/valid-N.js`   | every accepted guess (large, permissive dictionary) |

The daily word for grid *N* is `answers-N[ daysSince(2026-01-01) mod length ]`.
Lists are pre-shuffled, so the sequence is fixed but not alphabetical.

Regenerate them with `tools/build-words.sh` (needs `curl` + coreutils). Sources:
- validity: `dwyl/english-words`
- commonness: `hackerb9/gwordlist` (Google Books frequency, filtered to dictionary
  headwords — no proper nouns or web junk)
