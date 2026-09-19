class_name BusinessPulse
extends Area2D
## A wave of the Manager's will: three concentric arcs - the shape of a
## signal - sent from his temple across the room. Each has one gap, low or
## high, and the gap is the whole decision: a low one is crouched through, a
## high one jumped through, and a boy who hesitates is hit. He sends them in
## trains, so the reading has to be quick.
##
## Built in code like the shards, and rewindable like a Bullet. A
## stop holds a train in the air - and its gaps are still gaps.

## Where the gap is, and so how it is passed.
enum Gap { LOW, HIGH }

const SPEED := 420.0
const DAMAGE := 15.0
const MAX_LIFETIME := 5.0
## From the floor up to here is what the wave covers.
const HEIGHT := 200.0
## A low gap leaves the floor clear to here: a crouched boy (70) fits, a
## standing one (100) does not.
const LOW_GAP_TOP := 80.0
## A high gap starts here: feet that clear it - a jump peaks at ~190 - pass.
const HIGH_GAP_BOTTOM := 100.0
const FRONT_WIDTH := 24.0
const RADIUS := 130.0
const IMPACT_DURATION := 0.24
const GOLD := Color(1.0, 0.67, 0.19)
const CYAN := Color(0.3, 0.85, 1.0)
const PULSE_SOUND := preload("res://assets/sounds/boss/forceField_002.ogg")
const HIT_SOUND := preload("res://assets/sounds/boss/impactGeneric_light_003.ogg")

var direction := 1.0
var gap := Gap.LOW
var left_bound := -INF
var right_bound := INF
var _age := 0.0
var _spent := false
var _impact_age := 0.0
var _floor_y := 0.0
var _shape: CollisionShape2D
var _pulse_audio: AudioStreamPlayer2D
var _hit_audio: AudioStreamPlayer2D


func _init() -> void:
	collision_layer = 0
	collision_mask = 2
	_shape = CollisionShape2D.new()
	_shape.shape = RectangleShape2D.new()
	add_child(_shape)
	_pulse_audio = _audio(PULSE_SOUND, -2.0, 1.45)
	_hit_audio = _audio(HIT_SOUND, -2.0, 1.0)
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


## Sent from `origin` (his temple) toward `travel_direction`, over the floor
## at `floor_y`, with the gap `where`. Gone once past the room's walls.
func send(origin: Vector2, floor_y: float, travel_direction: float, where: Gap,
		arena_left: float, arena_right: float) -> void:
	global_position = Vector2(origin.x, floor_y)
	_floor_y = floor_y
	direction = signf(travel_direction)
	gap = where
	left_bound = arena_left
	right_bound = arena_right
	scale.x = direction
	# The hit region is the arc's front, less the gap. Local y runs up from
	# the floor, so the shape sits above the origin.
	var rect := _shape.shape as RectangleShape2D
	if gap == Gap.LOW:
		rect.size = Vector2(FRONT_WIDTH, HEIGHT - LOW_GAP_TOP)
		_shape.position = Vector2(0.0, -(LOW_GAP_TOP + HEIGHT) * 0.5)
	else:
		rect.size = Vector2(FRONT_WIDTH, HIGH_GAP_BOTTOM)
		_shape.position = Vector2(0.0, -HIGH_GAP_BOTTOM * 0.5)
	_pulse_audio.play()
	queue_redraw()


func _physics_process(delta: float) -> void:
	if TimeService.is_rewinding():
		return
	var scaled := TimeService.world_delta(delta)
	for audio in [_pulse_audio, _hit_audio]:
		audio.stream_paused = TimeService.is_world_frozen()
	if is_zero_approx(scaled):
		return
	if _spent:
		_impact_age += scaled
		if _impact_age >= IMPACT_DURATION:
			TimeService.retire(self)
		queue_redraw()
		return
	_age += scaled
	global_position.x += direction * SPEED * scaled
	queue_redraw()
	if global_position.x < left_bound - RADIUS or global_position.x > right_bound + RADIUS \
			or _age >= MAX_LIFETIME:
		TimeService.retire(self)


func _on_body_entered(body: Node2D) -> void:
	if _spent or not (body is Player) or TimeService.is_rewinding():
		return
	_spent = true
	_impact_age = 0.0
	set_deferred(&"monitoring", false)
	body.health.take_damage(DAMAGE, self)
	_hit_audio.play()
	queue_redraw()


