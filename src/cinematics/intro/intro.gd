extends Control

var skip_intro := false

var intro_music = preload("res://assets/music/A_Bridge_to_Yesterday.mp3")

var images = [
	preload("res://assets/intro/1home.jpg"),
	preload("res://assets/intro/2arrive.png"),
	preload("res://assets/intro/3clock.jpg"),
	preload("res://assets/intro/4knockout.jpg"),
	preload("res://assets/intro/5desert.jpg"),
	preload("res://assets/intro/6revenge.jpg")
]

var subtitles = [
	"We had a home. We had each other. We had everything that mattered.",
	"Until they came.",
	"Cad Corp took everything from me. My family, my home... all I have left is my dad's clock.",
	"But I was lucky enough to survive.",
	"Or that is what I thought.",
	"My family is still out there. I can feel it. My journey begins now... and I will bring them home."
]

# Time in the voice-over when each scene should start. Measured from the actual
# narration track (assets/sounds/intro.mp3, 24.32s) via silence-gap analysis
# (ffmpeg silencedetect) rather than guessed: each value is where speech resumes
# after the pause that follows the previous scene's last line.
var scene_times = [
	0.0,    # Scene 1 - "We had a home..."
	5.03,   # Scene 2 - "Until they came."
	6.74,   # Scene 3 - "Cad Corp took everything..."
	14.10,  # Scene 4 - "But I was lucky enough..."
	16.36,  # Scene 5 - "Or that is what I thought."
	18.18   # Scene 6 - "My family is still out there..."
]

# Cue times are likewise read off the narration's silence gaps, so a line lands
# only once it is actually being spoken. Where a single breath covers a lead-in
# and its landing word with no measurable gap between them (e.g. "We had a" /
# "HOME."), the breath's duration is split by word count, weighted so the
# emphasised word lands later and holds longer - the way a reader's stress
# falls on it. The first cue is held slightly after t=0 on purpose: the voice
# should be heard for a beat before any text appears.
var text_cues = [
	{"time": 0.30, "support": "We had a", "emphasis": "", "detail": ""},
	{"time": 0.59, "support": "", "emphasis": "HOME.", "detail": ""},
	{"time": 1.41, "support": "We had", "emphasis": "", "detail": ""},
	{"time": 1.74, "support": "", "emphasis": "EACH OTHER.", "detail": ""},
	{"time": 2.90, "support": "We had", "emphasis": "", "detail": ""},
	{"time": 3.68, "support": "", "emphasis": "EVERYTHING", "detail": "that mattered."},
	{"time": 5.03, "support": "", "emphasis": "UNTIL THEY CAME.", "detail": ""},
	{"time": 6.74, "support": "Cad Corp took", "emphasis": "EVERYTHING", "detail": "from me."},
	{"time": 8.84, "support": "My family,", "emphasis": "MY HOME.", "detail": ""},
	{"time": 9.91, "support": "All I have left is my dad's clock.", "emphasis": "", "detail": ""},
	{"time": 14.10, "support": "But I was", "emphasis": "LUCKY ENOUGH", "detail": "to survive."},
	{"time": 16.36, "support": "Or that is", "emphasis": "WHAT I THOUGHT.", "detail": ""},
	{"time": 18.18, "support": "My family is still out there.", "emphasis": "", "detail": ""},
	{"time": 19.85, "support": "I can feel it.", "emphasis": "", "detail": ""},
	{"time": 21.17, "support": "My journey begins now.", "emphasis": "", "detail": ""},
	{"time": 22.77, "support": "", "emphasis": "I WILL BRING THEM HOME.", "detail": ""}
]

@onready var image: TextureRect = $Image
@onready var cinematic_text: Control = $CinematicText
@onready var support_text: Label = $CinematicText/Support
@onready var emphasis_text: Label = $CinematicText/Emphasis
@onready var detail_text: Label = $CinematicText/Detail
@onready var fade: ColorRect = $Fade
@onready var vignette: ColorRect = $Vignette
@onready var voice_over: AudioStreamPlayer = $VoiceOver

## Scene stays lightly dimmed the whole time text is up, so a big emphasis word
## reads as more attention rather than as an on/off flash.
const VIGNETTE_IDLE := 0.12
const VIGNETTE_EMPHASIS := 0.3

var current_image := 0
var current_text_cue := -1


func _ready():
	# Voice-over should be clearly louder than the background music.
	voice_over.volume_db = 0.0

	# Start background music at a lower volume.
	MusicManager.play_music(intro_music, 1.5, -12.0)

	# Start with a black screen.
	fade.modulate.a = 1.0

	var tween = create_tween()
	tween.tween_property(
		fade,
		"modulate:a",
		0.0,
		2.0
	)

	await tween.finished

	if skip_intro:
		return

	# Start narration.
	voice_over.play()

	# Start the visual intro.
	await play_intro()


