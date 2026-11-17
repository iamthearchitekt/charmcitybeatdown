# CHARM CITY BEATDOWN

A playable Godot 4 one-on-one arcade fighter with original characters on Baltimore's Inner Harbor docks. Windows x64 build and complete editable GDScript source are included. The visual revision uses original generated raster sprite atlases and detailed painted-style harbor artwork. Effects, defeat voices and music come from user-supplied audio files.

## Visual revision

The roster now has four selectable appearances: **Marcus** and **Maya** are the original fighters, **Alex** is the white male with brown hair, and **Emma** is the white female with blonde hair. Marcus/Alex share the projectile and anti-air move set; Maya/Emma share the advancing pressure move set. Each has a complete 18-pose sprite set and matching portrait. Use Left/Right or click a fighter to choose from all four.

All four grounded knockdown/KO poses lie face-up on their backs, with the head away from the opponent. Facing stays locked while down so the body cannot flip if the opponent crosses over. Nonfatal knockdowns recover through fixed crouch and guard poses; defeated fighters remain grounded.

The initial geometric characters and flat stage have been replaced. Each fighter has 18 illustrated key poses for stance, movement, punches, kicks, crouching, jumping, guard, hit reactions, uppercut and KO. Idle animation stays in hands-up boxing stances. The stage has textured brick, an illuminated waterfront and a two-frame water loop at four frames per second. The skyline, boat, dock and props remain still; rain continues as a separate foreground effect. The title, character selection, portrait health bars and results screen use a unified arcade presentation. Fighters stand approximately 291 pixels tall (30% larger than the previous 224-pixel size) in a 720p viewport, with correspondingly enlarged collision geometry. Player 1 uses the arrow keys. Match music now uses the supplied Go Straight track at the increased volume.

## Movement and pace update

Regular jumps now use a dedicated tucked-leg, hands-up airborne pose for each fighter. Jumping kicks extend the leg only during the attack, then retract to the neutral jump pose; jumping punches have separate airborne punch artwork. For P1, **Up alone jumps; press C or V while airborne to kick**. P2 uses **W**, then **H or J**. Controller Up jumps, followed by the mapped kick button. These visual states do not change combat hitboxes or attack timing.

- Walk speed increased from 3.5 to 5.2 pixels/frame for Marcus/Alex, and 4.6 to 6.0 for Maya/Emma.
- **Double-tap forward or back** for a quick dash/backdash. Dashes do not grant invincibility. You can attack out of the latter part of a dash.
- Jumps travel faster with limited midair steering. Projectiles also move faster.
- Attack startup is approximately 20% shorter, recovery approximately 26% shorter, and hitstop is 3 frames for light hits / 5 for heavy hits. Short combos remain supported.
- Guard contact opens space. CPU opponents use short approach steps and pause/back off after two attacks instead of continuously crowding the player.
- Knocked-out fighters continue falling during round-end and settle on the dock. Both fighters settle correctly after a double KO.
- Pause freezes simulation, fighter animation, rain, water and effects. Resume continues from the frozen state.

## Play on Windows

1. Double-click **Play.cmd** in this folder, or **build\CharmCityBeatdown.exe**. The included executable needs no Godot installation.
2. Choose **Arcade**, **Local Versus**, or **Training** with Up/Down and Enter, or click a mode. On the title screen, Left/Right or the CPU button changes difficulty.
3. Choose your fighter with Left/Right, press Enter, choose the opponent, and press Enter again.
4. **Arrow keys control Player 1: Up jumps, Down crouches, Left/Right move.**

**Go Straight** plays during matches at -13 dB. It stops on the KO frame before the defeat scream, and restarts for the next round. **Level Complete** plays once when the results screen opens, after the KO presentation ends. Rematching or returning to the title stops that clip. N toggles menu and match music; M mutes all audio. F11 toggles fullscreen. Esc pauses and shows both move lists. Close the window to quit.

## Sound update

The main menu and character selection play the supplied **Never Return Alive** track at -13 dB. It cuts immediately when a match starts, before **Go Straight** begins; returning to the title restarts it. Every screen uses bundled **Upheaval Pro** for headings, fighter names, HUD, controls, move lists and buttons; the title screen no longer displays the fighter sprites, their name labels, or the Baltimore / After Midnight tagline.

