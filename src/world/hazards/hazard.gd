class_name Hazard
extends Area2D
## A damage volume wrapped around a piece of hazard art. Spikes, saws and acid
## all use this; the sprite stays a plain child so the art and the danger can be
## adjusted independently.
##
## Lethal by default - a phase-1 pit is meant to end the run, not chip at it.
## Drop `damage` below the player's max health to turn one into a chip hazard.

@export var damage := 99.0

## Seconds before the same body can be hurt again, so standing in acid does not
## drain a hit every frame.
@export var cooldown := 0.75

## Cooldown left per body, keyed by instance id rather than by the body itself:
## a typed Node2D key rejects every read and erase once that body is freed,
## which would strand the entry and error on each frame after.
var _cooldowns: Dictionary[int, float] = {}

func _ready() -> void:
	body_entered.connect(_on_body_entered)


## Left running rather than toggled off when idle, so a subclass can drive
## movement from here without the cooldown bookkeeping switching it off.
func _physics_process(delta: float) -> void:
	if _cooldowns.is_empty():
		return
	for id in _cooldowns.keys():
		_cooldowns[id] -= delta
		if _cooldowns[id] <= 0.0:
			_cooldowns.erase(id)
	# A body that never leaves keeps taking hits once its cooldown expires.
	for body in get_overlapping_bodies():
		_hurt(body)


func _on_body_entered(body: Node2D) -> void:
	_hurt(body)


func _hurt(body: Node2D) -> void:
	var id := body.get_instance_id()
	if _cooldowns.has(id):
		return
	var health := body.get(&"health") as HealthComponent
	if health == null or not health.is_alive():
		return
	_cooldowns[id] = cooldown
	health.take_damage(damage, self)
