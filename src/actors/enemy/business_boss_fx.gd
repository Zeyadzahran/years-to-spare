extends Node2D
## Cosmetic geometry sampled from the boss's saved combat clocks.

var boss: BusinessBoss

func _ready() -> void:
	boss = get_parent() as BusinessBoss
	z_index = 7

func _draw() -> void:
	if boss.phase in [BusinessBoss.Phase.WAITING, BusinessBoss.Phase.DEFEATED]:
		return
	var clock := boss._visual_time
	var gold := Color(1.0, 0.67, 0.19, 0.65)
	if boss.phase in [BusinessBoss.Phase.DISAPPEARING, BusinessBoss.Phase.APPEARING]:
		var progress := clampf(boss._phase_elapsed / BusinessBoss.TRANSITION_DURATION, 0.0, 1.0)
		var dissolved := progress if boss.phase == BusinessBoss.Phase.DISAPPEARING else 1.0 - progress
		gold.a *= 1.0 - smoothstep(0.0, 0.5, dissolved)
	# Orbiting fragments make his control of the room visible between shots.
	for i in 6:
		var angle := clock * 0.85 + i * TAU / 6.0
		var point := Vector2(cos(angle) * 46.0, -62.0 + sin(angle) * 54.0)
		draw_set_transform(point, angle, Vector2.ONE)
		draw_rect(Rect2(-1, -3, 2, 6), gold)
	draw_set_transform(Vector2.ZERO)
	# Teleport fragments are now drawn in the animated sheet itself.
	if boss.phase == BusinessBoss.Phase.DYING:
		var progress := clampf(boss._phase_elapsed / BusinessBoss.TRANSITION_DURATION, 0.0, 1.0)
		var outward := progress
		for i in 18:
			var angle := i * 2.399
			var start := Vector2(sin(angle) * 20.0, -8.0 - i * 6.0)
			var point := start + Vector2.from_angle(angle) * outward * 78.0
			draw_line(point, point + Vector2(0, -7.0 - outward * 15.0), Color(1.0, 0.73, 0.25, sin(progress * PI)), 2.0)
	var muzzle := Vector2(boss.facing * BusinessBoss.BOSS_MUZZLE_FORWARD, BusinessBoss.BOSS_MUZZLE_HEIGHT)
	if boss.phase == BusinessBoss.Phase.FIGHTING and boss.state == &"Attack":
		if boss._shots_fired == 0:
			var charge := clampf(boss._state_elapsed / boss.attack_hit_time, 0.0, 1.0)
			draw_circle(muzzle, 5.0 + charge * 13.0, Color(0.1, 0.6, 1.0, 0.12 + charge * 0.16))
			draw_arc(muzzle, 13.0 - charge * 7.0, 0.0, TAU, 24, Color(0.5, 0.9, 1.0, 0.85), 2.0)
			draw_circle(muzzle, 2.0 + charge * 3.0, Color(0.85, 1.0, 1.0))
			# Short sight marks show the committed direction without hiding terrain.
			for i in 5:
				var from := muzzle + Vector2(boss.facing * (30.0 + i * 22.0), 0)
				draw_line(from, from + Vector2(boss.facing * 10.0, 0), Color(0.2, 0.75, 1.0, charge * 0.6), 1.5)
		else:
			var since_shot := boss._state_elapsed - boss.attack_hit_time - (boss._shots_fired - 1) * BusinessBoss.BURST_GAP
			var flash := maxf(1.0 - since_shot / 0.12, 0.0)
			draw_circle(muzzle, 18.0 * flash, Color(0.2, 0.7, 1.0, 0.3 * flash))
			draw_line(muzzle - Vector2(0, 14) * flash, muzzle + Vector2(0, 14) * flash, Color(0.7, 0.95, 1.0, flash), 3.0)
			draw_line(muzzle, muzzle + Vector2(boss.facing * 28, 0) * flash, Color(0.6, 0.9, 1.0, flash), 5.0)
	if boss._hit_fx_left > 0.0:
		var fade := boss._hit_fx_left / BusinessBoss.HIT_FX_DURATION
		var center := Vector2(0, -60)
		for i in 6:
			var direction := Vector2.from_angle(i * TAU / 6.0)
			draw_line(center + direction * 20.0, center + direction * (20.0 + (1.0 - fade) * 24.0), Color(1.0, 0.85, 0.45, fade), 2.5)
	if boss._arrival_fx_left > 0.0:
		var fade := boss._arrival_fx_left / BusinessBoss.ARRIVAL_FX_DURATION
		draw_set_transform(Vector2(0, -2), 0.0, Vector2(1.0, 0.35))
		draw_arc(Vector2.ZERO, 18.0 + (1.0 - fade) * 70.0, 0.0, TAU, 40, Color(1.0, 0.75, 0.25, fade), 3.0)
