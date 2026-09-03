extends Node
## Run-level progress: which phase we are on and which time powers are unlocked.
## Levels read this on load; nothing else needs to know the order of the game.

const ABILITY_STOP := &"stop"
const ABILITY_REWIND := &"rewind"
const ABILITY_SLOW := &"slow"

## Fill in as phases are built.
const LEVELS: Array[Dictionary] = [
	{
		"id": &"phase_1",
		"scene": "res://src/levels/level_01.tscn",
		"grants": ABILITY_STOP,
	},
]

var level_index := 0
var unlocked: Array[StringName] = []

## The checkpoint the boy goes back to, and the age he had when he reached it.
## Deliberately not cleared by `start_new_run()`: that runs on every level load,
## including the reload a death triggers, which is exactly when this is needed.
var checkpoint_id: StringName = &""
var checkpoint_level: StringName = &""
var checkpoint_position := Vector2.ZERO
var checkpoint_age := 0.0

func start_new_run() -> void:
	level_index = 0
	unlocked.clear()
	_grant_for_current_level()


## Called by a Checkpoint the first time the boy passes it.
func set_checkpoint(id: StringName, position: Vector2, age: float) -> void:
	checkpoint_id = id
	checkpoint_level = current_level()["id"]
	checkpoint_position = position
	checkpoint_age = age


func is_active_checkpoint(id: StringName) -> bool:
	return checkpoint_id != &"" and checkpoint_id == id


## True once a checkpoint in this level has been reached; until then a death
## restarts the level the way it always has.
func has_checkpoint(level_id: StringName) -> bool:
	return checkpoint_id != &"" and checkpoint_level == level_id


func clear_checkpoint() -> void:
	checkpoint_id = &""
	checkpoint_level = &""
	checkpoint_position = Vector2.ZERO
	checkpoint_age = 0.0


func current_level() -> Dictionary:
	return LEVELS[clampi(level_index, 0, LEVELS.size() - 1)]


func has_ability(id: StringName) -> bool:
	return unlocked.has(id)


func advance() -> bool:
	if level_index >= LEVELS.size() - 1:
		return false
	level_index += 1
	clear_checkpoint()
	_grant_for_current_level()
	return true


func _grant_for_current_level() -> void:
	var id: StringName = current_level()["grants"]
	if not unlocked.has(id):
		unlocked.append(id)
		EventBus.ability_unlocked.emit(id)
