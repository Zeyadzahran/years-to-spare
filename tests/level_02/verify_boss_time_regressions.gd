extends "res://tests/level_02/verify_business_boss.gd"
## Frozen threshold hits remain valid; Rewind preserves/reclaims fight music.

func frozen_thresholds() -> void:
	for phase_break in [0, 1]:
		await fresh()
		arena._phase_breaks = phase_break
		boss.set_combat_phase(phase_break + 1)
		var threshold := boss.health.max_health * float(2 - phase_break) / 3.0
		boss.health.restore_to(threshold + 20.0)
		await frames(5)
		TimeService.mode = TimeService.Mode.STOPPED
		var position_before := boss.global_position
		boss.receive_player_hit(34.0, player)
		boss.receive_player_hit(34.0, player)
		await frames(15)
		check(boss.health.current == threshold - 48.0, "Frozen threshold swallowed a subsequent hit")
		check(arena.stage == arena.Stage.FIGHTING and boss.phase == BusinessBoss.Phase.FIGHTING, "Frozen threshold started disappearance")
		check(boss.global_position == position_before, "Threshold moved the frozen boss")
		var saved_arena: Array = arena.rewind_capture()
		var saved_boss := boss.rewind_capture()
		TimeService.mode = TimeService.Mode.NORMAL
		await frames(2)
		check(arena.stage == arena.Stage.LEAVING and arena._phase_breaks == phase_break + 1, "Resuming did not start exactly one pending break")
		# Restore the frozen instant: the pending break comes from HP, so it
		# needs no unsaved timer or callback that could fire twice.
		TimeService.mode = TimeService.Mode.REWINDING
		arena.rewind_apply(saved_arena)
		boss.rewind_apply(saved_boss)
		TimeService.mode = TimeService.Mode.STOPPED
		await frames(5)
		boss.receive_player_hit(34.0, player)
		check(boss.health.current == threshold - 82.0, "Restored frozen threshold lost vulnerability")
		TimeService.mode = TimeService.Mode.NORMAL
		await wait_stage(arena.Stage.WAVE)
		check(arena._phase_breaks == phase_break + 1, "Restored threshold duplicated a wave")
	print("BOSS_TIME frozen thresholds: continued damage, frozen body, one wave on resume, restored pending break")

func music_rewind() -> void:
	await fresh()
	await frames(150)
	check(MusicManager.player.playing and MusicManager.player.stream == arena.BATTLE_MUSIC, "Fight music did not start")
	var playback := MusicManager.player.get_stream_playback()
	TimeService.mode = TimeService.Mode.REWINDING
	await frames(30)
	check(MusicManager.player.playing and not MusicManager.player.stream_paused, "Rewind stopped or paused fight music")
	TimeService.mode = TimeService.Mode.NORMAL
	await frames(80)
	check(MusicManager.player.get_stream_playback() == playback, "Normal rewind restarted the soundtrack")
	# A pending fade must be cancelled when Rewind restores active combat.
	MusicManager.stop_music(1.0)
	TimeService.mode = TimeService.Mode.REWINDING
	await frames(10)
	TimeService.mode = TimeService.Mode.NORMAL
	await frames(100)
	check(MusicManager.player.playing and MusicManager.current_song == arena.BATTLE_MUSIC and is_equal_approx(MusicManager.player.volume_db, arena.BATTLE_MUSIC_VOLUME_DB), "Pending music fade silenced the restored fight")
	check(MusicManager.player.get_stream_playback() == playback, "Cancelling a fade restarted the same track")
	MusicManager.player.stop()
	TimeService.mode = TimeService.Mode.REWINDING
	await frames(5)
	TimeService.mode = TimeService.Mode.NORMAL
	await frames(80)
	check(MusicManager.player.playing and MusicManager.player.stream == arena.BATTLE_MUSIC, "Rewind did not recover interrupted fight music")
	MusicManager.stop_music(0.1)
	await frames(15)
	check(not MusicManager.player.playing and MusicManager.current_song == null, "Intentional music stop no longer completes")
	print("BOSS_TIME music: continuous rewind, cancelled fade, interrupted playback recovery, intentional stop")

func _ready() -> void:
	await frozen_thresholds()
	await music_rewind()
	print("BOSS_TIME_REGRESSIONS_VERIFIED failures=%d" % failures)
	TimeService.reset()
	level.queue_free()
	await frames(2)
	get_tree().quit(1 if failures else 0)
