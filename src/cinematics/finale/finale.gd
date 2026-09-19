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

## The boy's closing narration, running under the stills. Times are the speech
## boundaries measured from boy-finale-vo.mp3 (ffmpeg silencedetect at -45 dB):
## start is the end of the preceding silence, end is the start of the next one.
const SUBTITLE_CUES: Array[Dictionary] = [
	{"start": 0.00, "end": 2.65, "text": "I waited so long for those doors to open."},
	{"start": 5.23, "end": 6.65, "text": "My mom held me first."},
	{"start": 8.14, "end": 9.29, "text": "She said I got old."},
	{"start": 9.92, "end": 10.95, "text": "I just let her hold me."},
	{"start": 12.79, "end": 14.08, "text": "I knelt there for a second."},
	{"start": 15.27, "end": 17.59, "text": "Just one second, where I didn't have to be strong."},
	{"start": 19.56, "end": 20.81, "text": "Then we walked out together."},
	{"start": 22.24, "end": 23.00, "text": "I don't know where."},
	{"start": 24.08, "end": 25.23, "text": "I don't think it matters."},
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
@onready var subtitle: RichTextLabel = $CinematicText/Subtitle
@onready var end_subtitle: Label = $EndSubtitle
@onready var end_title: Label = $EndTitle
@onready var end_hint: Label = $EndHint
@onready var clock: AudioStreamPlayer = $Clock
@onready var voice_over: AudioStreamPlayer = $VoiceOver
@onready var enter_hint: Label = $EnterHint
@onready var credits_box: CenterContainer = $Credits

## Set by Enter: abandons the stills, line and credits and lands on THE END.
var _skip := false
var _on_end_card := false
var _finished := false
var _current_cue := -1


func _ready() -> void:
	image_back.texture = IMAGES[0]
	image_front.modulate.a = 0.0
	credits_box.modulate.a = 0.0
	end_subtitle.modulate.a = 0.0
	end_title.modulate.a = 0.0
	end_hint.modulate.a = 0.0
	subtitle.modulate.a = 0.0
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
	_sync_subtitles()
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
			voice_over.stop()
			_hide_subtitle()


## A beat that Enter can cut short on the way to THE END. Also nudges the
## narration subtitles along, sourced from the voice-over's playback position.
func _wait_beat(seconds: float) -> void:
	var left := seconds
	while left > 0.0 and not _skip and not _finished:
		await get_tree().create_timer(minf(0.1, left)).timeout
		left -= 0.1
		_sync_subtitles()


func _play_images() -> void:
	voice_over.play()
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
	# The narration ends a beat after the stills do; keep its last line syncing
	# across the final fade instead of leaving it cut off.
	while _finished == false and !_skip and voice_over.playing:
		_sync_subtitles()
		await get_tree().create_timer(0.1).timeout
	# Playback resets when the voice ends, so its last cue may never expire.
	# Retire the narration before the separate closing line appears.
	subtitle.hide()
	if closing.is_running():
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


## Looks up the current narration line from the voice-over's playback position
## and shows or hides it in step with the speech.
func _sync_subtitles() -> void:
	if _finished or _skip or not voice_over.playing or not is_instance_valid(subtitle):
		return
	var position := voice_over.get_playback_position()
	var next := _current_cue + 1
	if next < SUBTITLE_CUES.size() and position >= SUBTITLE_CUES[next].start:
		_current_cue = next
		_show_subtitle(SUBTITLE_CUES[_current_cue])
	if _current_cue >= 0 and position >= SUBTITLE_CUES[_current_cue].end:
		_hide_subtitle()


func _show_subtitle(cue: Dictionary) -> void:
	subtitle.text = "[center]%s[/center]" % cue.text
	subtitle.modulate.a = 0.0
	var show := create_tween()
	show.tween_property(subtitle, ^"modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_SINE)


func _hide_subtitle() -> void:
	if not is_instance_valid(subtitle) or subtitle.modulate.a == 0.0:
		return
	var hide := create_tween()
	hide.tween_property(subtitle, ^"modulate:a", 0.0, 0.15)


## The black screen with the end on it. Waits here for Enter before leaving
## for the menu. Landing here by skip covers the frozen frame instantly -
## music, clock, line and credits all cut - instead of fading over it.
func _show_end_title() -> void:
	if _on_end_card or _finished:
		return
	_on_end_card = true
	clock.stop()
	voice_over.stop()
	subtitle.hide()
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
