extends PlayerState
## Plays the collapse, then asks the level to spend a heart and respawn or
## restart. The current life ends only after the animation has finished.

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

	# Held while a rewind is under way: it is about to reach back past this
	# and stand him up, and the level must not reload out from under it.
	if player.powers.is_casting(GameState.ABILITY_REWIND):
		return &""
	if not _announced and _elapsed >= DURATION:
		_announced = true
		# Which of the two clocks ran out decides whether the level gives him
		# the marker back or starts the phase over.
		EventBus.player_died.emit(player.age.age >= player.age.death_age)
	return &""
