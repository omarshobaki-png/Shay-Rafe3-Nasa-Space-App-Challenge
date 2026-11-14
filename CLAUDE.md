# Instructions for Claude (and any teammate) working in this repo

This is **Space Mission Designer**, Team Shay Rafe3's entry for the NASA Space Apps Challenge 2026
("Space Mission Design Game"). It's a Godot 4.7.2 / GDScript 2D pixel-art game.

## Before doing anything

1. Read [`context/README.md`](context/README.md) and follow its reading order (6 short files). At
   minimum, read `context/00_TEAM_NOTES.md`, `context/01_PROJECT_BRIEF.md` and
   `context/04_STATUS_AND_ROADMAP.md`.
2. Read `context/00_TEAM_NOTES.md`: it's the team's vision and the source of truth for *what* to
   build. Decisions are listed in `context/03_GAME_DESIGN.md` §5. **Don't change the vision or a
   decision on your own.** Game-design choices must come from the team (a hackathon rule: AI must not
   come up with the idea). For anything new or unclear, lay out the options and their costs, then ask.
3. Pick work from the roadmap table in `04_STATUS_AND_ROADMAP.md`, top first, unless the user says
   otherwise.

## Hard rules

- **Godot 4.7.2, GDScript only** (no C#: Godot 4 can't export C# to the web). Don't write Godot 3
  syntax.
- **Every number goes in `game/scripts/data.gd` with a `src` field.** Real values name their source;
  invented values say `"game rule"` or `"game estimate"`. Never hard-code a gameplay number in a
  screen script.
- **No AI-generated images, video or audio, and no NASA logos.** Art is produced by the scripts in
  `game/tools/` (Blender + Python) or drawn by the team. Real NASA photos are allowed with a credit.
- **Disclose AI use.** If you add a new kind of AI contribution, update the "AI disclosure" section
  of the root `README.md`.
- **Don't commit or push.** The team commits. Don't add files over 50 MB; the Windows build goes to
  GitHub Releases, not git (`builds/` is ignored).
- `docs/` is the GitHub Pages site. `docs/index.html` is the project website (Ahmad's design: overview, the game,
  missions, rocket-equation lab, NASA data, team), with `docs/styles.css`, `docs/main.js`, `docs/assets/`
  and `docs/NASA_Data_In_Game.pdf`. The game
  lives in **`docs/play/`**. The "Web" preset in `game/export_presets.cfg` exports to `build/web/`
  (ignored by git), with threads off. Copy that output into **`docs/play/`** to publish it (never into
  `docs/` itself, which would overwrite the website), and keep the empty `docs/.nojekyll` file.
- Keep the base resolution at 640×360 with nearest filtering. Pixel art must stay crisp.

## How to run and check

- Editor: open `game/project.godot` in Godot 4.7.2 and press F5.
- Jump straight to a screen: run with `-- screen=builder dest=mars` (also `flight`, `landing`,
  `surface`, `probe`, `report`; dest `moon|mars|saturn`). It loads the example ship.
- Web build test: serve `docs/` over HTTP (e.g. `python -m http.server` in `docs/`) and open `/play/`.
  Opening the file directly fails.
- After a change: run every screen for all 3 destinations and check the Output panel for errors.
  Then say plainly what you did *not* play by hand.

## Keep the context true

When you finish a roadmap item or the team decides something:
- tick or edit `context/04_STATUS_AND_ROADMAP.md`;
- fill in the decision line in `context/03_GAME_DESIGN.md`;
- if you changed what the game does, update the code map and mission table there.
