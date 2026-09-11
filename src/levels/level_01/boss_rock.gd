class_name BossRock
extends Area2D
## A vertically moving boss hazard using the existing graded stone sprites.
## Each instance owns a ground warning, movement weight and impact strength.
##
## The warning is the whole game here, so it is drawn as a thing in the room
## rather than a marker on it. A falling stone throws a shadow on the floor
## that tightens and darkens as it comes down, ringed by a target that locks
## with a snap once the marker stops following the boy. A stone coming up
## through the floor bulges it first: the ground rises, cracks spread, and
## pebbles jump, with torchlight leaking out of the split before it bursts.

enum RockSize { SMALL, MEDIUM, LARGE }
enum MotionKind { FALL, ERUPT }

const IMPACT_SCENE := preload("res://src/levels/level_01/boss_impact_effect.tscn")
const MAX_LIFETIME := 4.2
const DROP_HEIGHT := 820.0
const LIGHT_IMPACTS: Array[AudioStream] = [
	preload("res://assets/sounds/boss/impactGeneric_light_000.ogg"),
	preload("res://assets/sounds/boss/impactGeneric_light_001.ogg"),
	preload("res://assets/sounds/boss/impactGeneric_light_002.ogg"),
	preload("res://assets/sounds/boss/impactGeneric_light_003.ogg"),
	preload("res://assets/sounds/boss/impactGeneric_light_004.ogg"),
]
const HEAVY_IMPACTS: Array[AudioStream] = [
	preload("res://assets/sounds/boss/impactMining_000.ogg"),
	preload("res://assets/sounds/boss/impactMining_001.ogg"),
	preload("res://assets/sounds/boss/impactMining_002.ogg"),
	preload("res://assets/sounds/boss/impactMining_003.ogg"),
	preload("res://assets/sounds/boss/impactMining_004.ogg"),
]
const SMALL_REGIONS := [
	Rect2(58, 104, 27, 23),
	Rect2(131, 84, 41, 42),
	Rect2(215, 79, 48, 47),
	Rect2(303, 75, 62, 51),
]
const MEDIUM_REGIONS := [
	Rect2(410, 69, 61, 61),
	Rect2(509, 61, 90, 74),
	Rect2(628, 50, 79, 90),
]
const LARGE_REGIONS := [
	Rect2(736, 45, 111, 95),
	Rect2(873, 35, 132, 106),
	Rect2(1032, 36, 158, 101),
]

const TRACKING := Color(1.0, 0.42, 0.08)
const LOCKED := Color(1.0, 0.78, 0.3)

@onready var sprite: Sprite2D = $Sprite
@onready var shape: CollisionShape2D = $Shape

var size_kind := RockSize.MEDIUM
var motion_kind := MotionKind.FALL
var landing_position := Vector2.ZERO
var warning_active := true
var damage := 18.0

var _velocity := Vector2.ZERO
var _gravity := Vector2.ZERO
var _launch_delay := 0.0
var _delay_left := 0.0
var _launch_called := false
var _launched := false
var _lifetime := 0.0
var _pulse := 0.0
var _rotation_speed := 5.0
var _collision_radius := 22.0
var _tracked_target: Player
var _tracking_left := 0.0
var _prediction_horizon := 0.0
var _target_offset_x := 0.0
var _tracking_left_bound := -INF
var _tracking_right_bound := INF
var _warning_locked := true
var _lock_flash := 0.0
var _frozen := false
var _cracks: Array[PackedVector2Array] = []
var _trickle: CPUParticles2D
var _tremor: CPUParticles2D
var _wake: CPUParticles2D


func _ready() -> void:
	add_to_group(&"boss_hazard")
	body_entered.connect(_on_body_entered)
	shape.shape = shape.shape.duplicate()
	monitoring = false


