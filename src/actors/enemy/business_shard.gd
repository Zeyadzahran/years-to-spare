class_name BusinessShard
extends Area2D
## A piece of the floor the Manager tears loose with his mind and throws.
## Three of them rise around him - the floor cracks where each comes out -
## and orbit him on streams of light from his temple while he holds them,
## then go one by one at wherever the boy is standing, on an arc that ends
## in a crack in the floor. Harmless in the air until thrown: the hold is
## the warning.
##
## Built here in code like the pulse, and rewindable the same way: a rewind
## lifts a landed shard back into the air and sets it back in his hold.

enum Stage { RISING, HELD, THROWN, SPENT }

const RISE_TIME := 0.5
const HOVER_HEIGHT := -120.0
const ORBIT_RATE := 0.9
const FLIGHT_TIME := 0.7
const GRAVITY := 2620.0
const DAMAGE := 16.0
const SPENT_TIME := 0.34
const RADIUS := 16.0
## Where the streams come from on him: his temple.
const TEMPLE := Vector2(6.0, -100.0)
const GOLD := Color(1.0, 0.67, 0.19)
const CYAN := Color(0.3, 0.85, 1.0)
const THROW_SOUND := preload("res://assets/sounds/boss/shard_throw.ogg")
const LAND_SOUND := preload("res://assets/sounds/boss/impactMining_002.ogg")

var stage := Stage.RISING
## Whose mind holds it; where the streams start and the orbit centres.
var anchor: Node2D
var _floor := Vector2.ZERO
var _clock := 0.0
var _velocity := Vector2.ZERO
var _spin := 0.0
var _angle := 0.0
var _orbit := 0.0
var _orbit_radius := 100.0
var _throw_audio: AudioStreamPlayer2D
var _land_audio: AudioStreamPlayer2D
var _stream: CPUParticles2D
var _dust: CPUParticles2D
var _trail: CPUParticles2D
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
	_stream = _motes()
	_dust = _dust_burst()
	_trail = _spark_trail()
	z_index = 6


func _audio(stream: AudioStream, volume_db: float, pitch: float) -> AudioStreamPlayer2D:
	var player := AudioStreamPlayer2D.new()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch
	player.max_distance = 2400.0
	add_child(player)
	return player


## Motes of his will, flowing from the temple to the shard: the pull made
## visible. Aimed every frame in _physics_process.
func _motes() -> CPUParticles2D:
	var motes := CPUParticles2D.new()
	motes.emitting = false
	motes.amount = 44
	motes.lifetime = 0.5
	motes.local_coords = true
	motes.spread = 5.0
	motes.gravity = Vector2.ZERO
	motes.scale_amount_min = 2.0
	motes.scale_amount_max = 4.0
	motes.color = Color(0.75, 0.92, 1.0, 0.9)
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.85, 0.5, 0.2))
	ramp.set_color(1, Color(CYAN, 1.0))
	motes.color_ramp = ramp
	motes.z_index = -1
	add_child(motes)
	return motes


## The floor coming apart where it is torn out.
func _dust_burst() -> CPUParticles2D:
	var dust := CPUParticles2D.new()
	dust.emitting = false
	dust.one_shot = true
	dust.explosiveness = 0.9
	dust.amount = 18
	dust.lifetime = 0.7
	dust.local_coords = false
	dust.direction = Vector2.UP
	dust.spread = 55.0
	dust.initial_velocity_min = 120.0
	dust.initial_velocity_max = 260.0
	dust.gravity = Vector2(0.0, 900.0)
	dust.scale_amount_min = 1.5
	dust.scale_amount_max = 3.5
	dust.color = Color(0.55, 0.45, 0.32, 0.9)
	add_child(dust)
	return dust


## Sparks off the back of a thrown shard.
func _spark_trail() -> CPUParticles2D:
	var sparks := CPUParticles2D.new()
	sparks.emitting = false
	sparks.amount = 30
	sparks.lifetime = 0.35
	sparks.local_coords = false
	sparks.spread = 25.0
	sparks.initial_velocity_min = 40.0
	sparks.initial_velocity_max = 120.0
	sparks.gravity = Vector2.ZERO
	sparks.scale_amount_min = 1.0
	sparks.scale_amount_max = 2.5
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.9, 0.6, 1.0))
	ramp.set_color(1, Color(GOLD, 0.0))
	sparks.color_ramp = ramp
	sparks.z_index = -1
	add_child(sparks)
	return sparks


func _ready() -> void:
	add_to_group(TimeService.REWINDABLE_GROUP)
	add_to_group(&"business_hazard")
	body_entered.connect(_on_body_entered)


## Torn out of the floor at `from`, up into `holder`'s orbit.
func lift(from: Vector2, holder: Node2D) -> void:
	anchor = holder
	_floor = from
	global_position = from + Vector2(0.0, 8.0)
	stage = Stage.RISING
	_clock = 0.0
	var offset := from - holder.global_position
	_orbit_radius = maxf(absf(offset.x), 70.0)
	_orbit = 0.0 if offset.x >= 0.0 else PI
	_dust.global_position = from
	_dust.restart()
	_dust.emitting = true
	_stream.emitting = true
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
	_stream.emitting = false
	_trail.emitting = true
	_throw_audio.play()


func is_harmful() -> bool:
	return stage == Stage.THROWN


