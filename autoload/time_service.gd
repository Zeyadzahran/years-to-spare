extends Node
## Owns the flow of time for everything except the player.
##
## Engine.time_scale is deliberately not used: the player must keep moving at
## full speed while the world is stopped or slowed. Instead the world advances
## on `world_delta()`, and any node that should obey time powers asks for its
## delta here rather than using the raw frame delta.

enum Mode { NORMAL, STOPPED, SLOWED, REWINDING }

const SLOW_SCALE := 0.25

var mode: Mode = Mode.NORMAL:
	set = _set_mode

## Multiplier applied to world time.
var world_scale := 1.0

func world_delta(delta: float) -> float:
	return delta * world_scale


func is_world_frozen() -> bool:
	return is_zero_approx(world_scale)


func reset() -> void:
	_set_mode(Mode.NORMAL)


func _set_mode(value: Mode) -> void:
	if mode == value:
		return
	mode = value
	match mode:
		Mode.NORMAL: world_scale = 1.0
		Mode.SLOWED: world_scale = SLOW_SCALE
		Mode.STOPPED, Mode.REWINDING: world_scale = 0.0
	EventBus.time_mode_changed.emit(mode)
