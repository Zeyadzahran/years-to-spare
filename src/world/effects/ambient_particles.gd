class_name AmbientParticles
extends CPUParticles2D
## Sand on the wind. A thin column of grains born just past the upwind edge
## of the view and driven across it, so every grain the boy sees has blown in
## from off-screen - nothing ever appears out of the air beside him. The
## emitter rides the camera; the grains live in world space, so the ones
## already flying stay on their course while the view slides past them.
##
## Built in code like BossVfx, for the same reason: one place to tune, and the
## grain is drawn here rather than shipped as an asset. It obeys the boy's
## powers the way the boss dust does - a stopped world holds every grain in
## the air exactly where it was.

## Where the wind blows, in pixels per second. Negative x is leftward: the
## sand enters from the right edge and crosses to the left, into the boy's
## face as he heads for the boss. Flip the sign to turn the wind round; the
## emitter moves to the other edge on its own.
@export var wind := Vector2(-260.0, 12.0)
## Grains in the air at once across the whole view.
@export var density := 90
## Sun-bright sand at one end of the deal, shadowed grit at the other.
@export var tint_light := Color(0.93, 0.85, 0.66)
@export var tint_dark := Color(0.78, 0.64, 0.42)
## How solid a grain is at its brightest.
@export var opacity := 0.55

## Distance past the view edge the column sits, so grains are already moving
## when they cross into view.
const EDGE_MARGIN := 24.0

var _view := Vector2.ZERO

func _ready() -> void:
	local_coords = false
	amount = density
	randomness = 0.6
	emission_shape = EMISSION_SHAPE_RECTANGLE
	direction = wind.normalized()
	# Nearly parallel: sand streams, it does not scatter.
	spread = 6.0
	initial_velocity_min = wind.length() * 0.7
	initial_velocity_max = wind.length() * 1.5
	# A whisper of gravity, so the streams sag rather than run dead level.
	gravity = Vector2(0.0, 4.0)
	scale_amount_min = 0.8
	scale_amount_max = 1.4
	texture = _grain_texture()
	var tint := Gradient.new()
	tint.set_color(0, tint_light)
	tint.set_color(1, tint_dark)
	color_initial_ramp = tint
	# Born off-screen, so the fade-in only has to cover the first few pixels;
	# the fade-out keeps a grain from popping at the end of its run.
	var fade := Gradient.new()
	fade.set_offset(0, 0.0)
	fade.set_color(0, Color(1, 1, 1, 0))
	fade.set_offset(1, 1.0)
	fade.set_color(1, Color(1, 1, 1, 0))
	fade.add_point(0.05, Color(1, 1, 1, opacity))
	fade.add_point(0.85, Color(1, 1, 1, opacity))
	color_ramp = fade
	EventBus.time_mode_changed.connect(_on_time_mode_changed)
	_on_time_mode_changed(TimeService.mode)
	_follow_camera()
	# Start with sand already streaming across; an empty first screen that
	# fills in from one edge reads as the effect switching on, not as weather.
	preprocess = lifetime
	restart()


func _process(_delta: float) -> void:
	_follow_camera()


## Parks the column just past the upwind edge, the full height of the view,
## and gives each grain long enough to cross the whole view at its slowest.
func _follow_camera() -> void:
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return
	var view := get_viewport_rect().size / camera.zoom
	var upwind := -signf(wind.x) if not is_zero_approx(wind.x) else -1.0
	global_position = camera.get_screen_center_position() \
		+ Vector2(upwind * (view.x * 0.5 + EDGE_MARGIN), 0.0)
	if view.is_equal_approx(_view):
		return
	_view = view
	emission_rect_extents = Vector2(EDGE_MARGIN * 0.5, view.y * 0.6)
	lifetime = (view.x + EDGE_MARGIN * 4.0) / initial_velocity_min


func _on_time_mode_changed(_mode: int) -> void:
	speed_scale = TimeService.world_scale


## An 8x3 streak, bright in the middle and soft at both ends - a grain that
## is moving too fast to be a dot.
static func _grain_texture() -> Texture2D:
	var w := 8
	var h := 3
	var image := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var u := (x + 0.5) / w * 2.0 - 1.0
			var v := (y + 0.5) / h * 2.0 - 1.0
			var along := 1.0 - u * u
			var across := 1.0 - absf(v)
			image.set_pixel(x, y, Color(1, 1, 1, clampf(along * across * 1.6, 0.0, 1.0)))
	return ImageTexture.create_from_image(image)