21 active imported WAVs provide distinct punch/kick impacts, blocking, attack whooshes, specials, movement, landings, menus and defeat voices. Marcus and Alex use `27_male_ko.wav`; Maya and Emma use `53_chunli_ko.wav`. A defeat scream plays once only when a fighter is knocked out in the match-deciding round. Earlier round losses and drawn double KOs have no scream; body thuds still follow the actual landing. Combat audio pauses with the game. See `audio/SFX-MAPPING.md` for the source mapping and `audio/sfx-map.json` to adjust effects levels or replace clips.

## Knockdowns and final KO

The announcer now says **Fight!** at each round start. Only the final match loss triggers a defeat scream. Results then announce **You win!** or **You lose!** from Player 1's perspective in Arcade; Local Versus uses **You win!** for the named winner. The results screen contains no fighter sprites or match HUD: logo, winner, score and buttons are centered. Completion music ducks briefly for the announcement and returns to normal afterward. Rematch/title exit cuts the announcement immediately.

Throws, sweeps and launchers send the victim backward using a fixed airborne hit pose, then onto the dock for 22 frames before a 14-frame recovery. A sweep uses a lower arc. Jump launch velocity is now 25.5 pixels/frame, rising knockbacks use 16.5, and sweeps use 10.5; backward knockback speed is 9.2, or 10.5 for throws. Knockdown and get-up artwork uses fixed key poses without sprite rotation or scaling animation. Airborne hits and lethal hits also cause a knockdown. Grounded jabs and ordinary punches preserve standing hitstun and short combos. Prone/recovering fighters cannot be hit until they regain control; defeated fighters stay down. Knockback speed, launch speed, grounded duration and recovery duration can be edited per move in `data/moves.json` (`knockback_speed`, `launch_speed`, `down_frames`, `rise_frames`, `knockdown`).

The match-winning KO uses 0.8 seconds at quarter speed followed by 0.4 seconds at half speed, then resumes normal speed. Fixed 60 Hz combat steps are scheduled less frequently during this presentation; move frame data is unchanged. The defeat scream keeps its normal playback rate. Pause freezes slow motion too. Timeouts and non-decisive rounds do not trigger it.

## Default controls

| Action | Player 1 | Player 2 | Xbox-style controller |
|---|---|---|---|
| Left / right | Left / Right arrows | A / D | D-pad or left stick |
| Jump / crouch | Up / Down arrows | W / S | Up / Down |
| Dash / backdash | Double-tap Right / Left (relative to facing) | Double-tap D / A (relative to facing) | Double-tap forward / back |
| Light punch (LP) | Z | F | X |
| Heavy punch (HP) | X | G | Y |
| Light kick (LK) | C | H | A |
| Heavy kick (HK) | V | J | B |
| Throw | B | R | LB |
| Pause / resume | Esc | Esc | Start |

The first connected controller drives Player 1 and the second drives Player 2. Keyboard and controllers can be mixed; keyboard input remains active. Default controller A confirms menus and B returns. D-pad and left stick both navigate menus. Shared keyboard rollover depends on your hardware; two controllers avoid keyboard ghosting.

### Sega Bluetooth controller setup

1. Pair your controller in Windows **Settings > Bluetooth & devices**, then launch the game. If Windows does not expose it as a game controller, use the pad manufacturer's Windows-compatible mode and pair again.
2. Click **Controller Setup** on the title screen or press **F4** from any screen. During a match this pauses the game.
3. Press any button on the pad you want to configure, then follow the 12 prompts. Release each control before entering the next. Directions can be buttons or axes, and attacks can also use axis-backed buttons.
4. Suggested six-button Sega layout: **X = light punch, Z = heavy punch, A = light kick, C = heavy kick, Y = throw, Start = pause**. Set **A = menu confirm** and **B = menu back** in the last two prompts. Physical labels are captured directly; the game does not guess Windows button numbering.
5. When it says **Saved**, press **Esc** to close setup. If you opened it during a match, press mapped **Start** or Esc to resume.

Only controller settings change: **P1 arrows / Z X C V B and P2 WASD / F G H J R remain exactly as before**. Complete mappings are saved per controller identity in `%APPDATA%\Godot\app_userdata\CHARM CITY BEATDOWN\controllers.cfg`. Identical models share a mapping. Esc cancels an unfinished mapping without replacing the old one. Reconnects restore the saved mapping and player slot; disconnecting a player controller pauses a match without moving the other controller to a different player. To remap again, reopen F4.

No controller was connected during this run. The custom mapping path is tested with synthetic Godot controller events; the actual Bluetooth connection and your pad's reported buttons still need a hands-on check.

