class_name HealthComponent
extends Node
## Hit points for anything that can be hurt. Rules beyond "subtract and report"
## (armour, i-frames, damage types) belong here when the design settles.

signal damaged(amount: float, source: Node)
signal healed(amount: float)
signal changed(current: float, maximum: float)
signal died

@export var max_health := 100.0

var current: float

func _ready() -> void:
	current = max_health


func is_alive() -> bool:
	return current > 0.0


func take_damage(amount: float, source: Node = null) -> void:
	if not is_alive() or amount <= 0.0:
		return
	current = maxf(current - amount, 0.0)
	damaged.emit(amount, source)
	changed.emit(current, max_health)
	if current <= 0.0:
		died.emit()


## Fatal contacts still enter the same damaged/died signal flow as combat.
## This keeps the player death state, animation, checkpoint reload and UI as
## the only death system while avoiding arbitrary "huge damage" values.
func kill(source: Node = null) -> void:
	if not is_alive():
		return
	take_damage(current, source)


## Puts the bar at an exact value, dead or alive, for a rewind handing back the
## health he had a few seconds ago. Announced like any other change so the HUD
## follows; `damaged`/`healed` stay quiet, because nothing hit or healed him.
func restore_to(value: float) -> void:
	var next := clampf(value, 0.0, max_health)
	if is_equal_approx(next, current):
		return
	current = next
	changed.emit(current, max_health)


func heal(amount: float) -> void:
	if not is_alive() or amount <= 0.0:
		return
	current = minf(current + amount, max_health)
	healed.emit(amount)
	changed.emit(current, max_health)
