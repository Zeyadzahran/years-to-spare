class_name RobotBeam
extends Area2D
## A fast, horizontal lethal pulse. Sweep its full shape through each physics
## step so neither thin walls nor the player can fall between samples.

const LIFETIME := 1.25

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var sweep: ShapeCast2D = $Sweep

var _velocity := Vector2.ZERO
var _age := 0.0
var _spent := false

func setup(direction: int, speed: float) -> void:
	_velocity = Vector2(direction * speed, 0.0)


func _ready() -> void:
	add_to_group(TimeService.REWINDABLE_GROUP)
	add_to_group(&"robot_beam")
	body_entered.connect(_on_body_entered)
	_sync_art()


func _physics_process(delta: float) -> void:
	if _spent or TimeService.is_rewinding():
		return
	var scaled := TimeService.world_delta(delta)
	# A zero-length sweep still detects the player walking into a frozen beam.
	var motion := _velocity * scaled
	sweep.target_position = motion
	sweep.force_shapecast_update()
	if sweep.is_colliding():
		global_position += motion * sweep.get_closest_collision_safe_fraction()
		_on_body_entered(sweep.get_collider(0))
		return
	global_position += motion
	_age += scaled
	_sync_art()
	if _age >= LIFETIME:
		_spend()


func _on_body_entered(body: Node2D) -> void:
	if _spent or TimeService.is_rewinding():
		return
	if body is Player:
		body.die_instantly(self)
	_spend()


func _spend() -> void:
	_spent = true
	TimeService.retire(self)


func _sync_art() -> void:
	sprite.flip_h = _velocity.x < 0.0
	var animation_fps := sprite.sprite_frames.get_animation_speed(&"beam")
	sprite.frame = int(_age * animation_fps) % sprite.sprite_frames.get_frame_count(&"beam")
	queue_redraw()


## The dim tail is cosmetic; the bright core stays inside the swept hitbox.
## Derive every pulse and spark from recorded world age so the effect freezes
## and rewinds with the projectile, without independent particle timers.
func _draw() -> void:
	var direction := -1.0 if _velocity.x < 0.0 else 1.0
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(direction, 1.0))
	var pulse := 0.85 + 0.15 * sin(_age * TAU * 6.0)
	for layer in 3:
		var thickness := (15.0 - layer * 4.0) * pulse
		var tail := -96.0 + layer * 12.0
		var outline := PackedVector2Array([
			Vector2(tail, 0), Vector2(-40, -thickness), Vector2(42, -thickness),
			Vector2(58, 0), Vector2(42, thickness), Vector2(-40, thickness),
		])
		draw_colored_polygon(outline, Color(1.0, 0.65 + layer * 0.1, 0.08, 0.08 + layer * 0.035))
	# A white-hot leading edge and small trailing embers give the shot direction.
	draw_circle(Vector2(48, 0), 7.0 * pulse, Color(1.0, 0.9, 0.35, 0.65))
	draw_line(Vector2(-42, 0), Vector2(50, 0), Color(1.0, 1.0, 0.85), 3.0)
	for spark in 3:
		var progress := fposmod(_age * 2.5 + spark / 3.0, 1.0)
		var side := -1.0 if spark % 2 == 0 else 1.0
		var at := Vector2(8.0 - progress * 96.0, side * (8.0 + progress * 5.0)).round()
		draw_rect(Rect2(at, Vector2(3, 2)), Color(1.0, 0.85, 0.3, (1.0 - progress) * 0.7))


func rewind_capture() -> Array:
	return [global_position, _velocity, _age, _spent]


func rewind_apply(saved: Array) -> void:
	global_position = saved[0]
	_velocity = saved[1]
	_age = saved[2]
	_spent = saved[3]
	visible = not _spent
	set_deferred(&"monitoring", not _spent)
	set_physics_process(not _spent)
	process_mode = Node.PROCESS_MODE_INHERIT
	_sync_art()


func rewind_retire() -> void:
	visible = false
	set_deferred(&"monitoring", false)
	set_physics_process(false)
	process_mode = Node.PROCESS_MODE_DISABLED
