# CAD Corp owner: proportion redesign

## What was inconsistent

The guard, gunner and adult player use side-facing adult silhouettes: smaller heads, visible necks, longer limbs, narrow feet and fine shaded outlines. Their source frames are 256 x 256 and render at 0.45 scale. The previous boss sheets used a much larger head, shorter legs, oversized glasses/hair and a thick cartoon outline. Matching their screen height alone could not fix the difference in anatomy.

References inspected:

- assets/sprites/player_adult/man-idle/frame_000.png
- assets/sprites/player_teen/boy-idle-animation/East_0001.png
- assets/sprites/guard/idle/East_0001.png and run/East_0003.png
- assets/sprites/gunner/idle/frame_000.png and shoot/frame_006.png
- assets/sprites/business_man/idle.png and combat_refined_sheet.png

## Design rules

- Use roughly six-and-a-half to seven head heights as an art target, rather than the previous exaggerated head-to-body ratio. This is a visual design target, not an anatomical measurement inferred from code.
- Match the adult player's side view and the troops' outline/shading density.
- Preserve the owner's charcoal suit, white shirt, cyan tie, black hair, small rectangular glasses and blue energy pistol.
- Convey authority through upright posture, controlled gestures and gold time-energy effects.
- Keep the same face, proportions, scale and foot anchor across idle, walking, shooting, hurt, disappearance and defeat.
- Use uniformly scaled artwork, never stretch the body or shrink only its head in code.

## Generated assets

Generated with Codex's built-in image generation tool. The original assets remain available. The model establishes the design; animation sheets are generated from that model plus the adult player and guard references.

- assets/sprites/business_man/redesign/model.png
- assets/sprites/business_man/redesign/movement_hurt.png: four idle poses, eight walk poses, four hurt poses.
- assets/sprites/business_man/redesign/shoot_death.png: twelve shooting poses, four defeat poses.
- assets/sprites/business_man/redesign/teleport.png: eight disappearance poses, also reversed for arrival.

## Runtime integration

All boss clips reference the redesign sheets in business_boss_frames.tres. Movement/hurt and shooting/defeat sheets are 1254 x 1254, each a 4 x 4 grid. Atlas margins place the foot anchor at (150, 320) on a 360 x 340 canvas; uniform 0.4 scale gives roughly 106-112 pixels of standing height. Teleport is 1774 x 887 in a 4 x 2 grid, scaled uniformly to about 110 pixels tall with a fixed foot origin, including spark-only frames. Death poses share their root rather than being centered individually as the body falls.

Idle, hurt, attacks, death and teleport sample saved world clocks, so Stop Time and Rewind restore the correct pose. The eight walking poses are available as `run`; the encounter remains stationary. Muzzle emission is aligned to the new pistol at (53, -94), mirrored with facing. Collision shape, health, combat patterns and fight progression are unchanged by this art pass.

The comparison preview is rendered by Godot with the real textures and runtime scales, enlarged equally for inspection.

## Verification

Godot rendered the comparison and the actual arena shooting, hurt and teleport poses. Five focused suites passed with zero assertion failures: verify_business_boss, verify_business_boss_polish, verify_cad_sequence, verify_boss_time_regressions and verify_boss_retries. Idle and defeat coverage checks pose advancement, Stop Time and snapshot restoration. Existing headless macOS certificate and shutdown resource warnings remain.

## Proportion correction

The initial animation generation enlarged heads relative to the model. A second built-in edit reduced each head, including hair and glasses, while preserving the body, poses and layout. The final sheets below include that correction.

