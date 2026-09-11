class_name BossShockwave
extends Area2D
## A short ground-hugging stomp wave. It stays low enough to jump over and
## obeys TimeService, making the player's time power useful against it.
##
## Drawn as the floor itself being shoved along: a low ridge in the floor's
## colours with real chunks off the rock sheet tumbling on its crest, a dust
## wake behind it, and a line of cracked ground it leaves in its path. The
## silhouette stays compact - the whole thing says "jump", not "wall".

const MAX_LIFETIME := 3.8
const CHUNK_REGIONS := [Rect2(58, 104, 27, 23), Rect2(131, 84, 41, 42), Rect2(58, 354, 35, 30)]

@onready var shape: CollisionShape2D = $Shape

var direction := 1.0
var speed := 680.0
var damage := 22.0
var left_bound := 0.0
var right_bound := 0.0
var _age := 0.0
var _pulse := 0.0
var _spent := false
var _frozen := false
var _origin_x := 0.0
var _chunks: Array[Sprite2D] = []
var _wake: CPUParticles2D
var _spray: CPUParticles2D


func _ready() -> void:
	add_to_group(&"boss_hazard")
	body_entered.connect(_on_body_entered)


func configure(at: Vector2, travel_direction: float, travel_speed: float,
		arena_left: float, arena_right: float) -> void:
	global_position = at
	_origin_x = at.x
	direction = signf(travel_direction)
	speed = travel_speed
	left_bound = arena_left
	right_bound = arena_right
	scale.x = direction
	_build_chunks()
	# The wake is left in world space behind the front; the spray is thrown
	# forward off the crest and falls back onto the floor ahead.
	_wake = BossVfx.trail(self, 30, -1)
	_wake.position = Vector2(-18.0, 2.0)
	_wake.emission_sphere_radius = 16.0
	_wake.scale_amount_min = 0.6
	_wake.scale_amount_max = 1.2
	_wake.lifetime = 0.8
	_spray = BossVfx.tremor(self, global_position + Vector2(direction * 14.0, -4.0), 10.0, 1)
	_spray.direction = Vector2(1, -1)
	_spray.spread = 30.0
	_spray.initial_velocity_min = 120.0
	_spray.initial_velocity_max = 300.0
	_spray.gravity = Vector2(0, 1900.0)
	_spray.amount = 14
	_spray.lifetime = 0.5
	queue_redraw()


func stop() -> void:
	monitoring = false
	queue_free()


func _physics_process(delta: float) -> void:
	var scaled := TimeService.world_delta(delta)
	BossVfx.tick(_wake, TimeService.world_scale)
	BossVfx.tick(_spray, TimeService.world_scale)
	if is_zero_approx(scaled):
		_frozen = true
		return
	if _frozen:
		_frozen = false
		_hit_whoever_is_inside()
	_age += scaled
	_pulse += scaled
	global_position.x += direction * speed * scaled
	_tumble_chunks(scaled)
	queue_redraw()
	if global_position.x < left_bound - 90.0 or global_position.x > right_bound + 90.0 \
			or _age >= MAX_LIFETIME:
		queue_free()


## As with the stones: a stopped wave is a still ridge of floor, and only
## hurts once it is moving again - including whoever it was stopped on.
func _on_body_entered(body: Node2D) -> void:
	if _spent or not body is Player or TimeService.is_world_frozen():
		return
	_spent = true
	body.health.take_damage(damage, self)
	set_deferred(&"monitoring", false)


func _hit_whoever_is_inside() -> void:
	if _spent or not monitoring:
		return
	for body in get_overlapping_bodies():
		_on_body_entered(body)