func configure(ground_position: Vector2, rock_size: int, movement: int,
		launch_delay := 0.0, variant := 0) -> void:
	size_kind = rock_size
	motion_kind = movement
	landing_position = ground_position
	_launch_delay = launch_delay
	_delay_left = launch_delay
	_apply_stone_variant(variant)
	if motion_kind == MotionKind.FALL:
		global_position = Vector2(landing_position.x, landing_position.y - DROP_HEIGHT)
		sprite.show()
		_trickle = _build_trickle()
	else:
		global_position = landing_position + Vector2(0.0, _collision_radius * 0.7)
		sprite.hide()
		_build_cracks()
		_tremor = BossVfx.tremor(self, landing_position, _collision_radius + 10.0, -1)
	queue_redraw()


func launch() -> void:
	_lock_warning()
	_launch_called = true
	if _launch_delay <= 0.0:
		_begin_motion()


func stop() -> void:
	monitoring = false
	queue_free()


func is_vertical_plan() -> bool:
	return is_zero_approx(_velocity.x)


func configure_tracking(tracked_player: Player, target_offset_x: float,
		left_bound: float, right_bound: float, tracking_duration: float,
		prediction_horizon: float) -> void:
	_tracked_target = tracked_player
	_target_offset_x = target_offset_x
	_tracking_left_bound = left_bound
	_tracking_right_bound = right_bound
	_tracking_left = maxf(tracking_duration, 0.0)
	_prediction_horizon = maxf(prediction_horizon, 0.0)
	_warning_locked = is_zero_approx(_tracking_left)
	_update_tracked_landing()


func warning_is_locked() -> bool:
	return _warning_locked


func _physics_process(delta: float) -> void:
	var scaled := TimeService.world_delta(delta)
	for particles in [_trickle, _tremor, _wake]:
		BossVfx.tick(particles, TimeService.world_scale)
	if is_zero_approx(scaled):
		_frozen = true
		return
	if _frozen:
		_frozen = false
		_hit_whoever_is_inside()
	_pulse += scaled
	if not _launched:
		if warning_active and not _warning_locked:
			_tracking_left -= scaled
			_update_tracked_landing()
			if _tracking_left <= 0.0:
				_lock_warning()
	if _lock_flash > 0.0:
		_lock_flash = maxf(_lock_flash - scaled * 5.5, 0.0)
	if not _launched:
		queue_redraw()
		if _launch_called and _launch_delay > 0.0:
			_delay_left -= scaled
			if _delay_left <= 0.0:
				_begin_motion()
		return

	_velocity += _gravity * scaled
	global_position += _velocity * scaled
	sprite.rotation += _rotation_speed * scaled
	_lifetime += scaled
	queue_redraw()
	var landing_center_y := landing_position.y - _collision_radius
	if _velocity.y > 0.0 and global_position.y >= landing_center_y:
		_impact_ground()
	elif _lifetime >= MAX_LIFETIME:
		queue_free()


func _begin_motion() -> void:
	_lock_warning()
	_launched = true
	warning_active = false
	monitoring = true
	sprite.show()
	_stop_emitting(_trickle)
	_stop_emitting(_tremor)
	_wake = BossVfx.trail(self, 22 if size_kind == RockSize.SMALL else 34, -1)
	_wake.position = Vector2.ZERO
	_wake.emission_sphere_radius = _collision_radius * 0.6
	if motion_kind == MotionKind.FALL:
		var fall_speed := 1040.0 if size_kind == RockSize.SMALL else 860.0 if size_kind == RockSize.MEDIUM else 690.0
		_velocity = Vector2(0.0, fall_speed)
		_gravity = Vector2(0.0, 180.0)
	else:
		var rise_speed := 940.0 if size_kind == RockSize.SMALL else 840.0 if size_kind == RockSize.MEDIUM else 750.0
		_velocity = Vector2(0.0, -rise_speed)
		_gravity = Vector2(0.0, 1680.0)
		# The floor bursts open on the way out, the same event as a landing
		# but smaller, and it takes the camera tremor with it.
		var parent := get_parent()
		if parent != null:
			var burst := IMPACT_SCENE.instantiate() as BossImpactEffect
			parent.add_child(burst)
			burst.configure(landing_position,
				0.5 if size_kind == RockSize.SMALL else 0.7 if size_kind == RockSize.MEDIUM else 0.95)
		_play_detached(LIGHT_IMPACTS, -7.0, 0.82)
	queue_redraw()


