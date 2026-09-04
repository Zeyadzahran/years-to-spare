class_name Pickup
extends Area2D
## A fig the boy can pick up once. Heals him immediately through his own
## HealthComponent; full HP leaves it alone, so a fig is never wasted.

@export var heal_amount := 34.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	var health := body.get(&"health") as HealthComponent
	if health == null or health.current >= health.max_health:
		return
	health.heal(heal_amount)
	queue_free()
