class_name Level
extends Node2D
## Every phase scene runs this. Owns nothing but the level's lifecycle, so the
## content of a phase stays in its scene tree.

@export var level_id: StringName = &"phase_1"
@export_node_path("Marker2D") var level_start_path: NodePath

## The track under the whole phase. Left empty, the level runs on its ambience
## alone. Set to loop here rather than in the import, the way the boss theme
## is, so the file stays a plain asset. A boss room that starts its own music
## fades this out on the way in; MusicManager keeps it running across a
## checkpoint reload, so a death does not restart the song.
@export var music: AudioStream
## Sits under the boss theme (-7 dB on a much hotter track) so the fight reads
## as an escalation, and leaves the desert wind audible beneath it.
@export var music_volume_db := -3.0

## Testing aid: tick this to leave the boy exactly where the Player node sits
## in the editor instead of moving him to the level start. Only ever applies
## when there is no checkpoint to honour yet and the scene is run from the
## editor (see OS.has_feature("editor") below) - an exported build, and any
## run a checkpoint or death has already touched, are untouched by this.
@export var debug_keep_editor_spawn := false

## Testing aid: point this at a Marker2D to start there instead, without
## having to drag the Player node itself around. Same editor-only,
## no-checkpoint-yet guard as debug_keep_editor_spawn, and wins over it if
## both are set.

## Testing aid: point this at a Marker2D to start there instead of the Player
## node's own authored position. Only ever applies when there is no
## checkpoint to honour yet and the scene is run from the editor (see
## OS.has_feature("editor") below) - an exported build, and any run a
## checkpoint or death has already touched, are untouched by this.
@export_node_path("Marker2D") var debug_spawn_path: NodePath

func _ready() -> void:
	TimeService.reset()
	GameState.start_new_run(level_id)
	EventBus.player_died.connect(_on_player_died)
	EventBus.enemy_died.connect(_on_enemy_died)
	_remove_the_fallen()
	_resume_run()
	_start_music()
	EventBus.level_started.emit(level_id)


func _start_music() -> void:
	if music == null:
		return
	if music is AudioStreamMP3 or music is AudioStreamOggVorbis:
		music.set(&"loop", true)
	MusicManager.play_music(music, 2.0, music_volume_db)


## A death reloads the whole level, so this runs on every load and is what turns
## that reload into a respawn rather than a restart.
##
## Every death - combat, a spike, the void - costs a heart the same way, because
## GameState.lose_heart() has already run by the time this reload happens. A
## heart still covers it, so the checkpoint is still recorded and this puts him
## back on it; the third one instead clears the checkpoint before the reload,
## which leaves him at the Player node's own authored position here - the same
## place a run that never reached a checkpoint at all resumes from. Either way
## his age is preserved; handing years back would make the game's only currency
## free and walk his body backwards on every mistake.
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
		return
	if OS.has_feature("editor"):
		_apply_debug_spawn(player)


## Testing aid only - see debug_spawn_path above. Reached only once there is no
## checkpoint to honour, so it can start a test run at a specific marker
## without ever pre-empting what a real checkpoint sends the boy back to.
func _apply_debug_spawn(player: Node2D) -> void:
	var marker := get_node_or_null(debug_spawn_path) as Marker2D
	if marker != null:
		player.global_position = marker.global_position


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


## Health runs out and he tries again from the marker - unless that was his
## third try since the last full start, in which case a heart no longer
## covers it and the level starts over the way old age does. Years run out
## and there is nothing left to try with regardless: the marker, the bodies
## and the age all go, and the phase starts over from fourteen.
func _on_player_died(of_old_age: bool) -> void:
	if of_old_age:
		GameState.clear_run_progress()
	else:
		var player := get_tree().get_first_node_in_group(&"player") as Node2D
		if player != null:
			GameState.run_age = player.age.age
		if GameState.lose_heart() <= 0:
			GameState.clear_run_progress()
	reload()
