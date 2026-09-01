extends PlayerState

func physics_update(delta: float) -> StringName:
	player.apply_gravity(delta)
	player.apply_horizontal(delta)
	player.move_and_slide()

	if player.can_jump() or not player.is_on_floor():
		return &"Air"
	if Input.is_action_just_pressed(&"attack"):
		return &"Attack"
	if Input.is_action_pressed(&"crouch"):
		return &"Crouch"
	if is_zero_approx(player.input_dir) and is_zero_approx(player.velocity.x):
		return &"Idle"
	return &""
