class_name BossGate
extends Area2D
## A one-way threshold into the final arena. Entering its arch locks the player
## briefly, blooms the gate, fades the screen, and moves him without reloading
## the level so his age and run progress survive the crossing.

@export var boss_room_scene: PackedScene
@export_node_path("Node2D") var boss_room_parent_path: NodePath
@export_node_path("Marker2D") var boss_room_anchor_path: NodePath

const REST_SCALE := Vector2(0.14, 0.14)
const ACTIVE_SCALE := Vector2(0.15, 0.15)

var _transitioning := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	$Transition/Fade.color.a = 0.0


func _on_body_entered(body: Node2D) -> void:
	if _transitioning or not body is Player:
		return
	var room_parent := get_node_or_null(boss_room_parent_path) as Node2D
	var room_anchor := get_node_or_null(boss_room_anchor_path) as Marker2D
	if boss_room_scene == null or room_parent == null or room_anchor == null:
		push_error("BossGate requires the existing boss-room scene, parent and anchor")
		return
	_transitioning = true
	monitoring = false
	_enter_gate(body, room_parent, room_anchor)


func _enter_gate(player: Player, room_parent: Node2D, room_anchor: Marker2D) -> void:
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

	# Load the authored room while the screen is covered. It is not sitting in
	# the normal level off-screen anymore: crossing this gate creates the one
	# existing boss-room scene at its dedicated world anchor.
	var boss_room := _load_boss_room(room_parent, room_anchor)
	var boss_spawn := boss_room.get_node_or_null(^"PlayerSpawn") as Marker2D
	if boss_spawn == null:
		push_error("The boss room requires its PlayerSpawn marker")
		_abort_transition(player)
		return

	player.global_position = boss_spawn.global_position
	player.velocity = Vector2.ZERO
	player.facing = 1
	var camera := player.get_node_or_null(^"Camera2D") as Camera2D
	if camera != null:
		if boss_room.has_method(&"configure_camera"):
			boss_room.configure_camera(camera)
		camera.reset_smoothing()

	var reveal := create_tween()
	reveal.tween_interval(0.12)
	reveal.tween_property($Transition/Fade, ^"color:a", 0.0, 0.48)
	await reveal.finished
	player.process_mode = Node.PROCESS_MODE_INHERIT
	if boss_room.has_method(&"begin_encounter"):
		boss_room.begin_encounter()

	$Effects.emitting = false
	$Art.scale = REST_SCALE
	$Art.modulate = Color.WHITE
	$Glow.modulate.a = 0.0


func _load_boss_room(room_parent: Node2D, room_anchor: Marker2D) -> Node2D:
	var existing := room_parent.get_node_or_null(^"BossRoom") as Node2D
	if existing != null:
		return existing
	var boss_room := boss_room_scene.instantiate() as Node2D
	boss_room.name = "BossRoom"
	boss_room.position = room_parent.to_local(room_anchor.global_position)
	room_parent.add_child(boss_room)
	return boss_room


func _abort_transition(player: Player) -> void:
	player.process_mode = Node.PROCESS_MODE_INHERIT
	$Transition/Fade.color.a = 0.0
	$Effects.emitting = false
	$Art.scale = REST_SCALE
	$Art.modulate = Color.WHITE
	$Glow.modulate.a = 0.0
	_transitioning = false
	monitoring = true
