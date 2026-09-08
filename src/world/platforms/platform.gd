@tool
class_name Platform
extends StaticBody2D
## A reusable deck using the purpose-built platform sprite sheet.

@export var size := Vector2(160.0, 24.0): set = _set_size
@export var tint := Color.WHITE: set = _set_tint
@export var one_way := true: set = _set_one_way

@onready var art: Sprite2D = $Art
@onready var shape: CollisionShape2D = $Shape

func _ready() -> void:
	_apply()


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
	if not is_node_ready():
		return
	# Scale uniformly so the painted rocks, machinery and pixel density are not
	# distorted. Align the art's top edge with the physical walking surface.
	var art_size := art.texture.get_size()
	var art_scale := size.x / art_size.x
	art.scale = Vector2.ONE * art_scale
	art.position.y = -size.y * 0.5 + art_size.y * art_scale * 0.5
	art.modulate = tint
	var box := shape.shape as RectangleShape2D
	if box:
		box.size = size
	shape.one_way_collision = one_way
	shape.one_way_collision_margin = 16.0