func _update_tracked_landing() -> void:
	if _tracked_target == null or not is_instance_valid(_tracked_target):
		_lock_warning()
		return
	var predicted_x := _tracked_target.global_position.x
	predicted_x += _tracked_target.velocity.x * _prediction_horizon
	predicted_x += _target_offset_x
	landing_position.x = clampf(predicted_x, _tracking_left_bound, _tracking_right_bound)
	global_position.x = landing_position.x
	if _trickle != null and is_instance_valid(_trickle):
		_trickle.global_position.x = landing_position.x
	if _tremor != null and is_instance_valid(_tremor):
		_tremor.global_position.x = landing_position.x
	queue_redraw()


func _lock_warning() -> void:
	if _warning_locked:
		return
	_warning_locked = true
	_tracking_left = 0.0
	_lock_flash = 1.0
	queue_redraw()


func _apply_stone_variant(variant: int) -> void:
	var regions: Array
	var diameter: float
	match size_kind:
		RockSize.SMALL:
			regions = SMALL_REGIONS
			diameter = 34.0
			_collision_radius = 13.0
			damage = 12.0
			_rotation_speed = 8.0
		RockSize.LARGE:
			regions = LARGE_REGIONS
			diameter = 88.0
			_collision_radius = 34.0
			damage = 28.0
			_rotation_speed = 3.0
		_:
			regions = MEDIUM_REGIONS
			diameter = 58.0
			_collision_radius = 22.0
			damage = 18.0
			_rotation_speed = 5.2
	var region: Rect2 = regions[posmod(variant, regions.size())]
	sprite.region_rect = region
	var source_diameter := maxf(region.size.x, region.size.y)
	sprite.scale = Vector2.ONE * (diameter / source_diameter)
	(shape.shape as CircleShape2D).radius = _collision_radius


## Grit shaken loose from the ceiling above where the stone will land - the
## room telling you something is coming down before the rock is in frame.
func _build_trickle() -> CPUParticles2D:
	var trickle := BossVfx.tremor(self,
		Vector2(landing_position.x, landing_position.y - DROP_HEIGHT + 40.0),
		_collision_radius + 6.0, -1)
	trickle.amount = 6
	# Long enough to reach the floor from the ceiling, no longer.
	trickle.lifetime = 1.3
	trickle.direction = Vector2(0, 1)
	trickle.spread = 8.0
	trickle.gravity = Vector2(0, 900.0)
	trickle.initial_velocity_min = 20.0
	trickle.initial_velocity_max = 60.0
	trickle.scale_amount_min = 0.08
	trickle.scale_amount_max = 0.16
	return trickle


func _build_cracks() -> void:
	_cracks.clear()
	var reach := _collision_radius + 26.0
	for index in 5:
		var angle := lerpf(PI * 1.05, PI * 1.95, float(index) / 4.0) + randf_range(-0.12, 0.12)
		var direction := Vector2.from_angle(angle)
		var length := reach * randf_range(0.7, 1.15)
		_cracks.append(PackedVector2Array([
			direction * 4.0,
			direction.rotated(randf_range(-0.2, 0.2)) * length * 0.45,
			direction.rotated(randf_range(-0.12, 0.12)) * length * 0.75,
			direction * length,
		]))


func _impact_ground() -> void:
	monitoring = false
	var effect := IMPACT_SCENE.instantiate() as BossImpactEffect
	get_parent().add_child(effect)
	var impact_strength := 0.55 if size_kind == RockSize.SMALL else 0.78 if size_kind == RockSize.MEDIUM else 1.1
	effect.configure(landing_position, impact_strength, size_kind == RockSize.LARGE)
	_play_impact_sound()
	if size_kind == RockSize.LARGE:
		var fx := BossScreenFx.find(get_tree())
		if fx != null:
			fx.shockwave(landing_position, 0.45)
	_release_wake()
	queue_free()


