extends Control
## The game's closing cinematic - what plays over the fade after the boss
## instead of a plain black screen. Stills, cross-faded, with the track
## underneath; there is no narration here the way the intro has one, so
## nothing needs to be cued off a voice-over. Any key, click or controller
## button skips straight to the close - see _unhandled_input.

const MUSIC := preload("res://assets/music/paulyudin-romantic-romantic-music-573992.mp3")

## Only the four images currently in assets/cut-scene/ - "embrace" was
## removed from the set, so it is no longer listed here.
const IMAGES: Array[Texture2D] = [
	preload("res://assets/cut-scene/cutscene_01_chamber.png"),
	preload("res://assets/cut-scene/cutscene_02_escape.png"),
	preload("res://assets/cut-scene/cutscene_03_aftercare.png"),
	preload("res://assets/cut-scene/cutscene_04_fight.png"),
]

## The track runs 74.6s. A volume sweep across it (ffmpeg volumedetect, 12
## even slices) shows a quiet ~-21dB open, a rise through the teens, a swell
## peaking around -13dB at 31-37s, then a gentle taper back to ~-20dB by the
## end. Starting the cue here catches the rise into that swell rather than
## the quiet open, so the music is already building by the time the boy
## reaches her - and its own taper lands under the last image instead of
## being cut off.
const MUSIC_START := 21.0
const MUSIC_VOLUME_DB := -4.0

## Screen time per image, including the crossfade that carries it in. The
## last holds longest, as the sequence's resting beat. One entry per image
## above - trimmed again (from [7.5, 7.5, 7.5, 7.5, 9.5]) both because a
## shorter, four-image sequence reads slack at the old pace and because the
## remaining images should move a little faster still. Crossfades, music and
## everything else are untouched.
const IMAGE_HOLD := [6.0, 6.0, 6.0, 8.0]
const CROSSFADE_DURATION := 2.0
const OPENING_FADE_DURATION := 2.0
const CLOSING_FADE_DURATION := 3.0

## Same "black screen, then title" scene the game already opens Level 1 with
## (src/ui/level_title/level_title.gd) - reused rather than duplicated, just
## pointed at Level 2 instead. Played whether the cutscene finished on its
## own or was skipped, so there is never a path back to the boss arena.
const LEVEL_2_TITLE_SCENE := "res://src/ui/level_title/city_of_time_title.tscn"

@onready var image_back: TextureRect = $ImageBack
@onready var image_front: TextureRect = $ImageFront
@onready var fade: ColorRect = $Fade

var _skipped := false
var _finished := false


func _ready() -> void:
	image_back.texture = IMAGES[0]
	image_front.modulate.a = 0.0
	fade.color.a = 1.0

	MusicManager.play_music(MUSIC, OPENING_FADE_DURATION, MUSIC_VOLUME_DB, MUSIC_START)

	var opening := create_tween()
	opening.tween_property(fade, ^"color:a", 0.0, OPENING_FADE_DURATION).set_trans(Tween.TRANS_SINE)
	await opening.finished
	if _skipped:
		return

	for i in range(1, IMAGES.size()):
		await get_tree().create_timer(IMAGE_HOLD[i - 1] - CROSSFADE_DURATION).timeout
		if _skipped:
			return
		await _crossfade_to(IMAGES[i])
		if _skipped:
			return

	await get_tree().create_timer(IMAGE_HOLD[-1] - CLOSING_FADE_DURATION).timeout
	if _skipped:
		return

	await _finish()


## Any actual press - key, mouse button or controller button - skips the rest
## of the sequence. Motion events (mouse move, joystick tilt) do not count.
func _unhandled_input(event: InputEvent) -> void:
	if _skipped or _finished:
		return
	var is_press: bool = (event is InputEventKey and event.pressed and not event.echo) \
		or (event is InputEventMouseButton and event.pressed) \
		or (event is InputEventJoypadButton and event.pressed)
	if not is_press:
		return
	get_viewport().set_input_as_handled()
	_skipped = true
	_finish()


## Fades the next image in over the back layer, then folds it down onto that
## layer so the front stays clear (alpha 0) and ready for the next cut.
func _crossfade_to(next_image: Texture2D) -> void:
	image_front.texture = next_image
	image_front.modulate.a = 0.0
	var crossfade := create_tween()
	crossfade.tween_property(image_front, ^"modulate:a", 1.0, CROSSFADE_DURATION)
	await crossfade.finished
	if _skipped:
		return
	image_back.texture = next_image
	image_front.modulate.a = 0.0


## Reached either by playing out naturally or by a skip - both close the same
## way and land on the same Level 2 intro, so there is only ever one path
## out of this scene.
func _finish() -> void:
	if _finished:
		return
	_finished = true
	MusicManager.stop_music(CLOSING_FADE_DURATION)
	var closing := create_tween()
	closing.tween_property(fade, ^"color:a", 1.0, CLOSING_FADE_DURATION).set_trans(Tween.TRANS_SINE)
	await closing.finished
	get_tree().change_scene_to_file(LEVEL_2_TITLE_SCENE)
