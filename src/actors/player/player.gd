class_name Player
extends CharacterBody2D
## The boy. Deliberately *not* a TimeBody2D: he keeps moving at full speed while
## his powers hold the world still. That contrast is the whole game.
##
## Movement numbers are first-pass placeholders. Combat lives in a future
## Attack state; the state machine is already the place to hang it.

const GROUND_ACCEL := 6000.0
const AIR_ACCEL := 3300.0
const GROUND_FRICTION := 7200.0
const AIR_FRICTION := 1200.0
const COYOTE_TIME := 0.1
const JUMP_BUFFER := 0.12

@export var speed := 560.0
@export var jump_velocity := -1250.0
@export var gravity := 4100.0

## Crouched box height, from the sprite: the boy is ~71% of standing height
## while ducked.
const CROUCH_HEIGHT := 70.0

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
var _standing_size: Vector2
var _standing_offset: float

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
	EventBus.player_spawned.emit(self)


func _physics_process(delta: float) -> void:
	input_dir = Input.get_axis(&"move_left", &"move_right")
	_coyote_left = COYOTE_TIME if is_on_floor() else maxf(_coyote_left - delta, 0.0)
	_jump_buffered = maxf(_jump_buffered - delta, 0.0)
	if Input.is_action_just_pressed(&"jump"):
		_jump_buffered = JUMP_BUFFER


func apply_gravity(delta: float) -> void:
	velocity.y += gravity * delta


func apply_horizontal(delta: float) -> void:
	var grounded := is_on_floor()
	var rate := (GROUND_ACCEL if grounded else AIR_ACCEL) if not is_zero_approx(input_dir) \
		else (GROUND_FRICTION if grounded else AIR_FRICTION)
	velocity.x = move_toward(velocity.x, input_dir * speed, rate * delta)
	if not is_zero_approx(input_dir):
		facing = 1 if input_dir > 0.0 else -1


func can_jump() -> bool:
	return _jump_buffered > 0.0 and _coyote_left > 0.0


func consume_jump() -> void:
	_jump_buffered = 0.0
	_coyote_left = 0.0
	velocity.y = jump_velocity


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


func _on_died() -> void:
	powers.cancel()
	states.travel(&"Dead")
