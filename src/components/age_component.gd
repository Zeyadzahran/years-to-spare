class_name AgeComponent
extends Node
## The game's real resource. Time powers burn years; killing Cad Corp troops
## takes them back. Reaching `death_age` ends the run.

signal changed(age: float, death_age: float)
signal died

@export var start_age := 14.0
@export var death_age := 60.0

var age: float

func _ready() -> void:
	age = start_age


## 0 at the starting age, 1 at death. Drives the "older and weaker" falloff -
## currently his top speed, see Player.top_speed.
func frailty() -> float:
	return clampf((age - start_age) / maxf(death_age - start_age, 0.001), 0.0, 1.0)


func spend(amount: float) -> void:
	if amount <= 0.0 or age >= death_age:
		return
	age = minf(age + amount, death_age)
	changed.emit(age, death_age)
	if age >= death_age:
		died.emit()


## Puts the boy at an exact age, for a checkpoint handing back the years he had
## when he reached it. Announces the change like any other, so whatever listens
## for `player_age_changed` - the HUD, and the body he is wearing - follows.
func set_to(value: float) -> void:
	age = clampf(value, start_age, death_age)
	changed.emit(age, death_age)


func restore(amount: float) -> void:
	if amount <= 0.0 or age >= death_age:
		return
	age = maxf(age - amount, start_age)
	changed.emit(age, death_age)
