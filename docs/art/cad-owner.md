# CAD Corp art and arena flow

The active boss now uses the proportion redesign in [boss-proportions.md](boss-proportions.md): smaller adult head, longer limbs and side-facing poses matching the player, guard and gunner. His charcoal suit, cyan tie, glasses and blue pistol remain. Idle, walk, shooting, hurt, defeat and teleport all use the new sheets in business_man/redesign. Atlas margins align feet; uniform scaling preserves anatomy. Combat remains stationary. The older boss sheets and prompts below are retained as superseded source history.

There is no in-game intro. Entering the arena starts combat with the normal player camera. After the boss's rewindable death delay, the high chamber platform falls, a player on another platform makes one jump using normal jump velocity and gravity, lands, and walks along the ground to the chamber. A player riding the chamber descends with it. The screen fades only after the approach completes, and Level.complete() fires once. BossArena._finish_walk() is the future artwork-cutscene handoff. The chamber remains closed.

## Generated artwork

Created with Codex's built-in image generation tool, using existing art as edit targets. Original images are retained.

- assets/sprites/business_man/teleport_refined_sheet.png: eight disappearance frames, 1536 x 1024, four columns by two rows. The saved phase clock samples them at 12 fps and reverses them for arrival. The body stays aligned at the cell's (192, 480) anchor with uniform 0.3 scale. Body breakup comes from the artwork; only the final sparks fade. Stop Time and Rewind restore the exact pose.

- assets/sprites/business_man/combat_refined_sheet.png: 16-frame shooting/hurt sheet, returned at 1254 x 1254. Transparent alpha is preserved. Measured atlas regions and margins align the feet; fire frame 0 coincides with laser emission. Original source PNGs are retained.
- assets/sprites/parents/chamber_idle_sheet.png: six-frame glowing suffering idle, referenced from the parents chamber and Level 1 sister frames. The returned atlas is 1536 x 1024; inspected regions align each machine at the same base. Playback runs at 6 fps and pauses/rewinds with world time.
- assets/sprites/business_boss/business_portal_gate_refined.png: refined original blue clock, gear and hourglass portal. Its frame stays rigid; opacity, glow and interior sparks animate from the arena's saved clock.

## Boss disappearance prompt

Use case: identity-preserve.
Asset type: transparent pixel-art sprite sheet for a side-scrolling game's boss teleport disappearance.
Inputs: reference 1 is the current boss combat animation sheet; reference 2 is the original boss identity. Make EIGHT new frames of the SAME suited man. Closely match reference 1's pixel-art style and character proportions: short swept black hair, black rectangular glasses, pale clean-shaven face, charcoal business suit, white shirt, cyan tie, black shoes, compact blue pistol lowered by his side. No new costume, armor, beard, cape, staff or giant gauntlets.
Output a 1536x1024 RGBA sheet, exactly FOUR columns by TWO rows of 384x512 cells. True transparent background outside sprites and particles, no black matte, no checkerboard baked in, no grid, text or numbers. Read frames left to right then next row.
All eight cells use EXACTLY the same world anchor: body center x192, ground baseline y450, fully standing human height 300 pixels (hair top y150). The camera, character scale, and foot positions stay fixed. After feet dissolve, keep their former ground anchor; never center or scale the remaining fragments separately. Modest right-facing three-quarter angle like the neutral pistol-down pose in reference 1.
Frame 1: composed neutral stance, pistol down, subtle golden glint at free left hand.
Frame 2: left hand raised slightly, shoulders tense, small amber energy threads climbing the suit, face and clothing still perfectly clear.
Frame 3: controlled power gesture, head tilted slightly down, amber rim light and a few square fragments peel from shoes and coat hem.
Frame 4: lower legs and coat edges start dissolving into bright golden pixel fragments spiraling upward; face, glasses and torso remain recognizable.
Frame 5: roughly half the body is gone; torso silhouette breaking into separated gold pixels, head still recognizable. No solid golden statue.
Frame 6: only partial head/glasses and shoulder fragments remain above a narrow scatter of amber particles; most body is genuinely transparent.
Frame 7: NO intact person, only a slender dispersed trail of small gold/cyan pixel fragments and a faint central glint.
Frame 8: almost empty, only 5-8 very small fading sparks, no body and no solid mass.
A clean deliberate magic/time-energy departure, NOT an explosion, gore, smoke cloud, death collapse or burning man. Keep effects compact within each cell and restrained enough to read at 110px character height. Crisp hard pixel clusters, limited palette matching existing art, transparent gaps between fragments. No ground ring that moves the baseline, no scene, no detached black pieces or extra limbs. Preserve consistency in identity, body size and alignment across all eight frames.

## Boss combat prompt

