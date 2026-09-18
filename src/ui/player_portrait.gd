class_name PlayerPortrait
extends RefCounted
## His face for the HUD: the three-quarter head from
## each character sheet (assets/sprites/portraits), one per body he can be
## wearing, so the portrait ages with him.

const BOY := preload("res://assets/sprites/portraits/boy.png")
const MAN := preload("res://assets/sprites/portraits/man.png")
const ELDER := preload("res://assets/sprites/portraits/elder.png")


## The portrait for a set of frames, told apart by the animator that owns the
## three sets - so the age lines stay its business.
static func texture_for(frames: SpriteFrames, animator: PlayerAnimator) -> Texture2D:
	if animator == null:
		return BOY
	if frames == animator.elder_frames:
		return ELDER
	if frames == animator.adult_frames:
		return MAN
	return BOY
