class_name HealthComponent
extends Node
## Hit points for anything that can be hurt. Rules beyond "subtract and report"
## (armour, i-frames, damage types) belong here when the design settles.

signal damaged(amount: float, source: Node)
signal healed(amount: float)
signal changed(current: float, maximum: float)
signal died

@export var max_health := 3.0

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


func heal(amount: float) -> void:
	if not is_alive() or amount <= 0.0:
		return
	current = minf(current + amount, max_health)
	healed.emit(amount)
	changed.emit(current, max_health)
