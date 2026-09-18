extends PlayerState
## Plays the collapse, then spends a heart. With a heart still left that is
## all it is: the level puts him back at the marker and nothing gets in the
## way. On his last heart, or out of years, the run is over and the Game Over
## screen asks whether to start the level again or leave.

const GAME_OVER := preload("res://src/ui/game_over.gd")

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
		var old_age := player.age.age >= player.age.death_age
		if old_age or GameState.hearts <= 1:
			var screen := GAME_OVER.new()
			screen.player = player
			player.add_child.call_deferred(screen)
		else:
			EventBus.player_died.emit.call_deferred(false)
	return &""
