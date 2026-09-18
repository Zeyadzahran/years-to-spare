extends PlayerState
## Plays the collapse, then holds him down for a moment in which a rewind can
## still reach him - the one press that undoes a death - before spending a
## heart. With a heart still left that is all it is: the level puts him back
## at the marker and nothing gets in the way. On his last heart, or out of
## years, the run is over and the Game Over screen asks whether to start the
## level again or leave.

const GAME_OVER := preload("res://src/ui/game_over.gd")

## Matches the dying clip: 9 frames at 14 fps.
const DURATION := 0.64
## How long after the collapse a rewind is still his to press. TimePowers
## polls the key on its own and lets Rewind through while he is down; this
## state only has to wait and then commit.
const GRACE := 1.5

var _elapsed := 0.0
var _collapsed := false
var _committed := false

func enter(_previous: StringName) -> void:
	_elapsed = 0.0
	_collapsed = false
	_committed = false


func physics_update(delta: float) -> StringName:
	_elapsed += delta
	player.apply_gravity(delta)
	player.velocity.x = move_toward(player.velocity.x, 0.0, Player.GROUND_FRICTION * delta)
	player.move_and_slide()

	# Held while a rewind is under way: it is about to reach back past this
	# and stand him up, and the level must not reload out from under it.
	if player.powers.is_casting(GameState.ABILITY_REWIND):
		return &""
	if not _collapsed and _elapsed >= DURATION:
		_collapsed = true
		EventBus.player_collapsed.emit(player)
	if not _committed and _elapsed >= DURATION + GRACE:
		_committed = true
		# Deferred: the level's answer travels this machine to Idle, which
		# must not happen from inside this state's own update.
		var old_age := player.age.age >= player.age.death_age
		if old_age or GameState.hearts <= 1:
			var screen := GAME_OVER.new()
			screen.player = player
			player.add_child.call_deferred(screen)
		else:
			EventBus.player_died.emit.call_deferred(false)
	return &""
