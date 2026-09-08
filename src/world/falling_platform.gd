@tool
class_name FallingPlatform
extends AnimatableBody2D
## A warning-sag deck. Its delay, fall, absence and return all obey world time.

enum State { READY, WARNING, FALLING, HIDDEN }

@export var size := Vector2(180.0, 28.0): set = _set_size
@export var tint := Color.WHITE: set = _set_tint
@export var delay := 0.7
@export var fall_speed := 760.0
@export var fall_distance := 620.0
@export var respawn_after := 2.4

var _origin := Vector2.ZERO
var _state := State.READY
var _elapsed := 0.0


func _ready() -> void:
	_origin = position
	_apply()
	var rider_zone := $RiderZone as Area2D
	rider_zone.body_entered.connect(_on_rider_entered)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var scaled := TimeService.world_delta(delta)
	if is_zero_approx(scaled):
		return
	match _state:
		State.WARNING:
			_elapsed += scaled
			($Art as Sprite2D).modulate = tint.lerp(Color(1.0, 0.42, 0.22), 0.35 + sin(_elapsed * 24.0) * 0.2)
			position.y = _origin.y + sin(_elapsed * 32.0) * 3.0
			if _elapsed >= delay:
				_state = State.FALLING
				_elapsed = 0.0
		State.FALLING:
			position.y += fall_speed * scaled
			if position.y >= _origin.y + fall_distance:
				_hide_deck()
		State.HIDDEN:
			_elapsed += scaled
			if _elapsed >= respawn_after and not _player_blocks_respawn():
				_respawn()


func _on_rider_entered(body: Node2D) -> void:
	if _state == State.READY and body.is_in_group(&"player") and body.is_on_floor():
		_state = State.WARNING
		_elapsed = 0.0


func _hide_deck() -> void:
	_state = State.HIDDEN
	_elapsed = 0.0
	visible = false
	($Shape as CollisionShape2D).set_deferred(&"disabled", true)
	($RiderZone/Shape as CollisionShape2D).set_deferred(&"disabled", true)


func _respawn() -> void:
	position = _origin
	_state = State.READY
	_elapsed = 0.0
	visible = true
	($Art as Sprite2D).modulate = tint
	($Shape as CollisionShape2D).set_deferred(&"disabled", false)
	($RiderZone/Shape as CollisionShape2D).set_deferred(&"disabled", false)


func _player_blocks_respawn() -> bool:
	var player := get_tree().get_first_node_in_group(&"player") as Node2D
	return player != null and absf(player.global_position.x - _origin.x) < size.x * 0.6 \
		and absf(player.global_position.y - _origin.y) < 130.0


func _set_size(value: Vector2) -> void:
	size = value
	_apply()


func _set_tint(value: Color) -> void:
	tint = value
	_apply()


func _apply() -> void:
	var art := get_node_or_null(^"Art") as Sprite2D
	var collision := get_node_or_null(^"Shape") as CollisionShape2D
	var sensor := get_node_or_null(^"RiderZone/Shape") as CollisionShape2D
	if art != null:
		var art_size := art.texture.get_size()
		var art_scale := size.x / art_size.x
		art.scale = Vector2.ONE * art_scale
		art.position.y = -size.y * 0.5 + art_size.y * art_scale * 0.5
		art.modulate = tint
	for item in [collision, sensor]:
		if item != null:
			var box := item.shape as RectangleShape2D
			if box != null:
				box.size = Vector2(size.x, 18.0 if item == sensor else size.y)
	if sensor != null:
		sensor.position.y = -size.y * 0.5 - 10.0
