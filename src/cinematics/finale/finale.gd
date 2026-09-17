extends Control
## The game's final cinematic: the walk to the parents chamber ends on a fade,
## and this picks it up - stills from assets/cut-scene-l02 in their numbered
## order, cross-faded with the track underneath, then a black-screen line,
## the credits, then THE END. Enter skips everything and lands on THE END;
## another Enter there leaves for the main menu. Clicks and taps never skip.

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
const SUBTITLE_HOLD := 4.5
const CREDITS_HOLD := 6.0
const END_TITLE_FADE_DURATION := 2.0

const MAIN_MENU_SCENE := "res://src/ui/main_menu/main_menu.tscn"

@onready var image_back: TextureRect = $ImageBack
@onready var image_front: TextureRect = $ImageFront
@onready var fade: ColorRect = $Fade
@onready var end_subtitle: Label = $EndSubtitle
@onready var end_title: Label = $EndTitle
@onready var end_hint: Label = $EndHint
@onready var clock: AudioStreamPlayer = $Clock
@onready var enter_hint: Label = $EnterHint
@onready var credits_box: CenterContainer = $Credits

## Set by Enter: abandons the stills, line and credits and lands on THE END.
var _skip := false
var _on_end_card := false
var _finished := false


func _ready() -> void:
	image_back.texture = IMAGES[0]
	image_front.modulate.a = 0.0
	credits_box.modulate.a = 0.0
	end_subtitle.modulate.a = 0.0
	end_title.modulate.a = 0.0
	end_hint.modulate.a = 0.0
	fade.color.a = 1.0

	MusicManager.play_music(MUSIC, OPENING_FADE_DURATION, MUSIC_VOLUME_DB, MUSIC_START)

	var opening := create_tween()
	opening.tween_property(fade, ^"color:a", 0.0, OPENING_FADE_DURATION).set_trans(Tween.TRANS_SINE)
	await opening.finished
	if _finished:
		return
	await _play_images()
	if _finished:
		return
	if not _skip:
		await _fade_to_black()
		if _finished:
			return
		await _show_black_subtitle()
		if _finished:
			return
		await _show_credits()
		if _finished:
			return
	await _show_end_title()


## Enter - and only Enter - skips everything and lands on THE END; another
## Enter there leaves for the main menu. Clicks, taps and controller buttons
## never skip, so the stills cannot be lost to a stray press.
func _unhandled_input(event: InputEvent) -> void:
	if _finished:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ENTER:
		get_viewport().set_input_as_handled()
		if _on_end_card:
			_finish()
		else:
			_skip = true


## A beat that Enter can cut short on the way to THE END.
func _wait_beat(seconds: float) -> void:
	var left := seconds
	while left > 0.0 and not _skip and not _finished:
		await get_tree().create_timer(minf(0.1, left)).timeout
		left -= 0.1


func _play_images() -> void:
	for i in range(1, IMAGES.size()):
		await _wait_beat(IMAGE_HOLD[i - 1] - CROSSFADE_DURATION)
		if _skip or _finished:
			return
		await _crossfade_to(IMAGES[i])
		if _skip or _finished:
			return
	await _wait_beat(IMAGE_HOLD[-1] - CLOSING_FADE_DURATION)


## Fades the next image in over the back layer, then folds it down onto that
## layer so the front stays clear (alpha 0) and ready for the next cut.
func _crossfade_to(next_image: Texture2D) -> void:
	if _finished or not is_instance_valid(image_front):
		return
	image_front.texture = next_image
	image_front.modulate.a = 0.0
	var crossfade := create_tween()
	crossfade.tween_property(image_front, ^"modulate:a", 1.0, CROSSFADE_DURATION)
	await _wait_beat(CROSSFADE_DURATION)
	if _finished or not is_instance_valid(image_back):
		return
	if crossfade != null and crossfade.is_valid():
		crossfade.kill()
	image_back.texture = next_image
	image_front.modulate.a = 0.0


func _fade_to_black() -> void:
	MusicManager.stop_music(CLOSING_FADE_DURATION)
	var closing := create_tween()
	closing.tween_property(fade, ^"color:a", 1.0, CLOSING_FADE_DURATION).set_trans(Tween.TRANS_SINE)
	await closing.finished


## The quiet beat on black before the title: one low line, held long enough
## to read, stepping to THE END on the next press.
func _show_black_subtitle() -> void:
	if _finished or not is_instance_valid(end_subtitle):
		return
	# The music is gone; the clock ticks under the line instead. Looped here
	# rather than in the import, the way level tracks are, so the file stays
	# a plain asset.
	if clock.stream is AudioStreamMP3:
		clock.stream.loop = true
	clock.play()
	end_subtitle.modulate.a = 0.0
	var show := create_tween()
	show.tween_property(end_subtitle, ^"modulate:a", 1.0, 1.0).set_trans(Tween.TRANS_SINE)
	await show.finished
	if _finished:
		return
	await _wait_beat(SUBTITLE_HOLD)
	if _finished or not is_instance_valid(end_subtitle):
		return
	var hide := create_tween()
	hide.tween_property(end_subtitle, ^"modulate:a", 0.0, 0.6)
	await hide.finished


## The credits on black before the title: the team, held long enough to
## read, stepping to THE END on the next press.
func _show_credits() -> void:
	if _finished or not is_instance_valid(credits_box):
		return
	credits_box.modulate.a = 0.0
	var show := create_tween()
	show.tween_property(credits_box, ^"modulate:a", 1.0, 1.5).set_trans(Tween.TRANS_SINE)
	await show.finished
	if _finished:
		return
	await _wait_beat(CREDITS_HOLD)
	if _finished or not is_instance_valid(credits_box):
		return
	var hide := create_tween()
	hide.tween_property(credits_box, ^"modulate:a", 0.0, 1.0)
	await hide.finished


## The black screen with the end on it. Waits here for Enter before leaving
## for the menu. Landing here by skip covers the frozen frame instantly -
## music, clock, line and credits all cut - instead of fading over it.
func _show_end_title() -> void:
	if _on_end_card or _finished:
		return
	_on_end_card = true
	clock.stop()
	enter_hint.hide()
	if _skip:
		MusicManager.stop_music(1.0)
		fade.color.a = 1.0
		end_subtitle.modulate.a = 0.0
		credits_box.modulate.a = 0.0
		image_front.modulate.a = 0.0
	var title := create_tween().set_parallel()
	title.tween_property(end_title, ^"modulate:a", 1.0, END_TITLE_FADE_DURATION).set_trans(Tween.TRANS_SINE)
	title.tween_property(end_hint, ^"modulate:a", 0.65, END_TITLE_FADE_DURATION).set_trans(Tween.TRANS_SINE)
	await title.finished


func _finish() -> void:
	if _finished:
		return
	_finished = true
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)
