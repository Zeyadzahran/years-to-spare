class_name Guard
extends Enemy
## Cad Corp's basic melee unit. Patrols a stretch of ground, chases the boy
## once he's close enough, and swings a baton when he's close enough for that.
##
## Everything here runs from `_tick(delta)`, and `delta` is already scaled by
## TimeService - stop the world mid-swing and the swing stops with it.

const KNOCKBACK := 200.0
const ATTACK_DURATION := 0.56
const ATTACK_HIT_TIME := 0.25
const HURT_DURATION := 0.35
const GROUND_FRICTION := 1400.0

@export var speed := 180.0
@export var detection_range := 430.0
@export var attack_range := 58.0
@export var damage := 1.0
@export var patrol_distance := 180.0

@onready var sprite: AnimatedSprite2D = $Sprite

var target: Player
var facing := -1
var patrol_origin_x := 0.0
var patrol_direction := 1
var state: StringName = &"Idle"
var _state_elapsed := 0.0
var _attack_hit := false
var _hurt_from := 1

func _ready() -> void:
	super._ready()
	patrol_origin_x = global_position.x
	health.damaged.connect(_on_damaged)
	sprite.animation_finished.connect(_on_animation_finished)
	_set_animation(&"idle")


func _tick(delta: float) -> void:
	_state_elapsed += delta
	target = get_tree().get_first_node_in_group(&"player") as Player

	match state:
		&"Idle":
			_tick_patrol(delta)
			if _can_see_player():
				_change_state(&"Chase")
		&"Chase":
			_tick_chase(delta)
			if target == null or global_position.distance_to(target.global_position) > detection_range * 1.35:
				_change_state(&"Idle")
			elif _in_attack_range():
				_change_state(&"Attack")
		&"Attack":
			_tick_attack(delta)
		&"Hurt":
			_tick_hurt(delta)
		&"Dead":
			_tick_dead(delta)


func _tick_patrol(_delta: float) -> void:
	velocity.x = patrol_direction * speed * 0.45
	if absf(global_position.x - patrol_origin_x) >= patrol_distance:
		patrol_direction *= -1
	# Every tick, not just on the turn: `facing` starts at -1 while the patrol
	# starts heading +1, so the first leg used to be walked backwards.
	facing = patrol_direction
	_set_animation(&"run")


func _tick_chase(delta: float) -> void:
	if target == null:
		return
	var dx := target.global_position.x - global_position.x
	var direction: float = signf(dx)
	facing = 1 if direction > 0.0 else -1 if direction < 0.0 else facing
	velocity.x = move_toward(velocity.x, direction * speed, 1800.0 * delta)
	_set_animation(&"run")


func _tick_attack(_delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, GROUND_FRICTION * _delta)
	_set_animation(&"attack")

	if target == null or target.is_down():
		_change_state(&"Idle")
		return

	var dx := target.global_position.x - global_position.x
	if absf(dx) <= attack_range * 1.4:
		facing = 1 if dx > 0.0 else -1 if dx < 0.0 else facing

	if not _attack_hit and _state_elapsed >= ATTACK_HIT_TIME:
		_attack_hit = true
		if _in_attack_range():
			target.health.take_damage(damage, self)

	if _state_elapsed >= ATTACK_DURATION:
		_change_state(&"Attack" if _in_attack_range() else &"Chase")


func _tick_hurt(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, GROUND_FRICTION * delta)
	_set_animation(&"hurt")
	if _state_elapsed >= HURT_DURATION:
		_change_state(&"Chase" if _can_see_player() else &"Idle")


func _tick_dead(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, GROUND_FRICTION * delta)
	_set_animation(&"dying")


func _can_see_player() -> bool:
	if target == null or not is_instance_valid(target) or target.is_down():
		return false
	return absf(target.global_position.x - global_position.x) <= detection_range


func _in_attack_range() -> bool:
	if target == null or not is_instance_valid(target):
		return false
	return absf(target.global_position.x - global_position.x) <= attack_range \
		and absf(target.global_position.y - global_position.y) <= 70.0


func _change_state(next: StringName) -> void:
	if state == next:
		return
	state = next
	_state_elapsed = 0.0
	_attack_hit = false
	match state:
		&"Idle": _set_animation(&"idle")
		&"Chase": _set_animation(&"run")
		&"Attack": _set_animation(&"attack")
		&"Hurt": _set_animation(&"hurt")
		&"Dead": _set_animation(&"dying")


func _set_animation(name: StringName) -> void:
	if sprite.animation != name:
		sprite.play(name)
	sprite.flip_h = facing < 0


func _on_damaged(_amount: float, source: Node) -> void:
	if state == &"Dead":
		return
	if source != null:
		var from_right: bool = source.global_position.x > global_position.x
		_hurt_from = 1 if from_right else -1
	velocity = Vector2(-_hurt_from * KNOCKBACK, -180.0)
	_change_state(&"Hurt")


func _on_died() -> void:
	# Enemy normally disappears immediately. Guards keep the body around long
	# enough to show their dying animation.
	_change_state(&"Dead")
	collision_layer = 0
	collision_mask = 1


func _on_animation_finished() -> void:
	if sprite.animation == &"dying" and state == &"Dead":
		EventBus.enemy_died.emit(self, age_reward)
		queue_free()
