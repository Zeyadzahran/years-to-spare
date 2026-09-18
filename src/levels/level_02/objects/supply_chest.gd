extends Area2D
## A visible supply cache. Opens on contact only when what is inside is useful:
## its healing, or the heart it holds - a HeartPickup child named `Heart`,
## stowed, which springs out when the lid opens. The two are separate: a lid
## opened for the heart at full health leaves the healing in the box for
## whenever he comes back hurt. A heart already taken on an earlier try is
## gone from the box before the level's first frame, so that chest is back to
## healing only.
@export_range(1.0, 100.0, 1.0) var heal_amount := 50.0
var opened := false
var healed := false

func _ready() -> void:
	add_to_group(TimeService.REWINDABLE_GROUP)


## Opened and used up, or still shut: a rewind past the moment he reached it
## closes it again, and the health it gave goes back with his own snapshot.
## The heart it holds keeps its own snapshot and stows itself.
func rewind_capture() -> Array:
	return [opened, $Art.frame, healed]


func rewind_apply(saved: Array) -> void:
	opened = saved[0]
	$Art.frame = saved[1]
	healed = saved[2]


func _physics_process(_delta: float) -> void:
	if (opened and healed) or TimeService.is_rewinding():
		return
	for body in get_overlapping_bodies():
		if not (body is Player) or not body.health.is_alive():
			continue
		var heart := _heart()
		var hurt: bool = body.health.current < body.health.max_health
		var gives: bool = heart != null and GameState.hearts < GameState.HEART_CAP
		if not opened and (hurt or gives):
			opened = true
			$Art.frame = 3
			$OpenAudio.play()
			if heart != null:
				heart.release()
		if opened and hurt and not healed:
			healed = true
			body.health.heal(heal_amount)
		return


## Looked up when needed rather than held: the level removes a heart already
## taken before the first frame, after this node is ready.
func _heart() -> HeartPickup:
	return get_node_or_null(^"Heart") as HeartPickup
