extends Control

## Narration is the clock. Times were measured against intro.mp3 (31.634 s).
## Re-measured directly from the actual audio file's silence gaps on 2026-09-14.
const INTRO_MUSIC = preload("res://assets/music/A_Bridge_to_Yesterday.mp3")
const IMAGES: Array[Texture2D] = [
	preload("res://assets/intro/1home.jpg"),
	preload("res://assets/intro/2arrive.png"),
	preload("res://assets/intro/3clock.jpg"),
	preload("res://assets/intro/4knockout.jpg"),
	preload("res://assets/intro/5desert.jpg"),
	preload("res://assets/intro/6revenge.jpg"),
]

# Transitions start in the pause before each story beat.
const IMAGE_CUES := [
	{"time": 0.0, "image": 0},
	{"time": 6.32, "image": 1},  # "Until they came."
	{"time": 13.80, "image": 2}, # Dad's clock.
	{"time": 17.24, "image": 3}, # Surviving the attack.
	{"time": 19.50, "image": 4}, # The aftermath (was 20.50 -> flashed by in 1.15s, now covers "Or... / that is what I thought.")
	{"time": 23.60, "image": 5}, # Family, resolve, and the journey ahead (was 21.65 -> way too early, now starts right before "My family is still out there.")
]

# Start/end are actual speech boundaries measured from intro.mp3, not estimates.
# Everything from "Or..." onward was previously 0.4s-2.3s too early, which is why
# captions/images looked like they were racing ahead of the still-slow voice over.
const SUBTITLE_CUES := [
	{"start": 0.06, "end": 0.84, "text": "We had a [font_size=27][color=#ffd27b]home[/color][/font_size].", "impact": true},
	{"start": 1.89, "end": 2.69, "text": "We had each other."},
	{"start": 3.81, "end": 5.09, "text": "We had [font_size=27][color=#ffd27b]everything[/color][/font_size] that mattered.", "impact": true},
	{"start": 6.67, "end": 7.64, "text": "Until [font_size=27][color=#ff9b70]they came[/color][/font_size].", "impact": true},
	{"start": 8.87, "end": 10.47, "text": "Cad Corp took [font_size=27][color=#ff9b70]everything[/color][/font_size] from me.", "impact": true},
	{"start": 11.39, "end": 12.85, "text": "My family. My home..."},
	{"start": 14.16, "end": 16.05, "text": "All I have left is my dad's [font_size=27][color=#ffd27b]clock[/color][/font_size].", "impact": true},
	{"start": 17.60, "end": 19.27, "text": "But I was lucky enough to survive."},
	{"start": 20.86, "end": 21.38, "text": "Or..."},
	{"start": 22.00, "end": 23.05, "text": "that is what I thought."},
	{"start": 24.27, "end": 25.70, "text": "My [font_size=27][color=#ffd27b]family[/color][/font_size] is still out there.", "impact": true},
	{"start": 26.05, "end": 26.72, "text": "I can feel it."},
	{"start": 28.33, "end": 29.80, "text": "My journey begins now..."},
	{"start": 30.44, "end": 30.85, "text": "and I will bring them"},
	{"start": 30.86, "end": 31.63, "text": "[font_size=30][color=#ffd27b]HOME.[/color][/font_size]", "impact": true},
]

@onready var image: TextureRect = $Image
@onready var subtitle: RichTextLabel = $CinematicText/Subtitle
@onready var fade: ColorRect = $Fade
@onready var voice_over: AudioStreamPlayer = $VoiceOver

var skip_intro := false
var current_image_cue := 0
var current_subtitle_cue := -1
var subtitle_visible := false
var image_tween: Tween
var subtitle_tween: Tween


func _ready() -> void:
	voice_over.volume_db = 0.0
	MusicManager.play_music(INTRO_MUSIC, 1.5, -12.0)
	image.texture = IMAGES[0]
	image.modulate.a = 1.0
	subtitle.modulate.a = 0.0
	var fade_in := create_tween()
	fade_in.tween_property(fade, ^"modulate:a", 0.0, 1.4)
	await fade_in.finished
	if skip_intro:
		return
	voice_over.play()
	await play_intro()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and not skip_intro:
		skip_intro = true
		start_game()


func play_intro() -> void:
	while voice_over.playing:
		if skip_intro:
			return
		var position := voice_over.get_playback_position()
		_update_image(position)
		_update_subtitle(position)
		await get_tree().process_frame
	_hide_subtitle()
	await show_title()


func _update_image(position: float) -> void:
	while current_image_cue + 1 < IMAGE_CUES.size() and position >= IMAGE_CUES[current_image_cue + 1].time:
		current_image_cue += 1
		_transition_to_image(IMAGE_CUES[current_image_cue].image)


func _transition_to_image(index: int) -> void:
	if image_tween != null and image_tween.is_valid():
		image_tween.kill()
	image_tween = create_tween()
	image_tween.tween_property(image, ^"modulate:a", 0.12, 0.24).set_trans(Tween.TRANS_SINE)
	image_tween.tween_callback(func() -> void: image.texture = IMAGES[index])
	image_tween.tween_property(image, ^"modulate:a", 1.0, 0.38).set_trans(Tween.TRANS_SINE)


func _update_subtitle(position: float) -> void:
	var next := current_subtitle_cue + 1
	if next < SUBTITLE_CUES.size() and position >= SUBTITLE_CUES[next].start:
		current_subtitle_cue = next
		_show_subtitle(SUBTITLE_CUES[current_subtitle_cue])
	if current_subtitle_cue >= 0 and subtitle_visible and position >= SUBTITLE_CUES[current_subtitle_cue].end:
		_hide_subtitle()


func _show_subtitle(cue: Dictionary) -> void:
	if subtitle_tween != null and subtitle_tween.is_valid():
		subtitle_tween.kill()
	subtitle.text = "[center]%s[/center]" % cue.text
	subtitle_visible = true
	subtitle.modulate.a = 0.0
	subtitle.scale = Vector2(0.88, 0.88) if cue.get("impact", false) else Vector2(0.96, 0.96)
	subtitle.pivot_offset = subtitle.size * 0.5
	subtitle_tween = create_tween().set_parallel()
	subtitle_tween.tween_property(subtitle, ^"modulate:a", 1.0, 0.14)
	subtitle_tween.tween_property(subtitle, ^"scale", Vector2.ONE, 0.28 if cue.get("impact", false) else 0.20).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _hide_subtitle() -> void:
	if not subtitle_visible:
		return
	subtitle_visible = false
	if subtitle_tween != null and subtitle_tween.is_valid():
		subtitle_tween.kill()
	subtitle_tween = create_tween().set_parallel()
	subtitle_tween.tween_property(subtitle, ^"modulate:a", 0.0, 0.12)


func show_title() -> void:
	if skip_intro:
		return
	await get_tree().create_timer(0.45).timeout
	if not skip_intro:
		start_game()


func start_game() -> void:
	if voice_over.playing:
		voice_over.stop()
	MusicManager.stop_music(1.0)
	get_tree().change_scene_to_file("res://src/ui/level_title/level_01_title.tscn")