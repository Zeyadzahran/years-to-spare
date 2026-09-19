class_name BusinessSurge
extends Area2D
## The Manager's floor wave: a low ridge of lifted ground and ledger pages
## shoved along the floor with his mind. Knee-high on purpose - the whole
## shape says "jump", not "wall" - and it hugs whatever it runs on: off the
## edge of a platform it drops to the floor below and keeps going.
##
## Built entirely here rather than in a scene, the way the Guardian's effects
## are, so the arena stays as authored. Obeys the world clock like a Bullet: a
## stop holds it still, a rewind runs it backward, and a stopped one is still
## solid ground to walk into.

const SPEED := 480.0
const DAMAGE := 20.0
const MAX_LIFETIME := 3.8
const HITBOX := Vector2(60.0, 34.0)
const GRAVITY := 2620.0
## How far below the front the floor may be before the wave counts as falling.
const FLOOR_REACH := 14.0
const IMPACT_DURATION := 0.26
const WORLD_LAYER := 1
const GOLD := Color(1.0, 0.67, 0.19)
const CYAN := Color(0.3, 0.85, 1.0)
const LAUNCH_SOUND := preload("res://assets/sounds/boss/impactSoft_heavy_001.ogg")
const HIT_SOUND := preload("res://assets/sounds/boss/impactGeneric_light_002.ogg")

var direction := 1.0
var left_bound := -INF
var right_bound := INF
var _fall_speed := 0.0
var _age := 0.0
var _pulse := 0.0
var _spent := false
var _impact_age := 0.0
var _origin_x := 0.0
var _launch_audio: AudioStreamPlayer2D
var _hit_audio: AudioStreamPlayer2D
## Cosmetic only: where each page rides the crest and how it bobs.
var _pages: Array[Vector3] = []


func _init() -> void:
	collision_layer = 0
	collision_mask = 2
	var shape := CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	shape.shape.size = HITBOX
	shape.position = Vector2(0.0, -HITBOX.y * 0.5)
	add_child(shape)
	_launch_audio = _audio(LAUNCH_SOUND, -4.0, 0.7)
	_hit_audio = _audio(HIT_SOUND, -2.0, 1.1)
	for i in 5:
		_pages.append(Vector3(-26.0 + i * 13.0, randf_range(0.0, TAU), randf_range(-0.6, 0.6)))
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


## Sent along the floor from `at`, toward `travel_direction`, and gone once it
## is past the room's walls.
func launch(at: Vector2, travel_direction: float, arena_left: float, arena_right: float) -> void:
	global_position = at
	_origin_x = at.x
	direction = signf(travel_direction)
	left_bound = arena_left
	right_bound = arena_right
	scale.x = direction
	_launch_audio.play()
	queue_redraw()


func _physics_process(delta: float) -> void:
	if TimeService.is_rewinding():
		return
	var scaled := TimeService.world_delta(delta)
	for audio in [_launch_audio, _hit_audio]:
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
	_pulse += scaled
	global_position.x += direction * SPEED * scaled
	_follow_floor(scaled)
	queue_redraw()
	if global_position.x < left_bound - 90.0 or global_position.x > right_bound + 90.0 \
			or _age >= MAX_LIFETIME:
		TimeService.retire(self)


## Ground under the front keeps it level; none within reach and it falls
## until there is - a wave sent along a platform lands on the floor below.
func _follow_floor(scaled: float) -> void:
	var query := PhysicsRayQueryParameters2D.create(
		global_position + Vector2(0.0, -24.0),
		global_position + Vector2(0.0, FLOOR_REACH + _fall_speed * scaled),
		WORLD_LAYER)
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		_fall_speed += GRAVITY * scaled
		global_position.y += _fall_speed * scaled
	else:
		_fall_speed = 0.0
		global_position.y = hit.position.y


func _on_body_entered(body: Node2D) -> void:
	if _spent or not (body is Player) or TimeService.is_rewinding():
		return
	_spent = true
	_impact_age = 0.0
	set_deferred(&"monitoring", false)
	body.health.take_damage(DAMAGE, self)
	_hit_audio.play()
	queue_redraw()


func _ridge_height(x: float) -> float:
	var along := clampf((x + 34.0) / 68.0, 0.0, 1.0)
	return sin(along * PI) * (32.0 + sin(_pulse * 17.0 + x * 0.1) * 3.0) * (0.55 + along * 0.45)


