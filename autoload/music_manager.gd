extends Node

var player: AudioStreamPlayer
var current_song: AudioStream
var fade_tween: Tween


func _ready():
	# Music keeps playing while the options overlay pauses the level, so the
	# volume slider has something to be heard against.
	process_mode = Node.PROCESS_MODE_ALWAYS
	player = AudioStreamPlayer.new()
	# Its own bus, so the options panel can silence music alone - and do it
	# by muting, which leaves the fades here untouched.
	SettingsManager.music_bus_index()
	player.bus = SettingsManager.MUSIC_BUS
	add_child(player)


func play_music(song: AudioStream, fade_time := 1.0, target_volume_db := 0.0, start_position := 0.0):
	if song == current_song and player.playing and not player.stream_paused:
		return

	current_song = song

	if fade_tween:
		fade_tween.kill()

	if player.playing and player.stream != song:
		fade_tween = create_tween()
		fade_tween.tween_property(player, "volume_db", -40.0, fade_time)
		await fade_tween.finished

	# Reclaiming a track during its fade-out must cancel the stop without
	# restarting the song. A different or stopped track starts normally.
	if player.stream != song or not player.playing:
		player.stream = song
		player.volume_db = -40.0
		player.play(start_position)
	player.stream_paused = false

	fade_tween = create_tween()
	fade_tween.tween_property(player, "volume_db", target_volume_db, fade_time)


func stop_music(fade_time := 1.0):
	# Clear the requested song now, not after the fade. Otherwise play_music
	# mistakes a track that is fading out for one that should keep playing.
	current_song = null
	if not player.playing:
		return

	if fade_tween:
		fade_tween.kill()

	fade_tween = create_tween()
	fade_tween.tween_property(player, "volume_db", -40.0, fade_time)
	await fade_tween.finished

	player.stop()
	current_song = null