Use case: precise-object-edit / identity-preserve.
Edit the FIRST sprite sheet. The second image (adult player) and third (guard) are proportion references. The first sheet still has heads too large relative to the torso; fix only that anatomical mismatch across EVERY visible character.
Make each head INCLUDING all hair, face, ear and glasses approximately 25% SMALLER in BOTH width and height than it currently is. Keep the head attached naturally at the SAME neck base. Preserve the face identity and hair silhouette, but scale their details together. The reduced head should occupy about 14-16% of full standing height, like the adult player. Do NOT shrink the whole character, do NOT shorten the limbs, do NOT enlarge the torso, do NOT change the camera, clothes, limbs, shoes, gun, pose, foot locations, cells or their alignment. Keep exact original sheet dimensions, same number/order of frames and exact grid. Reconnect collar/neck cleanly with fine pixel art. Eliminate any old enlarged-head remnants. No large heads, puffed-up hair, chibi, giant sunglasses or heavy cartoon contours.
Preserve transparent RGBA background and existing effect transparency. No added backgrounds, text or labels. Keep exact suit/pistol colors and fine shaded pixel style.
This is a corrective pass, not a redesign of any other part. The most important change is visibly smaller, adult-proportioned heads compared with the prior sheet.

Use case: precise-object-edit / identity-preserve.
Edit the FIRST sprite sheet. The second image (adult player) and third (guard) are proportion references. The first sheet still has heads too large relative to the torso; fix only that anatomical mismatch across EVERY visible character.
Make each head INCLUDING all hair, face, ear and glasses approximately 25% SMALLER in BOTH width and height than it currently is. Keep the head attached naturally at the SAME neck base. Preserve the face identity and hair silhouette, but scale their details together. The reduced head should occupy about 14-16% of full standing height, like the adult player. Do NOT shrink the whole character, do NOT shorten the limbs, do NOT enlarge the torso, do NOT change the camera, clothes, limbs, shoes, gun, pose, foot locations, cells or their alignment. Keep exact original sheet dimensions, same number/order of frames and exact grid. Reconnect collar/neck cleanly with fine pixel art. Eliminate any old enlarged-head remnants. No large heads, puffed-up hair, chibi, giant sunglasses or heavy cartoon contours.
Preserve transparent RGBA background and existing effect transparency. No added backgrounds, text or labels. Keep exact suit/pistol colors and fine shaded pixel style.
This is a corrective pass, not a redesign of any other part. The most important change is visibly smaller, adult-proportioned heads compared with the prior sheet.

Use case: precise-object-edit / identity-preserve.
Edit the FIRST sprite sheet. The second image (adult player) and third (guard) are proportion references. The first sheet still has heads too large relative to the torso; fix only that anatomical mismatch across EVERY visible character.
Make each head INCLUDING all hair, face, ear and glasses approximately 25% SMALLER in BOTH width and height than it currently is. Keep the head attached naturally at the SAME neck base. Preserve the face identity and hair silhouette, but scale their details together. The reduced head should occupy about 14-16% of full standing height, like the adult player. Do NOT shrink the whole character, do NOT shorten the limbs, do NOT enlarge the torso, do NOT change the camera, clothes, limbs, shoes, gun, pose, foot locations, cells or their alignment. Keep exact original sheet dimensions, same number/order of frames and exact grid. Reconnect collar/neck cleanly with fine pixel art. Eliminate any old enlarged-head remnants. No large heads, puffed-up hair, chibi, giant sunglasses or heavy cartoon contours.
Preserve transparent RGBA background and existing effect transparency. No added backgrounds, text or labels. Keep exact suit/pistol colors and fine shaded pixel style. On the teleport sheet, apply the head reduction to every intact or partially intact head; keep the final spark-only cell empty of anatomy.
This is a corrective pass, not a redesign of any other part. The most important change is visibly smaller, adult-proportioned heads compared with the prior sheet.

## Model prompt

