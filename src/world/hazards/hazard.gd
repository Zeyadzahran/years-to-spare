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

var _cooldowns: Dictionary[Node2D, float] = {}

func _ready() -> void:
	set_physics_process(false)
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	if _cooldowns.is_empty():
		set_physics_process(false)
		return
	for body in _cooldowns.keys():
		_cooldowns[body] -= delta
		if _cooldowns[body] <= 0.0 or not is_instance_valid(body):
			_cooldowns.erase(body)
	# A body that never leaves keeps taking hits once its cooldown expires.
	for body in get_overlapping_bodies():
		_hurt(body)


func _on_body_entered(body: Node2D) -> void:
	_hurt(body)


func _hurt(body: Node2D) -> void:
	if _cooldowns.has(body):
		return
	var health := body.get(&"health") as HealthComponent
	if health == null or not health.is_alive():
		return
	_cooldowns[body] = cooldown
	set_physics_process(true)
	health.take_damage(damage, self)
