class_name BusinessLaser
extends Bullet
## A swept laser with a short, rewindable impact. No effect outlives its shot.

const IMPACT_DURATION := 0.26
var _impact_age := 0.0
@onready var sweep: ShapeCast2D = $Sweep

func _ready() -> void:
	super._ready()
	add_to_group(&"business_laser")

func _physics_process(delta: float) -> void:
	if TimeService.is_rewinding():
		return
	var scaled := TimeService.world_delta(delta)
	if _impact_audio != null:
		_impact_audio.stream_paused = TimeService.is_world_frozen()
	if _spent:
		_impact_age += scaled
		if _impact_age >= IMPACT_DURATION:
			TimeService.retire(self)
	else:
		# The parent rotates to face the shot. Sweep in its local coordinates.
		var motion := _velocity * scaled
		sweep.target_position = motion.rotated(-rotation)
		sweep.force_shapecast_update()
		if sweep.is_colliding():
			global_position += motion * sweep.get_closest_collision_safe_fraction()
			_on_body_entered(sweep.get_collider(0))
		else:
			global_position += motion
			_age += scaled
			if _age >= LIFETIME:
				TimeService.retire(self)
	queue_redraw()

func _on_body_entered(body: Node2D) -> void:
	if _spent or TimeService.is_rewinding():
		return
	_spent = true
	_impact_age = 0.0
	$Sprite.hide()
	set_deferred(&"monitoring", false)
	if body is Player:
		body.health.take_damage(_damage, _shooter if is_instance_valid(_shooter) else null)
	if _impact_audio != null:
		_impact_audio.play()
	queue_redraw()

func _draw() -> void:
	if _spent:
		var progress := clampf(_impact_age / IMPACT_DURATION, 0.0, 1.0)
		var fade := 1.0 - progress
		draw_arc(Vector2.ZERO, 5.0 + progress * 27.0, 0.0, TAU, 24, Color(0.25, 0.8, 1.0, fade), 2.0)
		for i in 8:
			var direction := Vector2.from_angle(i * TAU / 8.0)
			draw_line(direction * (4.0 + progress * 8.0), direction * (10.0 + progress * 28.0), Color(0.8, 0.95, 1.0, fade), 2.0)
	else:
		var length := minf(_age * _velocity.length(), 70.0)
		draw_line(Vector2(-length, 0), Vector2(12, 0), Color(0.1, 0.65, 1.0, 0.15), 14.0)
		draw_line(Vector2(-length * 0.8, 0), Vector2(12, 0), Color(0.3, 0.8, 1.0, 0.5), 6.0)
		draw_line(Vector2(-length * 0.5, 0), Vector2(12, 0), Color(0.85, 1.0, 1.0), 2.0)

func rewind_capture() -> Array:
	var saved := super()
	saved.append(_impact_age)
	return saved

func rewind_apply(saved: Array) -> void:
	super(saved)
	_impact_age = saved[7]
	set_physics_process(true)
	$Sprite.visible = not _spent
	queue_redraw()

func rewind_began() -> void:
	if _impact_audio != null:
		_impact_audio.stop()
