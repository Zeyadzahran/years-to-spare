class_name Level
extends Node2D
## Every phase scene runs this. Owns nothing but the level's lifecycle, so the
## content of a phase stays in its scene tree.

@export var level_id: StringName = &"phase_1"

func _ready() -> void:
	TimeService.reset()
	GameState.start_new_run()
	EventBus.player_died.connect(_on_player_died)
	EventBus.level_started.emit(level_id)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"restart"):
		reload()


func complete() -> void:
	EventBus.level_completed.emit(level_id)


func reload() -> void:
	TimeService.reset()
	get_tree().reload_current_scene()


func _on_player_died() -> void:
	reload()
