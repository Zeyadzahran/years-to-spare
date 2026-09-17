extends Area2D
## One-shot day->night crossfade, triggered by walking through the gateway
## structure this sits inside. Reuses the exact tween idiom
## Level._play_opening_fade() already uses (src/levels/level.gd) - a plain
## create_tween().tween_property() - just aimed at a CanvasModulate and the
## background's existing Day/Night sprite pairs instead of a fade rect.

@export var canvas_modulate_path: NodePath
@export var night_color := Color(0.35, 0.4, 0.62, 1.0)
@export var duration := 2.0
## Existing Day-layer sprites to fade out (Sky gradient + each CityLayer).
@export var day_fade_out: Array[NodePath] = []
## The Night-texture siblings added alongside them, faded in over the same span.
@export var night_fade_in: Array[NodePath] = []

var _triggered := false
var _transition: Tween


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	# A respawn rebuilds the whole level from its authored Day state; the
	# checkpoint that sent the boy back here is what says whether that is
	# right. Restoring Night here is instant, not a replay of the crossing he
	# already earned - only a fresh crossing plays the tween.
	if GameState.has_checkpoint(GameState.current_level()["id"]) and GameState.checkpoint_night:
		_apply_instant_night()


func _on_body_entered(body: Node2D) -> void:
	if _triggered or not (body is Player):
		return
	_triggered = true
	GameState.night_active = true
	_run_transition()


func _run_transition() -> void:
	var canvas_modulate := get_node_or_null(canvas_modulate_path) as CanvasModulate
	_transition = create_tween().set_parallel(true)
	if canvas_modulate != null:
		_transition.tween_property(canvas_modulate, ^"color", night_color, duration)
	for path in day_fade_out:
		var node := get_node_or_null(path) as CanvasItem
		if node != null:
			_transition.tween_property(node, ^"modulate:a", 0.0, duration)
	for path in night_fade_in:
		var node := get_node_or_null(path) as CanvasItem
		if node != null:
			_transition.tween_property(node, ^"modulate:a", 1.0, duration)


## The one-way boss gate calls this under its opaque fade. Keep the saved
## checkpoint's night flag intact so a later level reload restores that area.
func restore_daylight() -> void:
	if _transition != null and _transition.is_valid():
		_transition.kill()
	_triggered = true
	GameState.night_active = false
	var canvas_modulate := get_node_or_null(canvas_modulate_path) as CanvasModulate
	if canvas_modulate != null:
		canvas_modulate.color = Color.WHITE
	for path in day_fade_out:
		var node := get_node_or_null(path) as CanvasItem
		if node != null:
			node.modulate.a = 1.0
	for path in night_fade_in:
		var node := get_node_or_null(path) as CanvasItem
		if node != null:
			node.modulate.a = 0.0


## Same end state _run_transition() tweens to, applied on the spot instead of
## over its 2s - a respawn is not the moment he crossed into Night, so there
## is nothing here for a tween to play out.
func _apply_instant_night() -> void:
	_triggered = true
	GameState.night_active = true
	var canvas_modulate := get_node_or_null(canvas_modulate_path) as CanvasModulate
	if canvas_modulate != null:
		canvas_modulate.color = night_color
	for path in day_fade_out:
		var node := get_node_or_null(path) as CanvasItem
		if node != null:
			node.modulate.a = 0.0
	for path in night_fade_in:
		var node := get_node_or_null(path) as CanvasItem
		if node != null:
			node.modulate.a = 1.0
