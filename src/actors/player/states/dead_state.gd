extends PlayerState
## Terminal. Plays the collapse, then tells the level the run is over - the
## reload waits for the animation instead of cutting it off.

## Matches the dying clip: 9 frames at 14 fps.
const DURATION := 0.64

var _elapsed := 0.0
var _announced := false

func enter(_previous: StringName) -> void:
	_elapsed = 0.0
	_announced = false


func physics_update(delta: float) -> StringName:
	_elapsed += delta
	player.apply_gravity(delta)
	player.velocity.x = move_toward(player.velocity.x, 0.0, Player.GROUND_FRICTION * delta)
	player.move_and_slide()

	if not _announced and _elapsed >= DURATION:
		_announced = true
		EventBus.player_died.emit()
	return &""
