class_name Guard
extends Enemy
## Cad Corp's basic melee unit. Patrols a stretch of ground, chases the boy
## once he's close enough, and swings a baton when he's close enough for that.
##
## The state machine is Enemy's. What is here is the patrol, the swing, and the
## numbers that make him a Guard rather than a Gunner.

## Fraction of his speed he walks the beat at. Patrolling is not chasing.
const PATROL_PACE := 0.45

@export var patrol_distance := 180.0

## How far either side of his post he is willing to go. He is paid to hold a
## stretch of road, not to follow the boy across the phase: step off his ground
## and he loses interest and walks home. Set a little under the 800 px the
## camera shows, so giving up happens on screen rather than somewhere behind it.
@export var territory := 640.0

var patrol_origin_x := 0.0
var patrol_direction := 1

func _init() -> void:
	# Fast enough to be worth running from now the boy tops out at 450. He still
	# cannot catch a boy who commits to leaving - and is not meant to - but
	# strolling away from a fight is no longer free.
	speed = 240.0
	detection_range = 430.0
	attack_range = 58.0
	damage = 34.0
	attack_duration = 0.56
	attack_hit_time = 0.25
	attack_recovery = 0.6
	hurt_duration = 0.35
	knockback = 200.0
	attack_animation = &"attack"


func _ready() -> void:
	patrol_origin_x = global_position.x
	super._ready()


## A Guard does not stand his post; he walks it - and walks back to it after a
## chase has dragged him off.
func _tick_idle(_delta: float) -> void:
	var offset := global_position.x - patrol_origin_x
	if absf(offset) >= patrol_distance:
		# Aimed at the post rather than simply reversed. Flipping direction is
		# right at the end of the beat and wrong everywhere else: a guard left
		# standing well outside his patch flips every frame and shivers on the
		# spot instead of going home.
		patrol_direction = -1 if offset > 0.0 else 1
	velocity.x = patrol_direction * speed * PATROL_PACE
	# Every tick, not just on the turn: `facing` starts at -1 while the patrol
	# starts heading +1, so the first leg used to be walked backwards.
	facing = patrol_direction
	_set_animation(&"run")


## He notices nobody standing off his ground. This covers picking a fight and,
## through Recover, going back to one.
func _can_see_player() -> bool:
	return super() and _within_territory()


## Chasing stops at the edge of his ground. Enemy gives up on distance from
## himself, which a chase carries with him and so never really ends; the boy
## only has to step off the guard's patch, not outrun his eyesight.
func _tick_chase(delta: float) -> void:
	if not _within_territory():
		_change_state(&"Idle")
		return
	super(delta)


func _within_territory() -> bool:
	if target == null or not is_instance_valid(target):
		return false
	return absf(target.global_position.x - patrol_origin_x) <= territory


## The baton only tracks the boy while he is roughly still in front of it, so a
## swing cannot pivot to follow him around behind.
func _face_target_mid_attack() -> void:
	var dx := target.global_position.x - global_position.x
	if absf(dx) <= attack_range * 1.4:
		facing = 1 if dx > 0.0 else -1 if dx < 0.0 else facing


func _attack() -> void:
	if _in_attack_range():
		target.health.take_damage(damage, self)
		play_hit_audio()