## Combat and commands

Hold **away from your opponent** to block. Stand guard blocks mids and overheads; crouch guard blocks mids and lows. Throws beat guard. Jumping attacks are overheads. Crouching kicks are lows. Standing heavy kicks are overheads. Air blocking is unavailable.

Directions are relative to your current facing: **6 = forward, 4 = back, 2 = down, 8 = up, 3 = down-forward, 5 = neutral**. P means either punch. Enter motions within about 0.4 seconds. Specials take priority over normals. Attack inputs buffer for six simulation frames, including hitstop. Cancel routes require contact; recovery remains punishable on a whiff.

| Fighter | Command | Move | Function |
|---|---|---|---|
| Marcus / Alex | 236 + P | Harbor Current | Mid projectile |
| Marcus / Alex | 623 + P | Breakwater Rise | Rising anti-air; punishable recovery |
| Marcus / Alex | Throw | Mooring Toss | Close-range guard-beating throw |
| Maya / Emma | 236 + P | Pratt Street Rush | Fast advancing pressure |
| Maya / Emma | 623 + P | Redline Vault | Advancing overhead rising strike |
| Maya / Emma | Throw | Switchback | Close-range guard-beating throw |

**Player 1, facing right:** Harbor Current / Pratt Street Rush = Down, Down+Right, Right+Z (or X). Rising special = Right, Down, Down+Right+Z (or X). Reverse Left/Right when facing left.

All four fighters have LP, HP, LK, HK, four crouching attacks, and four jumping attacks. Normal move names and precise frame data are in `data/moves.json`.

Practical close-range routes, with `>` meaning cancel after contact:

- Both: LP > HP > 236 P.
- Both: LK > HK, or crouching LK > 236 P.
- Marcus / Alex: crouching LP > crouching HP > 623 P.
- Maya / Emma: LP > HP > 236 P > 623 P.

The first player to win two rounds wins the match. Each round lasts 99 simulation seconds; hitstop pauses the timer. Timeouts award the round to the fighter with more health. Draws and double KOs replay the round without awarding a win.

After the match-winning KO, the defeat scream and brief slow-motion presentation play, followed directly by the results screen and completion music. There is no finishing move, command, or extra input window. Enter rematches the selected matchup; Esc returns to the title.

## Training

- **F2:** cycle stand, crouch, standing guard, crouching guard.
- **F3:** reset positions and health.
- **F1:** show hurtboxes (green), pushboxes (blue), active hitboxes (red).
- Input history shows newest input first, in facing-relative numeric notation.
- Health regenerates between exchanges; the timer and match endings are disabled.

## Source and extension

Open `project.godot` in Godot 4, then press **F5**. This build was implemented and tested with Godot 4.7.2. `Launch.ps1` finds the installed Godot on PATH and can launch the source if the executable is absent. Node.js is needed only to regenerate the optional procedural assets.

| File | Purpose |
|---|---|
| `scripts/combat.gd` | Fixed 60 Hz combat, collision, guard rules, trades, rounds, results |
| `scripts/commands.gd` | Direction history, motion recognition, input priority |
| `scripts/controller_bindings.gd` | Separate saved controller profiles, button/axis bindings and player slots |
| `data/moves.json` | Fighter definitions and editable frame data |
| `scripts/cpu.gd` | Delayed, range-sensitive legal-move CPU |
| `scripts/main.gd` | Menus, controls, HUD, audio and effects |
| `scripts/sfx_bank.gd` | Bounded, pause-aware effect and KO voice playback |
| `audio/sfx-map.json` | Editable source WAV routing, variants and levels |
| `scripts/harbor_stage.gd` | Painted Inner Harbor stage, two-frame water shader and separate rain |
| `scripts/fighter_sprites.gd` | Atlas regions, pivots, pose animation and portraits |
| `data/appearance-atlases.json` | New sprite regions and original fighters' face-up KO artwork |
| `assets/` | Original generated fighter atlases, harbor artwork and title logo |
| `tools/build-assets.cjs` | Reproducible original WAV synthesis and initial move table generator |
| `tests/verify.gd` | Automated combat and scene-input checks |

Combat timing is independent of visual animation. Contacts are collected before applying damage, so simultaneous hits trade. Each move/projectile can hit a target once. Attack-facing locks during moves, while neutral facing updates after side switches. Fighter geometry uses a common 1.82 scale; the jump arc supports crossing over the larger opponents.

