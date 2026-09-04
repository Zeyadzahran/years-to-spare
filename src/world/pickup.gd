class_name Pickup
extends Area2D
## A fig. Walking into it heals him - there is nothing to carry, nothing to
## press and nothing to read off the HUD.
##
## It was briefly a charge you banked and spent with a key, which put a counter
## on screen and a decision in the way of a pickup that is already sitting where
## the level put it. The placement is the decision; picking it up is not.

## A third of the bar, so three figs are a full heal from nothing.
@export var heal_amount := 34.0

## Overlap is polled rather than taken off `body_entered`, the same way Hazard
## keeps hurting a body that never leaves it. Entering is not the only moment
## that matters here: a boy standing on a fig at full health who then takes a
## hit has already entered, and the fig would sit under his feet doing nothing
## until he stepped off and back on.
func _physics_process(_delta: float) -> void:
	for body in get_overlapping_bodies():
		if _take(body):
			return


func _take(body: Node2D) -> bool:
	var health := body.get(&"health") as HealthComponent
	if health == null or not health.is_alive():
		return false
	# Left where it is for someone who actually needs it. Walking over a fig at
	# full health should not quietly waste it.
	if health.current >= health.max_health:
		return false
	health.heal(heal_amount)
	
	$PickupAudio.play()
	
	# Hide/disable the fruit immediately cause they need to be synced
	visible = false
	set_physics_process(false)
	monitoring = false

	$PickupAudio.finished.connect(queue_free)
	
	return true