func _physics_process(delta: float) -> void:
	if TimeService.is_rewinding():
		for particles in [_stream, _dust, _trail]:
			particles.speed_scale = 0.0
		return
	var scaled := TimeService.world_delta(delta)
	for audio in [_throw_audio, _land_audio]:
		audio.stream_paused = TimeService.is_world_frozen()
	for particles in [_stream, _dust, _trail]:
		particles.speed_scale = TimeService.world_scale
	_aim_stream()
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
			# A slow orbit of his head, with a wobble: held, not parked.
			_orbit += ORBIT_RATE * scaled
			_angle += _spin * 0.5 * scaled
			if is_instance_valid(anchor):
				global_position = anchor.global_position + Vector2(cos(_orbit) * _orbit_radius,
					HOVER_HEIGHT + sin(_orbit) * 34.0 + sin(_clock * 4.7) * 6.0)
		Stage.THROWN:
			_velocity.y += GRAVITY * scaled
			global_position += _velocity * scaled
			_angle += _spin * 3.0 * scaled
			_trail.direction = -_velocity.normalized()
			if _clock > 3.0:
				_land()
		Stage.SPENT:
			if _clock >= SPENT_TIME:
				TimeService.retire(self)
	queue_redraw()


## The stream runs from his temple to here, whatever either of them does.
func _aim_stream() -> void:
	if not _stream.emitting or not is_instance_valid(anchor):
		return
	var from := to_local(anchor.global_position + Vector2(anchor.get(&"facing") * TEMPLE.x, TEMPLE.y))
	_stream.position = from
	var to := -from
	var distance := maxf(to.length(), 1.0)
	_stream.direction = to / distance
	_stream.initial_velocity_min = distance / _stream.lifetime * 0.9
	_stream.initial_velocity_max = distance / _stream.lifetime * 1.1


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
	_stream.emitting = false
	_trail.emitting = false
	_dust.global_position = global_position
	_dust.restart()
	_dust.emitting = true
	_land_audio.play()
	if is_instance_valid(anchor) and anchor.has_signal(&"major_impact"):
		anchor.emit_signal(&"major_impact", 3.5)
	queue_redraw()


func _draw() -> void:
	# The hole it left: cracks spreading from the lift point, fading as it
	# rises. Drawn in local space, so it stays put while the shard moves.
	if stage in [Stage.RISING, Stage.HELD]:
		var fade := clampf(1.0 - _clock / 1.4, 0.0, 1.0)
		var hole := to_local(_floor)
		for i in 6:
			var angle := PI + i * PI / 5.0 + 0.2
			var out := Vector2.from_angle(angle)
			draw_line(hole + out * 3.0, hole + out * (10.0 + i * 3.0), Color(0.05, 0.04, 0.03, 0.9 * fade), 2.0)
			draw_line(hole + out * 3.0, hole + out * (8.0 + i * 3.0), Color(GOLD, 0.5 * fade), 1.0)
		draw_set_transform(hole, 0.0, Vector2(1.0, 0.3))
		draw_circle(Vector2.ZERO, 14.0, Color(0.05, 0.04, 0.03, 0.85 * fade))
		draw_set_transform(Vector2.ZERO)
	if stage == Stage.SPENT:
		var progress := clampf(_clock / SPENT_TIME, 0.0, 1.0)
		var fade := 1.0 - progress
		for i in 9:
			var angle := PI + i * PI / 8.0
			var out := Vector2.from_angle(angle)
			draw_line(out * 4.0, out * (14.0 + progress * 30.0), Color(GOLD, fade * 0.9), 2.5)
		draw_arc(Vector2.ZERO, 8.0 + progress * 26.0, PI, TAU, 16, Color(CYAN, fade * 0.7), 2.0)
		return
	if stage in [Stage.RISING, Stage.HELD]:
		var glow := 0.35 + 0.25 * sin(_clock * 9.0)
		draw_circle(Vector2.ZERO, RADIUS + 8.0, Color(GOLD, glow * 0.3))
		draw_circle(Vector2.ZERO, RADIUS + 3.0, Color(CYAN, glow * 0.18))
	draw_set_transform(Vector2.ZERO, _angle, Vector2.ONE)
	draw_colored_polygon(_outline, Color(0.2, 0.16, 0.1, 0.98))
	var closed := PackedVector2Array(_outline)
	closed.append(_outline[0])
	draw_polyline(closed, GOLD if stage != Stage.THROWN else Color(1.0, 0.8, 0.4), 2.0, true)
	draw_circle(Vector2.ZERO, 4.0, Color(CYAN, 0.9))
	draw_set_transform(Vector2.ZERO)
	if stage == Stage.THROWN:
		var tail := -_velocity.normalized() * 26.0
		draw_line(Vector2.ZERO, tail, Color(GOLD, 0.6), 3.0)
		draw_line(Vector2.ZERO, tail * 0.6, Color(CYAN, 0.7), 1.5)


func rewind_capture() -> Array:
	return [global_position, stage, _clock, _velocity, _angle, _orbit, _floor, anchor, visible, monitoring]


func rewind_apply(saved: Array) -> void:
	global_position = saved[0]
	stage = saved[1]
	_clock = saved[2]
	_velocity = saved[3]
	_angle = saved[4]
	_orbit = saved[5]
	_floor = saved[6]
	anchor = saved[7]
	visible = saved[8]
	set_deferred(&"monitoring", saved[9])
	process_mode = Node.PROCESS_MODE_INHERIT
	_stream.emitting = stage in [Stage.RISING, Stage.HELD]
	_trail.emitting = stage == Stage.THROWN
	queue_redraw()


func rewind_retire() -> void:
	visible = false
	set_deferred(&"monitoring", false)
	_stream.emitting = false
	_trail.emitting = false
	process_mode = Node.PROCESS_MODE_DISABLED
