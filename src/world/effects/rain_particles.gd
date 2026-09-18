class_name RainParticles
extends CPUParticles2D
## Rain over the city. A thin band of drops born just above the top edge of the
## view and driven down across it, so every drop the boy sees has fallen in
## from off-screen. The emitter rides the camera; the drops live in world
## space, so the ones already falling stay on their course while the view
## slides past them. The same shape as the desert's sand
## (ambient_particles.gd), turned to fall instead of blow.
##
## Built in code like the sand, for the same reason: one place to tune, and the
## drop is drawn here rather than shipped as an asset. It obeys the boy's
## powers the same way - a stopped world holds every drop in the air.

## Where the rain falls, in pixels per second. A little sideways so the streaks
## lean the way the wind would push them; the emitter widens to cover the drift.
@export var fall := Vector2(-140.0, 900.0)
## Drops in the air at once across the whole view.
@export var density := 160
## Cold grey-blue, so it reads as rain against the night tint as well as the day.
@export var tint := Color(0.72, 0.8, 0.9)
## How solid a drop is at its brightest.
@export var opacity := 0.45

## Distance past the top edge the band sits, so drops are already moving when
## they cross into view.
const EDGE_MARGIN := 32.0

var _view := Vector2.ZERO

func _ready() -> void:
	local_coords = false
	amount = density
	randomness = 0.4
	emission_shape = EMISSION_SHAPE_RECTANGLE
	direction = fall.normalized()
	# Nearly parallel: rain streaks, it does not scatter.
	spread = 3.0
	initial_velocity_min = fall.length() * 0.8
	initial_velocity_max = fall.length() * 1.2
	gravity = Vector2.ZERO
	scale_amount_min = 0.8
	scale_amount_max = 1.3
	# Streaks point the way they fall, whichever way the wind leans them. Set on
	# the drops, not the node: the node's rotation would turn the fall as well.
	angle_min = rad_to_deg(fall.angle() - PI * 0.5)
	angle_max = angle_min
	texture = _drop_texture()
	color = tint
	# Born off-screen, so the fade-in only has to cover the first few pixels;
	# the fade-out keeps a drop from popping at the end of its run.
	var fade := Gradient.new()
	fade.set_offset(0, 0.0)
	fade.set_color(0, Color(1, 1, 1, 0))
	fade.set_offset(1, 1.0)
	fade.set_color(1, Color(1, 1, 1, 0))
	fade.add_point(0.05, Color(1, 1, 1, opacity))
	fade.add_point(0.9, Color(1, 1, 1, opacity))
	color_ramp = fade
	EventBus.time_mode_changed.connect(_on_time_mode_changed)
	_on_time_mode_changed(TimeService.mode)
	_follow_camera()
	# Start with rain already falling across; an empty first screen that fills
	# in from the top reads as the effect switching on, not as weather.
	preprocess = lifetime
	restart()


func _process(_delta: float) -> void:
	_follow_camera()


## Parks the band just above the top edge, wider than the view by however far
## a drop drifts sideways on the way down, and gives each drop long enough to
## cross the whole view at its slowest.
func _follow_camera() -> void:
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return
	var view := get_viewport_rect().size / camera.zoom
	var drift := absf(fall.x) / maxf(fall.y, 1.0) * view.y
	global_position = camera.get_screen_center_position() \
		+ Vector2(signf(fall.x) * drift * -0.5, -(view.y * 0.5 + EDGE_MARGIN))
	if view.is_equal_approx(_view):
		return
	_view = view
	emission_rect_extents = Vector2(view.x * 0.5 + drift * 0.5 + EDGE_MARGIN, EDGE_MARGIN * 0.5)
	lifetime = (view.y + EDGE_MARGIN * 4.0) / initial_velocity_min


func _on_time_mode_changed(_mode: int) -> void:
	speed_scale = TimeService.world_scale


## A 2x14 streak, bright in the middle and soft at both ends - a drop that is
## moving too fast to be a dot.
static func _drop_texture() -> Texture2D:
	var w := 2
	var h := 14
	var image := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var v := (y + 0.5) / h * 2.0 - 1.0
			var along := 1.0 - v * v
			image.set_pixel(x, y, Color(1, 1, 1, clampf(along * 1.4, 0.0, 1.0)))
	return ImageTexture.create_from_image(image)
