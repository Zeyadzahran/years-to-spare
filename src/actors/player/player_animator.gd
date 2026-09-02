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
	&"Air": &"jump",
	&"Hurt": &"hurt",
	&"Dead": &"dying",
}

## Landing has its own clip, played over whichever ground state we land into.
const LAND_CLIP := &"land"

## Defaults assume this node sits under the Player alongside its StateMachine.
@export var state_machine_path: NodePath = ^"../StateMachine"

@onready var sword_audio: AudioStreamPlayer2D = $"../SwordAudio"

@onready var player: Player = get_parent() as Player
@onready var states: StateMachine = get_node(state_machine_path) as StateMachine

var _after_landing: StringName = &""

func _ready() -> void:
	states.state_changed.connect(_on_state_changed)
	animation_finished.connect(_on_animation_finished)
	_on_state_changed(&"", states.current_name)


func _process(_delta: float) -> void:
	flip_h = player.facing < 0


func _on_state_changed(from: StringName, to: StringName) -> void:
	var clip: StringName = STATE_CLIPS.get(to, &"")
	# Touching down plays the landing frames first, then hands over to the
	# ground state's own clip. Leaving Air for an air swing is not a landing.
	if from == &"Air" and player.is_on_floor() and to != &"Hurt" and to != &"Dead":
		_after_landing = clip
		_play(LAND_CLIP)
		return
	_after_landing = &""
	_play(clip)
	
	if to == &"Attack":
		if sword_audio:
			sword_audio.play()


func _on_animation_finished() -> void:
	if animation == LAND_CLIP and not _after_landing.is_empty():
		_play(_after_landing)
		_after_landing = &""


func _play(clip: StringName) -> void:
	if not clip.is_empty() and animation != clip:
		play(clip)
