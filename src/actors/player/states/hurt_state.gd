extends PlayerState
## Recoil from a hit: knocked away from whatever struck him, input ignored
## until the stagger finishes.

## Matches the hurt clip: 9 frames at 20 fps.
const STUN := 0.45
const KNOCKBACK := 240.0

var _elapsed := 0.0

func enter(_previous: StringName) -> void:
	_elapsed = 0.0
	player.velocity = Vector2(-player.hurt_from * KNOCKBACK, -180.0)


func physics_update(delta: float) -> StringName:
	_elapsed += delta
	player.apply_gravity(delta)
	player.velocity.x = move_toward(player.velocity.x, 0.0, 900.0 * delta)
	player.move_and_slide()

	if _elapsed < STUN:
		return &""
	if not player.is_on_floor():
		return &"Air"
	return &"Move" if not is_zero_approx(player.input_dir) else &"Idle"
