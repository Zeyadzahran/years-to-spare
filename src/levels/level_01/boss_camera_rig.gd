class_name BossCameraRig
extends Node
## The camera work for the boss fight, hung under the boy's own Camera2D when
## the arena starts so the player scene does not need a camera script it has no
## other use for.
##
## Four things layered on top of the ordinary follow, all resolved into the
## camera's `offset`, `rotation` and `zoom` every frame:
##
##   1. trauma - a 0..1 value that every impact adds to and that decays on its
##      own. Shake is trauma squared, sampled from noise rather than random, so
##      a small hit is a tremor and a stomp is a lurch, and neither buzzes;
##   2. kicks - a directional shove that springs back, for the moment of a
##      slam: the picture drops with the foot, then settles;
##   3. zoom punches - a brief push in and ease out, the thing that makes a hit
##      feel like it has mass rather than just noise;
##   4. focus - a slow pull of the frame toward a point, used to look at the
##      guardian while it wakes and for the death.
##
## Runs on the raw frame delta on purpose. The shake is the player's own
## nervous system, not the world's, and should not freeze when time does.

const TRAUMA_DECAY := 1.35
const MAX_OFFSET := Vector2(34.0, 24.0)
const MAX_ROLL := 0.045
const NOISE_SPEED := 34.0
const KICK_STIFFNESS := 210.0
const KICK_DAMPING := 17.0

var _camera: Camera2D
var _noise := FastNoiseLite.new()
var _time := 0.0
var _trauma := 0.0
var _kick := Vector2.ZERO
var _kick_velocity := Vector2.ZERO
var _rest_zoom := Vector2.ONE
var _zoom_punch := 0.0
var _zoom_punch_left := 0.0
var _zoom_punch_span := 1.0
var _focus := Vector2.ZERO
var _focus_target := Vector2.ZERO
var _focus_speed := 3.0
var _rest_offset := Vector2.ZERO
var _rest_rotation := 0.0
var _was_ignoring_rotation := true


static func attach(camera: Camera2D) -> BossCameraRig:
	if camera == null:
		return null
	var existing := camera.get_node_or_null(^"BossCameraRig") as BossCameraRig
	if existing != null:
		return existing
	var rig := BossCameraRig.new()
	rig.name = &"BossCameraRig"
	camera.add_child(rig)
	return rig


static func find(tree: SceneTree) -> BossCameraRig:
	return tree.get_first_node_in_group(&"boss_camera_rig") as BossCameraRig


func _ready() -> void:
	add_to_group(&"boss_camera_rig")
	# The camera keeps processing while the boy is frozen for the outro walk;
	# the shake has to as well or the last stomp's tremor stalls mid-frame.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_camera = get_parent() as Camera2D
	_rest_offset = _camera.offset
	_rest_rotation = _camera.rotation
	_rest_zoom = _camera.zoom
	_was_ignoring_rotation = _camera.ignore_rotation
	# Camera2D discards its own rotation unless told otherwise; the roll is
	# most of what separates a shake from a jitter.
	_camera.ignore_rotation = false
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = 1.0
	_noise.seed = 1408


func _exit_tree() -> void:
	if _camera == null or not is_instance_valid(_camera):
		return
	_camera.offset = _rest_offset
	_camera.rotation = _rest_rotation
	_camera.zoom = _rest_zoom
	_camera.ignore_rotation = _was_ignoring_rotation


## Add to the shake. Amounts are on the 0..1 scale; they stack but cap at one,
## so a barrage of small stones cannot out-shake a stomp.
func add_trauma(amount: float) -> void:
	_trauma = clampf(_trauma + amount, 0.0, 1.0)


## Trauma from something that happened at a point, scaled by how close the
## camera is to it. A stone landing across the room is a tremor; one landing
## next to the boy is a jolt.
func add_trauma_at(amount: float, at: Vector2, full_within := 180.0, none_beyond := 900.0) -> void:
	if _camera == null:
		return
	var distance := _camera.get_screen_center_position().distance_to(at)
	var falloff := 1.0 - smoothstep(full_within, none_beyond, distance)
	add_trauma(amount * falloff)


## A single shove in `direction` (screen space, pixels) that springs back.
func kick(direction: Vector2) -> void:
	_kick_velocity += direction * KICK_STIFFNESS * 0.42


## Push the picture in by `amount` (0.06 is a stomp) and let it ease back over
## `duration`.
func punch_zoom(amount: float, duration := 0.32) -> void:
	_zoom_punch = maxf(_zoom_punch, amount)
	_zoom_punch_span = maxf(duration, 0.05)
	_zoom_punch_left = _zoom_punch_span


## Pull the frame toward a world point. `weight` is how much of the distance
## to cover, so the boy stays in shot; pass zero weight to let go.
func focus_on(world_point: Vector2, weight := 0.45, speed := 3.0) -> void:
	if _camera == null:
		return
	var from := _camera.get_screen_center_position() - _camera.offset
	_focus_target = (world_point - from) * weight
	_focus_speed = speed


func release_focus(speed := 2.2) -> void:
	_focus_target = Vector2.ZERO
	_focus_speed = speed


## Change what "rest" means, after the arena has re-zoomed the camera.
func rebase() -> void:
	_rest_zoom = _camera.zoom


func _process(delta: float) -> void:
	if _camera == null or not is_instance_valid(_camera):
		return
	_time += delta
	_trauma = maxf(_trauma - TRAUMA_DECAY * delta, 0.0)
	var shake := _trauma * _trauma
	var sample := _time * NOISE_SPEED
	var shake_offset := Vector2(
		_noise.get_noise_2d(sample, 11.0) * MAX_OFFSET.x,
		_noise.get_noise_2d(sample, 57.0) * MAX_OFFSET.y) * shake
	var roll := _noise.get_noise_2d(sample, 101.0) * MAX_ROLL * shake

	# The kick is a critically-damped-ish spring pulled back to zero.
	var spring := -_kick * KICK_STIFFNESS - _kick_velocity * KICK_DAMPING
	_kick_velocity += spring * delta
	_kick += _kick_velocity * delta

	_focus = _focus.lerp(_focus_target, 1.0 - exp(-_focus_speed * delta))

	var punch := 0.0
	if _zoom_punch_left > 0.0:
		_zoom_punch_left = maxf(_zoom_punch_left - delta, 0.0)
		var progress := 1.0 - _zoom_punch_left / _zoom_punch_span
		# In hard, out slow: the push is instant, the settle is what you see.
		punch = _zoom_punch * (1.0 - ease(progress, 0.35))
		if _zoom_punch_left <= 0.0:
			_zoom_punch = 0.0

	# Shake in screen pixels, so it looks the same at every zoom.
	var screen_to_world := 1.0 / maxf(_camera.zoom.x, 0.01)
	_camera.offset = _rest_offset + (shake_offset + _kick) * screen_to_world + _focus
	_camera.rotation = _rest_rotation + roll
	_camera.zoom = _rest_zoom * (1.0 + punch)