## The arcs are centred behind the front, so the front is where they are
## tallest - the signal shape, moving. Angles are measured from the direction
## of travel; the gap is a missing stretch of every arc.
func _draw() -> void:
	var centre := Vector2(-RADIUS, -HEIGHT * 0.5)
	if _spent:
		var progress := clampf(_impact_age / IMPACT_DURATION, 0.0, 1.0)
		var fade := 1.0 - progress
		for i in 3:
			draw_arc(centre, RADIUS - i * 22.0 + progress * 30.0, -0.9, 0.9, 32, Color(CYAN, fade * (0.8 - i * 0.2)), 3.0)
		return
	var half := asin(HEIGHT * 0.5 / RADIUS)
	# Which angles the gap removes: y above the centre is negative.
	var gap_from := 0.0
	var gap_to := 0.0
	if gap == Gap.LOW:
		gap_from = asin(clampf((HEIGHT * 0.5 - LOW_GAP_TOP) / RADIUS, -1.0, 1.0))
		gap_to = half
	else:
		gap_from = -half
		gap_to = -asin(clampf((HEIGHT * 0.5 - HIGH_GAP_BOTTOM) / RADIUS, -1.0, 1.0))
	var shimmer := 0.85 + 0.15 * sin(_age * 30.0)
	# A translucent band between the outer and inner arcs first, so the wave
	# reads as one body with a hole in it, not three lines.
	_draw_band(centre, RADIUS + 3.0, RADIUS - 48.0, -half, gap_from, Color(GOLD, 0.2 * shimmer))
	_draw_band(centre, RADIUS + 3.0, RADIUS - 48.0, gap_to, half, Color(GOLD, 0.2 * shimmer))
	for i in 3:
		var radius := RADIUS - i * 22.0
		var strength := 1.0 - i * 0.22
		var width := 5.5 - i * 1.2
		_draw_arc_with_gap(centre, radius, -half, gap_from, Color(GOLD, strength * shimmer), width)
		_draw_arc_with_gap(centre, radius, gap_to, half, Color(GOLD, strength * shimmer), width)
		_draw_arc_with_gap(centre, radius - 2.5, -half, gap_from, Color(CYAN, strength * 0.55), 1.5)
		_draw_arc_with_gap(centre, radius - 2.5, gap_to, half, Color(CYAN, strength * 0.55), 1.5)
	# The gap: its edges burn brightest, and a faint cyan seam runs across it
	# so the hole is framed - that is where to look, and where to go.
	var edge_from := centre + Vector2.from_angle(gap_from) * RADIUS
	var edge_to := centre + Vector2.from_angle(gap_to) * RADIUS
	var steps := 6
	for step in steps:
		var a := edge_from.lerp(edge_to, float(step) / steps)
		var b := edge_from.lerp(edge_to, (float(step) + 0.45) / steps)
		draw_line(a, b, Color(CYAN, 0.35), 1.5)
	for edge in [edge_from, edge_to]:
		draw_circle(edge, 11.0, Color(CYAN, 0.3))
		draw_circle(edge, 6.0, Color(1.0, 0.95, 0.75, 0.95))
	# A faint wake behind, so the wave reads as moving.
	for i in 3:
		var radius := RADIUS - 60.0 - i * 18.0
		if radius > 10.0:
			draw_arc(centre, radius, -half * 0.7, half * 0.7, 24, Color(GOLD, 0.12 - i * 0.03), 2.0)


## A filled ring segment between two radii over one angular span.
func _draw_band(centre: Vector2, outer: float, inner: float, from: float, to: float, colour: Color) -> void:
	if to - from <= 0.02:
		return
	var points := PackedVector2Array()
	var steps := 14
	for step in steps + 1:
		points.append(centre + Vector2.from_angle(lerpf(from, to, float(step) / steps)) * outer)
	for step in steps + 1:
		points.append(centre + Vector2.from_angle(lerpf(to, from, float(step) / steps)) * inner)
	draw_colored_polygon(points, colour)


func _draw_arc_with_gap(centre: Vector2, radius: float, from: float, to: float, colour: Color, width: float) -> void:
	if to - from > 0.02:
		draw_arc(centre, radius, from, to, 24, colour, width, true)


func rewind_capture() -> Array:
	return [global_position, _age, _spent, _impact_age, visible, monitoring]


func rewind_apply(saved: Array) -> void:
	global_position = saved[0]
	_age = saved[1]
	_spent = saved[2]
	_impact_age = saved[3]
	visible = saved[4]
	set_deferred(&"monitoring", saved[5])
	process_mode = Node.PROCESS_MODE_INHERIT
	queue_redraw()


func rewind_retire() -> void:
	visible = false
	set_deferred(&"monitoring", false)
	process_mode = Node.PROCESS_MODE_DISABLED