Use case: identity-preserve / style-transfer.
Create a production character model sprite for the owner of CAD Corp in an existing 2D side-scrolling pixel-art game.
REFERENCE PRIORITY: images 1, 2, 3 are the AUTHORITY for anatomy, proportions, side-view camera, outline weight and pixel rendering: an armored guard, adult player and gunner. Image 4 supplies ONLY the boss's clothing/colors/identity, NOT its oversized-head anatomy. The old boss has rejected chibi proportions. Correct that mismatch.
One full-body character only, facing RIGHT in a strict side-on platformer view like the adult player. Grounded relaxed alert stance, feet slightly apart, right hand holding a compact blue-accented energy pistol pointed diagonally down, left hand relaxed. Adult human about 7 HEAD HEIGHTS tall: hair-to-chin occupies at most 14-15% of full standing height. Long natural legs approximately half total height, normal hands and narrow shoes, defined neck, proportionate shoulders. Mature clean-shaven businessman, swept-back short black hair with restrained volume, small rectangular black-rim eyeglasses with clear lenses, sharp serious face. Tailored charcoal suit, white shirt, slender cyan tie, subtle cyan cuff details. No armored limbs, beard, huge gloves, huge feet, sunglasses hiding his face, baby face or oversized hair.
Match the input guard/adult-player sprites' fine pixel-art shading and natural body proportions exactly. Thin dark contour, coherent small pixel clusters, muted fabric shading, no giant black cartoon outline. This is an in-game sprite, not a painted concept illustration.
Transparent RGBA background, no floor, cast shadow, aura, effects, labels, text or extra objects. 1024x1024 canvas, entire character centered, full standing height around 850 pixels, generous padding all sides, all shoes and pistol visible. His authority comes from straight posture, tailored suit and stern expression, not exaggerated body proportions.

## Idle, walk and hurt prompt

Use case: identity-preserve. Production pixel-art character animation sheet for an existing side-scrolling game.
Reference 1 is the redesigned CAD Corp owner: copy this exact adult, face, dark short swept hair, small rectangular clear-lens glasses, charcoal tailored suit, white shirt, slim cyan tie, normal black shoes, compact cyan-accented energy pistol. Reference 2 adult player and reference 3 guard define the game's pixel-art rendering and realistic proportions. Match ALL characters' natural adult anatomy: standing height around SIX-AND-A-HALF to SEVEN head heights, SMALL head including hair about 43-46px for a 300px-tall body, long natural legs, narrow shoes, proportionate hands, defined neck. Absolutely no chibi anatomy, giant head, chunky outlines, oversized hair or bulky boots. Preserve the master reference's mature serious businessman identity and muted fine pixel shading in every frame.
Strict right-facing side view, fixed camera, identical size in every frame, no three-quarter front poses. Thin dark outlines, coherent detailed pixel clusters like the player and guard references. True transparent RGBA background, no matte rectangles, shadows, floor, labels, text or grid. Full sprites and effects stay inside each cell, all body parts visible where the animation requires them.
Precise shared layout: FOUR columns. Every cell 384x384 pixels. Standing body 300 pixels tall, hair top y50, shoes baseline y350, body/hip anchor x160. Same origin, baseline and scale across cells, no individual recentering. Pistol points down when relaxed; eyes face right. No costume/weapon/face changes.
Output 1536x1536 sheet, FOUR rows, exactly 16 frames. Read left to right then next row.
Row1 frames0-3: gentle four-frame idle breathing loop, pistol relaxed downward, stern face, body rises/falls only 1-2px with feet fixed.
Rows2-3 frames4-11: eight-frame WALK loop in place, natural measured executive stride at consistent speed: right-foot contact, right support down, left passing, left up, left-foot contact, left support down, right passing, right up. Arms counter-swing subtly, pistol held down. Same head/body proportions throughout; no sliding the entire body sideways between cells.
Row4 frames12-15: four-frame HURT reaction, 12 shoulder tenses, 13 torso leans backward slightly with pained face, 14 free hand braces ribs and weight catches, 15 straightens toward neutral. Feet stay near fixed stance, no gore, no collapse. Keep adult anatomy, never enlarge the head for expression.

## Shooting and defeat prompt

