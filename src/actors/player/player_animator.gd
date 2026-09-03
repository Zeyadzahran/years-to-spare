class_name PlayerAnimator
extends AnimatedSprite2D
## Maps player states to clips, flips the sprite, and dresses the boy in the age
## he has spent, so the states stay about movement and never mention an
## animation name.
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

## The golden clock energy. A power is held rather than fired, so it loops.
const POWER_CLIP := &"power"

## Defaults assume this node sits under the Player alongside its StateMachine.
@export var state_machine_path: NodePath = ^"../StateMachine"

@export_group("Ageing")
## Spending years is meant to show: the GDD has the powers "subtly changing his
## face, hair, and body over time". These are the three sets drawn for that. He
## wears whichever his current age falls into - and wears it back down when
## killing troops buys years back, so the change reads in both directions.
@export var teen_frames: SpriteFrames = preload("res://src/actors/player/player_frames.tres")
@export var adult_frames: SpriteFrames = preload("res://src/actors/player/player_adult_frames.tres")
@export var elder_frames: SpriteFrames = preload("res://src/actors/player/player_elder_frames.tres")
## Roughly even thirds of the 14-to-60 run. Picked to be tuned, not measured.
@export var adult_age := 30.0
@export var elder_age := 45.0

@onready var sword_audio: AudioStreamPlayer2D = $"../SwordAudio"
## Loops for as long as the run clip does; the stream itself is imported
## looping, so starting and stopping it is all this needs to do.
@onready var run_audio: AudioStreamPlayer2D = $"../RunAudio"
@onready var time_stop_audio: AudioStreamPlayer2D = $"../TimeStopAudio"

@onready var player: Player = get_parent() as Player
@onready var states: StateMachine = get_node(state_machine_path) as StateMachine

var _after_landing: StringName = &""
var _channelling := false

func _ready() -> void:
	states.state_changed.connect(_on_state_changed)
	animation_finished.connect(_on_animation_finished)
	# Through the bus rather than the components: Player wires its own @onready
	# references after its children are ready, so reaching for player.age from
	# here would race it.
	EventBus.player_age_changed.connect(_on_age_changed)
	EventBus.ability_started.connect(_on_ability_changed.bind(true))
	EventBus.ability_stopped.connect(_on_ability_changed.bind(false))
	_on_state_changed(&"", states.current_name)
	# A frame later every _ready upstream has run and the starting age is real.
	_sync_form.call_deferred()


func _process(_delta: float) -> void:
	flip_h = player.facing < 0


func _sync_form() -> void:
	if player != null and player.age != null:
		_wear(_frames_for(player.age.age))


func _frames_for(age: float) -> SpriteFrames:
	if age >= elder_age:
		return elder_frames
	if age >= adult_age:
		return adult_frames
	return teen_frames


## Assigning a new library restarts playback at frame 0, which would jolt the
## boy mid-stride every time he crosses an age line, so the clip and how far
## through it he is are carried across.
func _wear(frames: SpriteFrames) -> void:
	if frames == null or frames == sprite_frames:
		return
	var clip := animation
	var index := frame
	var progress := frame_progress
	var was_playing := is_playing()
	sprite_frames = frames
	if not frames.has_animation(clip):
		return
	if was_playing:
		play(clip)
	else:
		animation = clip
	set_frame_and_progress(clampi(index, 0, maxi(frames.get_frame_count(clip) - 1, 0)), progress)


func _on_age_changed(age: float, _death_age: float) -> void:
	_wear(_frames_for(age))


func _on_ability_changed(ability_id: StringName, active: bool) -> void:
	# Only holding the world still gets its own sound, and it is left to ring
	# out rather than cut on release - a clipped whoosh reads as a glitch.
	if active and ability_id == GameState.ABILITY_STOP:
		time_stop_audio.play()
	if _channelling == active:
		return
	_channelling = active
	# Only the standing pose gives way to the aura. He still runs, jumps and
	# swings while the world is held still - that contrast is the whole game -
	# so those clips are never taken over.
	if states.current_name == &"Idle":
		_play(_clip_for(&"Idle"))


func _clip_for(state: StringName) -> StringName:
	if state == &"Idle" and _channelling:
		return POWER_CLIP
	return STATE_CLIPS.get(state, &"")


func _on_state_changed(from: StringName, to: StringName) -> void:
	var clip := _clip_for(to)
	# Touching down plays the landing frames first, then hands over to the
	# ground state's own clip. Leaving Air for an air swing is not a landing.
	if from == &"Air" and player.is_on_floor() and to != &"Hurt" and to != &"Dead":
		_after_landing = clip
		_play(LAND_CLIP)
		return
	_after_landing = &""
	_play(clip)

	if to == &"Attack":
		sword_audio.play()


func _on_animation_finished() -> void:
	if animation == LAND_CLIP and not _after_landing.is_empty():
		# Recomputed rather than replayed: a power may have started during the
		# landing frames.
		_play(_clip_for(states.current_name))
		_after_landing = &""


func _play(clip: StringName) -> void:
	if not clip.is_empty() and animation != clip:
		play(clip)
	_sync_footsteps()


## Footsteps follow the run clip rather than the Move state, so the landing
## frames the boy runs out of stay silent until the stride actually starts.
func _sync_footsteps() -> void:
	if animation == STATE_CLIPS[&"Move"]:
		if not run_audio.playing:
			run_audio.play()
	else:
		run_audio.stop()
