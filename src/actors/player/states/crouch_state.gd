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
	if Input.is_action_just_pressed(&"attack"):
		return &"Attack"
	# Standing up under an overhang would shove him through it, so stay down.
	if not Input.is_action_pressed(&"crouch") and player.can_stand():
		return &"Move" if not is_zero_approx(player.input_dir) else &"Idle"
	return &""
