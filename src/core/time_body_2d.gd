class_name TimeBody2D
extends CharacterBody2D
## Base for anything that must obey the player's time powers. Subclasses tick on
## `world_delta` and call `move_in_time()` instead of `move_and_slide()`, which
## keeps velocity stored in real units while the world crawls or freezes.

@export var gravity := 1400.0

func world_delta(delta: float) -> float:
	return TimeService.world_delta(delta)


func apply_gravity(scaled_delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * scaled_delta


func move_in_time() -> void:
	var world_scale := TimeService.world_scale
	if is_zero_approx(world_scale):
		return
	velocity *= world_scale
	move_and_slide()
	velocity /= world_scale
