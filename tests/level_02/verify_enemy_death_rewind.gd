extends "res://tests/level_02/verify_business_boss.gd"
## Rewind a retired enemy only into its collapse, then let that clip finish
## again. Restoring a frame alone cannot resume a finished non-looping clip.

func restore_dying_enemy(scene: PackedScene, stopped: bool) -> void:
	await fresh(false)
	var enemy := scene.instantiate() as Enemy
	arena.get_node("Reinforcements").add_child(enemy)
	enemy.global_position = arena.to_global(Vector2(800, 639))
	await frames(30)
	var announcements := [0]
	var on_death := func(unit: Node2D, _reward: float):
		if unit == enemy:
			announcements[0] += 1
	EventBus.enemy_died.connect(on_death)
	enemy.health.kill(player)
	await frames(8)
	var during_death: float = TimeService._now
	check(enemy.state == &"Dead" and enemy.sprite.is_playing(), "Fixture did not reach an animated death")
	for i in 150:
		if not enemy.visible:
			break
		await frames(1)
	check(not enemy.visible and announcements[0] == 1, "Enemy did not finish its original death")
	await frames(6)
	TimeService.mode = TimeService.Mode.REWINDING
	while TimeService._now > during_death:
		await frames(1)
	check(enemy.visible and enemy.state == &"Dead" and not enemy.health.is_alive(), "Rewind did not stop inside the death animation")
	var restored_frame := enemy.sprite.frame
	var restored_progress := enemy.sprite.frame_progress
	TimeService.mode = TimeService.Mode.STOPPED if stopped else TimeService.Mode.NORMAL
	check(enemy.sprite.frame == restored_frame and is_equal_approx(enemy.sprite.frame_progress, restored_progress), "Releasing rewind restarted the death clip")
	check(enemy.sprite.is_playing(), "Restored death frame has no running animation")
	await frames(3)
	check(enemy.sprite.frame != restored_frame or not is_equal_approx(enemy.sprite.frame_progress, restored_progress), "Death frame stayed frozen after rewind")
	for i in 150:
		if not enemy.visible:
			break
		await frames(1)
	check(not enemy.visible and announcements[0] == 2, "Restored death did not finish and retire exactly once")
	var finished_count: int = announcements[0]
	await frames(6)
	check(announcements[0] == finished_count, "Finished death was announced repeatedly")
	EventBus.enemy_died.disconnect(on_death)
	print("ENEMY death rewind: %s stopped=%s" % [scene.resource_path.get_file(), stopped])

func _ready() -> void:
	for scene in [preload("res://src/actors/enemy/guard.tscn"), preload("res://src/actors/enemy/gunner.tscn"), preload("res://src/actors/enemy/robot.tscn")]:
		for stopped in [false, true]:
			await restore_dying_enemy(scene, stopped)
	print("ENEMY_DEATH_REWIND_VERIFIED failures=%d" % failures)
	TimeService.reset()
	level.queue_free()
	await frames(2)
	get_tree().quit(1 if failures else 0)