Edit `moves.json` directly to tune attacks. **Running `node tools/build-assets.cjs` regenerates that JSON and overwrites manual move edits.** To re-export elsewhere, set the Windows export template paths in `export_presets.cfg` to your installed Godot templates (or clear the custom paths to use your standard installation).

Run the verification suite from this folder with your Godot console executable:

```powershell
Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/verify.gd
```

## Verification and remaining testing

18 announcer/results checks pass for round-start voice, pause/resume, both Arcade outcomes, both Local Versus winners, one-shot sequencing, centered buttons, rematch and title-exit cancellation. The centered results screen was visually inspected. The revised SFX suite passes 36 checks, including silent early-round losses and preserved landing sounds. The rebuilt Windows executable launched successfully with no runtime errors in the launch log.

28 jump-pose checks pass across all four fighters: neutral jumps, no damage without an attack, legal airborne kicks, distinct kick/punch artwork, and neutral startup/recovery poses. Side-by-side rendered jump/kick captures are in `tests/visual/jump-vs-kick-*.png`.

33 controller checks pass for custom Sega-style mapping, axis D-pads and attack buttons, duplicate/held input rejection, saved settings, cancellation, keyboard isolation, both players, mirrored QCF/DP commands, menu navigation, disconnect pause and reconnect retention. Run `tests/controller_verify.gd` with the Godot console executable. These are simulated controller events, not a physical Bluetooth hardware test.

Project repository: https://github.com/iamthearchitekt/charmcitybeatdown.git

15 roster checks pass for four-way selection, Alex/Emma match launch, every fighter's legal special and matching audio, defeat voice assignment, rematch selection retention and locked grounded facing. All four face-up KO poses, the four-fighter selection screen, new portraits, pause move lists and Alex's results screen were visually inspected. Report: `tests/roster-verification.txt`.

The knockdown/music update passed 49 additional checks covering both fighters, both knockback directions, throws/sweeps/launchers, corner recovery, ground-hit protection, increased match music levels, immediate KO cutoff, final-KO slow motion, pause, direct KO-to-results completion audio, one-shot playback, rematches and title exit. Coverage also includes menu music continuity, immediate track switching, the music toggle, and the bundled Upheaval Pro font. Rendered title, airborne, grounded and recovery poses were inspected. Report: `tests/knockdown-audio-verification.txt`.

39 audio checks passed: 32 event-routing checks and 7 checks using the real audio driver. These cover all 21 active WAV imports, hit versus block and whiff sounds, projectile timing, trades, match-deciding KO screams, silent earlier round losses, fighter identity in both slots, silent drawn double KOs, landing synchronization, pause/resume, bounded playback and clipping headroom. The latest overlap stress test, including the new match music, peaked at -1.2 dBFS with the master limiter. Reports: `tests/sfx-verification.txt` and `tests/audio-mix-verification.txt`. Run `tests/sfx_verify.gd` and `tests/audio_mix_check.gd` with the Godot console executable without `--headless` to exercise the real audio driver. Subjective voice/effect balance still benefits from hands-on play at your preferred speaker volume.

63 combat/input/asset checks and 5 GPU-rendered visual regression checks passed. Coverage includes specials from both sides, normal input priority, standing/crouching guard, throws, trades, one-hit contact suppression, startup/whiffs, corners, side switches, projectiles, anti-airs, hitstop buffering, combos, rounds, timeouts, double KOs, direct results, rematches, legal CPU moves, both players' keyboard inputs, arrow controls, dashes, grounded KOs, CPU disengagement, boxing idles and valid sprite regions. Rendered frame comparisons confirm pixel-identical pause/resume behavior and exactly two water frames with all non-water scenery unchanged. Reports: `tests/verification.txt` and `tests/visual-regressions.txt`. `tests/visual_check.gd` captures key screens for inspection.

The Windows executable was launched, and the revised title, selection, match, attacks, guard, crouch, KO and results were visually inspected. Keyboard checks use Godot's actual event-input path; desktop automation key injection did not register in the native game window, so physical-keyboard play remains a hands-on check. Also remaining: real controller mapping and simultaneous controllers, keyboard rollover under two-player use, subjective balance and input feel, and longer sessions on other displays. Animation currently uses 18 keyed poses per fighter; it is not a fully hand-animated production set. Additional in-between frames remain a future polish task.

Godot is distributed under the MIT license; see https://godotengine.org/license/ for engine and third-party notices.
