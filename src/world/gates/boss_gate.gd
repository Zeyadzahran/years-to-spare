class_name BossGate
extends Area2D
## A one-way threshold into the final arena authored inside Level 1. Entering
## its arch locks the player, blooms the gate, fades the screen, and carries the
## same Player into the hidden chamber beyond the level's final gap.

@export_node_path("Node2D") var boss_arena_path: NodePath
@export_node_path("Marker2D") var arena_spawn_path: NodePath

const ARENA_CAMERA_ZOOM := Vector2(0.75, 0.75)

const REST_SCALE := Vector2(0.14, 0.14)
const ACTIVE_SCALE := Vector2(0.15, 0.15)

var _transitioning := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	$Transition/Fade.color.a = 0.0


func _on_body_entered(body: Node2D) -> void:
	if _transitioning or not body is Player:
		return
	var boss_arena := get_node_or_null(boss_arena_path) as Node2D
	var arena_spawn := get_node_or_null(arena_spawn_path) as Marker2D
	if boss_arena == null or arena_spawn == null:
		push_error("BossGate requires the Level 1 BossArena and PlayerSpawn")
		return
	_transitioning = true
	set_deferred(&"monitoring", false)
	_enter_gate(body, boss_arena, arena_spawn)


func _enter_gate(player: Player, boss_arena: Node2D, arena_spawn: Marker2D) -> void:
	player.powers.cancel()
	player.velocity = Vector2.ZERO
	player.process_mode = Node.PROCESS_MODE_DISABLED
	$Effects.emitting = true

	var charge := create_tween().set_parallel(true)
	charge.tween_property($Art, ^"scale", ACTIVE_SCALE, 0.32).set_trans(Tween.TRANS_BACK)
	charge.tween_property($Art, ^"modulate", Color(1.8, 1.35, 0.65, 1.0), 0.32)
	charge.tween_property($Glow, ^"modulate:a", 0.72, 0.32)
	await charge.finished

	var cover := create_tween()
	cover.tween_property($Transition/Fade, ^"color:a", 1.0, 0.28)
	await cover.finished
	$Transition/Fade.color.a = 1.0

	# Keep the cover completely opaque until the same live Player, arena, and
	# boss-only camera limits have all reached their destination.
	boss_arena.show()
	player.global_position = arena_spawn.global_position
	player.velocity = Vector2.ZERO
	player.facing = 1
	if boss_arena.has_method(&"prepare_gate_entry"):
		boss_arena.call(&"prepare_gate_entry", player)
	var camera := player.get_node_or_null(^"Camera2D") as Camera2D
	if camera != null:
		camera.zoom = ARENA_CAMERA_ZOOM
		camera.position_smoothing_enabled = false
		camera.reset_smoothing()
		camera.force_update_scroll()
	await get_tree().process_frame
	await get_tree().process_frame
	if camera != null:
		camera.reset_smoothing()
		camera.force_update_scroll()

	var reveal := create_tween()
	reveal.tween_interval(0.12)
	reveal.tween_property($Transition/Fade, ^"color:a", 0.0, 0.48)
	await reveal.finished
	player.process_mode = Node.PROCESS_MODE_INHERIT
	if camera != null:
		camera.position_smoothing_enabled = true
	$Effects.emitting = false
	$Art.scale = REST_SCALE
	$Art.modulate = Color.WHITE
	$Glow.modulate.a = 0.0


func _abort_transition(player: Player) -> void:
	player.process_mode = Node.PROCESS_MODE_INHERIT
	$Transition/Fade.color.a = 0.0
	$Effects.emitting = false
	$Art.scale = REST_SCALE
	$Art.modulate = Color.WHITE
	$Glow.modulate.a = 0.0
	_transitioning = false
	set_deferred(&"monitoring", true)