## Same call as the saw: the danger is the motion, so a stone hanging in a
## stopped world is just a stone, and the boy can walk through the gap it
## has left him to reach the titan. The moment time runs again it is a
## falling rock, and anyone still standing in it is hit.
func _on_body_entered(body: Node2D) -> void:
	if not body is Player or TimeService.is_world_frozen():
		return
	body.health.take_damage(damage, self)
	var effect := IMPACT_SCENE.instantiate() as BossImpactEffect
	get_parent().add_child(effect)
	effect.configure(global_position, 0.45 if size_kind == RockSize.SMALL else 0.7)
	_play_impact_sound()
	_release_wake()
	queue_free()


## The dust wake outlives the stone: hand it to the parent so it can finish
## fading where it is instead of vanishing with the rock.
func _release_wake() -> void:
	if _wake == null or not is_instance_valid(_wake):
		return
	var parent := get_parent()
	if parent == null:
		return
	var at := _wake.global_position
	_wake.reparent(parent, false)
	_wake.global_position = at
	BossVfx.release(_wake)
	_wake = null


func _stop_emitting(particles: CPUParticles2D) -> void:
	if particles != null and is_instance_valid(particles):
		particles.emitting = false


## `body_entered` already fired, and was ignored, for anyone who stepped into
## the stone while it hung; so the overlap is re-read when the clock restarts.
func _hit_whoever_is_inside() -> void:
	if not monitoring:
		return
	for body in get_overlapping_bodies():
		_on_body_entered(body)
		if is_queued_for_deletion():
			return


func _play_impact_sound() -> void:
	if size_kind == RockSize.SMALL:
		_play_detached(LIGHT_IMPACTS, -5.0, randf_range(1.02, 1.16))
	else:
		var volume := -1.5 if size_kind == RockSize.LARGE else -3.5
		var pitch := randf_range(0.72, 0.84) if size_kind == RockSize.LARGE \
			else randf_range(0.9, 1.02)
		_play_detached(HEAVY_IMPACTS, volume, pitch)


func _play_detached(streams: Array[AudioStream], volume_db: float,
		pitch_scale: float) -> void:
	if streams.is_empty() or get_parent() == null:
		return
	var audio := AudioStreamPlayer2D.new()
	get_parent().add_child(audio)
	audio.global_position = landing_position
	audio.stream = streams[randi() % streams.size()]
	audio.volume_db = volume_db
	audio.pitch_scale = pitch_scale
	audio.max_distance = 1800.0
	audio.finished.connect(audio.queue_free)
	audio.play()


func _draw() -> void:
	if warning_active:
		if motion_kind == MotionKind.FALL:
			_draw_fall_warning(to_local(landing_position))
		else:
			_draw_erupt_warning(to_local(landing_position))
	elif _launched and motion_kind == MotionKind.FALL and _velocity.y > 0.0:
		_draw_falling_shadow(to_local(landing_position))


func _warning_color() -> Color:
	var color := LOCKED if _warning_locked else TRACKING
	if _lock_flash > 0.0:
		color = color.lerp(Color.WHITE, _lock_flash)
	return color


