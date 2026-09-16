@tool
class_name MovingIndustrialPlatform
extends AnimatableBody2D
## A Level 2 tile-built platform that rides vertically and carries the player.

@export_range(2, 32, 1) var width_tiles := 3:
	set(value):
		width_tiles = maxi(value, 2)
		_apply()
@export var one_way := true:
	set(value):
		one_way = value
		_apply()
@export var travel := Vector2(0, -140)
@export var speed := 90.0
@export_range(0.0, 1.0) var start_at := 0.0

var _origin := Vector2.ZERO
var _progress := 0.0
var _direction := 1.0

func _ready() -> void:
	_origin = position
	_progress = clampf(start_at, 0.0, 1.0)
	_direction = -1.0 if is_equal_approx(_progress, 1.0) else 1.0
	_update_position()
	_apply()
	if not Engine.is_editor_hint():
		add_to_group(TimeService.REWINDABLE_GROUP)

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var scaled := TimeService.world_delta(delta)
	var length := travel.length()
	if is_zero_approx(scaled) or is_zero_approx(length) or is_zero_approx(speed):
		return
	_progress += _direction * scaled * speed / length
	if _progress >= 1.0:
		_progress = 1.0
		_direction = -1.0
	elif _progress <= 0.0:
		_progress = 0.0
		_direction = 1.0
	_update_position()

func rewind_capture() -> Array:
	return [position, _progress, _direction]

func rewind_apply(saved: Array) -> void:
	position = saved[0]
	_progress = saved[1]
	_direction = saved[2]

func _update_position() -> void:
	position = _origin + travel * _progress

func _apply() -> void:
	if not is_node_ready():
		return
	var width := width_tiles * 64.0
	$Left.position.x = -width * 0.5 + 32.0
	$Right.position.x = width * 0.5 - 32.0
	$Middle.visible = width_tiles > 2
	$Middle.region_rect = Rect2(0, 0, (width_tiles - 2) * 32, 32)
	($Shape.shape as RectangleShape2D).size = Vector2(width, 24)
	$Shape.one_way_collision = one_way
