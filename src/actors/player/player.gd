class_name Player
extends CharacterBody2D
## The boy. Deliberately *not* a TimeBody2D: he keeps moving at full speed while
## his powers hold the world still. That contrast is the whole game.
##
## Movement numbers are first-pass placeholders. Combat lives in a future
## Attack state; the state machine is already the place to hang it.

## For the animator: leaving the ground is not the same as jumping - he also
## reaches Air by walking off a ledge - so the sound hangs off the push itself.
signal jumped

const GROUND_ACCEL := 6000.0
const AIR_ACCEL := 3300.0
const GROUND_FRICTION := 7200.0
const AIR_FRICTION := 1200.0
const COYOTE_TIME := 0.1
const JUMP_BUFFER := 0.12
const ATTACK_BUFFER := 0.12

## Three swings to down a Guard, on the 100-point scale.
@export var attack_damage := 34.0

@export var speed := 560.0
@export var jump_velocity := -1250.0
@export var gravity := 4100.0

## Crouched box height, from the sprite: the boy is ~71% of standing height
## while ducked.
const CROUCH_HEIGHT := 70.0

## What ducking costs him in speed. He creeps under the overhang rather than
## being pinned to the spot by it, which is what the crouch-walk frames are for.
const CROUCH_SPEED := 0.42

## Below this he is ducked but not going anywhere, and shows the held pose
## instead of the creep. Set above zero so the last of the friction slide does
## not leave him mouthing the walk cycle in place.
const CRAWL_SPEED := 24.0

@onready var shape: CollisionShape2D = $Shape
@onready var health: HealthComponent = $Health
@onready var age: AgeComponent = $Age
@onready var powers: TimePowers = $TimePowers
@onready var states: StateMachine = $StateMachine

var input_dir := 0.0
var facing := 1

## Which side the last hit came from, so Hurt knocks him the right way.
var hurt_from := 1

var _coyote_left := 0.0
var _jump_buffered := 0.0
var _attack_buffered := 0.0
var _attack_hit_done := false
var _standing_size: Vector2
var _standing_offset: float
## Built rather than instanced: see src/actors/player/sword_effects.gd.
var _effects: SwordEffects

func _ready() -> void:
	add_to_group(&"player")
	# Own the shape so resizing it for crouch cannot leak into other instances.
	shape.shape = shape.shape.duplicate()
	_standing_size = (shape.shape as RectangleShape2D).size
	_standing_offset = shape.position.y
	health.changed.connect(func(c, m): EventBus.player_health_changed.emit(c, m))
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	age.changed.connect(func(a, d): EventBus.player_age_changed.emit(a, d))
	age.died.connect(_on_died)
	# Killing Cad Corp's troops is the only way to buy years back, which is what
	# `age_reward` on a unit has always been for and what nothing was listening
	# for. Wired here rather than in the level: they are his years.
	EventBus.enemy_died.connect(_on_enemy_died)
	_effects = SwordEffects.new()
	add_child(_effects)
	EventBus.player_spawned.emit(self)


func _physics_process(delta: float) -> void:
	input_dir = Input.get_axis(&"move_left", &"move_right")
	_coyote_left = COYOTE_TIME if is_on_floor() else maxf(_coyote_left - delta, 0.0)
	_jump_buffered = maxf(_jump_buffered - delta, 0.0)
	if Input.is_action_just_pressed(&"jump"):
		_jump_buffered = JUMP_BUFFER
	_attack_buffered = maxf(_attack_buffered - delta, 0.0)
	if Input.is_action_just_pressed(&"attack"):
		_attack_buffered = ATTACK_BUFFER


func apply_gravity(delta: float) -> void:
	velocity.y += gravity * delta


## `speed_scale` is how much of his top speed the state allows. Only the target
## is scaled: however slowly he is going, stopping should feel the same.
func apply_horizontal(delta: float, speed_scale := 1.0) -> void:
	var grounded := is_on_floor()
	var rate := (GROUND_ACCEL if grounded else AIR_ACCEL) if not is_zero_approx(input_dir) \
		else (GROUND_FRICTION if grounded else AIR_FRICTION)
	velocity.x = move_toward(velocity.x, input_dir * speed * speed_scale, rate * delta)
	if not is_zero_approx(input_dir):
		facing = 1 if input_dir > 0.0 else -1


## Ducked and actually covering ground. Crouch is one state and two poses, and
## this is what separates them - a question about his speed, not his state.
func is_crawling() -> bool:
	return absf(velocity.x) > CRAWL_SPEED


## Buffered like the jump, so a press is never lost to frame timing.
func wants_attack() -> bool:
	return _attack_buffered > 0.0


func consume_attack() -> void:
	_attack_buffered = 0.0
	_attack_hit_done = false


## The blade going out, fired as the swing starts rather than when it lands: a
## miss is still an attack and still has to look like one, and the lance has to
## be most of the way out by the time the hit is actually tested.
func begin_swing() -> void:
	_effects.thrust(global_position, facing)


func perform_attack_hit() -> void:
	if _attack_hit_done:
		return
	_attack_hit_done = true
	for enemy in get_tree().get_nodes_in_group(&"enemy"):
		if not is_instance_valid(enemy) or not enemy.has_node("Health"):
			continue
		var offset: Vector2 = enemy.global_position - global_position
		# `offset.x * facing >= 0` rather than comparing signs: an enemy standing
		# exactly level with the boy has signf(offset.x) == 0, which matched
		# neither facing and let the swing pass straight through it.
		if absf(offset.x) <= 78.0 and absf(offset.y) <= 75.0 and offset.x * facing >= 0.0:
			enemy.health.take_damage(attack_damage, self)
			# On the blade line rather than on the unit's middle: a thrust
			# connects where the sword is, which is chest height off the floor
			# the boy is standing on, not off wherever the unit's feet are.
			_effects.impact(Vector2(enemy.global_position.x,
				global_position.y + SwordEffects.THRUST_Y))


func can_jump() -> bool:
	return _jump_buffered > 0.0 and _coyote_left > 0.0


func consume_jump() -> void:
	_jump_buffered = 0.0
	_coyote_left = 0.0
	velocity.y = jump_velocity
	jumped.emit()


func set_crouched(crouched: bool) -> void:
	var box := shape.shape as RectangleShape2D
	box.size = Vector2(_standing_size.x, CROUCH_HEIGHT if crouched else _standing_size.y)
	shape.position.y = -CROUCH_HEIGHT * 0.5 if crouched else _standing_offset


## False when a ceiling would trap the standing box, so crouch cannot pop the
## boy through an overhang.
func can_stand() -> bool:
	var box := shape.shape as RectangleShape2D
	var size := box.size
	var offset := shape.position.y
	box.size = _standing_size
	shape.position.y = _standing_offset
	var blocked := test_move(global_transform, Vector2.ZERO)
	box.size = size
	shape.position.y = offset
	return not blocked


func is_down() -> bool:
	return states.current_name == &"Dead"


func _on_damaged(_amount: float, source: Node) -> void:
	if is_down():
		return
	hurt_from = 1 if source != null and source.global_position.x > global_position.x else -1
	states.travel(&"Hurt")


func _on_enemy_died(_enemy: Node2D, age_reward: float) -> void:
	age.restore(age_reward)


func _on_died() -> void:
	powers.cancel()
	states.travel(&"Dead")
