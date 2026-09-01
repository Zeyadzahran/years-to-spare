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
		"scene": "res://src/levels/test_level.tscn",
		"grants": ABILITY_STOP,
	},
]

var level_index := 0
var unlocked: Array[StringName] = []

func start_new_run() -> void:
	level_index = 0
	unlocked.clear()
	_grant_for_current_level()


func current_level() -> Dictionary:
	return LEVELS[clampi(level_index, 0, LEVELS.size() - 1)]


func has_ability(id: StringName) -> bool:
	return unlocked.has(id)


func advance() -> bool:
	if level_index >= LEVELS.size() - 1:
		return false
	level_index += 1
	_grant_for_current_level()
	return true


func _grant_for_current_level() -> void:
	var id: StringName = current_level()["grants"]
	if not unlocked.has(id):
		unlocked.append(id)
		EventBus.ability_unlocked.emit(id)
