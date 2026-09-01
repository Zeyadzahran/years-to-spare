extends PlayerState
## Held crouch. The clip does not loop, so it plays down and rests on its last
## frame for as long as the button is held.

func physics_update(delta: float) -> StringName:
	player.apply_gravity(delta)
	player.velocity.x = move_toward(player.velocity.x, 0.0, Player.GROUND_FRICTION * delta)
	player.move_and_slide()

	if not player.is_on_floor():
		return &"Air"
	if Input.is_action_just_pressed(&"attack"):
		return &"Attack"
	if not Input.is_action_pressed(&"crouch"):
		return &"Move" if not is_zero_approx(player.input_dir) else &"Idle"
	return &""
