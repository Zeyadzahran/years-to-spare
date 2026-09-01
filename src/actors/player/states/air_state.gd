extends PlayerState
## Covers both jump and fall; split them when they need different animations.

func enter(_previous: StringName) -> void:
	if player.can_jump():
		player.consume_jump()


func physics_update(delta: float) -> StringName:
	player.apply_gravity(delta)
	player.apply_horizontal(delta)
	player.move_and_slide()

	if player.wants_attack():
		return &"Attack"
	if player.is_on_floor():
		return &"Move" if not is_zero_approx(player.input_dir) else &"Idle"
	return &""
