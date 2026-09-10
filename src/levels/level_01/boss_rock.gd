class_name BossRock
extends Area2D
## A vertically moving boss hazard using the existing graded stone sprites.
## Each instance owns a ground warning, movement weight and impact strength.

enum RockSize { SMALL, MEDIUM, LARGE }
enum MotionKind { FALL, ERUPT }

const IMPACT_SCENE := preload("res://src/levels/level_01/boss_impact_effect.tscn")
const MAX_LIFETIME := 4.2
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
		global_position = Vector2(landing_position.x, landing_position.y - 820.0)
		sprite.show()
	else:
		global_position = landing_position + Vector2(0.0, _collision_radius * 0.7)
		sprite.hide()
	queue_redraw()


func launch() -> void:
	_launch_called = true
	if _launch_delay <= 0.0:
		_begin_motion()


func stop() -> void:
	monitoring = false
	queue_free()


func is_vertical_plan() -> bool:
	return is_zero_approx(_velocity.x)


func _physics_process(delta: float) -> void:
	var scaled := TimeService.world_delta(delta)
	if is_zero_approx(scaled):
		return
	_pulse += scaled
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
	_launched = true
	warning_active = false
	monitoring = true
	sprite.show()
	if motion_kind == MotionKind.FALL:
		var fall_speed := 1040.0 if size_kind == RockSize.SMALL else 860.0 if size_kind == RockSize.MEDIUM else 690.0
		_velocity = Vector2(0.0, fall_speed)
		_gravity = Vector2(0.0, 180.0)
	else:
		var rise_speed := 940.0 if size_kind == RockSize.SMALL else 840.0 if size_kind == RockSize.MEDIUM else 750.0
		_velocity = Vector2(0.0, -rise_speed)
		_gravity = Vector2(0.0, 1680.0)
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


func _impact_ground() -> void:
	monitoring = false
	var effect := IMPACT_SCENE.instantiate() as BossImpactEffect
	get_parent().add_child(effect)
	var impact_strength := 0.55 if size_kind == RockSize.SMALL else 0.78 if size_kind == RockSize.MEDIUM else 1.1
	effect.configure(landing_position, impact_strength, size_kind == RockSize.LARGE)
	queue_free()


func _on_body_entered(body: Node2D) -> void:
	if not body is Player:
		return
	body.health.take_damage(damage, self)
	monitoring = false
	var effect := IMPACT_SCENE.instantiate() as BossImpactEffect
	get_parent().add_child(effect)
	effect.configure(global_position, 0.45 if size_kind == RockSize.SMALL else 0.7)
	queue_free()


func _draw() -> void:
	if warning_active:
		_draw_warning(to_local(landing_position))
	elif _launched:
		_draw_motion_debris()


func _draw_warning(at: Vector2) -> void:
	var pulse := 0.82 + sin(_pulse * 12.0) * 0.12
	var radius := (_collision_radius + 16.0) * pulse
	if motion_kind == MotionKind.FALL:
		draw_set_transform(at, 0.0, Vector2(1.0, 0.28))
		draw_circle(Vector2.ZERO, radius, Color(0.05, 0.035, 0.03, 0.62))
		draw_arc(Vector2.ZERO, radius + 5.0, 0.0, TAU, 24,
			Color(1.0, 0.44, 0.08, 0.78), 4.0, true)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		draw_circle(at, radius * 0.55, Color(0.48, 0.22, 0.06, 0.24))
		for index in 6:
			var angle := TAU * float(index) / 6.0 + 0.2
			var direction := Vector2.from_angle(angle)
			draw_polyline(PackedVector2Array([
				at + direction * 5.0,
				at + direction.rotated(0.16) * radius * 0.58,
				at + direction * radius,
			]), Color(1.0, 0.38, 0.06, 0.82), 3.0)
		for index in 5:
			var dust_at := at + Vector2(-radius + float(index) * radius * 0.5,
				-5.0 - float(index % 2) * 5.0)
			draw_circle(dust_at, 4.0 + float(index % 2) * 2.0,
				Color(0.75, 0.42, 0.19, 0.46))


func _draw_motion_debris() -> void:
	var direction := -signf(_velocity.y)
	for index in 3:
		var trail_position := Vector2((float(index) - 1.0) * 7.0,
			direction * (15.0 + float(index) * 9.0))
		draw_circle(trail_position, 3.5 - float(index) * 0.65,
			Color(0.68, 0.47, 0.32, 0.38))
