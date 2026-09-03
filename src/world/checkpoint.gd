class_name Checkpoint
extends Area2D
## A place the boy is sent back to. Records where he stood and the age he had
## when he first passed it, so dying costs him the ground he covered but not the
## years he spent covering it.
##
## Detection, shape, art and both tints are authored in the scene and the
## Inspector. The only part that needs code is handing the pair to GameState:
## a death reloads the level, so the record has to outlive this node.

## How the marker reads before and after it takes. Tune in the Inspector.
@export var idle_tint := Color(0.85, 0.95, 1.1)
@export var active_tint := Color(0.45, 1.35, 1.05)

@onready var _marker: Sprite2D = $Marker

func _ready() -> void:
	# Respawning rebuilds the level, so the one that is already recorded has to
	# come back lit rather than dormant.
	_marker.modulate = active_tint if GameState.is_active_checkpoint(name) else idle_tint


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
	_marker.modulate = active_tint
