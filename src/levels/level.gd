class_name Level
extends Node2D
## Every phase scene runs this. Owns nothing but the level's lifecycle, so the
## content of a phase stays in its scene tree.

@export var level_id: StringName = &"phase_1"

func _ready() -> void:
	TimeService.reset()
	GameState.start_new_run()
	EventBus.player_died.connect(_on_player_died)
	EventBus.enemy_died.connect(_on_enemy_died)
	_remove_the_fallen()
	_resume_run()
	EventBus.level_started.emit(level_id)


## A death reloads the whole level, so this runs on every load and is what turns
## that reload into a respawn rather than a restart.
##
## The boy comes back where he last stood and as old as he was when he fell:
## losing health costs him ground, never years. Handing the years back would
## make the game's only currency free, and would walk his body backwards from
## the elder frames to the boy's on every mistake.
##
## Runs after the scene's children are ready, so the player and its components
## exist and the age it announces reaches the HUD and his sprite set.
func _resume_run() -> void:
	var player := get_tree().get_first_node_in_group(&"player") as Node2D
	if player == null:
		return
	if GameState.run_age >= 0.0:
		player.age.set_to(GameState.run_age)
	if GameState.has_checkpoint(level_id):
		player.global_position = GameState.checkpoint_position


## Units downed earlier in the run do not get up again for a retry. Done before
## the first frame, so a body already recorded never ticks, swings or fires.
func _remove_the_fallen() -> void:
	for enemy in get_tree().get_nodes_in_group(&"enemy"):
		if GameState.is_enemy_cleared(level_id, _tag(enemy)):
			enemy.queue_free()


## How a unit is named across reloads. The path inside the level scene, which is
## stable as long as nobody renames the node - the same contract a Checkpoint's
## own name already relies on.
func _tag(enemy: Node) -> String:
	return String(get_path_to(enemy))


func complete() -> void:
	EventBus.level_completed.emit(level_id)


func reload() -> void:
	TimeService.reset()
	get_tree().reload_current_scene()


func _on_enemy_died(enemy: Node2D, _age_reward: float) -> void:
	# Recorded here rather than by the unit itself: the tag is a path inside
	# this level, and the unit has no business knowing which level it stands in.
	if is_instance_valid(enemy) and is_ancestor_of(enemy):
		GameState.clear_enemy(level_id, _tag(enemy))


## Health runs out and he tries again from the marker. Years run out and there
## is nothing left to try with: the marker, the bodies and the age all go, and
## the phase starts over from fourteen.
func _on_player_died(of_old_age: bool) -> void:
	if of_old_age:
		GameState.clear_run_progress()
	else:
		var player := get_tree().get_first_node_in_group(&"player") as Node2D
		if player != null:
			GameState.run_age = player.age.age
	reload()
