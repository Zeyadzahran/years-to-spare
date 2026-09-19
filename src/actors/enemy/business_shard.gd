class_name BusinessShard
extends Area2D
## A piece of the floor the Manager lifts with his mind and throws. Three of
## them rise around him, hang there turning while he holds them, then go one
## by one at wherever the boy is standing, on an arc that ends in a crack in
## the floor. Harmless in the air until thrown: the hold is the warning.
##
## Built here in code like the surge, and rewindable the same way: a rewind
## lifts a landed shard back into the air and sets it back in his hold.

enum Stage { RISING, HELD, THROWN, SPENT }

const RISE_TIME := 0.5
const HOVER_HEIGHT := -110.0
const FLIGHT_TIME := 0.7
const GRAVITY := 2620.0
const DAMAGE := 16.0
const SPENT_TIME := 0.3
const RADIUS := 16.0
const GOLD := Color(1.0, 0.67, 0.19)
const CYAN := Color(0.3, 0.85, 1.0)
const THROW_SOUND := preload("res://assets/sounds/boss/shard_throw.ogg")
const LAND_SOUND := preload("res://assets/sounds/boss/impactMining_002.ogg")

var stage := Stage.RISING
var _floor := Vector2.ZERO
var _clock := 0.0
var _velocity := Vector2.ZERO
var _spin := 0.0
var _angle := 0.0
var _throw_audio: AudioStreamPlayer2D
var _land_audio: AudioStreamPlayer2D
## The jagged outline, fixed per shard.
var _outline := PackedVector2Array()


func _init() -> void:
	collision_layer = 0
	collision_mask = 3
	var shape := CollisionShape2D.new()
	shape.shape = CircleShape2D.new()
	shape.shape.radius = RADIUS
	add_child(shape)
	monitoring = false
	_throw_audio = _audio(THROW_SOUND, -4.0, 1.3)
	_land_audio = _audio(LAND_SOUND, -3.0, 0.9)
	for i in 7:
		var angle := i * TAU / 7.0 + randf_range(-0.2, 0.2)
		_outline.append(Vector2.from_angle(angle) * randf_range(11.0, 18.0))
	_spin = randf_range(2.0, 4.0) * (1.0 if randf() < 0.5 else -1.0)
	z_index = 6


func _audio(stream: AudioStream, volume_db: float, pitch: float) -> AudioStreamPlayer2D:
	var player := AudioStreamPlayer2D.new()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch
	player.max_distance = 2400.0
	add_child(player)
	return player


func _ready() -> void:
	add_to_group(TimeService.REWINDABLE_GROUP)
	add_to_group(&"business_hazard")
	body_entered.connect(_on_body_entered)


## Pulled out of the floor at `from`, up to its hover.
func lift(from: Vector2) -> void:
	_floor = from
	global_position = from + Vector2(0.0, 8.0)
	stage = Stage.RISING
	_clock = 0.0
	queue_redraw()


## Let go at `target`, on an arc that gets there in FLIGHT_TIME.
func throw(target: Vector2) -> void:
	if stage in [Stage.THROWN, Stage.SPENT]:
		return
	var to := target - global_position
	_velocity = Vector2(to.x / FLIGHT_TIME, to.y / FLIGHT_TIME - 0.5 * GRAVITY * FLIGHT_TIME)
	stage = Stage.THROWN
	_clock = 0.0
	set_deferred(&"monitoring", true)
	_throw_audio.play()


func is_harmful() -> bool:
	return stage == Stage.THROWN


