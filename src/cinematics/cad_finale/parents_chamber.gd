extends Node2D
## A six-frame suffering idle stays closed. Its occupants are freed in the
## future artwork cutscene; this scene only shows the source of the boss power.

const FRAMES := preload("res://src/cinematics/cad_finale/parents_chamber_frames.tres")
const IDLE_FPS := 6.0
var machine: AnimatedSprite2D
var clock := 0.0
var boss: BusinessBoss
var landed_at := -1.0

func _ready() -> void:
	add_to_group(TimeService.REWINDABLE_GROUP)
	machine = AnimatedSprite2D.new()
	machine.sprite_frames = FRAMES
	machine.animation = &"idle"
	machine.scale = Vector2.ONE * 0.565
	# All six regions share the same machine centre and foot baseline.
	machine.position.y = -238.0 * 0.565
	machine.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	machine.speed_scale = 0.0
	add_child(machine)
	_sync_frame()

func _sync_frame() -> void:
	if machine == null:
		return
	var powered := is_instance_valid(boss) and boss.health.is_alive()
	machine.frame = int(clock * IDLE_FPS) % 6 if powered else 0

func _physics_process(delta: float) -> void:
	if TimeService.is_rewinding():
		return
	clock += TimeService.world_delta(delta)
	_sync_frame()
	queue_redraw()

func land() -> void:
	landed_at = clock
	queue_redraw()

func _draw() -> void:
	if landed_at >= 0.0:
		var progress := clampf((clock - landed_at) / 0.55, 0.0, 1.0)
		for i in 16:
			var side := -1.0 if i % 2 == 0 else 1.0
			var point := Vector2(side * (75 + i * 7 + progress * 70), -sin(progress * PI) * (12 + i * 2))
			draw_rect(Rect2(point, Vector2(5, 3)), Color(0.65, 0.72, 0.8, 1.0 - progress))
	var energy := 1.0 if is_instance_valid(boss) and boss.health.is_alive() else 0.0
	# A small hourglass halo and rising motes link the power to stolen years.
	for i in 14:
		var point := Vector2(sin(i * 2.4) * 100.0, -30.0 - fmod(clock * 25.0 + i * 19.0, 220.0))
		draw_rect(Rect2(point, Vector2(2, 4)), Color(1.0, 0.72, 0.22, 0.45 * energy))
	if is_instance_valid(boss) and boss.phase in [BusinessBoss.Phase.DORMANT, BusinessBoss.Phase.FIGHTING]:
		var destination := to_local(boss.global_position + Vector2(0, -75))
		var source := Vector2(0, -245)
		for i in 9:
			var t := fmod(clock * 0.28 + i / 9.0, 1.0)
			var point := source.lerp(destination, t) + Vector2(0, -sin(t * PI) * 45.0)
			draw_circle(point, 2.0, Color(1.0, 0.72, 0.24, energy * 0.6))

func rewind_capture() -> Array:
	return [clock]

func rewind_apply(saved: Array) -> void:
	clock = saved[0]
	_sync_frame()
	queue_redraw()
