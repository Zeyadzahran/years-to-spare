class_name EmberParticles
extends CPUParticles2D
## Embers over the city after dark: flecks that drift up off the streets and
## rooftops, glow, and go out. Born anywhere in the view rather than blown in
## from an edge - the sparks come from the city itself, not the weather. The
## emitter rides the camera; the embers live in world space.
##
## Drawn additive: the night tint (a CanvasModulate over the whole level)
## multiplies every colour on screen, and an orange spark under it comes out
## as mud. Added on top of the tint instead, and lit past white, it glows.
## Meant to sit in DayNightTransition.night_fade_in, so it fades in with the
## dark and is put away again with the daylight.

## How many embers are in the air at once across the whole view.
@export var density := 40
## How hard the embers rise, in pixels per second.
@export var lift := 40.0
## Lit and going out. Both past white on purpose, see above.
@export var glow := Color(2.4, 1.2, 0.3)
@export var ash := Color(0.9, 0.5, 0.35)
## How bright an ember is at its brightest.
@export var opacity := 0.9

## Distance past the bottom edge the field extends, so an ember can rise into
## view from below the screen as well as start inside it.
const EDGE_MARGIN := 48.0

var _view := Vector2.ZERO

func _ready() -> void:
	local_coords = false
	amount = density
	lifetime = 4.0
	randomness = 0.8
	emission_shape = EMISSION_SHAPE_RECTANGLE
	direction = Vector2.UP
	# Wide, so the rise wanders rather than files straight up.
	spread = 45.0
	initial_velocity_min = lift * 0.4
	initial_velocity_max = lift * 1.2
	# A little more lift than the launch, so a fleck keeps climbing after its
	# push runs out; damping takes the sideways wander off it as it goes.
	gravity = Vector2(0.0, -lift * 0.6)
	damping_min = 4.0
	damping_max = 12.0
	angular_velocity_min = -90.0
	angular_velocity_max = 90.0
	scale_amount_min = 0.7
	scale_amount_max = 1.5
	texture = _ember_texture()
	var material := CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	self.material = material
	# Flares up on its way out of the dark, burns for most of its life, then
	# cools to ash before it fades - the colour and the alpha both carry it.
	var burn := Gradient.new()
	burn.set_offset(0, 0.0)
	burn.set_color(0, Color(glow, 0.0))
	burn.set_offset(1, 1.0)
	burn.set_color(1, Color(ash, 0.0))
	burn.add_point(0.15, Color(glow, opacity))
	burn.add_point(0.6, Color(glow, opacity))
	burn.add_point(0.85, Color(ash, opacity * 0.6))
	color_ramp = burn
	EventBus.time_mode_changed.connect(_on_time_mode_changed)
	_on_time_mode_changed(TimeService.mode)
	_follow_camera()
	preprocess = lifetime
	restart()


func _process(_delta: float) -> void:
	_follow_camera()


## Covers the whole view and a margin below it, from the camera's centre.
func _follow_camera() -> void:
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return
	var view := get_viewport_rect().size / camera.zoom
	global_position = camera.get_screen_center_position() + Vector2(0.0, EDGE_MARGIN * 0.5)
	if view.is_equal_approx(_view):
		return
	_view = view
	emission_rect_extents = Vector2(view.x * 0.5, view.y * 0.5 + EDGE_MARGIN * 0.5)


func _on_time_mode_changed(_mode: int) -> void:
	speed_scale = TimeService.world_scale


## A 5x5 dot, bright at the centre and soft at the rim.
static func _ember_texture() -> Texture2D:
	var size := 5
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var centre := (size - 1) * 0.5
	for y in size:
		for x in size:
			var d := Vector2(x - centre, y - centre).length() / centre
			image.set_pixel(x, y, Color(1, 1, 1, clampf(1.0 - d * d, 0.0, 1.0)))
	return ImageTexture.create_from_image(image)
