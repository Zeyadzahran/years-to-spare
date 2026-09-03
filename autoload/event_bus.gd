extends Node
## Global signal contract. Systems talk through here instead of holding
## references to each other, so UI, audio and gameplay stay decoupled.
##
## Add signals as features land; nothing here should ever gain logic.

signal player_spawned(player: Node2D)
signal player_health_changed(current: float, maximum: float)
signal player_heals_changed(count: int)
signal player_died

signal player_age_changed(age: float, death_age: float)

signal enemy_died(enemy: Node2D, age_reward: float)

signal ability_unlocked(ability_id: StringName)
signal ability_started(ability_id: StringName)
signal ability_stopped(ability_id: StringName)

signal time_mode_changed(mode: int)

signal level_started(level_id: StringName)
signal level_completed(level_id: StringName)
