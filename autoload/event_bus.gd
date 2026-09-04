extends Node
## Global signal contract. Systems talk through here instead of holding
## references to each other, so UI, audio and gameplay stay decoupled.
##
## Add signals as features land; nothing here should ever gain logic.

signal player_spawned(player: Node2D)
signal player_health_changed(current: float, maximum: float)
signal player_heals_changed(count: int)
## `of_old_age` separates the two ways the run can end. Running out of health
## costs the boy the ground he covered; running out of years is the end of him,
## and the level starts over from the top rather than from a checkpoint.
signal player_died(of_old_age: bool)

signal player_age_changed(age: float, death_age: float)

signal enemy_died(enemy: Node2D, age_reward: float)

signal ability_unlocked(ability_id: StringName)
## Pressed and paid for: the boy starts his flourish, the world still running.
signal ability_started(ability_id: StringName)
## The flourish has landed and the world has actually changed. This, not
## `ability_started`, is the moment the screen should react to.
signal ability_engaged(ability_id: StringName, duration: float)
signal ability_stopped(ability_id: StringName)
## A press that could not be paid for. Carries how many more years the boy would
## have needed, so the HUD can say why nothing happened.
signal ability_refused(ability_id: StringName, missing_years: float)

signal time_mode_changed(mode: int)

signal level_started(level_id: StringName)
signal level_completed(level_id: StringName)
