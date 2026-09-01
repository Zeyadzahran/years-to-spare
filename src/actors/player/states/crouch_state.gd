extends PlayerState
## Held duck. Shrinks the collision box so the boy actually passes under low
## cover - that is the whole point of the state, not the pose.

func enter(_previous: StringName) -> void:
	player.set_crouched(true)


func exit() -> void:
	player.set_crouched(false)


func physics_update(delta: float) -> StringName:
	player.apply_gravity(delta)
	player.velocity.x = move_toward(player.velocity.x, 0.0, Player.GROUND_FRICTION * delta)
	player.move_and_slide()

	if not player.is_on_floor():
		return &"Air"
	# Every exit restores the tall box, so nothing may leave while an overhang
	# would trap it.
	if not player.can_stand():
		return &""
	if player.wants_attack():
		return &"Attack"
	if not Input.is_action_pressed(&"crouch"):
		return &"Move" if not is_zero_approx(player.input_dir) else &"Idle"
	return &""
