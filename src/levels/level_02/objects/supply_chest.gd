extends Area2D
## A visible supply cache. Opens on contact only when its healing is useful.
@export_range(1.0, 100.0, 1.0) var heal_amount := 50.0
var opened := false

func _physics_process(_delta: float) -> void:
	if opened:
		return
	for body in get_overlapping_bodies():
		if body is Player and body.health.is_alive() and body.health.current < body.health.max_health:
			body.health.heal(heal_amount)
			opened = true
			$Art.frame = 3
			$OpenAudio.play()
			return
