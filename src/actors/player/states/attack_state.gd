extends PlayerState
## One swing, on the ground or in the air. Drives the clip, blocks other actions
## while it runs, and calls the hit through at HIT_TIME. The blade's lance goes
## out with the clip so the two travel together; only the impact burst waits for
## the hit.

## Matches the attack clip: 8 frames at 16 fps.
const DURATION := 0.5
const HIT_TIME := 0.22

var _elapsed := 0.0
var _hit_done := false

func enter(_previous: StringName) -> void:
	_elapsed = 0.0
	_hit_done = false
	player.consume_attack()
	player.begin_swing()


func physics_update(delta: float) -> StringName:
	_elapsed += delta
	if not _hit_done and _elapsed >= HIT_TIME:
		_hit_done = true
		player.perform_attack_hit()
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
