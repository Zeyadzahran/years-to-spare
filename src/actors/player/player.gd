class_name Player
extends CharacterBody2D
## The boy. Deliberately *not* a TimeBody2D: he keeps moving at full speed while
## his powers hold the world still. That contrast is the whole game.
##
## Movement numbers are first-pass placeholders. Combat lives in a future
## Attack state; the state machine is already the place to hang it.

const GROUND_ACCEL := 2000.0
const AIR_ACCEL := 1100.0
const GROUND_FRICTION := 2400.0
const AIR_FRICTION := 400.0
const COYOTE_TIME := 0.1
const JUMP_BUFFER := 0.12

@export var speed := 195.0
@export var jump_velocity := -430.0
@export var gravity := 1400.0

@onready var health: HealthComponent = $Health
@onready var age: AgeComponent = $Age
@onready var powers: TimePowers = $TimePowers
@onready var states: StateMachine = $StateMachine

var input_dir := 0.0
var facing := 1

var _coyote_left := 0.0
var _jump_buffered := 0.0

func _ready() -> void:
	add_to_group(&"player")
	health.changed.connect(func(c, m): EventBus.player_health_changed.emit(c, m))
	health.died.connect(_on_death)
	age.changed.connect(func(a, d): EventBus.player_age_changed.emit(a, d))
	age.died.connect(_on_death)
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


func _on_death() -> void:
	powers.cancel()
	EventBus.player_died.emit()
