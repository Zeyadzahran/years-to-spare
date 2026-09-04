class_name Gunner
extends Enemy
## Cad Corp's ranged unit. Stands down until the boy is close enough to
## notice, closes the distance while he's out of range, then plants his feet
## and fires. Same state shape as Guard (Idle / Chase / Attack / Recover /
## Hurt / Dead) so the two read the same way from the outside; only the
## attack itself is different - a spawned round instead of a melee hitbox.
##
## Everything here runs from `_tick(delta)`, and `delta` is already scaled by
## TimeService - stop the world mid-shot and the shot stops with it, muzzle
## flash and all (see Enemy._sync_sprite_to_world_time).

const BULLET_SCENE := preload("res://src/actors/enemy/bullet.tscn")

const KNOCKBACK := 170.0
## The shipped art crops the muzzle flash on its last frame (the gun points
## past the edge of the source canvas), so that frame is dropped entirely -
## the clip now ends on frame 7, which still shows a full flash. See
## gunner_frames.tres.
const SHOOT_DURATION := 0.6667
## Frame 6 of 0..7 is where the flash first appears - that's when the round
## actually leaves the barrel.
const SHOOT_FIRE_TIME := 0.5
## Breather between shots, long enough that a hit-and-retreat actually buys
## the player a gap rather than walking back into the next round.
const SHOOT_RECOVERY := 0.7
const HURT_DURATION := 0.4
const GROUND_FRICTION := 1400.0
const BULLET_SPEED := 900.0
## How far above the gunner's feet the round leaves the barrel, roughly
## shoulder height on the sprite.
const MUZZLE_HEIGHT := -78.0
const MUZZLE_FORWARD := 34.0

@export var speed := 150.0
## Ranged unit, so this is "notices the boy exists", not "can hit him" - that
## is `attack_range`, and it is deliberately shorter so Chase has ground to
## close before Attack takes over.
@export var detection_range := 560.0
@export var attack_range := 430.0
@export var damage := 14.0
## Only used to accept a shot without adding a whole line-of-sight system:
## Attack still fires if the boy briefly hops above/below this band.
@export var attack_height_tolerance := 110.0

@onready var sprite: AnimatedSprite2D = $Sprite

var target: Player
var facing := -1
var state: StringName = &"Idle"
var _state_elapsed := 0.0
var _shot_fired := false
var _hurt_from := 1

func _ready() -> void:
	super._ready()
	health.damaged.connect(_on_damaged)
	sprite.animation_finished.connect(_on_animation_finished)
	_set_animation(&"idle")


func _tick(delta: float) -> void:
	_state_elapsed += delta
	if target == null or not is_instance_valid(target):
		target = get_tree().get_first_node_in_group(&"player") as Player

	match state:
		&"Idle":
			_tick_idle(delta)
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
		&"Recover":
			_tick_recover(delta)
		&"Hurt":
			_tick_hurt(delta)
		&"Dead":
			_tick_dead(delta)


## Idle really is idle - a ranged unit pacing back and forth would just be
## walking into its own sightline. He stands his post until the boy is
## actually close enough to be worth reacting to.
func _tick_idle(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, GROUND_FRICTION * delta)
	_set_animation(&"idle")


func _tick_chase(delta: float) -> void:
	if target == null:
		return
	var dx := target.global_position.x - global_position.x
	var direction: float = signf(dx)
	facing = 1 if direction > 0.0 else -1 if direction < 0.0 else facing
	velocity.x = move_toward(velocity.x, direction * speed, 1600.0 * delta)
	_set_animation(&"run")


func _tick_attack(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, GROUND_FRICTION * delta)
	_set_animation(&"shoot")

	if target == null or target.is_down():
		_change_state(&"Idle")
		return

	var dx := target.global_position.x - global_position.x
	if not is_zero_approx(dx):
		facing = 1 if dx > 0.0 else -1

	if not _shot_fired and _state_elapsed >= SHOOT_FIRE_TIME:
		_shot_fired = true
		_fire()

	if _state_elapsed >= SHOOT_DURATION:
		_change_state(&"Recover")


## Mirrors Guard's Recover: a real state change re-arms `_shot_fired`, which
## re-entering Attack directly would not.
func _tick_recover(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, GROUND_FRICTION * delta)
	_set_animation(&"idle")
	if target != null and is_instance_valid(target):
		var dx := target.global_position.x - global_position.x
		if not is_zero_approx(dx):
			facing = 1 if dx > 0.0 else -1
	if _state_elapsed < SHOOT_RECOVERY:
		return
	if _in_attack_range():
		_change_state(&"Attack")
	elif _can_see_player():
		_change_state(&"Chase")
	else:
		_change_state(&"Idle")


func _tick_hurt(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, GROUND_FRICTION * delta)
	_set_animation(&"hurt")
	if _state_elapsed >= HURT_DURATION:
		_change_state(&"Chase" if _can_see_player() else &"Idle")


func _tick_dead(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, GROUND_FRICTION * delta)
	_set_animation(&"dying")


## Spawns the round that the sprite itself can't show: the source art clips
## the flash against the edge of its canvas before the shot goes anywhere, so
## this is what actually lets the Gunner injure the boy at range.
func _fire() -> void:
	if target == null or not is_instance_valid(target):
		return
	var bullet := BULLET_SCENE.instantiate() as Bullet
	get_tree().current_scene.add_child(bullet)
	# `sprite.flip_h` mirrors the drawn texture only; it does not mirror child
	# transforms. The barrel's world position has to be rebuilt from `facing`
	# by hand rather than read off a marker under the sprite.
	bullet.global_position = global_position + Vector2(facing * MUZZLE_FORWARD, MUZZLE_HEIGHT)
	bullet.setup(Vector2(facing, 0.0) * BULLET_SPEED, damage, self)


func _can_see_player() -> bool:
	if target == null or not is_instance_valid(target) or target.is_down():
		return false
	return absf(target.global_position.x - global_position.x) <= detection_range


func _in_attack_range() -> bool:
	if target == null or not is_instance_valid(target):
		return false
	return absf(target.global_position.x - global_position.x) <= attack_range \
		and absf(target.global_position.y - global_position.y) <= attack_height_tolerance


func _change_state(next: StringName) -> void:
	if state == next:
		return
	state = next
	_state_elapsed = 0.0
	_shot_fired = false
	match state:
		&"Idle": _set_animation(&"idle")
		&"Chase": _set_animation(&"run")
		&"Attack": _set_animation(&"shoot")
		&"Recover": _set_animation(&"idle")
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
	velocity = Vector2(-_hurt_from * KNOCKBACK, -160.0)
	_change_state(&"Hurt")


func _on_died() -> void:
	# Same reasoning as Guard: keep the body around for the dying clip instead
	# of vanishing mid-animation.
	_change_state(&"Dead")
	collision_layer = 0
	collision_mask = 1


func _on_animation_finished() -> void:
	if sprite.animation == &"dying" and state == &"Dead":
		EventBus.enemy_died.emit(self, age_reward)
		queue_free()
