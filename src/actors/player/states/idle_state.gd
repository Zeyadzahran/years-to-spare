extends PlayerState

func physics_update(delta: float) -> StringName:
	player.apply_gravity(delta)
	player.apply_horizontal(delta)
	player.move_and_slide()

	if player.can_jump():
		return &"Air"
	if not player.is_on_floor():
		return &"Air"
	if not is_zero_approx(player.input_dir):
		return &"Move"
	return &""
