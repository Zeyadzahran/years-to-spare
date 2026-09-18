extends PlayerState
## Plays the collapse, then pauses for a choice before spending a heart.

const DEATH_PROMPT := preload("res://src/ui/death_prompt.gd")

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
		var prompt := DEATH_PROMPT.new()
		prompt.player = player
		prompt.rewind_chosen.connect(func() -> void: _announced = false)
		player.add_child.call_deferred(prompt)
	return &""
