# AstroPixel v8: Mission Control talks, NORMAL sits in the middle, EASY can retry

Read the repo's `CLAUDE.md` and `context/04_STATUS_AND_ROADMAP.md` first (rules: numbers live in
`scripts/data.gd` with a `src`, no AI-generated audio or images, do not commit or push), then
`docs/V7_PLAN.md` (the three levels and `Game.diff()`), then this file. This file wins where they differ.
The project is `C:\Games\space-apps-2026\team-repo\game` (a clone of the team's GitHub repo, v7 plus the
teammate's multiplayer). Multiplayer must keep working: everything here is local presentation, so do not
change what is sent over `Net`, and keep solo and online code paths as they are.

## What the team asked for (14 Nov, after playing v7)
1. "the mission brief page sometimes is too long to fit and i wanna scroll but i cant scroll, add a scroll
   to menus that are too long to fit in the box"
2. "the flying rover thrusters should not be flames/fuel but rather a gas" (research: cold-gas thrusters
   that blow nitrogen, as on NASA's MMU jetpack of 1984, which had 24 nitrogen thrusters, and on the SAFER
   rescue pack; no combustion, so no flame)
3. "the medium difficulty is exactly like hard, make it harder than easy and easier than hard, like re-add
   the show me button but keep out the auto build option"
4. "add a restart from checkpoint on EASY MODE that resets me in the section i died from"
5. Mission Control dialogue (their full brief is below, shortened only in wording):
   - **Reuse the existing dialogue**: the builder's guide (portrait, speech bubble, typed text, its
     controls). Extend that one component; do not build a second, competing dialogue system.
   - **No new decision pop-ups.** Nothing here adds a choice, a confirmation or an interruption.
   - **Short objectives, detailed dialogue.** A task shows a short objective ("Collect rock samples");
     the dialogue says what to do, why it matters and what to watch ("Drive the rover to suitable rocks
     and use the drill. Watch your battery: you need enough power to finish."). Match the destination and
     the task. Read quantities and conditions from the mission data; never hardcode or invent them.
     Objective progress stays visible in the normal interface.
   - Show the explanation when the mission is briefed or the task becomes active; let the player replay
     it by selecting the objective or its existing information control; do not repeat it unasked.
   - **Introduce existing events about 2 seconds before their pop-up**: event triggers, Mission Control
     says one specific line ("We are seeing unusual readings from one of your systems."), then the
     existing card opens by itself. The line sets the scene; it never reveals an outcome, picks an answer
     or invents facts.
   - **Timing**: never trigger an event twice; never two dialogue panels or cards on top of each other;
     queue ordinary lines; keep each event's choices, odds, consequences and completion logic; response
     timers start when the card itself appears; respect the existing pause behaviour; do not delay urgent
     safety warnings; the player can finish or skip the text with the existing controls. The lead-in time
     is configurable, default about 2 s.
   - **A playful "bibi" sound while text types on** ("bibiibibibibibi", or "mimimimi"): short synthesized
     blips, in step with the letters, slight pitch and timing variation, small pauses at punctuation and
     sentence ends, nothing for spaces, quiet under the gameplay sounds, stopped at once when the text ends,
     the dialogue closes or the player skips, never overlapping when lines change fast. Use the existing
     audio system; respect mute; add a dialogue-sound volume or toggle if the settings allow it. No spoken
     voice, no ElevenLabs.
   - Scope: missions, physics, builder, minigames and event outcomes stay as they are.

## The one dialogue component: `scripts/talk.gd` (a working skeleton is already there)
```gdscript
const Talk = preload("res://scripts/talk.gd")
var talk: Control = Talk.make(self, Vector2(8, 300))   # once, in _ready(); `at` = top left of the portrait
talk.say("One line.")                                   # or an Array of lines; queued
talk.say(lines, {"who": "control", "hold": 2.5, "then": Callable(), "urgent": false, "key": "site_task"})
talk.busy() -> bool      talk.skip()      talk.clear()      Talk.said(key) -> bool (static)
```
It has no buttons. It draws nothing while silent. `who`: "control" (the Mission Control operator, the
portrait the MESSAGE FROM EARTH card uses) or "guide" (the builder's engineer). The talk agent finishes
it (the builder's exact look, the chatter sound, punctuation pauses, a fitted bubble); the signatures
above are fixed, so every other agent can code against them today.

Task texts come from the core, never from a screen (stubs exist today, the talk agent fills them in):
```gdscript
Game.task_short() -> String                 # the objective, short: "Collect 4 rock samples"
Game.task_talk(where) -> Array              # 1 to 3 short lines; where = "brief" | "builder" | "site"
```
Event lead-ins are done inside `EventCard.open()` (the card node shows the dialogue line first, then
itself), so `EventCard.is_open()` is already true during the lead-in and the screens stay frozen exactly
as they are during a card. Screens that open cards change nothing for this.

Checkpoints (already in `game.gd` / `main.gd`): `Game.can_retry() -> bool` (EASY, solo, a goal was
missed), `Game.retry_name() -> String` ("THE LANDING"), `Game.retry()`.

## Who owns what (edit nothing else)
| agent | files | work |
|---|---|---|
| talk | `scripts/talk.gd`, `scripts/audio.gd`, `audio/`, `tools/audio/`, `scripts/event_card.gd`, `scripts/events.gd`, `scripts/data.gd`, in `scripts/game.gd` only `task_short()` / `task_talk()` | the component, the chatter sound, event lead-ins, task texts |
| builder | `scripts/screens/builder.gd` | the guide drawn by the shared component, task explanation and replay, NORMAL gets SHOW ME back |
| front | `scripts/screens/menu.gd`, `scripts/screens/report.gd` | scrolling, briefing dialogue and replay, the EASY retry button |
| surface | `scripts/screens/surface.gd` | site explanation and replay, short objective |
| probe | `scripts/screens/probe.gd`, `art/probe/`, `tools/art/gen_probe.py` | nitrogen cold-gas puffs, site explanation and replay, short objective |
| orchestrator | `scripts/main.gd`, checkpoints in `scripts/game.gd`, `tools/dev/`, `docs/`, `context/`, exports | |

## Working while others work
- **Keep your file parse-valid at every save**: `main.gd` preloads every screen, so one broken file
  breaks every other agent's screenshots. If a run fails with a parse error in a file you do not own,
  wait a minute and retry.
- Set `export GODOT="<path to the Godot 4.7.2 console exe>"` and run from the
  `game` folder: `bash tools/dev/shot.sh <screen> <dest> <ABSOLUTE out.png> [wait] task=0|1|2 call=debug_x`.
  Scratch files under `C:\Games\space-apps-2026\research\work\v8_<label>\`. Never open a visible window.
- Keep every `debug_*` hook working (the self-play test `tools/dev/e2e.sh` uses `debug_auto` /
  `debug_autopilot`; the multiplayer test `scripts/mp_test.gd` drives the screens too).
- The team reviews by eye: check your work once by screenshot, then stop.
- Final report: under 150 words. What changed, what you checked, what is not done.

## v8 talk as built (talk agent; helpers for the builder, all static, the fixed API above is unchanged)
```gdscript
const Talk = preload("res://scripts/talk.gd")
Talk.wrap(text, width = Talk.BUBBLE_W - 14, max_lines = 3) -> String   # (= Talk.wrap_text) word wrap with "\n", builder font size 10
Talk.typed_chars(text, seconds) -> int     # letters shown after `seconds`, with Data.TALK cps and punctuation pauses
Talk.draw_bubble(ci, portrait_rect, bubble_pos, text, typed_chars, who = "guide", happy = false, more = false) -> Rect2
    # draws the portrait box (Pix.panel, cyan), the portrait frame (idle/blink/talking/happy, picked from
    # typed_chars and the clock), and the light bubble with the tail toward the portrait, dark ink, the green
    # paper when happy, and a small "ENTER" hint when more = true. `text` is wrapped inside (pass raw or
    # pre-wrapped text). Returns the bubble rect (use it for click hit tests).
Talk.chatter_tick(text, prev_chars, now_chars)   # call each frame with the letter counts before/after: one
    # Audio.chatter() per newly revealed letter, Audio.chatter_stop() once now_chars reaches the end
Audio.chatter(ch: String)   Audio.chatter_stop()   Audio.chatter_on (bool, saved with the settings)
```
Builder switch, in short: replace `int(g_t * SAY_CPS)` by `Talk.typed_chars(g_text, g_t)`, call
`Talk.chatter_tick(g_text, n_before, n_after)` in `_guide_tick`, and in `_draw_guide` call
`Talk.draw_bubble(ci, GUIDE_BOX, Vector2(BUBBLE_X, GUIDE_BOX.position.y + 2), g_text, n, "guide", g_happy > 0.0)`
(the pips stay builder code). Call `Audio.chatter_stop()` when the guide is hidden or the screen leaves.
Also built: `Talk.type_secs(text)`, `Talk.clear_all()` (every live Talk node goes quiet; `EventCard.open()` calls
it). The event lead-in is a Talk inside the card at (8, 300), so a guide the builder draws itself (not a Talk
node) should hide while `EventCard.is_open()`. Numbers: `Data.TALK` (cps 55, hold 2.5 s + 0.02 s per letter,
pauses 0.28 / 0.12 s, lead 2.0 s or typing + 0.5 s, chatter -16 dB, +-12% pitch, every 2nd or 3rd letter).
Chatter files: `audio/talk_bi*.wav` from `tools/audio/make_chatter.py` (pure Python, 22-38 ms, peak -9 dBFS).
`Audio.set_chatter(on)` switches the dialogue sound and keeps it in `user://audio.cfg`; no screen shows that
switch yet (the game has no sound settings). Task texts: `Data.JOBS[job]` short/kit/act by kind,
`Data.DEST[id]` why/build_talk.
