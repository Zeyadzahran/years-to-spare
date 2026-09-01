class_name Enemy
extends TimeBody2D
## Base for every Cad Corp unit: health, death and the time-obeying tick.
## Guard, Gunner and Charger subclass this and implement `_tick` only.

## Years the player takes back for killing this unit.
@export var age_reward := 2.0

@onready var health: HealthComponent = $Health

func _ready() -> void:
	add_to_group(&"enemy")
	health.died.connect(_on_died)


func _physics_process(delta: float) -> void:
	var scaled := world_delta(delta)
	if is_zero_approx(scaled):
		return
	apply_gravity(scaled)
	_tick(scaled)
	move_in_time()


## Subclass AI. `delta` is already scaled by the player's time powers.
func _tick(_delta: float) -> void:
	pass


func _on_died() -> void:
	EventBus.enemy_died.emit(self, age_reward)
	queue_free()