func _unhandled_input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		if skip_intro:
			return

		skip_intro = true
		start_game()


func play_intro():
	# Show the first scene immediately.
	current_image = 0

	image.texture = images[0]

	image.modulate.a = 1.0

	# The container itself stays visible throughout; each line now fades in
	# and out on its own as its cue changes, so it starts blank rather than
	# the whole block hidden.
	cinematic_text.modulate.a = 1.0
	_clear_lines()

	# Wait for each scene's timestamp according to the voice-over.
	for i in range(1, images.size()):

		while voice_over.playing:
			if skip_intro:
				return

			var current_time = voice_over.get_playback_position()

			if current_time >= scene_times[i]:
				break

			update_text(current_time)

			await get_tree().process_frame

		if skip_intro:
			return

		await change_scene(i)

		if skip_intro:
			return

	# Wait for the voice-over to finish.
	while voice_over.playing:
		if skip_intro:
			return

		update_text(voice_over.get_playback_position())
		await get_tree().process_frame

	await show_title()


func change_scene(index: int):
	current_image = index

	if skip_intro:
		return

	# Swap the image at the narration boundary so the visual never trails
	# the line it belongs to. The text still eases in independently below.
	image.texture = images[index]
	image.modulate.a = 1.0

	# Clear the previous phrase before revealing the new scene's cue.
	cinematic_text.modulate.a = 1.0
	_clear_lines()
	update_text(voice_over.get_playback_position())


func update_text(current_time: float) -> void:
	var next_cue := current_text_cue + 1
	if next_cue >= text_cues.size() or current_time < text_cues[next_cue].time:
		return

	current_text_cue = next_cue
	var cue: Dictionary = text_cues[current_text_cue]

	# Each line animates only when its own text actually changes, rather than
	# the whole block re-popping for every cue.
	_set_line(support_text, cue.support)
	_set_line(emphasis_text, cue.emphasis)
	_set_line(detail_text, cue.detail)

	var target_dim := VIGNETTE_EMPHASIS if cue.emphasis != "" else VIGNETTE_IDLE
	var vignette_tween := create_tween()
	vignette_tween.tween_property(vignette, "color:a", target_dim, 0.5)


## What each line is currently showing (or fading toward), tracked separately
## from Label.text: a fade-out only blanks the string once it lands, and a
## faster-arriving cue can overtake that in-flight fade-out first.
var _line_values := {}
## The in-flight tween per line, if any - killed before a new one starts so a
## fresh cue never fights the previous line's fade for the same property.
var _line_tweens := {}


## Silently blanks all three lines with no tween, for scene boundaries: the
## text should already be gone by the time the container is visible again.
func _clear_lines() -> void:
	for label in [support_text, emphasis_text, detail_text]:
		var tween: Tween = _line_tweens.get(label)
		if tween != null and tween.is_valid():
			tween.kill()
		_line_tweens.erase(label)
		_line_values[label] = ""
		label.text = ""
		label.modulate.a = 0.0


## Gentle fade/scale-in for a line taking on new text; a gentle fade-out for a
## line being cleared. Slow and understated on purpose - this is a landing
## word finding its place, not a UI popup.
func _set_line(label: Label, text: String) -> void:
	if _line_values.get(label, "") == text:
		return
	_line_values[label] = text

	var old_tween: Tween = _line_tweens.get(label)
	if old_tween != null and old_tween.is_valid():
		old_tween.kill()

	if text == "":
		var tween := create_tween()
		_line_tweens[label] = tween
		tween.tween_property(label, "modulate:a", 0.0, 0.3)
		tween.finished.connect(func(): label.text = "")
		return

	label.text = text
	label.pivot_offset = label.size / 2.0
	label.scale = Vector2(0.96, 0.96)
	label.modulate.a = 0.0

	var tween := create_tween().set_parallel()
	_line_tweens[label] = tween
	tween.tween_property(label, "modulate:a", 1.0, 0.32)
	tween.tween_property(label, "scale", Vector2.ONE, 0.42)


func show_title():
	if skip_intro:
		return

	$Title.modulate.a = 0.0

	var tween = create_tween()

	tween.tween_property(
		$Title,
		"modulate:a",
		1.0,
		2.0
	)

	await tween.finished

	if skip_intro:
		return

	await get_tree().create_timer(3.0).timeout

	if skip_intro:
		return

	start_game()


func start_game():
	if voice_over.playing:
		voice_over.stop()

	MusicManager.stop_music(1.0)

	get_tree().change_scene_to_file(
		"res://src/ui/level_title/level_01_title.tscn"
	)
