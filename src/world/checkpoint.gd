class_name Checkpoint
extends Area2D
## A place the boy is sent back to. Records where he stood when he first passed
## it, so dying costs him the ground he covered. It does not touch his age: the
## years he spent are spent, and a death that handed them back would make the
## game's only resource free.
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
	# Anything carrying an AgeComponent can arm these; anything else walks
	# through without touching them.
	if body.get(&"age") as AgeComponent == null:
		return
	# The boy respawns standing inside the one already recorded, so re-entering
	# it is not news.
	if GameState.is_active_checkpoint(name):
		return
	GameState.set_checkpoint(name, global_position)
	_marker.modulate = active_tint
