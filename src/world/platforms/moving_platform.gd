@tool
class_name MovingPlatform
extends AnimatableBody2D
## A physical deck that follows a line or an orbit on the world's clock.

enum MotionMode { LINEAR, ORBIT }

@export var size := Vector2(200.0, 28.0): set = _set_size
@export var tint := Color.WHITE: set = _set_tint
@export var one_way := false: set = _set_one_way
@export var motion_mode: MotionMode = MotionMode.LINEAR
@export var travel := Vector2(300.0, 0.0)
@export var speed := 500.0
@export_range(0.0, 1.0) var start_at := 0.0
@export_group("Orbit")
@export var orbit_radii := Vector2(260.0, 130.0)
@export var orbit_speed_degrees := 55.0
@export var clockwise := true

var _origin := Vector2.ZERO
var _progress := 0.0
var _direction := 1.0
var _angle := 0.0


func _ready() -> void:
	_origin = position
	_progress = clampf(start_at, 0.0, 1.0)
	_direction = -1.0 if is_equal_approx(_progress, 1.0) else 1.0
	_angle = _progress * TAU
	_update_position()
	_apply()


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var scaled := TimeService.world_delta(delta)
	if is_zero_approx(scaled):
		return
	if motion_mode == MotionMode.ORBIT:
		var turn := deg_to_rad(orbit_speed_degrees) * scaled
		_angle += -turn if clockwise else turn
	else:
		var length := travel.length()
		if is_zero_approx(length) or is_zero_approx(speed):
			return
		_progress += _direction * scaled * speed / length
		if _progress >= 1.0:
			_progress = 1.0
			_direction = -1.0
		elif _progress <= 0.0:
			_progress = 0.0
			_direction = 1.0
	_update_position()


func _update_position() -> void:
	if motion_mode == MotionMode.ORBIT:
		position = _origin + Vector2(cos(_angle) * orbit_radii.x,
			sin(_angle) * orbit_radii.y)
	else:
		position = _origin + travel * _progress


func _set_size(value: Vector2) -> void:
	size = value
	_apply()


func _set_tint(value: Color) -> void:
	tint = value
	_apply()


func _set_one_way(value: bool) -> void:
	one_way = value
	_apply()


func _apply() -> void:
	var art := get_node_or_null(^"Art") as Sprite2D
	var collision := get_node_or_null(^"Shape") as CollisionShape2D
	if art != null:
		var art_size := art.texture.get_size()
		var art_scale := size.x / art_size.x
		art.scale = Vector2.ONE * art_scale
		art.position.y = -size.y * 0.5 + art_size.y * art_scale * 0.5
		art.modulate = tint
	if collision != null:
		var box := collision.shape as RectangleShape2D
		if box != null:
			box.size = size
		collision.one_way_collision = one_way
		collision.one_way_collision_margin = 16.0
