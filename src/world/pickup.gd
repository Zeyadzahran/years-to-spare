class_name Pickup
extends Area2D
## A fig. Hurt, he eats it where he stands; full, it goes into the satchel and
## the HUD counter, to be spent later on H.
##
## Both halves matter. Healing on contact is what a pickup sitting in the level
## is for, and making him press a key for it wastes the moment he actually
## needed it. But refusing the fig at full health left it inert under his feet,
## so the walk back to it was the only way to use one.

## A third of the bar, so three figs are a full heal from nothing.
@export var heal_amount := 34.0

## Prickly pears this fig is worth once banked. Matches the counter in the HUD.
@export var charges := 1

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
	if health.current < health.max_health:
		health.heal(heal_amount)
	elif body.has_method(&"add_pear"):
		body.add_pear(charges)
	else:
		return false
	$PickupAudio.play()

	# Hide/disable the fruit immediately cause they need to be synced
	visible = false
	set_physics_process(false)
	monitoring = false

	$PickupAudio.finished.connect(queue_free)
	return true
