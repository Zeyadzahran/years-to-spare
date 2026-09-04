class_name Pickup
extends Area2D
## A fig the boy can pick up once. It goes into his satchel rather than into
## him: healing is H, deliberately, so the fruit is a decision about when to
## spend a turn standing still and not a reward for walking over it.

## Prickly pears this fig is worth. Matches the counter in the HUD.
@export var charges := 1

func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	# Anything that carries pears can pick one up; nothing else disturbs it.
	if not body.has_method(&"add_pear"):
		return
	body.add_pear(charges)
	queue_free()