Use case: identity-preserve. Production pixel-art character animation sheet for an existing side-scrolling game.
Reference 1 is the redesigned CAD Corp owner: copy this exact adult, face, dark short swept hair, small rectangular clear-lens glasses, charcoal tailored suit, white shirt, slim cyan tie, normal black shoes, compact cyan-accented energy pistol. Reference 2 adult player and reference 3 guard define the game's pixel-art rendering and realistic proportions. Match ALL characters' natural adult anatomy: standing height around SIX-AND-A-HALF to SEVEN head heights, SMALL head including hair about 43-46px for a 300px-tall body, long natural legs, narrow shoes, proportionate hands, defined neck. Absolutely no chibi anatomy, giant head, chunky outlines, oversized hair or bulky boots. Preserve the master reference's mature serious businessman identity and muted fine pixel shading in every frame.
Strict right-facing side view, fixed camera, identical size in every frame, no three-quarter front poses. Thin dark outlines, coherent detailed pixel clusters like the player and guard references. True transparent RGBA background, no matte rectangles, shadows, floor, labels, text or grid. Full sprites and effects stay inside each cell, all body parts visible where the animation requires them.
Precise shared layout: FOUR columns. Every cell 384x384 pixels. Standing body 300 pixels tall, hair top y50, shoes baseline y350, body/hip anchor x160. Same origin, baseline and scale across cells, no individual recentering. Pistol points down when relaxed; eyes face right. No costume/weapon/face changes.
Output 1536x1536 sheet, FOUR rows, exactly 16 frames. Read left to right then next row.
Frames0-5: shooting anticipation. 0 pistol low; 1 elbow bends to raise it; 2 pistol rises to chest; 3 both arms extend to aim; 4 settles horizontal aim; 5 tiny cyan charge at barrel. Stable feet, subtle shoulder movement.
Frames6-10: shot cycle. 6 compact bright cyan muzzle flash exactly as shot fires; 7 small shoulder recoil and smaller flash; 8 fading spark; 9 returns to steady aim; 10 settled aim without flash. Gun barrel approximately cell x270,y130; all flash fully inside cell. Flash must never obscure face.
Frame11: lowers pistol to neutral stance.
Frames12-15: defeated/death animation, no gore. 12 knees buckle, shoulders sag; 13 drops to one knee with head bowed; 14 tips toward ground; 15 lies still on his side across the cell baseline. Preserve full body's natural length; head remains small. No severed parts, explosions or extra people.

## Teleport prompt

Use case: identity-preserve. Production pixel-art character animation sheet for an existing side-scrolling game.
Reference 1 is the redesigned CAD Corp owner: copy this exact adult, face, dark short swept hair, small rectangular clear-lens glasses, charcoal tailored suit, white shirt, slim cyan tie, normal black shoes, compact cyan-accented energy pistol. Reference 2 adult player and reference 3 guard define the game's pixel-art rendering and realistic proportions. Match ALL characters' natural adult anatomy: standing height around SIX-AND-A-HALF to SEVEN head heights, SMALL head including hair about 43-46px for a 300px-tall body, long natural legs, narrow shoes, proportionate hands, defined neck. Absolutely no chibi anatomy, giant head, chunky outlines, oversized hair or bulky boots. Preserve the master reference's mature serious businessman identity and muted fine pixel shading in every frame.
Strict right-facing side view, fixed camera, identical size in every frame, no three-quarter front poses. Thin dark outlines, coherent detailed pixel clusters like the player and guard references. True transparent RGBA background, no matte rectangles, shadows, floor, labels, text or grid. Full sprites and effects stay inside each cell, all body parts visible where the animation requires them.
Precise shared layout: FOUR columns. Every cell 384x384 pixels. Standing body 300 pixels tall, hair top y50, shoes baseline y350, body/hip anchor x160. Same origin, baseline and scale across cells, no individual recentering. Pistol points down when relaxed; eyes face right. No costume/weapon/face changes.
Output 1536x768 sheet, TWO rows, exactly EIGHT teleport disappearance frames. Maintain the same 384x384 cells and origin as above, even after the feet dissolve.
Frame0 composed standing pose, pistol down, tiny amber glint in free hand.
Frame1 slight power gesture with free hand, fine gold threads climbing suit.
Frame2 amber edge light, a few square gold fragments peel from coat hem and shoes.
Frame3 lower legs dissolve; recognizable natural adult head, torso and glasses.
Frame4 half the body dissolves, torso breaking into gold pixel fragments with genuine transparent gaps.
Frame5 only parts of the SMALL natural head, glasses and shoulders remain; most body gone.
Frame6 no intact person, sparse vertical scatter of gold and a few cyan pixels.
Frame7 nearly empty, only 5-8 tiny fading sparks.
Deliberate time-energy dematerialization, not fire, smoke, explosion or a gold statue. Body does not shrink or grow; fragments occupy its original footprint. No background glow rectangle.
