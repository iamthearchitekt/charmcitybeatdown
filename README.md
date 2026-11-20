Latest sprite/throw update: see ART_REVIEW.md for the reviewed female designs, grounded KO correction, 1,092 passing checks and remaining polish notes. FIGHTER_STYLE_PLAN.md is the requested next-step proposal only. Men's body proportions are unchanged by the female correction pass.

# CHARM CITY BEATDOWN

Collision update (#11): all fourteen fighters now use 463 pose-specific profiles baked from the final rendered sprite alpha. Multiple inset body regions preserve gaps between limbs; punch, kick and rising-attack regions follow the distal hand/boot/forearm instead of shared move rectangles. Walking, crouch, airborne, hit recoil, signature rotations and thrown-body rotation use the exact same deterministic pose selection as drawing. Facing, scale, sprite anchors and floor alignment are shared. Hitstop freezes pose selection. Active frames alone can strike; existing timings, damage, pushbox spacing and throw/grab rules remain. High kicks visibly above a crouched head can now whiff. Impact sparks use the actual contact point. F1 shows individual green hurt/red strike regions, plus blue movement pushboxes.

Fighter contacts, projectiles and bonus strikes test individual regions. The six car objective bands remain. Keg hazards require contact with the visible central body, preserving the previous body-contact width; touching a prop with an attacking glove/boot does not itself damage the fighter. All fourteen fighters can clear all three bonus types through ordinary controls with the more accurate reach/height. Rebuild collision after art/anchor/scale changes: run `tools/export_collision_art.gd` in Godot, then Python `tools/bake_collision.py` (Pillow/NumPy). This writes `data/collision-profiles.json`; the simulation loads geometry only and never reads image pixels. Shared selector: `scripts/combat_pose.gd`; transforms: `scripts/collision_profiles.gd`. Focused checks: `tests/hitbox_verify.gd`, plus combat, throws, signature moves and all bonus/scoring suites.

HUD correction: scores, names and round markers now draw directly over the stage with no added black header/name panels or panel edge lines. Their aligned positions remain. All runtime text uses a slightly thicker shared black outline:4pixels below20pt,5pixels at20-47pt and7pixels at48pt+, each one pixel above the previous setting. Do not reintroduce filled score/name bars without an explicit request.

Latest presentation update: the fighting HUD groups scores above the health bars and names/round wins beneath them; bottom control instructions are removed. The pause screen still contains the full controls. Locked secret characters show only question marks on select, including preview names/art; the map uses WESTMINSTER. The level name appears only during the first-round introduction, with round numbers on subsequent intros.

All fourteen fighters have two dedicated stride/passing walking frames paced by distance traveled. The nine projectile users have gathered-hands startup and two-handed release poses. Sources are `assets/movement-a..d.png`, `data/movement-atlases.json`, `scripts/movement_art.gd` and `tools/register_movement.py`. Painted projectile, attack trail and contact sprites use fighter-specific palettes. Poe and Lamar share the violet projectile, and Spike retains his fire animation. Rebuild the shared action atlas with `tools/bake_action_fx.py`.

Stan's Redline Palms needs four fresh punch taps and recovers for 30 frames. Guarded hits hold the impact freeze, then slide the defender farther away during blockstun.

Westminster / Poe's Grave is now **dark stormy daytime**, with gray overcast daylight, no moon, subtle two-state cloud lighting, the existing rain effect and intermittent crows. Keg/car/box points now credit the cumulative Arcade total live, show their subtotal and final payout, and survive returning to the ladder. Standalone bonus testing initializes a run before awarding points. Bonus completion and bookkeeping are idempotent. New checks cover all46 poses and real hit/clear/failure/next-fight score carryover.

A Windows/Godot 4.3 arcade fighter with fourteen characters, eleven fighting stages and three rotating bonus challenges. Launch `Play.cmd` or the existing desktop shortcut. Keep `build/CharmCityBeatdown.exe` and its adjacent `.pck` together. Import `project.godot` in Godot 4.3 to work on the editable source.

The desktop shortcut targets `build/CharmCityBeatdown.exe` in this checkout. Publish every verified Windows build to that location using the Windows Desktop export preset so the same shortcut launches the latest version. Close the game before replacing its resource pack.

## Versus

In **Local Versus**, lock in both fighters, pick a stage from the thumbnail grid, and start the match. For **Online Versus**, install the same build on both PCs. One player selects **Create Room** and shares the code. Their friend pastes it into **Room Code** and selects **Join Room**. Both players use their usual first-player keyboard or controller layout.

Both online players lock in their own fighter before the stage grid opens. The host chooses the stage and starts the match. Online rematches require both players to agree and keep the selected fighters and stage.

Room codes use the [online relay](relay/README.md). Configure its public WebSocket origin before exporting a build with room-code support.

Eric and Stan’s Arcade fights take place at a sunny Pimlico infield with three two-frame flags. Alex’s home stage is an empty warehouse with metal shelving, a parked forklift with an amber beacon, and two foreground boxes that fighters can break independently.

## Arcade campaign and combat update

Arcade now fights each eligible opponent once in a shuffled ladder. Spike is penultimate and Rachel is the final boss; Stan substitutes for a player Spike and Jeff for a player Rachel. Locked secret fighters join the opponent pool on the next run after redemption. Rachel's final fight raises CPU difficulty one step, capped at Hard. The first application-session fight remains Inner Harbor, later stages rotate without immediate repeats, and the same stage/music continues across rounds. A final result reaches a campaign-clear screen and saves the run.

Damage earns ten points per health point. Each won round adds remaining seconds times100, remaining health times10 and10000 for a perfect. Score persists across rounds, fights, bonuses and continues. Arcade losses show a ten-second Continue countdown after the results; continuing retries the same opponent and stage. Expiry ends the run. The main menu's HIGH SCORES retains the top ten scores, fighter names, clear status and continue counts in `user://arcade-high-scores.cfg`. Training does not earn scores. Local Versus stays separate.

Press keyboard2 or the second controller's Start during an active solo fight for NEW CHALLENGER. Player2 selects a fighter and plays a separate local Versus match. The result returns to the suspended Arcade fight with its health, timer, opponent, stage, score and ladder position intact. Canceling challenger selection also resumes the fight. Start accepts Continue/result screens; ordinary face-button confirmation remains supported.

Unblocked strikes build hidden dizzy pressure; blocked attacks and throws do not. At300 points the victim is knocked down, then gets up temporarily dizzy with three outlined orbiting pixel stars. Neutral recovery takes three seconds; distinct directional changes/attack taps shorten it to no less than one second. Holding one direction does not repeatedly accelerate recovery. A hit or throw ends dizzy, and a short protection interval prevents an immediate repeat. Pressure decays after90 simulation frames without a hit. These are original balance values, not a claim of exact SFII frame data. CPU recovery is bounded too.

Opposing blue/fire projectiles now cancel each other before checking fighter contacts, with a compact pixel burst and the supplied special-impact sound. Same-owner shots and different-height shots do not cancel. Relative-motion checks catch shots crossing within a step. Clashes add no global hitstop.

After every two Arcade wins, except the final boss, bonuses rotate **Fells Point car -> Brewers Hill kegs -> Dundalk boxes**, then repeat. All use30-second timers, visual damage and secret-code rewards for complete destruction. Brewers Hill is a new nighttime brewery stage with **no people**; the second frame only dims the Natty Boh neon tubes slightly and changes their red pavement reflection. Architecture and camera stay identical. Twelve kegs drop from alternating sides, bounce and cross the lane; every keg must be broken. Dundalk has ten separately destructible stacked wooden shipping boxes whose unsupported upper boxes fall. Jumping, high/low attacks and specials work; throws do not damage props. No prop health bars or attack-instruction overlays.

Code: `scripts/arcade_run.gd`, `scripts/breakables_bonus.gd`, `scripts/dizzy_stars.gd`, plus combat/main/stage integration. New art: `assets/brewers-hill.png`, `assets/breakables-atlas.png`, metadata generated by `tools/register_breakables.py`. Tests: `dizzy_clash_verify.gd`, `arcade_run_verify.gd`, `breakables_verify.gd`, `arcade_visual_verify.gd`, plus the updated stage/solo and existing combat/car/music suites.

**LMR** now unlocks Lamar Jackson in a purple/black Ravens football uniform, correct white number **8**, braids, uncovered face and no helmet. He has all 22 gameplay poses and separate victory/defeat portraits in `assets/lamar-atlas.png` and `assets/results-portraits-g.png`. Walking speed7.2 is the fastest in the roster, and an optional per-fighter dash multiplier gives him 12% quicker forward/back dashes. Standard damage and health remain. Register with `tools/add_lamar.py`, `tools/register_throw_atlases.py` and `tools/register_results_portraits.py`. Jersey verification: https://www.baltimoreravens.com/team/players-roster/lamar-jackson/ . The seven-column/two-row roster now fills all fourteen slots; large preview names resize to fit without clipping.

**REL** now unlocks the playable Oriole Bird. His complete 22-pose atlas includes wing punches, orange-foot kicks, separate jumps, four throws and a face-up KO, plus two dedicated result portraits. His presentation scale is 1.1235, exactly Stan's. All art uses the shared fine pixel/dither pipeline. The thirteen-fighter select screen uses seven columns and two rows with enough clearance for the large previews. Reproduce registration with `tools/add_oriole.py`, `tools/register_throw_atlases.py` and `tools/register_results_portraits.py`. Source sheets: `assets/oriole-bird-atlas.png`, `assets/results-portraits-f.png`.

Every fighter has separate enlarged victory and bruised defeat portraits on the post-fight results screen. Women use playful confident gestures; men use power poses. All pass through the same fine pixel/dither treatment. Rachel's badge is removed from every gameplay and result pose; Rachel and Jeff's result faces follow the supplied reference photos. Sources are `assets/results-portraits-a..e.png`, `data/results-portraits.json`, `scripts/results_portraits.gd` and `tools/register_results_portraits.py`.

Enter **POE** in the main-menu cheat-code screen to unlock Edgar Allan Poe. He is pale, dressed in black Victorian garb, lanky and the same height as Spike, with all 22 ordinary/jump/throw/KO poses. Westminster / Poe's Grave joins the random stage rotation after the first Inner Harbor fight. One fixed painting supplies two subtle light states; separate two-frame crows cross overhead intermittently, alternating direction with long quiet gaps, and freeze on pause. Registration: `tools/add_poe.py`, then `tools/register_throw_atlases.py` and `tools/register_results_portraits.py`. Historical references: Westminster Hall's official history and the Library of Congress Poe portrait collection.

The car stage now gives **30 seconds** and omits attack instructions, jump hints and control prompts. Its timer, score, code reward and navigation remain visible.

The title screen displays the stage painting without the former 49% dark overlay. Title/menu music is -11 dB, a restrained 2 dB increase; stage music remains -13 dB.

Inner Harbor opens the first fight in each application session. Later fights randomize without immediate repeats; round transitions and returning to the menu do not reset the opener. Rats scuttle behind the fighters on Inner Harbor and Dundalk. Each rat has its own entry timing, pace and two pauses before returning from the opposite edge. Their animation uses the paused stage clock. Rat sources and registration are in `assets/harbor-rat-source.png`, `tools/register_harbor_rat.py` and `scripts/harbor_rat.gd`. Breakable street trash cans use four painted damage states from `assets/stage-trash-can-source.png`, registered by `tools/bake_stage_props.py`.

Stan's presentation scale is now 1.1235, exactly 5% above his former 1.07; Jeff remains tallest. Selection movement now uses the short `5B_zap_1.wav` at -22 dB, with a distinct `5E_zap_3.wav` confirm at -18 dB. Round intros sequence the supplied ROUND and number clips before FIGHT; rounds 1-9 are supported, with FINAL ROUND after that. The 150-frame intro leaves 110 frames for the call. A separate Hadouken voice fires once when an actual plasma projectile spawns, alongside the energy effect.

## Signature kick attacks

The approved new moves are implemented with 28 dedicated source poses across three sheets and the existing fine pixel/dither pipeline. All original moves, costumes, portraits, throws and KO poses are retained. New attacks use bounded multi-hit intervals, ordinary guarding, limited chip, recovery and existing KO follow-through. CPU opponents can use them with the existing reaction delays. Physical Sega controls are shown in the pause move list; keyboard kick bindings trigger the same commands.

| Fighter | Move | Sega input |
|---|---|---|
| Vivian | Blossom Lightning: rapid kick flurry | Tap X or C three times quickly |
| Vivian | Sakura Whirlwind: inverted spinning bird kick | Hold Down, then Up + X or C |
| Alex | Grey Cyclone: traveling upright hurricane kick | Roll Down to Back, then X or C |
| Brook Lynne | Orange Blitz: kick flurry | Tap X or C three times quickly |

Vivian keeps her black pigtails, cherry-blossom outfit, pink skirt over white leggings and stronger/faster kit. Her spinning poses are actually inverted rather than reused standing kicks. Alex retains his grey sleeveless hood-down hoodie, white wraps, charcoal pants and brown boxing boots; Brook Lynne retains deep brown skin, wavy high ponytail and orange/black/white outfit. `tools/add_signature_moves.py` and `tools/register_signature_art.py` reproduce registration. `signature_art.gd` stores the extra cached textures separately from the original atlas cache. Tests: signature mechanics33 and graphical28.

Spike's Iron Pulse now renders as an orange/red four-frame fireball with a bright hot core. Other fighters' plasma balls retain the original blue effect. Damage, speed, hitboxes and lifetime are unchanged. Art sources and registration: `assets/spike-fire-source.png`, `tools/register_spike_fire.py`; four 46x28 frames render through `arcade_projectile.gd`. The supplied hurricane-kick and spinning-bird-kick voice clips accompany the new special animations at restrained gain.

## Fells Point car bonus

Latest polish: character select uses a Baltimore City boundary/harbor map with local stage markers. Fighter shadows are shallow pixel contacts aligned to the opaque soles; the old mirrored reflections and offset discs are removed. Eric is scaled to .985 (Spike 1.0), approximately 5% larger than his former .94 scale, preserving his broader build. Fells Point spectators wear contemporary clothing and have a two-source-pixel upper-body second pose. Car health bars are removed; damage artwork is the progress display. Bonus jumping is reduced to 28.5 vertical launch / 10.2 horizontal speed, with a shaped roof/fender obstacle.

Block grunts are now -15 dB plus mix headroom, with small per-file balancing, a protected playback voice and a four-dB music duck while a grunt plays. The four stage tracks use prepared Ogg loops from `audio/loops`, with recorded ending fades removed and a two-second join. `tools/build_music_loops.py` reproduces these files from the preserved original MP3s using ffmpeg/NumPy. Loop points are recorded beside them. Playback stays continuous between rounds and still stops at whole-fight completion.

Arcade progression offers a rotating bonus after every two won matches (not individual rounds): car, kegs, boxes. Continue from the result screen to enter it, then return to the next opponent in the finite ladder. Versus and Training retain their ordinary flow. A fresh Arcade run resets the match counter.

The front-facing silver sedan has **six independent hit zones, three on each side**. Top/glass takes punches or high kicks; middle/hood takes crouching jabs; bottom/bumper takes crouching kicks. Each zone shows four registered damage states, local impact shake and fragments. A high attack cannot spill into a lower target. The car blocks grounded movement. Up plus direction crosses it in either direction; normal fighting movement is unchanged.

Destroy all six zones within **30 seconds** to reveal an existing three-character unlock password. Five zones or a timeout do not earn a code. New reward codes are preferred until all three have been revealed; results are saved separately from redeemed unlocks. Enter the code through the main-menu CHEAT CODE option. Poe, the Oriole Bird and Lamar Jackson are all playable after unlocking.

Fells Point uses one fixed painting with exactly two states at four frames per second. Existing upper lights, warm cobblestone reflections and spectators' upper bodies change; architecture, signs, feet and camera stay fixed. **Alien Power** plays throughout the challenge. Supplied CPS-1 sounds: `57_metal_clang.wav` for impacts, `58_break_glass.wav` for destroyed glass, `24_break_metal.wav` for destroyed hood/bumper, and a restrained metal/glass layer for the final wreck.

New implementation: `scripts/car_bonus.gd`, `scripts/bonus_car.gd`, `scripts/bonus_rewards.gd`. Art registration: `tools/register_bonus_car.py` preserves the common canvas and wheel baseline, using the shared fine raster/dither parameters. Verification: `tests/car_bonus_verify.gd` (80 checks), `tests/car_bonus_visual_verify.gd` (6 graphical checks), existing core (77), solo selection (32) and SFX (36).

## Roster

| Fighter | Appearance | Availability |
|---|---|---|
| Marcus | Original navy/orange dockworker | Available |
| Brook Lynne | Black woman, long black high ponytail, fuller lips and berry lipstick; orange/black/white outfit | Available |
| Alex | Medium athletic build, brown hair and fuller trimmed beard, gray sleeveless hood-down hoodie vest, charcoal training pants, brown boxing boots, white boxing wraps | Available |
| Lauren | Fair-skinned blonde with side braid and purple cropped jacket | Available |
| Chelsea | Straight orange-red hair; green/black outfit | Available |
| Vivian | East Asian woman with black pigtails, light-pink skirt over white leggings and cherry-blossom details | Available |
| Spike | Reference-matched bald face, dark brows and short dark beard; subtle eye scar, spiked black leather jacket, black jeans and mid-calf combat boots | Available |
| Eric | Shorter stocky build, long wavy brown hair and full beard; white/red/black racing suit | Available |
| Stan | Taller muscular build, full black beard and small black bun; black/red/white racing suit | Available |
| Rachel | Brown bun and glasses, fitted dark tactical field-agent outfit; strongest female damage kit | Available / boss |
| Jeff | Tallest, lanky with subtle athletic muscle; glasses, black BSE bomber jacket, jeans, boots and fingerless gloves | Available |
| Edgar Allan Poe | Pale, lanky at Spike's height; black Victorian frock coat, waistcoat, white collar and cravat | POE code |
| Oriole Bird | Black/orange mascot, orange beak/feet, black cap with orange brim; Stan's size | REL code |
| Lamar Jackson | Recognizable helmet-free likeness, purple Ravens number8 jersey, black padded pants and cleats; fastest walking speed and quicker dashes | LMR code |

Women have athletic feminine proportions, slim waists and upper bodies, fuller hips and proportionate thighs. Vivian moves slightly faster and deals approximately 8% more damage than the other women. Alex's walking speed is 6.2 versus Marcus/Spike 5.2, about 19% faster; health and damage are unchanged. Each playable fighter has 18 ordinary keyed poses and four dedicated throw poses, including separate neutral jump, airborne punch and jumping kick. Every KO lies face-up on the back, with the head away from the opponent and facing locked while grounded. Marcus's high-kick artwork has corrected anatomy.

All poses and portraits use one cached raster: 0.9 logical units per texel, about 178 native pixels for standing fighters (Alex is slightly smaller), nearest enlargement, hard alpha edges, 23 channel steps and subtle fixed 4x4 Bayer dithering. Original source atlases are preserved. Revised female atlases load raw PNG bytes; `data/female-atlases.json` supplies registered bounds/pivots. `tools/register_female_atlases.py` reads alpha to regenerate metadata without editing art; it needs Python, Pillow and NumPy. Rim cleanup removes bright baked directional lighting while preserving costume colors and berry lipstick.

## Sega controls

The primary Retro-Bit Sega layout also applies when Windows calls the pad a generic XInput device. Saved custom profiles take precedence. Other secondary pads retain standard Xbox controls unless identified as Retro-Bit.

| Action | Sega pad | P1 keyboard | P2 keyboard |
|---|---|---|---|
| Move / jump / crouch | D-pad | Arrows | WASD |
| Light punch | A | Z | F |
| Heavy punch | B | X | G |
| Light kick | X | C | H |
| High kick | C | V | J |
| Throw | Y | B | R |
| Pause / resume | Start | Esc | Esc |
| Menu confirm / back | A / B | Enter / Esc | Enter / Esc |

Genesis C is handled through Godot's normalized right-trigger axis. Holding an attack does not repeat it; release and press again. Controller setup (F4) supports buttons and axes, saves per controller identity, rejects duplicate gameplay bindings and preserves keyboard bindings. Canceling setup preserves the previous profile. Pair the controller in Windows before launching. Controller verification uses synthetic events; physical Bluetooth operation remains a hands-on check.

The pause menu presents a **SEGA MOVE LIST** with physical button labels and plain D-pad instructions. Forward means toward the opponent. For the first special, roll DOWN through DOWN-FORWARD to FORWARD, then press A or B. For the uppercut/rising special, press FORWARD, DOWN, DOWN-FORWARD and A or B. Hold BACK to guard; DOWN + BACK guards lows. Throws beat guard and keep the opponent in front even when holding BACK. Ground throws cannot grab airborne fighters, protected wake-ups or opponents out of range. UP jumps; X or C while airborne kicks. Double-tap forward/back to dash/backdash. Holding back takes one short step, then blocks in place until released.

N toggles music, M mutes all audio, F11 toggles fullscreen, and F also toggles fullscreen on the title screen. Keyboard F remains P2's light punch during fights. The seventh main-menu entry, **QUIT GAME**, exits via mouse, keyboard or controller.

## Passwords and unlocks

Choose **CHEAT CODE** on the main menu. Three slots accept letters/numbers. Keyboard: type, Backspace clears, Enter redeems, Esc returns. Pad: Up/Down cycles characters, Left/Right changes slot, A redeems, B returns. Unlocks persist in the local save.

| Code | Unlock |
|---|---|
| ALL | All current and future registered characters |
| POE | Edgar Allan Poe - playable unlock |
| LMR | Lamar Jackson - playable unlock |
| REL | Oriole Bird - playable unlock |

All three secret characters are fully playable after unlocking. No designs remain deferred. See `data/character-unlocks.json` and `scripts/character_unlocks.gd`.

## Modes and combat

Arcade selects a random different available CPU opponent for every new match/rematch and keeps that opponent between rounds. Versus and Training use manual selection. The roster matrix has seven columns and two rows for fourteen fighters: the original eleven are available immediately; Poe unlocks with POE, the Oriole Bird with REL, and Lamar with LMR. Rachel is marked BOSS and deals 22% more damage than the standard female kit, above Vivian; her health remains 1000 and her build stays proportionate. Jeff is tallest with subtle athletic muscle. Lamar's walking speed7.2 exceeds Jeff/Vivian6.4, with standard health/damage. Locked characters are skipped until unlocked. Training: F1 boxes, F2 dummy mode, F3 reset. Health regenerates and match endings are disabled in Training.

Combat runs at a fixed 60 Hz, independently of visual animation. Attack-facing locks through moves; neutral facing changes after side switches. Contacts are snapshotted before damage for simultaneous trades. Each move/projectile hits each target only once. Jumping attacks are overheads; crouching kicks are lows; standing high kicks are overheads. Uppercuts rise higher and launch farther with one small ground bounce.

The CPU observes executed attacks, learns after three repetitions, sometimes guards through hitstun or punishes recovery, and forgets after inactivity. It retains reaction delays, spacing pauses and imperfect decisions. A winning attack completes its active motion/recovery after KO; new attacks and contacts are suppressed. MAKE IT COUNT has been removed from fight announcements.

## Stages

The first fight after each application launch opens at Inner Harbor. Later stages rotate randomly without consecutive repeats and remain fixed between rounds. Each animated backdrop reuses one painting and exactly two fixed shader states. Architecture and camera do not drift.

| Stage | Two-frame animation |
|---|---|
| Inner Harbor Docks | Subtle water change; separate foreground rain |
| Dundalk / Seagirt Marine Terminal | Water, stack smoke and a warmer second-frame Domino Sugars sign glow; separate rain |
| Graffiti Alley / Bromo Tower | Visible blue clock pulse, puddle highlight and complementary window twinkles; no rain |
| Eutaw Street / Camden Yards | Fine crowd pixelation and a subtle two-pixel upper-body cheer; fixed warehouse, carts, smoke, gates and plaques |
| Power Plant Live! / UPC | The same fine crowd treatment/cheer, subtle sign glow and reflected-light changes; fixed storefronts, lettering, planters, pole and horizontal barricade rails |
| Westminster / Poe's Grave | Subtle warm window/lantern glow and reflected light; fixed church, graves, lettering and camera; separate intermittent two-pose crow flyovers |

Eutaw and Power Plant crowds use a two-source-pixel grid and 31 channel steps. Power Plant includes POWER PLANT LIVE!, PBR Baltimore, UPC / Underground Pizza Company and Angels Rock Bar signage. Pause freezes stages and gameplay.

GPU comparisons: Dundalk sign changes 5,660 pixels, outside allowed regions 0, overall mean RGB difference .01694. Graffiti changes 2,639 clock pixels, 1,617 puddle pixels and 1,324 windows, outside 0, mean .03454 (stronger than the rejected barely visible version). Power Plant crowd styling affects 122,074 pixels and cheering changes 53,391; outside allowed regions and rail changes are 0; light-only mean .01198.

## Presentation and audio

The Windows icon is the cracked gold C from the logo with a red slash behind it. `assets/game-icon.png` is a transparent freeform PNG, with no tile/backplate. `assets/charm-city-beatdown.ico` includes 16, 20, 24, 32, 40, 48, 64, 96, 128 and 256px frames. Project/window/taskbar settings and the export preset point to these assets. Both Windows EXEs have matching native icon resources; the existing desktop shortcut inherits the main EXE icon. ICO storage uses transparent padding without changing the PNG's proportions.

`tools/build_icon.py` encodes the PNG into ICO. On Windows, run `tools/apply_windows_icon.py` after replacing/re-exporting either EXE; it stages and verifies native icon resources without an external resource editor. PCK files must remain external. `tools/verify_windows_icon.py --shortcut "<path-to-shortcut>"` checks the Windows shell and the running game's icons. A normal PCK-only repack retains the EXE icons. Standard Godot 4.3 editor exports additionally need their Windows resource-editor configuration when `application/modify_resources` is enabled.

Street Fighter II-inspired selection uses a blue world map, large inward-facing fighters, a central portrait matrix and P1/P2 cursors. Spike/Lauren portrait crops include the complete head. UI has fine fixed grain, stepped arcade frames, dithered gold life bars, a red timer and a triangle cursor. Maroon selection/confirmation fills are removed; empty health is charcoal. Text has one black outline, rounded coordinates and no offset shadow: 3 pixels for small text, 4 for normal UI, 6 for announcements. Fight/round/KO banners sit roughly 80 pixels higher to leave standing fighters visible. The logo uses a detailed 512-pixel-wide dithered raster.

Original four-frame pixel hit/block bursts replace the colored line wheel. The blue projectile is an original four-frame pixel fireball with a bright rounded core and trailing flames. Nearest sampling and hard alpha preserve the arcade aesthetic; pause freezes effects. These visual revisions preserve existing collision and timing.

Music is assigned in `data/music.json`. The Street of Rage is the new title/menu song. Alien Power plays at Graffiti Alley; Back to the Industry plays at Dundalk; the former title track Never Return Alive now plays at Power Plant Live!. Inner Harbor and Camden Yards keep Go Straight. Stage music loops continuously across rounds at -13 dB, stopping only when the whole match is decided. Cached raw MP3 streams allow the supplied files to work without editor imports. Level Complete plays once on results.

Defeat screams play on every defeated round, including double KOs. A match-ending knockout plays the user-supplied final male/female WAV exactly ONCE; its echo is already baked into the file. There is no generated echo or repeat queue. Earlier round losses retain one original short scream. The female victory taunt follows the full final KO clip when a female CPU beats the player; results music/announcer wait until voice/taunt finish. Block contacts randomly select one of two grunts for the defender's male/female voice group, at a restrained -23 dB cue gain plus -1 dB mix headroom. All voices freeze during pause and clear on rematch/title exit. Timeouts without a knockout do not scream. Landing thuds follow actual landings. `audio/sfx-map.json` controls source WAV routing and base levels. There is no finishing-move phase.

## Source and verification

Key source files: `scripts/combat.gd` (simulation), `commands.gd` (motions), `cpu.gd`, `controller_bindings.gd`, `main.gd` (UI/audio), `fighter_sprites.gd`, `harbor_stage.gd`, `arcade_ui.gd`, `impact_sparks.gd`, `arcade_projectile.gd`, `character_unlocks.gd`, `data/moves.json` and `data/female-atlases.json`.

Run pure simulation tests headlessly with Godot 4.3. GPU suites waiting on `RenderingServer.frame_post_draw` must run with a graphics driver. Tests cover combat, legal inputs, controllers, solo opponents, roster, all-pose pixel consistency, face-up KOs, jumps, sound, continuous music, CPU attack memory, unlock persistence and stage mask/loop invariants. Visual captures live under `tests/visual` locally. Some legacy audio harnesses log resource-in-use warnings only at shutdown despite passing; physical controller feel, longer sessions and subjective balance still benefit from hands-on testing.

Repack an imported Windows project with a matching Godot 4.3 executable:

```powershell
godot.exe --headless --path . --script res://tools/pack_windows.gd
```

`tools/archive_source.py` creates a verified full editable-source ZIP, excluding build outputs, caches, local saves and screenshots. `tools/build-assets.cjs` regenerates the initial procedural assets and move table and can overwrite manual move edits; do not run it casually.

Repository: https://github.com/iamthearchitekt/charmcitybeatdown.git . This recovered workspace has no git history; no push was performed in this continuation. Godot is MIT-licensed; see https://godotengine.org/license/ .