func _physics_process(delta: float) -> void:
	if TimeService.is_rewinding():
		return
	var scaled := TimeService.world_delta(delta)
	for audio in [_throw_audio, _land_audio]:
		audio.stream_paused = TimeService.is_world_frozen()
	if is_zero_approx(scaled):
		return
	_clock += scaled
	match stage:
		Stage.RISING:
			var progress := clampf(_clock / RISE_TIME, 0.0, 1.0)
			global_position = _floor + Vector2(0.0, lerpf(8.0, HOVER_HEIGHT, smoothstep(0.0, 1.0, progress)))
			_angle += _spin * 0.5 * scaled
			if progress >= 1.0:
				stage = Stage.HELD
		Stage.HELD:
			global_position = _floor + Vector2(sin(_clock * 3.1) * 4.0, HOVER_HEIGHT + sin(_clock * 4.7) * 6.0)
			_angle += _spin * 0.5 * scaled
		Stage.THROWN:
			_velocity.y += GRAVITY * scaled
			global_position += _velocity * scaled
			_angle += _spin * 3.0 * scaled
			if _clock > 3.0:
				_land()
		Stage.SPENT:
			if _clock >= SPENT_TIME:
				TimeService.retire(self)
	queue_redraw()


func _on_body_entered(body: Node2D) -> void:
	if stage != Stage.THROWN or TimeService.is_rewinding():
		return
	if body is Player:
		body.health.take_damage(DAMAGE, self)
	_land()


## Let fall where it is - the hold is over before it was thrown.
func drop() -> void:
	if stage in [Stage.RISING, Stage.HELD]:
		_land()


func _land() -> void:
	stage = Stage.SPENT
	_clock = 0.0
	_velocity = Vector2.ZERO
	set_deferred(&"monitoring", false)
	_land_audio.play()
	queue_redraw()


func _draw() -> void:
	if stage == Stage.SPENT:
		var progress := clampf(_clock / SPENT_TIME, 0.0, 1.0)
		var fade := 1.0 - progress
		# The crack: radial splits in the floor, and the shard's dust going up.
		for i in 7:
			var angle := PI + i * PI / 6.0
			var out := Vector2.from_angle(angle)
			draw_line(out * 4.0, out * (12.0 + progress * 22.0), Color(GOLD, fade * 0.9), 2.0)
		draw_arc(Vector2.ZERO, 6.0 + progress * 20.0, PI, TAU, 16, Color(CYAN, fade * 0.6), 1.5)
		return
	# A thread of his will, drawn from the hold point down to the shard while
	# it is held, so the lift reads as his doing and not the floor's.
	if stage in [Stage.RISING, Stage.HELD]:
		var glow := 0.35 + 0.25 * sin(_clock * 9.0)
		draw_circle(Vector2.ZERO, RADIUS + 6.0, Color(GOLD, glow * 0.25))
	draw_set_transform(Vector2.ZERO, _angle, Vector2.ONE)
	draw_colored_polygon(_outline, Color(0.2, 0.16, 0.1, 0.98))
	var closed := PackedVector2Array(_outline)
	closed.append(_outline[0])
	draw_polyline(closed, GOLD if stage != Stage.THROWN else Color(1.0, 0.8, 0.4), 2.0, true)
	draw_circle(Vector2.ZERO, 3.5, Color(CYAN, 0.9))
	draw_set_transform(Vector2.ZERO)
	if stage == Stage.THROWN:
		# A short tail back along its flight.
		var tail := -_velocity.normalized() * 22.0
		draw_line(Vector2.ZERO, tail, Color(GOLD, 0.6), 3.0)
		draw_line(Vector2.ZERO, tail * 0.6, Color(CYAN, 0.7), 1.5)


func rewind_capture() -> Array:
	return [global_position, stage, _clock, _velocity, _angle, _floor, visible, monitoring]


func rewind_apply(saved: Array) -> void:
	global_position = saved[0]
	stage = saved[1]
	_clock = saved[2]
	_velocity = saved[3]
	_angle = saved[4]
	_floor = saved[5]
	visible = saved[6]
	set_deferred(&"monitoring", saved[7])
	process_mode = Node.PROCESS_MODE_INHERIT
	queue_redraw()


func rewind_retire() -> void:
	visible = false
	set_deferred(&"monitoring", false)
	process_mode = Node.PROCESS_MODE_DISABLED
