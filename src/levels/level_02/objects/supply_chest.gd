extends Area2D
## A visible supply cache. Opens on contact only when its healing is useful.
@export_range(1.0, 100.0, 1.0) var heal_amount := 50.0
var opened := false

func _ready() -> void:
	add_to_group(TimeService.REWINDABLE_GROUP)


## Opened and used up, or still shut: a rewind past the moment he reached it
## closes it again, and the health it gave goes back with his own snapshot.
func rewind_capture() -> Array:
	return [opened, $Art.frame]


func rewind_apply(saved: Array) -> void:
	opened = saved[0]
	$Art.frame = saved[1]


func _physics_process(_delta: float) -> void:
	if opened or TimeService.is_rewinding():
		return
	for body in get_overlapping_bodies():
		if body is Player and body.health.is_alive() and body.health.current < body.health.max_health:
			body.health.heal(heal_amount)
			opened = true
			$Art.frame = 3
			$OpenAudio.play()
			return
