class_name Guard
extends Enemy
## Cad Corp's basic melee unit. Patrols a stretch of ground, chases the boy
## once he's close enough, and swings a baton when he's close enough for that.
##
## The state machine is Enemy's. What is here is the patrol, the swing, and the
## numbers that make him a Guard rather than a Gunner.

@export var patrol_distance := 180.0

var patrol_origin_x := 0.0
var patrol_direction := 1

func _init() -> void:
	speed = 180.0
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


## A Guard does not stand his post; he walks it.
func _tick_idle(_delta: float) -> void:
	velocity.x = patrol_direction * speed * 0.45
	if absf(global_position.x - patrol_origin_x) >= patrol_distance:
		patrol_direction *= -1
	# Every tick, not just on the turn: `facing` starts at -1 while the patrol
	# starts heading +1, so the first leg used to be walked backwards.
	facing = patrol_direction
	_set_animation(&"run")


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
