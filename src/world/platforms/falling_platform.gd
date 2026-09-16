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
	if not Engine.is_editor_hint():
		add_to_group(TimeService.REWINDABLE_GROUP)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var scaled := TimeService.world_delta(delta)
	if is_zero_approx(scaled):
		return
	match _state:
		State.READY:
			_check_grounded_rider()
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
	if TimeService.is_rewinding():
		return
	if _state == State.READY and body.is_in_group(&"player") and body.is_on_floor():
		_state = State.WARNING
		_elapsed = 0.0


## body_entered alone can miss a player who is still airborne at the instant
## they cross into the zone - jumping onto the deck rather than walking onto
## it from level ground. The signal only fires once on entry, so nothing
## rechecks is_on_floor() once they actually land a frame or two later.
## Polling the zone's own overlap list while READY catches that case too,
## anywhere across its width, without changing how an already-grounded
## entry triggers.
func _check_grounded_rider() -> void:
	if TimeService.is_rewinding():
		return
	for body in ($RiderZone as Area2D).get_overlapping_bodies():
		if body.is_in_group(&"player") and body.is_on_floor():
			_state = State.WARNING
			_elapsed = 0.0
			return


## The whole cycle - warning, fall, absence, return - is a position, a state
## and a clock, plus what the state switched off on the way down.
func rewind_capture() -> Array:
	return [
		position, _state, _elapsed, visible, ($Art as Sprite2D).modulate,
		($Shape as CollisionShape2D).disabled, ($RiderZone/Shape as CollisionShape2D).disabled,
	]


func rewind_apply(saved: Array) -> void:
	position = saved[0]
	_state = saved[1]
	_elapsed = saved[2]
	visible = saved[3]
	($Art as Sprite2D).modulate = saved[4]
	($Shape as CollisionShape2D).set_deferred(&"disabled", saved[5])
	($RiderZone/Shape as CollisionShape2D).set_deferred(&"disabled", saved[6])


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
