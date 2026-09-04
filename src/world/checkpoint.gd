class_name Checkpoint
extends Area2D
## A place the boy is sent back to. Records where he stood and the age he had
## when he first passed it, so dying costs him the ground he covered but not the
## years he spent covering it.
##
## Detection, shape and art are authored in the scene. The only part that needs
## code is handing the pair to GameState: a death reloads the level, so the
## record has to outlive this node.

@onready var _marker: AnimatedSprite2D = $Marker

func _ready() -> void:
	# Respawning rebuilds the level, so the one that is already recorded has to
	# come back lit rather than dormant.
	_marker.play(&"green" if GameState.is_active_checkpoint(name) else &"red")


## Wired from this Area2D's body_entered in the scene.
func _on_body_entered(body: Node2D) -> void:
	# Only the age is read off the body, so anything carrying an AgeComponent
	# can use these; anything else walks through without arming them.
	var age := body.get(&"age") as AgeComponent
	if age == null:
		return
	# Re-entering the one already recorded must not overwrite it: the boy
	# respawns standing inside it, and it would bank whatever age he died at.
	if GameState.is_active_checkpoint(name):
		return
	GameState.set_checkpoint(name, global_position, age.age)
	_marker.play(&"green")
