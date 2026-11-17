# Imported CPS-1 effects

Menu music: the supplied `04 - Never Return Alive.mp3` is copied unchanged as `never-return-alive.mp3` and loops at -13 dB on the title and character-select screens. The player is stopped before the match track starts, and remains stopped during gameplay, pause and results. Returning to the title starts it again. N toggles both menu and match music; M mutes all audio.

These effects come from the local Street Fighter II / Super Street Fighter II CPS-1 Sound Effects and Voices packs supplied by the user. Original WAV filenames, samples and pitch are preserved in `sf2-cps1/`. These imported effects are not original game compositions.

The user-supplied `02 - Go Straight.mp3` is copied unchanged as `go-straight.mp3`, loops during matches at -13 dB, and stops before KO voice playback. `20 - Level Complete.mp3` is copied unchanged as `level-complete.mp3`, plays once on the results screen at -9 dB, and stops on rematch or return to title. These tracks use separate players from the effect pool. N toggles the match track; M mutes everything. Slow motion does not change audio pitch or playback speed.

| Event | Source filenames |
|---|---|
| Light punch hit | 13_attack_1, 19_attack_7 |
| Heavy punch hit | 14_attack_2, 15_attack_3 |
| Light kick hit | 16_attack_4, 1A_attack_8 |
| Heavy kick hit | 17_attack_5, 18_attack_6 |
| Special hit / throw impact | 1D_attack_10, 1B_attack_9 |
| Block contact | 22_attack_block |
| Attack whoosh, jump, dash, rush, uppercut | 59_whoosh, 5D_whoosh_2 |
| Projectile launch | 5C_zap_2 |
| Normal / hard landing | 12_thud_1 |
| KO body landing | 1E_thud_2 |
| Marcus / Alex knockout voice | 27_male_ko |
| Maya / Emma knockout voice | 53_chunli_ko |
| Menu movement / pause | 1C_clink |
| Confirm / back | 5B_zap_1 / 5C_zap_2 |
| Fight announcement | 2B_announcer_fight |

`sfx-map.json` is the editable routing/level map. Hit variants alternate deterministically. Whooshes begin on the first active frame; damage sounds play only on contact. Body thuds follow actual landing, including airborne KOs. Defeat screams play once only on the match-deciding KO, by fighter identity regardless of player slot. Earlier round losses and drawn double KOs do not scream. Timeouts with remaining health do not trigger a scream. Two simultaneous hits can sound together. Seven combat playback voices plus one reserved UI voice and 1 dB of effect headroom and a master limiter with a -1.2 dB ceiling bound the mix. Combat sounds pause/resume with the game; menu/pause cues remain available. Menu movement is quieter than impacts, and jumping/landing sounds are intentionally subtle.

The four unused Sound Effects files are `20_unknown_1.wav`, `25_plane.wav`, `58_break_glass.wav`, and `5A_unknown_2.wav`; the game currently has no corresponding aircraft/glass/unknown action. The Voices pack supplies two defeat screams and four announcer clips: 2B_announcer_fight, 40_announcer_you, 41_announcer_win, and 42_announcer_lose. Named character special-move calls are not used. A dedicated announcer player sequences YOU then WIN or LOSE on the results screen. Arcade uses Player 1 perspective; Local Versus announces YOU WIN for the displayed winner. Result music ducks during the call, then returns to its normal level. Rematch and title exit stop the announcement and clear its queue.
