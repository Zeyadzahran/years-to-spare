extends Area2D
## The fall that teaches Rewind. Sits in the hole at the start of the street,
## which no jump clears on a fresh run. The first time he falls in and the
## collapse plays out, the world stops and the card under this node tells him
## the one thing he needs: press L, and press it soon. Rewind is made ready
## whatever the guard before cost him, so the press cannot be refused. Once
## he is standing again the two ledges slide out of the walls while he and
## the street hold still, and the hole is a jump like any other. It happens
## once a run; a retry finds the ledges already out.
##
## Placed under Tutorial rather than Hazards: it hurts nothing, it only
## watches for him, and the card is its child so nothing has to be wired up.

@export var left_ledge: NodePath
@export var right_ledge: NodePath
## Where the two ledges end up, in their parent's space.
@export var left_closed := Vector2(1504, 640)
@export var right_closed := Vector2(1856, 640)
## How long the ledges take to slide out.
@export var slide_time := 1.2
## How long the camera takes to look over at the hole, and back.
@export var pan_time := 0.5
## Where the card's top-left corner sits relative to the centre of the view
## when it appears - the hole is off-screen by then, he is at the bottom of it.
@export var card_offset := Vector2(-220, -170)
## Where the camera looks while the ledges move.
@export var hole_centre_x := 1664.0

var _armed := false
var _waiting := false
var _reviving := false
var _player: Player

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process_input(false)
	$Card.visible = false
	if GameState.rewind_lesson_done:
		_snap_closed()
		monitoring = false
		return
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	EventBus.player_collapsed.connect(_on_player_collapsed)
	EventBus.ability_stopped.connect(_on_ability_stopped)


func _on_body_entered(body: Node2D) -> void:
	if body is Player and not GameState.rewind_lesson_done:
		_armed = true
		_player = body


## Walked out alive - a jump that fell short and was rewound by hand, say -
## so the next death, wherever it is, is not this lesson's.
func _on_body_exited(body: Node2D) -> void:
	if body is Player and not body.is_down():
		_armed = false


func _on_player_collapsed(player: Node2D) -> void:
	if not _armed or GameState.rewind_lesson_done:
		return
	_armed = false
	_player = player
	GameState.rewind_lesson_done = true
	player.powers.clear_cooldown(GameState.ABILITY_REWIND)
	$Card.global_position = _view_centre() + card_offset
	$Card.visible = true
	_waiting = true
	set_process_input(true)
	get_tree().set_deferred(&"paused", true)


## Only L gets through while the card is up. The world is paused, so the
## key has to be handed to his powers from here; the wind-up runs on once
## the pause lifts.
func _input(event: InputEvent) -> void:
	if not _waiting:
		return
	if event is InputEventKey or event is InputEventJoypadButton:
		get_viewport().set_input_as_handled()
	if not event.is_action_pressed(&"time_rewind"):
		return
	if not _player.powers.rewind_after_death():
		return
	_waiting = false
	_reviving = true
	set_process_input(false)
	$Card.visible = false
	get_tree().paused = false


func _on_ability_stopped(ability_id: StringName) -> void:
	if ability_id != GameState.ABILITY_REWIND:
		return
	if _reviving:
		_reviving = false
		# We are inside TimePowers' own update; the freeze waits a frame.
		_show_the_way.call_deferred()
	else:
		# A rewind of his own, out of the hole or anywhere: not the lesson.
		_armed = false


## He watches the ledges come out. Held still, and the street's guards with
## him - a rewind put him back among them - then the camera looks over at the
## hole, the ledges slide, and everything is handed back.
func _show_the_way() -> void:
	if not is_instance_valid(_player):
		return
	var enemies := _level_node(^"Enemies")
	if enemies != null:
		enemies.process_mode = Node.PROCESS_MODE_DISABLED
	_player.process_mode = Node.PROCESS_MODE_DISABLED
	if is_instance_valid(_player.sprite):
		_player.sprite.process_mode = Node.PROCESS_MODE_ALWAYS
	var camera := _player.get_node_or_null(^"Camera2D") as Camera2D
	var left := get_node_or_null(left_ledge) as Node2D
	var right := get_node_or_null(right_ledge) as Node2D
	var tween := create_tween()
	if camera != null:
		tween.tween_property(camera, ^"offset:x", hole_centre_x - _player.global_position.x, pan_time) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if left != null:
		tween.tween_property(left, ^"position", left_closed, slide_time) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if right != null:
		tween.parallel().tween_property(right, ^"position", right_closed, slide_time) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if camera != null:
		tween.tween_property(camera, ^"offset", Vector2.ZERO, pan_time) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	if is_instance_valid(_player):
		_player.process_mode = Node.PROCESS_MODE_INHERIT
		if is_instance_valid(_player.sprite):
			_player.sprite.process_mode = Node.PROCESS_MODE_INHERIT
	if is_instance_valid(enemies):
		enemies.process_mode = Node.PROCESS_MODE_INHERIT
	monitoring = false


## The centre of what is actually on screen. The camera smooths after the
## boy, so its own idea of its centre is ahead of the picture during a fall.
func _view_centre() -> Vector2:
	var viewport := get_viewport()
	return viewport.get_canvas_transform().affine_inverse() * (viewport.get_visible_rect().size * 0.5)


func _snap_closed() -> void:
	var left := get_node_or_null(left_ledge) as Node2D
	if left != null:
		left.position = left_closed
	var right := get_node_or_null(right_ledge) as Node2D
	if right != null:
		right.position = right_closed


## A node under the level this sits in, found by walking up to it.
func _level_node(path: NodePath) -> Node:
	var node := get_parent()
	while node != null and not (node is Level):
		node = node.get_parent()
	return node.get_node_or_null(path) if node != null else null
