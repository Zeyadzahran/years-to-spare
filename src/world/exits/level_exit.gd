extends Area2D
## Crossing the marked gate completes the level; enemy deaths never gate it.

var _completed := false


func _ready() -> void:
	$Completion/Panel.hide()
	body_entered.connect(_on_body_entered)
	$Completion/Panel/Copy/ReturnButton.pressed.connect(_return_to_menu)


func _on_body_entered(body: Node2D) -> void:
	if _completed or not body is Player:
		return
	_completed = true
	call_deferred(&"_complete", body)


func _complete(player: Player) -> void:
	var level := get_parent()
	while level != null and not level is Level:
		level = level.get_parent()
	if level == null:
		return
	player.powers.cancel()
	TimeService.reset()
	level.complete()
	$Completion/Panel.show()
	$Completion/Panel/Copy/ReturnButton.grab_focus()
	get_tree().paused = true


func _return_to_menu() -> void:
	get_tree().paused = false
	GameState.clear_run_progress()
	get_tree().change_scene_to_file("res://src/ui/main_menu/main_menu.tscn")
