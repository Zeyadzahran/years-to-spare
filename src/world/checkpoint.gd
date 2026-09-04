class_name Checkpoint
extends Area2D
## A place the boy is sent back to. Records where he stood when he first passed
## it, so dying costs him the ground he covered. It does not touch his age: the
## years he spent are spent, and a death that handed them back would make the
## game's only resource free.
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
	# Anything carrying an AgeComponent can arm these; anything else walks
	# through without touching them.
	if body.get(&"age") as AgeComponent == null:
		return
	# The boy respawns standing inside the one already recorded, so re-entering
	# it is not news.
	if GameState.is_active_checkpoint(name):
		return
	GameState.set_checkpoint(name, global_position, age.age)
	_marker.play(&"green")