Use case: identity-preserve.
Asset type: production pixel-art game sprite animation sheet, transparent RGBA background.
Regenerate only the SHOOTING and HURT animations of the EXACT existing boss shown in the references. Reference 1 is his original idle sprite and identity; reference 2 is original shooting pose and blue pistol; reference 3 is full source style sheet. Preserve his youthful/middle-aged clean-shaven pale face, black rectangular glasses, swept short black hair, charcoal gray business suit, white shirt, narrow cyan tie, black shoes, slim body proportions. He is NOT a different character, no beard, no armor, no gloves, no bulky gauntlets. Match original small pixel-art clusters and restrained gray palette, hard pixel edges, no painterly rendering.
Output ONE 1024x1024 sprite sheet divided into exactly FOUR columns by FOUR rows of equal 256x256 cells, no grid lines, no labels. Exactly 16 full-body frames, same character size and planted feet baseline at local y=236 in each cell, pelvis at x=104. Character standing height about 205 pixels in every frame. Right-facing three-quarter game view throughout, keep head identity and body dimensions consistent, both feet visible in every cell. Allow ample transparent room right of gun for flash. No shadows, background rectangles, stray limbs, detached effects, floor, text.
Read left to right, top to bottom:
Frames 0-5: smooth shooting anticipation: 0 relaxed with pistol low, 1 turn shoulder and bend elbow, 2 lift pistol halfway, 3 extend both arms forward, 4 aim pistol horizontal, 5 settle aim with small cyan muzzle charge.
Frames 6-10: shooting: 6 bright compact cyan muzzle flash, 7 slightly smaller flash and tiny shoulder recoil with feet fixed, 8 fading muzzle spark, 9 arms settle back into aim, 10 aimed ready pose. Keep muzzle at same local position approximately x=188,y=113 in frames 4-10.
Frame 11: recovered neutral pistol-lowered stance.
Frames 12-15: hurt reaction, without blood: 12 shoulders tense and head recoils slightly, 13 torso leans back with pained expression, 14 catches balance and left hand touches chest, 15 recovers almost upright. Small controlled body movement with feet at their anchors, no tumbling, no new costume.
Every cell must have true transparent background, no black matte patches behind the muzzle, no checkerboard baked in. The character must remain faithful to the original referenced boss, not redesigned. Pixel art animation, consistent scale, crisp silhouette.

## Chamber prompt

Edit target: first image, the existing double parents chamber. Supporting animation/style references: second and third images are the Level 1 sister's suffering idle loop. Generate a production sprite sheet of SIX animation frames of the SAME parents chamber, arranged precisely 3 columns x 2 rows on a 2304 x 1536 transparent canvas, each cell 768 x 768. The chamber in each cell must be IDENTICAL size, design, perspective and alignment: full original blue metal machine and two glass tubes, amber hourglass at top, mother on LEFT white dress dark curly hair, father RIGHT gray shirt brown trousers curly hair/beard. Preserve their faces and clothing. The machine is 520 pixels wide, 680 pixels tall, centered at cell x384, base at cell y724; leave transparent padding all around. The frame and glass NEVER move, warp, tilt or change size. Only the captive parents and light animate: frame1 weary tense idle gentle amber glow; frame2 heads lower slightly, shoulders tense as energy builds; frame3 eyes shut and subtle pained wince as golden bands flare brighter; frame4 peak extraction pulse, strained expressions, slight raised shoulders and hands tightening, tiny golden sparks floating upward; frame5 strength of light falls, shoulders relax a few pixels, eyes half open; frame6 back to weary idle matching frame1 for seamless looping. Keep both parents standing secured in the closed chamber in every frame, no release, no additional people, no gore, no opening. Match the sister chamber's restrained breathing and pulsing golden energy, not exaggerated body movement. Consistent crisp pixel-art clusters readable at game size. No words, numbers, labels, grid lines or backgrounds, genuine transparent alpha outside all six isolated machines.

## Portal prompt

Refine the provided ORIGINAL pixel-art portal asset for this game. Keep the exact recognizable design: blue industrial stone/metal arch, round clock at top, small gears beside the clock, cyan hourglass pillars on BOTH sides, rectangular block base, swirling luminous electric-blue oval energy doorway inside. Straight front orthographic view, symmetrical sturdy geometry, pixel art matching the reference. Improve crisp edges, coherent pixel clusters, clear clock hands, clean symmetrical pillars, smooth luminous spiral with a dark blue center and bright cyan rim, readable at 180 pixels tall. Do not redesign it as a generic rectangle, do not add gold/orange, do not add characters or scenery. One centered complete portal only, square 1024x1024 canvas with transparent alpha around the OUTSIDE of the arch, no opaque blue or black background, no floor shadow, no text. Full machine about 650px wide 860px tall, flat base at y950, enough padding so all glows and gears fit. Preserve the original reference's fantasy industrial time-machine identity.
