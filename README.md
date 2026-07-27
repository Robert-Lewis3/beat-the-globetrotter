# Beat The Globetrotter

A retro arcade boss-battle trivia game (Street Fighter style). One big screen is
hosted by you in **Godot**; players scan a **QR code** and answer on their phones.
One hero represents the whole room and fights 3 bosses — **Touri**, **Roam**, and
**Umberto** — 4 questions each.

## How it works

```
Godot game (host screen)  <--WebSocket-->  relay server (Node.js)  <--WebSocket-->  phones (browser)
                                            also serves the phone answer page + QR codes
```

- **Percentage damage**: each question is worth 25% of the boss's HP, scaled by
  the % of the room that answered correctly. Wrong answers cut both ways — the
  hero takes up to 25% damage scaled by the % who got it wrong (dramatic only,
  no early KO; hero HP refills at the start of each boss fight).
- If the boss still has HP after question 4 → **OVERTIME** sudden-death question
  (majority correct = KO, otherwise DEFEAT with an arcade Continue countdown).
- **Combo** counts consecutive questions where ≥50% of the room was right.
- Players earn 100 pts per correct answer + up to 50 speed bonus; the Victory
  screen crowns the top 3.

## Run it locally (testing)

1. Start the relay: `cd server && npm install && npm start` (listens on :3000)
2. Open `game/` in Godot 4.x and press F5 (or run
   `Godot_v4.7-stable_win64_console.exe --path game`).
3. Phones on the **same machine/network** can open `http://<your-ip>:3000/<ROOM>`
   — for a quick solo test just open that URL in a desktop browser tab.

## Deploy the relay to Render (for game night)

1. Push this repo to GitHub (private is fine).
2. In the Render dashboard: **New → Blueprint**, pick the repo — it reads
   `render.yaml` and creates the `globetrotter-relay` web service on the free plan.
3. Once live you'll get a URL like `https://globetrotter-relay.onrender.com`.
4. Put that URL in [game/server_config.cfg](game/server_config.cfg):
   `url="https://globetrotter-relay.onrender.com"`
5. **Free-tier note**: the service sleeps after ~15 min idle. Open its URL in a
   browser a minute or two before game night to wake it up.

## Graphics layer

Visual polish lives entirely outside the game logic, so it can be tuned or
removed without touching the question flow or networking:

- [shaders/crt.gdshader](game/shaders/crt.gdshader) — arcade tube look: scanlines,
  curvature, vignette, channel fringing, bloom. Tune the `uniform` defaults at the
  top of the file. It's applied by [CRT.gd](game/scripts/ui/CRT.gd) on a canvas
  layer above everything, and is **off on the Lobby screen on purpose** — curvature
  and scanlines over a QR code can stop phone cameras reading it. A screen opts out
  with `var crt_enabled := false`.
- [Fx.gd](game/scripts/ui/Fx.gd) — impact sparks, dust puffs, screen flash, screen shake.
- [ArenaFx.gd](game/scripts/ui/ArenaFx.gd) — blowing sand, temple mist, twinkling
  stars, turning globe. The static background in `Arena.gd` is still drawn once.

Measured ~60 fps on integrated Intel graphics at 1920x1080.

## Changing the questions

Everything lives in [game/scripts/Questions.gd](game/scripts/Questions.gd) —
question text, options, correct answers, accepted open-end keywords, fun facts,
boss names/taunts/colors. Nothing else needs to change. The bots' answer key in
[server/test/simulate.js](server/test/simulate.js) will need matching updates if
you want the automated test to keep passing.

## Automated end-to-end test

- Terminal 1: `cd server && npm start`
- Terminal 2: run the game with env `GT_AUTOPILOT=1`, wait for `ROOMCODE:XXXX`
  in its output, then in terminal 3: `cd server && node test/simulate.js XXXX 4 0.75`
- The game plays itself through all 3 bosses and exits 0 on success.
  `GT_AUTOPILOT=2` with correct-rate `0` tests the defeat path.
  Set `GT_SHOTS_DIR=<dir>` (non-headless) to also capture per-screen screenshots.

## Host controls

Space bar (or the on-screen buttons) advances everything:
SHOW QUESTION → answers open with a 25s countdown (auto-locks early when everyone
has answered) → REVEAL → NEXT. Read the question aloud like a game-show host.

## Credits

- Character sprites & sounds: [Kenney.nl](https://kenney.nl) (CC0) — Tiny Dungeon
  + Digital Audio packs
- Font: Press Start 2P (SIL Open Font License)
