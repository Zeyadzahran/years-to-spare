class_name Level
extends Node2D
## Every phase scene runs this. Owns nothing but the level's lifecycle, so the
## content of a phase stays in its scene tree.

@export var level_id: StringName = &"phase_1"

func _ready() -> void:
	TimeService.reset()
	GameState.start_new_run()
	EventBus.player_died.connect(_on_player_died)
	_resume_from_checkpoint()
	EventBus.level_started.emit(level_id)


## A death reloads the whole level, so this runs on every load and is what turns
## that reload into a respawn: the boy is moved to the checkpoint he reached and
## handed back the age he had there, rather than starting the phase over.
## Runs after the scene's children are ready, so the player and its components
## exist and the age it announces reaches the HUD and his sprite set.
func _resume_from_checkpoint() -> void:
	if not GameState.has_checkpoint(level_id):
		return
	var player := get_tree().get_first_node_in_group(&"player") as Node2D
	if player == null:
		return
	player.global_position = GameState.checkpoint_position
	player.age.set_to(GameState.checkpoint_age)


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
