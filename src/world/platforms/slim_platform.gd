@tool
class_name SlimPlatform
extends StaticBody2D
## A compact instance of the complete long platform artwork. Its wide source
## aspect keeps the boss-room ledges slim without cutting off their underside.

@export var size := Vector2(220.0, 18.0): set = _set_size

@onready var art: Sprite2D = $Art
@onready var shape: CollisionShape2D = $Shape


func _ready() -> void:
	_apply()


func _set_size(value: Vector2) -> void:
	size = value
	_apply()


func _apply() -> void:
	if not is_node_ready():
		return
	var art_size := art.texture.get_size()
	var art_scale := size.x / art_size.x
	art.scale = Vector2.ONE * art_scale
	art.position.y = art_size.y * art_scale * 0.5
	var box := shape.shape as RectangleShape2D
	box.size = size
	shape.position.y = size.y * 0.5
	shape.one_way_collision = true
	shape.one_way_collision_margin = 16.0