## The shadow on the floor: soft-edged, sized to the stone, and shared between
## the warning and the fall so the one turns into the other.
func _draw_shadow(at: Vector2, radius: float, darkness: float) -> void:
	draw_set_transform(at, 0.0, Vector2(1.0, 0.3))
	for step in 3:
		var spread := 1.0 + float(step) * 0.28
		draw_circle(Vector2.ZERO, radius * spread,
			Color(0.05, 0.03, 0.02, darkness * (0.42 - float(step) * 0.12)))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_fall_warning(at: Vector2) -> void:
	var color := _warning_color()
	# Sized for the room's 0.75 zoom: the marker has to read from across the
	# arena, not just when the boy is standing on it.
	var radius := _collision_radius + 26.0
	var breath := 1.0 + sin(_pulse * 9.0) * (0.03 if _warning_locked else 0.07)
	_draw_shadow(at, radius * 0.95, 0.75 if _warning_locked else 0.5)

	draw_set_transform(at, 0.0, Vector2(1.0, 0.3))
	var ring := radius * breath
	# A broken ring that turns while it hunts and stops dead when it locks.
	var spin := _pulse * (0.0 if _warning_locked else 2.4)
	for segment in 4:
		var start := spin + float(segment) * TAU / 4.0
		draw_arc(Vector2.ZERO, ring, start, start + TAU / 4.0 * 0.62, 12,
			color, 8.0 if _warning_locked else 6.0, true)
	# Four ticks outside the ring that close onto it as the lock comes.
	var settle := 1.0 if _warning_locked else clampf(1.0 - _tracking_left / 0.5, 0.0, 1.0)
	var gap := lerpf(30.0, 5.0, settle)
	for tick in 4:
		var direction := Vector2.from_angle(float(tick) * TAU / 4.0 + PI / 4.0)
		draw_line(direction * (ring + gap), direction * (ring + gap + 18.0),
			Color(color, color.a * 0.85), 5.0, true)
	if _warning_locked:
		draw_circle(Vector2.ZERO, 7.0, color)
		draw_line(Vector2(-ring * 0.55, 0.0), Vector2(ring * 0.55, 0.0), color, 3.0, true)
	if _lock_flash > 0.0:
		draw_arc(Vector2.ZERO, ring * (1.0 + (1.0 - _lock_flash) * 0.9), 0.0, TAU, 32,
			Color(1.0, 0.95, 0.85, 0.7 * _lock_flash), 6.0, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_erupt_warning(at: Vector2) -> void:
	var color := _warning_color()
	var swell := clampf(_pulse / 0.8, 0.0, 1.0)
	var reach := _collision_radius + 36.0
	var rise := lerpf(4.0, 20.0, ease(swell, 2.2))
	var width := lerpf(reach * 0.55, reach * 0.95, swell)

	# Torchlight leaking through the split before the floor gives.
	draw_set_transform(at, 0.0, Vector2(1.0, 0.35))
	draw_circle(Vector2.ZERO, reach * 1.15,
		Color(1.0, 0.5, 0.15, 0.1 + 0.18 * swell + 0.2 * _lock_flash))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# The bulge: the floor's own colours pushed up into a low dome, lit on top
	# and dark underneath so it reads as raised.
	var dome := PackedVector2Array()
	for step in 13:
		var ratio := float(step) / 12.0
		var x := lerpf(-width, width, ratio)
		var y := -sin(ratio * PI) * rise + sin(_pulse * 22.0 + ratio * 9.0) * swell * 1.2
		dome.append(at + Vector2(x, y + 2.0))
	draw_colored_polygon(dome, Color(0.55, 0.32, 0.17, 0.95))
	var crest := dome.slice(2, 11)
	draw_polyline(crest, Color(0.9, 0.62, 0.36, 0.9), 2.5, true)
	draw_polyline(PackedVector2Array([dome[0], dome[12]]), Color(0.16, 0.08, 0.05, 0.85), 2.0, true)

	for crack in _cracks:
		var visible := PackedVector2Array()
		var shown := 1 + int(swell * float(crack.size() - 1) + 0.999)
		for index in mini(shown, crack.size()):
			visible.append(at + crack[index] * Vector2(1.0, 0.45))
		if visible.size() < 2:
			continue
		draw_polyline(visible, Color(color, 0.65 + 0.35 * swell), 4.0 if _warning_locked else 3.0, true)
		draw_polyline(visible, Color(0.14, 0.06, 0.03, 0.9), 5.0 if _warning_locked else 4.0, true)
		draw_polyline(visible, Color(color, 0.55 + 0.45 * swell), 2.5, true)

	if _lock_flash > 0.0:
		draw_set_transform(at, 0.0, Vector2(1.0, 0.35))
		draw_arc(Vector2.ZERO, reach * (0.6 + (1.0 - _lock_flash) * 0.8), 0.0, TAU, 32,
			Color(1.0, 0.95, 0.85, 0.7 * _lock_flash), 4.0, true)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_falling_shadow(at: Vector2) -> void:
	var height := clampf((landing_position.y - global_position.y) / DROP_HEIGHT, 0.0, 1.0)
	var closeness := 1.0 - height
	_draw_shadow(at, (_collision_radius + 26.0) * lerpf(0.55, 1.0, closeness),
		lerpf(0.4, 1.0, closeness))
