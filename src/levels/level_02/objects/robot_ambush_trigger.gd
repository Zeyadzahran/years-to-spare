extends Area2D
## A one-shot reveal for a Robot authored hidden (or visible but inert) in the
## scene. It never moves or animates the Robot itself - only flips the three
## properties that already make Enemy.rewind_retire() a safe "doesn't exist
## yet" state, in reverse. Whatever happens after - falling, standing, seeing
## the boy and attacking - is entirely the existing Enemy/TimeBody2D/Robot
## behavior, untouched.

@export var robot_path: NodePath
## Mirrors pulse_trap.gd's warning_time: a short beat between the boy
## crossing the line and the robot actually coming alive, not an instant cut.
@export var anticipation_time := 0.15

@onready var _robot: CharacterBody2D = get_node_or_null(robot_path)

var _triggered := false
var _elapsed := 0.0
var _armed := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if _triggered or not (body is Player):
		return
	_triggered = true
	_armed = true
	_elapsed = 0.0
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	if not _armed or TimeService.is_rewinding():
		return
	_elapsed += delta
	if _elapsed >= anticipation_time:
		_reveal()


func _reveal() -> void:
	_armed = false
	set_physics_process(false)
	if _robot == null:
		return
	_robot.process_mode = Node.PROCESS_MODE_INHERIT
	_robot.visible = true
	_robot.collision_layer = 4
	var hurt_audio := _robot.get_node_or_null(^"HurtAudio") as AudioStreamPlayer2D
	if hurt_audio != null:
		hurt_audio.play()
