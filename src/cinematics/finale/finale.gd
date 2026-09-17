extends Control
## The game's final cinematic: the walk to the parents chamber ends on a fade,
## and this picks it up - stills from assets/cut-scene-l02 in their numbered
## order, cross-faded with the track underneath, then a black screen with
## THE END. Any key, click or controller button skips the stills and lands on
## THE END; another press there leaves for the main menu.

const MUSIC := preload("res://assets/music/paulyudin-romantic-romantic-music-573992.mp3")

## Numbered story order: freed, happy, tired, going away.
const IMAGES: Array[Texture2D] = [
	preload("res://assets/cut-scene-l02/freed-1.jpg"),
	preload("res://assets/cut-scene-l02/happy-2.jpg"),
	preload("res://assets/cut-scene-l02/tired-3.jpg"),
	preload("res://assets/cut-scene-l02/goingaway-4.jpg"),
]

## Same pacing as the level 1 ending: screen time per image including the
## crossfade that carries it in, the last holding longest as the resting beat.
const MUSIC_START := 21.0
const MUSIC_VOLUME_DB := -4.0
const IMAGE_HOLD := [6.0, 6.0, 6.0, 8.0]
const CROSSFADE_DURATION := 2.0
const OPENING_FADE_DURATION := 2.0
const CLOSING_FADE_DURATION := 3.0
const END_TITLE_FADE_DURATION := 2.0

const MAIN_MENU_SCENE := "res://src/ui/main_menu/main_menu.tscn"

@onready var image_back: TextureRect = $ImageBack
@onready var image_front: TextureRect = $ImageFront
@onready var fade: ColorRect = $Fade
@onready var end_title: Label = $EndTitle
@onready var end_hint: Label = $EndHint

var _skipped := false
var _on_end_card := false
var _finished := false


func _ready() -> void:
	image_back.texture = IMAGES[0]
	image_front.modulate.a = 0.0
	end_title.modulate.a = 0.0
	end_hint.modulate.a = 0.0
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

	await _show_end_card()


## Any actual press - key, mouse button or controller button. On the stills it
## skips ahead to THE END; on THE END it leaves for the main menu. Motion
## events (mouse move, joystick tilt) do not count.
func _unhandled_input(event: InputEvent) -> void:
	if _finished:
		return
	var is_press: bool = (event is InputEventKey and event.pressed and not event.echo) \
		or (event is InputEventMouseButton and event.pressed) \
		or (event is InputEventJoypadButton and event.pressed)
	if not is_press:
		return
	get_viewport().set_input_as_handled()
	if _on_end_card:
		_finish()
	else:
		_skipped = true
		_show_end_card()


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


## The black screen with the end on it. Reached by playing out naturally or
## by a skip - both wait here for a press before leaving for the menu.
func _show_end_card() -> void:
	if _on_end_card:
		return
	_on_end_card = true
	MusicManager.stop_music(CLOSING_FADE_DURATION)
	var closing := create_tween()
	closing.tween_property(fade, ^"color:a", 1.0, CLOSING_FADE_DURATION).set_trans(Tween.TRANS_SINE)
	await closing.finished
	var title := create_tween().set_parallel()
	title.tween_property(end_title, ^"modulate:a", 1.0, END_TITLE_FADE_DURATION).set_trans(Tween.TRANS_SINE)
	title.tween_property(end_hint, ^"modulate:a", 0.65, END_TITLE_FADE_DURATION).set_trans(Tween.TRANS_SINE)
	await title.finished


func _finish() -> void:
	if _finished:
		return
	_finished = true
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)
