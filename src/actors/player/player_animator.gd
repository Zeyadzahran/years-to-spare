class_name PlayerAnimator
extends AnimatedSprite2D
## Maps player states to clips and flips the sprite, so the states stay about
## movement and never mention an animation name.
##
## A state with no entry here keeps whatever is playing.

const STATE_CLIPS := {
	&"Idle": &"idle",
	&"Move": &"run",
	&"Attack": &"attack",
	&"Crouch": &"crouch",
}

## Defaults assume this node sits under the Player alongside its StateMachine.
@export var state_machine_path: NodePath = ^"../StateMachine"

@onready var player: Player = get_parent() as Player
@onready var states: StateMachine = get_node(state_machine_path) as StateMachine

func _ready() -> void:
	states.state_changed.connect(_on_state_changed)
	_on_state_changed(&"", states.current_name)


func _process(_delta: float) -> void:
	flip_h = player.facing < 0


func _on_state_changed(_from: StringName, to: StringName) -> void:
	var clip: StringName = STATE_CLIPS.get(to, &"")
	if not clip.is_empty() and animation != clip:
		play(clip)
