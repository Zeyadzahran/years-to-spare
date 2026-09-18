extends Area2D
## A reveal that shares the robot's time history. Rewinding before the ambush
## restores its warning and lets it trigger again; stopping time pauses it.
## The robot remains visible in the editor, but starts hidden at runtime.

@export var robot_path: NodePath
## Mirrors pulse_trap.gd's warning_time: a short beat between the boy
## crossing the line and the robot actually coming alive, not an instant cut.
@export var anticipation_time := 0.15

@onready var _robot: Robot = get_node_or_null(robot_path) as Robot

var _triggered := false
var _elapsed := 0.0
var _armed := false


func _ready() -> void:
	add_to_group(TimeService.REWINDABLE_GROUP)
	if is_instance_valid(_robot):
		_robot.visible = false
		_robot.process_mode = Node.PROCESS_MODE_DISABLED
		_robot.collision_layer = 0


func _physics_process(delta: float) -> void:
	if TimeService.is_rewinding() or not is_instance_valid(_robot):
		return
	# An overlap can start while time is stopped or remain after a rewind.
	# Checking it on forward ticks avoids depending on a second body_entered.
	if not _triggered:
		for body in get_overlapping_bodies():
			if body is Player:
				_triggered = true
				_armed = true
				_elapsed = 0.0
				break
	if not _armed or TimeService.is_world_frozen():
		return
	_elapsed += TimeService.world_delta(delta)
	if _elapsed >= anticipation_time:
		_reveal()


func _reveal() -> void:
	_armed = false
	if not is_instance_valid(_robot):
		return
	_robot.process_mode = Node.PROCESS_MODE_INHERIT
	_robot.visible = true
	_robot.collision_layer = 4
	var hurt_audio := _robot.get_node_or_null(^"HurtAudio") as AudioStreamPlayer2D
	if hurt_audio != null:
		hurt_audio.play()


func rewind_capture() -> Array:
	return [_triggered, _elapsed, _armed]


func rewind_apply(saved: Array) -> void:
	_triggered = saved[0]
	_elapsed = saved[1]
	_armed = saved[2]
	process_mode = Node.PROCESS_MODE_INHERIT


func rewind_retire() -> void:
	process_mode = Node.PROCESS_MODE_DISABLED
