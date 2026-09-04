class_name Gunner
extends Enemy
## Cad Corp's ranged unit. Stands his post until the boy is close enough to
## notice, closes the distance while he's out of range, then plants his feet
## and fires.
##
## The state machine is Enemy's. What is here is the shot, and the numbers that
## make him a Gunner rather than a Guard.

const BULLET_SCENE := preload("res://src/actors/enemy/bullet.tscn")

## Slowed alongside the boy: he lost a fifth of his speed, and a round that
## kept all of its would have made the same dodge harder than it was.
const BULLET_SPEED := 720.0
## Where the barrel actually is, measured off the shoot frames rather than
## guessed: the Sprite is scale 0.45 with offset (0, -120), so texture pixel
## (px, py) sits at node ((px - 128) * 0.45, (py - 128) * 0.45 - 54). The flash
## on frames 6 and 7 runs to the right edge of the 256px canvas at texture rows
## 37-62, which lands here. The earlier pair put the round 23px back and 11px
## low - inside his chest instead of at the muzzle.
const MUZZLE_HEIGHT := -89.0
const MUZZLE_FORWARD := 57.0

func _init() -> void:
	speed = 150.0
	# Both ranges have to stay inside the frame. The player camera is zoom 1.6
	# on a 1280px viewport, so exactly 800 world px are visible - 400 either
	# side of the boy, less while the camera's smoothing catches up. A shot
	# fired from further out than that arrives from an enemy nobody has seen.
	detection_range = 440.0
	attack_range = 340.0
	damage = 14.0
	# A ranged unit reads a taller slice of the world than a baton does, but
	# still not a whole screen: he should not be shooting at a boy on the floor
	# below him.
	attack_height_tolerance = 110.0
	# He sights along the barrel, so the line he checks is the line the round
	# will actually fly.
	eye_height = MUZZLE_HEIGHT
	# The clip runs to frame 7 and the flash appears on frame 6, which is when
	# the round leaves the barrel.
	attack_duration = 0.6667
	attack_hit_time = 0.5
	## Breather between shots, long enough that a hit-and-retreat actually buys
	## the player a gap rather than walking back into the next round.
	attack_recovery = 0.7
	hurt_duration = 0.4
	knockback = 170.0
	attack_animation = &"shoot"


## Spawns the round that the sprite itself cannot show. The shipped muzzle-flash
## art is cropped by its own canvas - frames 1, 6 and 7 all still have opaque
## pixels in the last column of the 256px source - so the flash never reads as
## leaving the frame. Re-exporting those frames with padding is art work that
## has not been done; until it is, this is what actually carries the shot.
func _attack() -> void:
	if target == null or not is_instance_valid(target):
		return
	# Checked again at the moment of firing, not just on the way into Attack:
	# the boy has half a second of wind-up to duck behind something, and a
	# Gunner who keeps shooting the rock he watched him step behind reads as
	# broken. Range is deliberately not re-checked - backing out of range
	# still earns the shot, it just has further to travel.
	if not has_line_of_sight():
		return
	var bullet := BULLET_SCENE.instantiate() as Bullet
	get_tree().current_scene.add_child(bullet)
	# `sprite.flip_h` mirrors the drawn texture only; it does not mirror child
	# transforms. The barrel's world position has to be rebuilt from `facing`
	# by hand rather than read off a marker under the sprite.
	bullet.global_position = global_position + Vector2(facing * MUZZLE_FORWARD, MUZZLE_HEIGHT)
	bullet.setup(Vector2(facing, 0.0) * BULLET_SPEED, damage, self)