func _draw() -> void:
	if _spent:
		var progress := clampf(_impact_age / IMPACT_DURATION, 0.0, 1.0)
		var fade := 1.0 - progress
		draw_arc(Vector2(0.0, -16.0), 8.0 + progress * 34.0, 0.0, TAU, 28, Color(GOLD, fade), 2.5)
		for i in 10:
			var out := Vector2.from_angle(i * TAU / 10.0)
			draw_line(out * (6.0 + progress * 10.0) + Vector2(0, -16.0),
				out * (14.0 + progress * 30.0) + Vector2(0, -16.0), Color(CYAN, fade * 0.8), 2.0)
		return
	var life_fade := clampf(1.0 - _age / MAX_LIFETIME, 0.3, 1.0)
	# The tear it leaves behind: a hairline of gold light along the floor,
	# fading with distance. Local space, so it flips with the wave.
	var travelled := minf(absf(global_position.x - _origin_x), 380.0)
	if travelled > 20.0:
		draw_line(Vector2(-34.0, 2.0), Vector2(-34.0 - travelled, 2.0), Color(GOLD, 0.35 * life_fade), 2.0)
		draw_line(Vector2(-34.0, 0.5), Vector2(-34.0 - travelled * 0.6, 0.5), Color(CYAN, 0.25 * life_fade), 1.0)
	# The light it throws on the floor around it, so it is seen coming.
	draw_set_transform(Vector2(0.0, 2.0), 0.0, Vector2(1.0, 0.3))
	draw_circle(Vector2.ZERO, 58.0, Color(GOLD, 0.16 * life_fade))
	draw_set_transform(Vector2.ZERO)
	# The ridge: dark lifted ground with a gold face and a cyan seam at the lip.
	var crest := PackedVector2Array()
	var body := PackedVector2Array([Vector2(-36.0, 4.0)])
	for step in 12:
		var x := lerpf(-34.0, 34.0, float(step) / 11.0)
		var point := Vector2(x, 2.0 - _ridge_height(x))
		crest.append(point)
		body.append(point)
	body.append(Vector2(36.0, 4.0))
	draw_colored_polygon(body, Color(0.16, 0.12, 0.08, 0.96 * life_fade))
	draw_polyline(crest, Color(GOLD, 0.95 * life_fade), 3.5, true)
	draw_polyline(crest, Color(1.0, 0.92, 0.7, 0.55 * life_fade), 1.4, true)
	draw_line(Vector2(28.0, 3.0), Vector2(36.0, -2.0 - _ridge_height(30.0) * 0.4), Color(CYAN, 0.85 * life_fade), 2.5, true)
	# Ledger pages torn up and riding the crest, each on its own bob.
	for page in _pages:
		var lift := absf(sin(_pulse * 11.0 + page.y)) * 12.0
		var at := Vector2(page.x, -6.0 - lift - _ridge_height(page.x) * 0.7)
		draw_set_transform(at, page.z + sin(_pulse * 6.0 + page.y) * 0.5, Vector2.ONE)
		draw_rect(Rect2(-4.0, -5.5, 8.0, 11.0), Color(0.98, 0.94, 0.82, 0.9 * life_fade))
		draw_line(Vector2(-2.5, -2.5), Vector2(2.5, -2.5), Color(0.35, 0.3, 0.25, 0.8), 1.0)
		draw_line(Vector2(-2.5, 0.5), Vector2(2.5, 0.5), Color(0.35, 0.3, 0.25, 0.8), 1.0)
	draw_set_transform(Vector2.ZERO)


func rewind_capture() -> Array:
	return [global_position, _fall_speed, _age, _pulse, _spent, _impact_age, visible, monitoring]


func rewind_apply(saved: Array) -> void:
	global_position = saved[0]
	_fall_speed = saved[1]
	_age = saved[2]
	_pulse = saved[3]
	_spent = saved[4]
	_impact_age = saved[5]
	visible = saved[6]
	set_deferred(&"monitoring", saved[7])
	process_mode = Node.PROCESS_MODE_INHERIT
	queue_redraw()


func rewind_retire() -> void:
	visible = false
	set_deferred(&"monitoring", false)
	process_mode = Node.PROCESS_MODE_DISABLED
