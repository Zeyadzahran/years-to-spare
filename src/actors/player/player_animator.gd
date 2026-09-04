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

## The golden clock energy. All three libraries ship it looping, from when a
## power was something you held down; a cast is one press, so it plays once and
## hands the boy back to standing. Turned off here rather than in the three
## .tres files so that re-exporting the art cannot quietly switch it back on.
const POWER_CLIP := &"power"

## jumb.mp3 is a sheet of several takes; the one we want starts two seconds in
## and runs until the recording drops back to room tone. There is no sub-clip
## resource for MP3, so playback starts at the offset and is cut at the end of
## the take in _process.
const JUMP_FROM := 2.0
const JUMP_LENGTH := 0.95

## One voice per body. The boy has not broken yet; the man and the elder share
## the older take.
const BOY_HURT := preload("res://assets/sounds/boy-hurt.mp3")
const MAN_HURT := preload("res://assets/sounds/young-man-hurt.mp3")

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
## No stream authored on the node: which of him is heard is decided per hit.
@onready var hurt_audio: AudioStreamPlayer2D = $"../HurtAudio"
@onready var jump_audio: AudioStreamPlayer2D = $"../JumpAudio"

@onready var player: Player = get_parent() as Player
@onready var states: StateMachine = get_node(state_machine_path) as StateMachine

var _after_landing: StringName = &""
var _channelling := false
## Whether this cast's flourish has already run. The world stays stopped for
## seconds after it; the tint and the dial are what carry the rest of the window.
var _power_spent := false

func _ready() -> void:
	states.state_changed.connect(_on_state_changed)
	player.jumped.connect(_on_jumped)
	animation_finished.connect(_on_animation_finished)
	# Through the bus rather than the components: Player wires its own @onready
	# references after its children are ready, so reaching for player.age from
	# here would race it.
	EventBus.player_age_changed.connect(_on_age_changed)
	EventBus.ability_started.connect(_on_ability_changed.bind(true))
	EventBus.ability_stopped.connect(_on_ability_changed.bind(false))
	for frames in [teen_frames, adult_frames, elder_frames]:
		if frames != null and frames.has_animation(POWER_CLIP):
			frames.set_animation_loop(POWER_CLIP, false)
	_on_state_changed(&"", states.current_name)
	# A frame later every _ready upstream has run and the starting age is real.
	_sync_form.call_deferred()


func _process(_delta: float) -> void:
	flip_h = player.facing < 0
	if jump_audio.playing and jump_audio.get_playback_position() >= JUMP_FROM + JUMP_LENGTH:
		jump_audio.stop()


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
	if active:
		_power_spent = false
	# Only the standing pose gives way to the aura. He still runs, jumps and
	# swings while the world is held still - that contrast is the whole game -
	# so those clips are never taken over.
	if states.current_name == &"Idle":
		_play(_clip_for(&"Idle"))


func _clip_for(state: StringName) -> StringName:
	if state == &"Idle" and _channelling and not _power_spent:
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
	elif to == &"Hurt":
		# Restarted rather than left to finish: a second hit during the first
		# grunt should sound like a second hit.
		hurt_audio.stream = _hurt_stream()
		hurt_audio.play()


func _on_jumped() -> void:
	jump_audio.play(JUMP_FROM)


## The voice follows the body rather than the age directly, so whichever set of
## frames he is wearing is the one heard - the two can never disagree, however
## the age thresholds are retuned.
func _hurt_stream() -> AudioStream:
	return BOY_HURT if sprite_frames == teen_frames else MAN_HURT


func _on_animation_finished() -> void:
	if animation == POWER_CLIP:
		# It has had its one time. Whatever he is doing now gets its own clip
		# back, even though the power is still running.
		_power_spent = true
		_play(_clip_for(states.current_name))
		return
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
