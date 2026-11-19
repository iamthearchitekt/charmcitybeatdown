# Sprite review — November 18, 2026

Latest direction: the men's physiques are fine. This pass changes the women’s arm treatment while preserving their individual designs. No additional broadening or muscle changes to men.

Reviewed the actual exported game textures side by side with the approved neutral references, then inspected native-game captures. Contact sheets cover all fourteen fighters, walking, jumps, attacks, grapple poses, signature moves and all fourteen grounded KOs. The five women also have native selection, combat, victory and defeat captures.

Applied corrections:

- Brook Lynne and Vivian: slender, smoother arms throughout main combat, walk/jump, signature and grapple sources. Brook retains berry lipstick, gold hoops, high wavy ponytail, orange/black/white outfit, fitted pants and orange heeled combat boots. Vivian retains her cherry-blossom collar/top, pink skirt over white leggings, twin pigtails and pink ties.
- Lauren: purple/gold jacket, blonde braid, fitted navy/lavender trousers and matching gloves carried into her six grapple poses; removed the inconsistent white wrist treatment.
- Chelsea: restored green jacket, black crop top, green details on black trousers and boots in her six grapple poses. Retained straight orange-red hair.
- Rachel: reviewed covered arms, brown bun, glasses and tactical costume. No badge added; her base design remains intact.
- Brook's enlarged victory/defeat portraits use the same smoother arm treatment and preserve lipstick and hoops. Other female result portraits were reviewed against their designs.
- Spike's previously requested stubble and full-length sleeves carry through supplemental motion, grapples and result sources. This is a costume/facial-hair correction, not a body redesign.
- Grounded KO now has priority over a grapple pose: every fighter uses their authored face-up, arms-at-sides base pose. Initial grapple reactions also now render the explicit pose used by collision.

Hands were inspected in the reviewed contact sheets and enlarged portrait/grapple sources. Fists and grips naturally hide some digits; this is not a claim that five digits should be visible in every pose. No whole-sheet repaint was used merely to expose hidden fingers.

The review also records a remaining polish issue outside this women's correction: some older male grapple frames have a muted palette relative to their ordinary sprites, especially Marcus. Do not silently replace those men's designs after the user's latest instruction. A focused color/identity correction should preserve their approved physique and use the original references. Current female corrections and grounded KO selection are complete; this note prevents a blanket claim that every historical asset is flawless.

Validation: 463 collision pose profiles regenerated from final registered textures. High-kick contact excludes proximal thigh pixels that were grazing the top of Brook's crouched hair. Fifteen mechanics suites passed (1,092 checks), covering throws, both facings, command grabs, holds/escapes, air throws, KO, body collision, movement, bonuses, arcade flow, music and controller mapping. Native throw capture run covered all fourteen fighters at grip, lift, release and impact. Twenty native female select/combat/result captures were produced. Original design references remain under assets/design-references.

Files: tools/install_slender_art.py registers existing generated PNGs without repainting; tools/art-registration-baseline contains its immutable metadata baseline. Final assets and registered data are self-contained in the source project. Images created during rejected intermediate attempts are not automatically installed.

## Elemental specials

Spike and Chelsea each have four new dedicated poses, registered independently of their existing sheets. Spike remains bald with stubble and full sleeves; his head-back standing shock pose keeps closed fists beside his hips. Chelsea retains her green/black costume, long orange-red hair and slender arms. Both use the shared 0.9-unit pixel/dither pipeline.

Reviewed native gameplay in both directions, all electrical palette phases, burning/shocked opponents, and the Sega pause list. White electrical flashes affect only the character, never the stage. Effects are temporary runtime palettes, not colored lighting painted onto costumes. New body collision profiles derive from the final rendered art; elemental attack volumes follow the visible aura/cone. Existing portraits, physiques, KO and grapple art remain unchanged.

Reference observation: Blanka Electric Thunder animation alternates ordinary/darker coloring, bright yellow-white flashes and jagged arcs. Chelsea uses the close-range flame-burst/burning-knockdown language of SFII Dhalsim, adapted to a palm cast. Reference links: https://www.sirlin.net/sf-hdr/ ; https://rq87.flyingomelette.com/RQ/SF/C/dhal.html ; https://captown.capcom.com/uploads/game/manual/23/SF2_en_G.be3a67c7-ad2f-47f6-9619-6ae47a163188.pdf
