@tool
class_name BlinkPlatform
extends AnimatableBody2D
## A deck that phases in and out. Stopping time preserves its current state,
## turning the power into a timing advantage rather than a mandatory key.

@export var size := Vector2(190.0, 28.0): set = _set_size
@export var tint := Color(0.72, 0.95, 1.0): set = _set_tint
@export var visible_time := 1.15
@export var hidden_time := 0.75
@export_range(0.0, 1.0) var phase_offset := 0.0
@export var starts_visible := true
@export var warning_time := 0.28

var _active := true
var _elapsed := 0.0


func _ready() -> void:
	_active = starts_visible
	_elapsed = (visible_time if _active else hidden_time) * phase_offset
	_apply()
	_set_active(_active)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var scaled := TimeService.world_delta(delta)
	if is_zero_approx(scaled):
		return
	_elapsed += scaled
	var duration := visible_time if _active else hidden_time
	if _elapsed >= duration:
		_elapsed = 0.0
		_set_active(not _active)
	elif _active:
		var art := $Art as Sprite2D
		var warning := clampf((visible_time - _elapsed) / maxf(warning_time, 0.01), 0.0, 1.0)
		art.modulate = tint if warning >= 1.0 else tint.lerp(Color(1.3, 0.45, 0.25, 0.35), 1.0 - warning)


func is_active() -> bool:
	return _active


func _set_active(value: bool) -> void:
	_active = value
	var art := get_node_or_null(^"Art") as Sprite2D
	var collision := get_node_or_null(^"Shape") as CollisionShape2D
	if art != null:
		art.visible = value
		art.modulate = tint
	if collision != null:
		collision.set_deferred(&"disabled", not value)


func _set_size(value: Vector2) -> void:
	size = value
	_apply()


func _set_tint(value: Color) -> void:
	tint = value
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
		collision.one_way_collision = true
		collision.one_way_collision_margin = 16.0
