extends "res://tests/level_02/verify_business_boss.gd"
## Sound events use supplied clips, pause with the world and abandon rewound tails.

func expect_clip(audio: Node, file: String) -> void:
	check(audio.stream != null and audio.stream.resource_path == "res://assets/sounds/cad_owner/" + file + ".wav", "Wrong sound on %s" % audio.name)
	check(audio.stream.get_length() > 0.0 and audio.stream.loop_mode == AudioStreamWAV.LOOP_DISABLED, "Sound missing data or unexpectedly looping")

func combat_sounds() -> void:
	await fresh()
	for entry in [[boss.charge_audio,"charge"],[boss._shot_audio,"shot"],[boss.hurt_audio,"hurt"],[boss.disappear_audio,"disappear"],[boss.teleport_audio,"appear"]]:
		expect_clip(entry[0],entry[1])
	player.global_position = boss.global_position + Vector2(-350,0)
	boss.target = player
	boss._change_state(&"Recover")
	boss._change_state(&"Attack")
	check(boss.charge_audio.playing, "Charge did not start")
	check(is_equal_approx(boss.charge_audio.stream.get_length() / boss.charge_audio.pitch_scale, boss.attack_hit_time), "Charge does not fit attack windup")
	TimeService.mode = TimeService.Mode.STOPPED
	await frames(3)
	check(boss.charge_audio.stream_paused, "Charge ignored Stop Time")
	TimeService.mode = TimeService.Mode.NORMAL
	await frames(42)
	check(not boss.charge_audio.playing and boss._shot_audio.playing, "Shot did not replace charge")
	boss.receive_player_hit(1.0,player)
	check(boss.hurt_audio.playing, "Boss hit did not play supplied hurt sound")
	boss.begin_intermission()
	check(boss.disappear_audio.playing, "Disappearance sound missing")
	await frames(45)
	boss.resume_after_intermission(arena.to_global(Vector2(1100,639)))
	check(boss.teleport_audio.playing and not boss.disappear_audio.playing, "Arrival did not replace departure sound")
	boss.rewind_began()
	for audio in boss._audio:
		check(not audio.playing, "Boss sound survived rewind")
	print("BOSS_AUDIO combat: assigned clips, windup timing, shot, hurt, departure, arrival and freeze/rewind")

func room_sounds() -> void:
	await fresh()
	var portal: AudioStreamPlayer2D = arena.get_node("ReinforcementGate/PortalAudio")
	var spawn: AudioStreamPlayer = arena.get_node("ReinforcementGate/SpawnAudio")
	var death: AudioStreamPlayer = arena.get_node("DeathAudio")
	for entry in [[portal,"portal_open"],[spawn,"enemy_spawn"],[death,"death"]]:
		expect_clip(entry[0],entry[1])
	check(spawn.stream.get_length() <= 0.66, "Named cut requests kept later cues")
	boss.health.take_damage(410,player)
	check(boss.disappear_audio.playing, "Health break did not play disappearance chimes")
	await wait_stage(arena.Stage.OPENING)
	check(portal.playing, "Portal opening sound missing")
	await wait_stage(arena.Stage.SPAWNING)
	for i in 80:
		if arena._spawn_index > 0: break
		await frames(1)
	check(spawn.playing, "Enemy spawn sound missing")
	check(spawn.volume_db >= -1.0, "Portal entry cue was reduced below the corrected mix")
	TimeService.mode = TimeService.Mode.STOPPED
	await frames(3)
	check(portal.stream_paused and spawn.stream_paused, "Room sounds ignored Stop Time")
	var music = MusicManager.player.get_stream_playback()
	arena.rewind_began()
	check(not portal.playing and not spawn.playing, "Room effects survived rewind")
	check(MusicManager.player.get_stream_playback() == music, "Rewinding effects restarted battle music")
	TimeService.mode = TimeService.Mode.NORMAL
	await fresh()
	death = arena.get_node("DeathAudio")
	boss.health.kill(player)
	check(death.playing, "Boss death sound missing")
	TimeService.mode = TimeService.Mode.STOPPED
	await frames(3)
	check(death.stream_paused, "Death sound ignored Stop Time")
	arena.rewind_began()
	check(not death.playing, "Rewind failed to stop death sound")
	TimeService.mode = TimeService.Mode.NORMAL
	await fresh()
	death = arena.get_node("DeathAudio")
	boss.health.kill(player)
	await wait_stage(arena.Stage.EXIT_WALK)
	check(is_instance_valid(death) and death.playing and not death.stream_paused, "Retiring the boss cut off death tail")
	print("BOSS_AUDIO room: disappear/open/spawn/death, requested cuts, pause, rewind and surviving death tail")

func _ready() -> void:
	await combat_sounds()
	await room_sounds()
	print("BOSS_AUDIO_VERIFIED failures=%d" % failures)
	TimeService.reset()
	level.queue_free()
	await frames(2)
	get_tree().quit(1 if failures else 0)