func _build_chunks() -> void:
	# Five stones of mixed size along the crest, each with its own bob phase
	# so the top of the wave churns instead of sliding as one piece.
	var slots := [-30.0, -14.0, 2.0, 16.0, 30.0]
	for index in slots.size():
		var chunk := Sprite2D.new()
		chunk.texture = BossVfx.chip_texture(CHUNK_REGIONS[index % CHUNK_REGIONS.size()])
		var size := 0.42 if index % 2 == 1 else 0.62
		chunk.scale = Vector2.ONE * size
		chunk.position = Vector2(slots[index], -8.0)
		chunk.rotation = randf_range(-PI, PI)
		chunk.z_index = 1
		chunk.set_meta(&"phase", randf_range(0.0, TAU))
		chunk.set_meta(&"spin", randf_range(3.0, 7.0) * (-1.0 if index % 2 == 0 else 1.0))
		add_child(chunk)
		_chunks.append(chunk)


func _tumble_chunks(delta: float) -> void:
	var slots := [-30.0, -14.0, 2.0, 16.0, 30.0]
	for index in _chunks.size():
		var chunk := _chunks[index]
		var phase: float = chunk.get_meta(&"phase")
		var lift := absf(sin(_pulse * 11.0 + phase)) * 13.0
		chunk.position = Vector2(slots[index], -8.0 - lift - _ridge_height(slots[index]) * 0.6)
		chunk.rotation += float(chunk.get_meta(&"spin")) * delta


func _ridge_height(x: float) -> float:
	# The ridge is highest just behind the front and falls off behind.
	var along := clampf((x + 44.0) / 88.0, 0.0, 1.0)
	return sin(along * PI) * (24.0 + sin(_pulse * 17.0 + x * 0.1) * 3.0) * (0.6 + along * 0.4)


func _draw() -> void:
	var life_fade := clampf(1.0 - _age / MAX_LIFETIME, 0.25, 1.0)

	# The scar it leaves: a dark split running back to where the wave started,
	# fading with distance. Drawn in local space, so it flips with the wave.
	var travelled := absf(global_position.x - _origin_x)
	var trail_length := minf(travelled, 420.0)
	if trail_length > 20.0:
		var trail := PackedVector2Array()
		var steps := int(trail_length / 18.0)
		for step in steps + 1:
			var x := -44.0 - float(step) * 18.0
			trail.append(Vector2(x, 6.0 + sin(float(step) * 2.3 + _origin_x * 0.01) * 2.0))
		var trail_alpha := 0.55 * life_fade
		draw_polyline(trail, Color(0.14, 0.07, 0.04, trail_alpha), 3.0, true)
		var lit := PackedVector2Array()
		for point in trail:
			lit.append(point + Vector2(0.0, -1.5))
		draw_polyline(lit, Color(0.9, 0.62, 0.36, trail_alpha * 0.5), 1.2, true)

	# The ridge: floor colour on the face, lit along the crest, dark under the
	# lip. Built from the same height curve the chunks ride on.
	var crest := PackedVector2Array()
	var body := PackedVector2Array([Vector2(-46.0, 9.0)])
	for step in 12:
		var x := lerpf(-44.0, 44.0, float(step) / 11.0)
		var point := Vector2(x, 6.0 - _ridge_height(x))
		crest.append(point)
		body.append(point)
	body.append(Vector2(46.0, 9.0))
	draw_colored_polygon(body, Color(0.7, 0.42, 0.21, 0.98 * life_fade))
	var shade := PackedVector2Array(body)
	for index in shade.size():
		shade[index].y = maxf(shade[index].y, -2.0)
	draw_colored_polygon(shade, Color(0.24, 0.12, 0.07, 0.92 * life_fade))
	draw_polyline(crest, Color(0.98, 0.72, 0.4, 0.95 * life_fade), 4.0, true)
	draw_polyline(crest, Color(1.0, 0.9, 0.65, 0.6 * life_fade), 1.6, true)
	# A hot seam along the front lip where the floor is tearing.
	draw_line(Vector2(38.0, 8.0), Vector2(46.0, -2.0 - _ridge_height(40.0) * 0.4),
		Color(1.0, 0.55, 0.18, 0.8 * life_fade), 2.5, true)
