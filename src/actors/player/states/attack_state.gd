extends PlayerState
## One swing, on the ground or in the air. Combat is not designed yet, so this
## drives the animation and blocks other actions while it runs - no hitbox.

## Matches the attack clip: 8 frames at 16 fps.
const DURATION := 0.5

var _elapsed := 0.0

func enter(_previous: StringName) -> void:
	_elapsed = 0.0
	player.consume_attack()


func physics_update(delta: float) -> StringName:
	_elapsed += delta
	player.apply_gravity(delta)
	if player.is_on_floor():
		player.velocity.x = move_toward(player.velocity.x, 0.0, Player.GROUND_FRICTION * delta)
	else:
		# An air swing keeps the arc; stopping him dead mid-jump feels awful.
		player.apply_horizontal(delta)
	player.move_and_slide()

	if _elapsed < DURATION:
		return &""
	if not player.is_on_floor():
		return &"Air"
	return &"Move" if not is_zero_approx(player.input_dir) else &"Idle"
