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
const GRACE := 1.0

var _elapsed := 0.0
var _collapsed := false
var _committed := false
## A death in the air - a fall into the void - holds the camera where it was:
## he keeps falling and drops out of the bottom of the frame, rather than the
## view following him down to a body lying on nothing. The camera's own floor
## is kept and put back, since the boss rooms set one of their own.
var _camera_held := false
var _camera_floor := 0

func enter(_previous: StringName) -> void:
	_elapsed = 0.0
	_collapsed = false
	_committed = false
	if not player.is_on_floor():
		_hold_camera()


func exit() -> void:
	_release_camera()


func _hold_camera() -> void:
	var camera := player.get_node_or_null(^"Camera2D") as Camera2D
	if camera == null:
		return
	var viewport := camera.get_viewport()
	var bottom := (viewport.get_canvas_transform().affine_inverse() * viewport.get_visible_rect().size).y
	_camera_floor = camera.limit_bottom
	camera.limit_bottom = mini(_camera_floor, roundi(bottom))
	_camera_held = true


func _release_camera() -> void:
	if not _camera_held:
		return
	_camera_held = false
	var camera := player.get_node_or_null(^"Camera2D") as Camera2D
	if camera != null:
		camera.limit_bottom = _camera_floor


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
	# Out of years there is no window: nothing is left to rewind with.
	var old_age := player.age.age >= player.age.death_age
	var due := DURATION if old_age else DURATION + GRACE
	if not _committed and _elapsed >= due:
		_committed = true
		# Deferred: the level's answer travels this machine to Idle, which
		# must not happen from inside this state's own update.
		if old_age or GameState.hearts <= 1:
			var screen := GAME_OVER.new()
			screen.player = player
			player.add_child.call_deferred(screen)
		else:
			EventBus.player_died.emit.call_deferred(false)
	return &""
