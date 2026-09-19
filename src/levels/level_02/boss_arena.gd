extends Node2D
## The room owns encounter progress; the boss owns his visible transitions.
## All waits are world-time clocks captured alongside the actors for Rewind.

enum Stage { DORMANT, INTRO, FIGHTING, LEAVING, OPENING, SPAWNING, WAVE, CLOSING, RETURNING, VICTORY, COMPLETE, EXIT_WALK }

const ROOM_LEFT := 0.0
const ROOM_RIGHT := 1600.0
const ROOM_TOP := -160.0
const ROOM_BOTTOM := 920.0
const GUARD_SCENE := preload("res://src/actors/enemy/guard.tscn")
const GUNNER_SCENE := preload("res://src/actors/enemy/gunner.tscn")
const PLATFORM_TELEPORT_COOLDOWN := 4.0
const PLATFORM_SETTLE_TIME := 0.35
const PORTAL_OPEN_TIME := 0.42
const PORTAL_CLOSE_TIME := 0.28
const SPAWN_INTERVAL := 0.7
const BATTLE_MUSIC_VOLUME_DB := -19.0
const BATTLE_MUSIC := preload("res://assets/music/Epic_Boss_Battle.ogg")
## Where the walk to the parents leads: the reunion cutscene, then THE END.
const ENDING_SCENE := "res://src/cinematics/finale/finale.tscn"
const INTRO_FONT := preload("res://assets/fonts/prstart.ttf")
## Entrance banter, played as subtitles while the fight is already running.
## Single combined array: subtitles[i] pairs with its speaker in the same entry.
## Style matches the intro cinematic (bottom-centre RichTextLabel, pixel font,
## cream text, black outline) with a coloured speaker prefix per line.
const INTRO_DIALOGUE := [
	{"speaker": "Manager", "text": "You're later than projected. Most of them don't make it this far.", "duration": 5.0},
	{"speaker": "Manager", "text": "Your sister, I let go. A gesture of good faith, one loss the ledger could absorb.", "duration": 5.5},
	{"speaker": "Manager", "text": "Your parents are a different entry. Older accounts. Harder to write off.", "duration": 5.0},
	{"speaker": "Boy", "text": "Then I'll take them back myself.", "duration": 3.5, "impact": true},
	{"speaker": "Manager", "text": "You've been paying for that choice your whole journey. Every ability, every year off your life, that was never cruelty. That was simply what the ledger requires.", "duration": 7.5},
	{"speaker": "Manager", "text": "You could have been given all of this, if you'd only asked the right people.", "duration": 4.5},
	{"speaker": "Manager", "text": "That's the tragedy here. Not the system. Just you, refusing to understand it.", "duration": 4.5},
	{"speaker": "Boy", "text": "I understand it fine. You took everything and called it math.", "duration": 4.0, "impact": true},
	{"speaker": "Manager", "text": "Let's finish the audit, then.", "duration": 3.5, "impact": true},
]
const INTRO_GAP := 0.6
const INTRO_BAR_TOP_HEIGHT := 72.0
const INTRO_BAR_BOTTOM_HEIGHT := 132.0
const INTRO_SUB_TOP := -128.0
const INTRO_SUB_BOTTOM := -20.0
const INTRO_WALK_DELAY := 0.4
const INTRO_WALK_DISTANCE := 220.0
const INTRO_WALK_SPEED := 260.0
const INTRO_BAR_COLOR := Color(0.025, 0.035, 0.06, 0.94)
const INTRO_SPEAKER_COLORS := {"Manager": "#ffd27b", "Boy": "#9fd8ff"}

var player: Player
var stage := Stage.DORMANT
var _elapsed := 0.0
var _phase_breaks := 0
var _reinforcements: Array[Enemy] = []
var _wave_count := 0
var _spawn_index := 0
var _platform_teleport_cooldown := 0.0
var _stood_on: MovingIndustrialPlatform
var _stand_time := 0.0
const PORTAL_SPAWN_GLOW_TIME := 0.6
var _portal_spawn_left := 0.0
var _shake_left := 0.0
var _shake_strength := 0.0
var _portal_clock := 0.0

@onready var cinematic: Node = $Cinematic
@onready var chamber: Node2D = $Platforms/ArenaPlatform/ParentsChamber
@onready var boss: BusinessBoss = $BusinessBoss
@onready var boss_bar: ProgressBar = $BossUI/Panel/BossHealth
@onready var boss_ui: CanvasLayer = $BossUI
@onready var reinforcement_gate: ReinforcementGate = $ReinforcementGate

var _intro_shown := false
var _intro_layer: CanvasLayer
var _intro_root: Control
var _intro_label: RichTextLabel
var _intro_tween: Tween
var _intro_bar_layer: CanvasLayer
var _intro_bar_top: ColorRect
var _intro_bar_bottom: ColorRect
var _intro_bar_tween: Tween
var _skip_hint: Label
var _intro_skip_requested := false

func _ready() -> void:
	add_to_group(TimeService.REWINDABLE_GROUP)
	_build_intro_subtitles()
	chamber.boss = boss
	boss.arena_left = global_position.x + ROOM_LEFT
	boss.arena_right = global_position.x + ROOM_RIGHT
	cinematic.walk_finished.connect(_finish_walk)
	boss.health.changed.connect(_on_boss_health_changed)
	boss.defeated.connect(_on_boss_defeated)
	boss.health.died.connect(_on_boss_dying)
	boss.reposition_requested.connect(_on_reposition_requested)
	boss.major_impact.connect(_on_major_impact)
	_on_boss_health_changed(boss.health.current, boss.health.max_health)
	_sync_presentation()

func prepare_gate_entry(entry_player: Player) -> void:
	player = entry_player
	var day_night := get_node_or_null(^"../../DayNightTransition")
	if day_night != null:
		day_night.restore_daylight()
	_configure_camera()
	if stage == Stage.DORMANT:
		_enter_stage(Stage.INTRO)
		_play_intro_dialogue()

func is_cinematic_active() -> bool:
	return stage in [Stage.INTRO, Stage.EXIT_WALK, Stage.COMPLETE]

## Spend a heart without rebuilding the room: damage, completed waves and
## surviving reinforcements remain exactly where the player left them.
func respawn_player(actor: Player) -> bool:
	if actor == null or actor != player or stage in [Stage.DORMANT, Stage.INTRO, Stage.EXIT_WALK, Stage.COMPLETE]:
		return false
	var destination := _respawn_position()
	if not destination.is_finite():
		return false
	# Old rounds must not hit the new spawn. Committing the spent heart also
	# clears history, so Rewind cannot return to the already-paid death.
	for projectile in get_tree().get_nodes_in_group(TimeService.REWINDABLE_GROUP):
		if projectile is Bullet or projectile.is_in_group(&"business_hazard"):
			TimeService.retire(projectile)
	actor.respawn_at(destination)
	actor.facing = 1 if destination.x < global_position.x + ROOM_RIGHT * 0.5 else -1
	TimeService.start_history_window()
	_restore_fight_music()
	return true

func _respawn_position() -> Vector2:
	var safest := Vector2.INF
	var best_clearance := -1.0
	for x in [150.0, 450.0, 750.0, 1050.0, 1450.0]:
		var candidate := _floor_at(x)
		if not candidate.is_finite():
			continue
		var clearance := INF
		for enemy in get_tree().get_nodes_in_group(&"enemy"):
			if not is_ancestor_of(enemy) or not enemy.health.is_alive() \
					or enemy.process_mode == Node.PROCESS_MODE_DISABLED:
				continue
			var at: Vector2 = enemy._spawn_to if enemy.state == &"Spawning" else enemy.global_position
			clearance = minf(clearance, candidate.distance_to(at))
		if clearance > best_clearance:
			best_clearance = clearance
			safest = candidate
	return safest

func _start_fight() -> void:
	# Rewind starts with controllable gameplay, never inside an input lock.
	TimeService.start_history_window()
	boss.activate()
	_enter_stage(Stage.FIGHTING)
	_start_music.call_deferred()

func _start_music() -> void:
	var song := BATTLE_MUSIC as AudioStreamOggVorbis
	song.loop = true
	MusicManager.play_music(song, 1.0, BATTLE_MUSIC_VOLUME_DB)

func _exit_tree() -> void:
	if MusicManager.current_song == BATTLE_MUSIC:
		MusicManager.stop_music(0.6)

## Bottom-centre subtitle layer matching the intro cinematic's Subtitle node:
## same pixel font, cream text, black outline and shadow, above the boss bar.
func _build_intro_subtitles() -> void:
	_intro_layer = CanvasLayer.new()
	_intro_layer.layer = 40
	_intro_layer.name = &"BossIntroSubtitles"
	add_child(_intro_layer)
	# Full-rect root exactly like the intro cinematic's own root Control, so
	# the subtitle and the skip hint anchor identically to the shipped intro.
	_intro_root = Control.new()
	_intro_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_intro_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_intro_layer.add_child(_intro_root)
	_intro_label = RichTextLabel.new()
	_intro_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	# Seated inside the lower letterbox bar (which spans -132..0), so the
	# text reads over solid black the way film subtitles do.
	_intro_label.offset_left = 128.0
	_intro_label.offset_top = INTRO_SUB_TOP
	_intro_label.offset_right = -128.0
	_intro_label.offset_bottom = INTRO_SUB_BOTTOM
	# Same skip hint as the intro cinematic: bottom-right, out of the way.
	_skip_hint = Label.new()
	_skip_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	# Box fits the full ~304px the pixel font needs: a narrower box makes
	# the Label outgrow it rightward, past the viewport edge.
	_skip_hint.offset_left = -350.0
	_skip_hint.offset_top = -58.0
	_skip_hint.offset_right = -32.0
	_skip_hint.offset_bottom = -28.0
	# Any residual overflow must grow leftward, never past the screen edge.
	_skip_hint.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_skip_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_skip_hint.add_theme_color_override(&"font_color", Color(1.0, 0.965, 0.88, 1.0))
	_skip_hint.add_theme_color_override(&"font_outline_color", Color(0.02, 0.015, 0.02, 1.0))
	_skip_hint.add_theme_constant_override(&"outline_size", 4)
	_skip_hint.add_theme_font_override(&"font", INTRO_FONT)
	_skip_hint.add_theme_font_size_override(&"font_size", 12)
	_skip_hint.text = "Press Enter to Skip"
	_skip_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_skip_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_intro_root.add_child(_skip_hint)
	_intro_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_intro_label.bbcode_enabled = true
	_intro_label.scroll_active = false
	_intro_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_intro_label.add_theme_color_override(&"default_color", Color(1.0, 0.965, 0.88, 1.0))
	_intro_label.add_theme_color_override(&"font_outline_color", Color(0.02, 0.015, 0.02, 1.0))
	_intro_label.add_theme_color_override(&"font_shadow_color", Color(0, 0, 0, 0.78))
	_intro_label.add_theme_constant_override(&"outline_size", 6)
	_intro_label.add_theme_constant_override(&"shadow_offset_x", 2)
	_intro_label.add_theme_constant_override(&"shadow_offset_y", 2)
	_intro_label.add_theme_font_override(&"normal_font", INTRO_FONT)
	_intro_label.add_theme_font_size_override(&"normal_font_size", 18)
	_intro_label.modulate.a = 0.0
	_intro_root.add_child(_intro_label)
	_intro_layer.hide()
	# Letterbox bars below the subtitles (layer 35 under 40), so the text
	# reads over the black the way film subtitles do. Same bars as the
	# finale walk in cad_cinematic.gd.
	_intro_bar_layer = CanvasLayer.new()
	_intro_bar_layer.layer = 35
	_intro_bar_layer.name = &"BossIntroLetterbox"
	add_child(_intro_bar_layer)
	_intro_bar_top = ColorRect.new()
	_intro_bar_top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_intro_bar_top.offset_bottom = 0.0
	_intro_bar_top.color = INTRO_BAR_COLOR
	_intro_bar_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_intro_bar_layer.add_child(_intro_bar_top)
	_intro_bar_bottom = ColorRect.new()
	_intro_bar_bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_intro_bar_bottom.offset_top = 0.0
	_intro_bar_bottom.color = INTRO_BAR_COLOR
	_intro_bar_bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_intro_bar_layer.add_child(_intro_bar_bottom)
	_intro_bar_layer.hide()

## Entrance walk-in, then banter: the boy steps into the room on his own
## while the boss stays dormant, then both hold still until the last line
## lands and the fight starts. Plays once per arena lifetime, never replays
## on respawn.
func _play_intro_dialogue() -> void:
	if _intro_shown:
		return
	_intro_shown = true
	_intro_skip_requested = false
	if is_instance_valid(player):
		player.powers.cancel()
		player.velocity = Vector2.ZERO
		player.process_mode = Node.PROCESS_MODE_DISABLED
	await _play_intro_walk()
	if not is_inside_tree() or stage != Stage.INTRO:
		return
	_set_intro_hud_visible(false)
	_show_intro_bars()
	_intro_layer.show()
	for cue in INTRO_DIALOGUE:
		# The arena can be freed (checkpoint reload) while a line is on
		# screen; stop quietly instead of touching dead nodes.
		if not is_inside_tree() or stage != Stage.INTRO or _intro_skip_requested:
			break
		_show_intro_line(cue)
		await _wait_intro(float(cue.get("duration", 2.5)))
		if not is_inside_tree():
			return
		if not is_instance_valid(_intro_label):
			return
		_hide_intro_line()
		await _wait_intro(INTRO_GAP)
	_hide_intro_layer()
	if not is_inside_tree() or stage != Stage.INTRO:
		_set_intro_hud_visible(true)
		return
	_hide_intro_bars()
	_set_intro_hud_visible(true)
	boss.target = player
	_start_fight()
	if is_instance_valid(player):
		player.process_mode = Node.PROCESS_MODE_INHERIT

## The walk-in: a short beat, then a few steps toward the boss on the flat
## arena floor. The sprite ticks on its own while the body stays locked,
## the way the level 1 victory walk does it.
func _play_intro_walk() -> void:
	if not is_instance_valid(player) or not is_inside_tree():
		return
	await _wait_intro(INTRO_WALK_DELAY)
	if not is_inside_tree() or not is_instance_valid(player) or stage != Stage.INTRO:
		return
	player.facing = 1
	if is_instance_valid(player.sprite):
		player.sprite.process_mode = Node.PROCESS_MODE_ALWAYS
		player.sprite.flip_h = false
		player.sprite.play(&"run")
	var destination := player.global_position + Vector2(INTRO_WALK_DISTANCE, 0.0)
	var walk := create_tween()
	walk.tween_property(player, ^"global_position", destination, INTRO_WALK_DISTANCE / INTRO_WALK_SPEED)
	await walk.finished
	if not is_inside_tree() or not is_instance_valid(player):
		return
	player.global_position = destination
	if is_instance_valid(player.sprite):
		player.sprite.play(&"idle")
		player.sprite.process_mode = Node.PROCESS_MODE_INHERIT

## Sliced wait so Enter can cut a line short. Timers ignore the pause menu
## (process_always false), so ESC genuinely freezes the cinematic.
func _wait_intro(seconds: float) -> void:
	var left := seconds
	while left > 0.0 and not _intro_skip_requested:
		if not is_inside_tree():
			return
		var step := minf(0.1, left)
		await get_tree().create_timer(step, false).timeout
		left -= step

func _unhandled_input(event: InputEvent) -> void:
	if stage != Stage.INTRO or _intro_skip_requested:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ENTER:
		get_viewport().set_input_as_handled()
		_intro_skip_requested = true

func _set_intro_hud_visible(value: bool) -> void:
	var level := get_parent().get_parent()
	var hud := level.get_node_or_null("HUD")
	if hud != null and hud.has_method("set_meters_visible"):
		hud.set_meters_visible(value)

func _show_intro_bars() -> void:
	if not is_instance_valid(_intro_bar_layer):
		return
	if _intro_bar_tween != null and _intro_bar_tween.is_valid():
		_intro_bar_tween.kill()
	_intro_bar_layer.show()
	_intro_bar_tween = create_tween().set_parallel()
	_intro_bar_tween.tween_property(_intro_bar_top, ^"offset_bottom", INTRO_BAR_TOP_HEIGHT, 0.5).set_trans(Tween.TRANS_SINE)
	_intro_bar_tween.tween_property(_intro_bar_bottom, ^"offset_top", -INTRO_BAR_BOTTOM_HEIGHT, 0.5).set_trans(Tween.TRANS_SINE)

func _hide_intro_bars() -> void:
	if not is_instance_valid(_intro_bar_layer):
		return
	if _intro_bar_tween != null and _intro_bar_tween.is_valid():
		_intro_bar_tween.kill()
	_intro_bar_tween = create_tween()
	_intro_bar_tween.tween_property(_intro_bar_top, ^"offset_bottom", 0.0, 0.5).set_trans(Tween.TRANS_SINE)
	_intro_bar_tween.tween_property(_intro_bar_bottom, ^"offset_top", 0.0, 0.5).set_trans(Tween.TRANS_SINE)
	_intro_bar_tween.tween_callback(_intro_bar_layer.hide)

func _show_intro_line(cue: Dictionary) -> void:
	if _intro_tween != null and _intro_tween.is_valid():
		_intro_tween.kill()
	var speaker := String(cue.get("speaker", ""))
	var color := String(INTRO_SPEAKER_COLORS.get(speaker, "#ffffff"))
	_intro_label.text = "[center][color=%s]%s:[/color] %s[/center]" % [color, speaker.to_upper(), cue.get("text", "")]
	_intro_label.modulate.a = 0.0
	_intro_label.scale = Vector2(0.88, 0.88) if bool(cue.get("impact", false)) else Vector2(0.96, 0.96)
	_intro_label.offset_top = INTRO_SUB_TOP
	_intro_label.offset_bottom = INTRO_SUB_BOTTOM
	_center_intro_line()
	_intro_tween = create_tween().set_parallel()
	_intro_tween.tween_property(_intro_label, ^"modulate:a", 1.0, 0.14)
	var pop_time := 0.28 if bool(cue.get("impact", false)) else 0.20
	_intro_tween.tween_property(_intro_label, ^"scale", Vector2.ONE, pop_time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## RichTextLabel has no vertical alignment, so seat each laid-out line on the
## middle of the subtitle region: one-liners and two-liners both read centred.
func _center_intro_line() -> void:
	if not is_instance_valid(_intro_label):
		return
	await get_tree().process_frame
	if not is_inside_tree() or not is_instance_valid(_intro_label):
		return
	var h := maxf(_intro_label.get_content_height(), 1.0)
	var mid := (INTRO_SUB_TOP + INTRO_SUB_BOTTOM) * 0.5
	_intro_label.offset_top = mid - h * 0.5
	_intro_label.offset_bottom = mid + h * 0.5
	_intro_label.pivot_offset = _intro_label.size * 0.5

func _hide_intro_line() -> void:
	if _intro_tween != null and _intro_tween.is_valid():
		_intro_tween.kill()
	_intro_tween = create_tween()
	_intro_tween.tween_property(_intro_label, ^"modulate:a", 0.0, 0.12)

func _hide_intro_layer() -> void:
	if is_instance_valid(_intro_layer):
		_intro_layer.hide()
	if is_instance_valid(_intro_label):
		_intro_label.modulate.a = 0.0

func _physics_process(delta: float) -> void:
	if TimeService.is_rewinding():
		return
	var scaled := TimeService.world_delta(delta)
	if is_zero_approx(scaled) or stage in [Stage.DORMANT, Stage.INTRO, Stage.COMPLETE, Stage.EXIT_WALK]:
		return
	_elapsed += scaled
	_portal_clock += scaled
	_portal_spawn_left = maxf(_portal_spawn_left - scaled, 0.0)
	_shake_left = maxf(_shake_left - scaled, 0.0)
	_sync_camera_shake()
	_platform_teleport_cooldown = maxf(_platform_teleport_cooldown - scaled, 0.0)
	match stage:
		Stage.FIGHTING:
			_check_phase_break()
			if stage == Stage.FIGHTING:
				_check_platform_teleport(scaled)
		Stage.LEAVING:
			if boss.phase == BusinessBoss.Phase.WAITING:
				_enter_stage(Stage.OPENING)
		Stage.OPENING:
			if _elapsed >= PORTAL_OPEN_TIME:
				_enter_stage(Stage.SPAWNING)
		Stage.SPAWNING:
			if _elapsed >= SPAWN_INTERVAL:
				if _spawn_reinforcement(_spawn_index):
					_spawn_index += 1
				_elapsed = 0.0
				if _spawn_index >= _wave_count:
					_enter_stage(Stage.WAVE)
		Stage.WAVE:
			if _living_reinforcements() == 0:
				_enter_stage(Stage.CLOSING)
		Stage.CLOSING:
			if _elapsed >= PORTAL_CLOSE_TIME:
				boss.set_combat_phase(_phase_breaks + 1)
				boss.resume_after_intermission(_return_position())
				_enter_stage(Stage.RETURNING)
		Stage.RETURNING:
			if boss.phase == BusinessBoss.Phase.FIGHTING:
				_enter_stage(Stage.FIGHTING)
		Stage.VICTORY:
			if _elapsed >= 1.15:
				_complete_encounter()
	_sync_presentation()

func _enter_stage(next: Stage) -> void:
	stage = next
	_elapsed = 0.0
	if next == Stage.OPENING:
		var audio: AudioStreamPlayer2D = $ReinforcementGate/PortalAudio
		audio.play()
	_sync_presentation()

func _check_phase_break() -> void:
	# Hits still count during Stop Time. Keep the visible boss vulnerable;
	# the next running physics tick starts the pending health break.
	if TimeService.is_world_frozen():
		return
	if stage != Stage.FIGHTING or _phase_breaks >= 2 or not boss.health.is_alive():
		return
	var threshold := boss.health.max_health * float(2 - _phase_breaks) / 3.0
	if boss.health.current > threshold:
		return
	_phase_breaks += 1
	_wave_count = randi_range(3, 5)
	_spawn_index = 0
	_reinforcements.clear()
	boss.begin_intermission()
	_enter_stage(Stage.LEAVING)

func _on_boss_health_changed(current: float, maximum: float) -> void:
	boss_bar.max_value = maximum
	boss_bar.value = current
	# Health restoration announces the bar too, but must never start a new wave.
	if not TimeService.is_rewinding():
		_check_phase_break()

func _check_platform_teleport(delta: float) -> void:
	var platform := _platform_under_player()
	if platform != _stood_on:
		_stood_on = platform
		_stand_time = 0.0
	if not is_instance_valid(player) or not player.is_grounded():
		_stand_time = 0.0
		return
	_stand_time += delta
	if _stand_time < PLATFORM_SETTLE_TIME or _platform_teleport_cooldown > 0.0:
		return
	# Track the landing throughout an attack, but wait for its recovery to end.
	if boss.state in [&"Attack", &"Recover", &"Hurt"]:
		return
	if platform == null:
		# Once the player leaves the decks, bring the stationary boss back to
		# the floor instead of leaving him shooting over the player's head.
		if boss.global_position.y < reinforcement_gate.global_position.y - 60.0:
			if boss.teleport_to_floor(_return_position()):
				_platform_teleport_cooldown = PLATFORM_TELEPORT_COOLDOWN
		return
	var half_width := platform.width_tiles * 32.0
	if absf(boss.global_position.y - platform.global_position.y) < 20.0 \
			and absf(boss.global_position.x - platform.global_position.x) < half_width:
		return
	var side := -1.0 if player.global_position.x >= platform.global_position.x else 1.0
	var offset := Vector2(side * maxf(half_width - 44.0, 0.0), -1.0)
	if boss.teleport_to_platform(platform, offset):
		_platform_teleport_cooldown = PLATFORM_TELEPORT_COOLDOWN

func _on_reposition_requested() -> void:
	if stage != Stage.FIGHTING or not is_instance_valid(player):
		return
	var platform := _platform_under_player()
	var moved := false
	if platform != null:
		var side := -1.0 if player.global_position.x >= platform.global_position.x else 1.0
		moved = boss.teleport_to_platform(platform, Vector2(side * (platform.width_tiles * 32.0 - 44.0), -1.0))
	else:
		var player_x := to_local(player.global_position).x
		var side := -1.0 if boss.global_position.x > player.global_position.x else 1.0
		var x := clampf(player_x + side * 320.0, 80.0, ROOM_RIGHT - 80.0)
		if absf(x - player_x) < 180.0:
			x = clampf(player_x - side * 320.0, 80.0, ROOM_RIGHT - 80.0)
		var destination := _floor_at(x)
		if destination.is_finite():
			moved = boss.teleport_to_floor(destination)
	if moved:
		_platform_teleport_cooldown = PLATFORM_TELEPORT_COOLDOWN

func _on_major_impact(strength: float) -> void:
	_shake_left = 0.25
	_shake_strength = maxf(_shake_strength, strength)

func _sync_camera_shake() -> void:
	if not is_instance_valid(player):
		return
	var camera := player.get_node_or_null(^"Camera2D") as Camera2D
	if camera != null:
		camera.offset = Vector2(sin(_shake_left * 95.0), cos(_shake_left * 81.0)) * _shake_strength * (_shake_left / 0.25)
	if is_zero_approx(_shake_left):
		_shake_strength = 0.0

func rewind_began() -> void:
	for audio in [$ReinforcementGate/PortalAudio, $ReinforcementGate/SpawnAudio, $DeathAudio]:
		audio.stop()
	_restore_fight_music()

func rewind_ended() -> void:
	_restore_fight_music()

func _restore_fight_music() -> void:
	# Music follows the encounter, not a rewound sound-effect snapshot.
	# Reclaim interrupted/fading playback while keeping a live song in place.
	if stage not in [Stage.DORMANT, Stage.INTRO, Stage.EXIT_WALK, Stage.COMPLETE]:
		_start_music()

## A jump passing near a deck is not a landing. Use the actual floor contact.
func _platform_under_player() -> MovingIndustrialPlatform:
	if not is_instance_valid(player) or not player.is_grounded():
		return null
	for i in player.get_slide_collision_count():
		var contact := player.get_slide_collision(i)
		var platform := contact.get_collider() as MovingIndustrialPlatform
		if platform != null and $Platforms.is_ancestor_of(platform) and contact.get_normal().y < -0.5:
			return platform
	return null

## Choose room-local floor slots beside the portal, never relative to the
## player's far side. A terrain ray validates the landing before a unit exists.
func _spawn_reinforcement(index: int) -> bool:
	var destination := _reinforcement_destination(index)
	if not destination.is_finite():
		return false
	var enemy := (GUARD_SCENE if index % 2 == 0 else GUNNER_SCENE).instantiate() as Enemy
	enemy.name = "Wave%dUnit%d" % [_phase_breaks, index]
	enemy.position = $Reinforcements.to_local(reinforcement_gate.global_position)
	$Reinforcements.add_child(enemy)
	_reinforcements.append(enemy)
	enemy.target = player
	enemy.begin_spawn(reinforcement_gate.global_position, destination)
	_portal_spawn_left = PORTAL_SPAWN_GLOW_TIME
	_on_major_impact(4.5)
	$ReinforcementGate/SpawnAudio.play()
	if enemy is Guard:
		var guard := enemy as Guard
		guard.patrol_origin_x = destination.x
		guard.territory = ROOM_RIGHT - ROOM_LEFT
	return true

func _reinforcement_destination(index: int) -> Vector2:
	for attempt in 12:
		var slot := (index + attempt) % 12
		var x := clampf(reinforcement_gate.position.x - 120.0 - slot * 100.0, 80.0, ROOM_RIGHT - 80.0)
		var destination := _floor_at(x)
		if not destination.is_finite():
			continue
		if is_instance_valid(player) and destination.distance_to(player.global_position) < 110.0:
			continue
		var occupied := false
		for enemy in _reinforcements:
			if is_instance_valid(enemy) and enemy.health.is_alive():
				var at := enemy._spawn_to if enemy.state == &"Spawning" else enemy.global_position
				if at.distance_to(destination) < 70.0:
					occupied = true
		if not occupied:
			return destination
	return Vector2.INF

func _floor_at(x: float) -> Vector2:
	var floor_y := reinforcement_gate.position.y
	var query := PhysicsRayQueryParameters2D.create(
		to_global(Vector2(x, floor_y - 32.0)), to_global(Vector2(x, floor_y + 64.0)), Enemy.WORLD_LAYER)
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	return hit.position + Vector2(0.0, -1.0) if not hit.is_empty() else Vector2.INF

func _return_position() -> Vector2:
	var destination := _reinforcement_destination(2)
	return destination if destination.is_finite() else $FutureBossPosition.global_position

func _living_reinforcements() -> int:
	var living := 0
	for enemy in _reinforcements:
		# Retired pit falls retain health for Rewind but cannot hold a wave open.
		if is_instance_valid(enemy) and not enemy.is_queued_for_deletion() \
				and enemy.process_mode != Node.PROCESS_MODE_DISABLED and enemy.health.is_alive():
			living += 1
	return living

func _configure_camera() -> void:
	var camera := player.get_node_or_null(^"Camera2D") as Camera2D
	if camera == null:
		return
	camera.limit_left = roundi(global_position.x + ROOM_LEFT)
	camera.limit_right = roundi(global_position.x + ROOM_RIGHT)
	camera.limit_top = roundi(global_position.y + ROOM_TOP)
	camera.limit_bottom = roundi(global_position.y + ROOM_BOTTOM)
	camera.limit_smoothed = false

func _on_boss_dying() -> void:
	# Keep the decay in the room: retiring the boss must not cut it short.
	$DeathAudio.play()

func _on_boss_defeated() -> void:
	if stage not in [Stage.VICTORY, Stage.COMPLETE]:
		_hide_intro_layer()
		_enter_stage(Stage.VICTORY)

func _complete_encounter() -> void:
	if stage != Stage.VICTORY:
		return
	_enter_stage(Stage.EXIT_WALK)
	# This is the committed end of combat. The death delay before this point
	# can still be rewound; the walk cannot be interrupted by old hazards.
	player.powers.cancel()
	for projectile in get_tree().get_nodes_in_group(&"rewindable"):
		if projectile is Bullet:
			projectile.queue_free()
	for unit in $Reinforcements.get_children():
		unit.process_mode = Node.PROCESS_MODE_DISABLED
		unit.hide()
	for platform in $Platforms.get_children():
		platform.set_physics_process(false)
	TimeService.start_history_window()
	cinematic.start(player, chamber)

func _finish_walk() -> void:
	if stage != Stage.EXIT_WALK:
		return
	_enter_stage(Stage.COMPLETE)
	var level := get_parent().get_parent() as Level
	if level != null:
		level.complete()
	# Only the real game goes on to the cutscene - a contract test builds
	# this same room as a plain child rather than as current_scene, and must
	# stay in the room to keep making its own assertions afterward.
	if level != null and get_tree().current_scene == level:
		get_tree().change_scene_to_file(ENDING_SCENE)

func _process(_delta: float) -> void:
	# Rewind restores enemies after the room; refresh the count after all of
	# those snapshots, so the label never shows the abandoned future's count.
	_sync_presentation()
	for audio in [$ReinforcementGate/PortalAudio, $ReinforcementGate/SpawnAudio, $DeathAudio]:
		audio.stream_paused = TimeService.is_world_frozen()

func _sync_presentation() -> void:
	boss_ui.visible = stage not in [Stage.DORMANT, Stage.INTRO, Stage.EXIT_WALK, Stage.COMPLETE]
	$BossUI/Panel/Result.visible = stage == Stage.COMPLETE
	var status: Label = $BossUI/Panel/Status
	var in_wave := stage in [Stage.LEAVING, Stage.OPENING, Stage.SPAWNING, Stage.WAVE, Stage.CLOSING]
	boss_bar.self_modulate.a = 0.4 if in_wave else 1.0
	status.modulate = Color(0.55, 0.85, 1.0)
	if in_wave:
		status.text = "REINFORCEMENTS REMAINING: %d" % (_living_reinforcements() + _wave_count - _spawn_index)
	elif stage in [Stage.VICTORY, Stage.COMPLETE]:
		status.text = ""
	elif is_instance_valid(boss):
		var pattern: String = ["SINGLE SHOT", "3-SHOT BURST", "TELEPORT + 2 SHOTS"][boss.combat_phase - 1]
		status.text = "PHASE %d - %s" % [boss.combat_phase, pattern]
		if boss.phase == BusinessBoss.Phase.RECOVERING or boss.state == &"Recover":
			status.text = "COUNTERATTACK"
			status.modulate = Color(0.6, 1.0, 0.65)
	var opening := 0.0
	match stage:
		Stage.OPENING: opening = _elapsed / PORTAL_OPEN_TIME
		Stage.SPAWNING, Stage.WAVE: opening = 1.0
		Stage.CLOSING: opening = 1.0 - _elapsed / PORTAL_CLOSE_TIME
	reinforcement_gate.set_open_fraction(opening, _portal_clock, _portal_spawn_left / PORTAL_SPAWN_GLOW_TIME)

func rewind_capture() -> Array:
	return [stage, _elapsed, _phase_breaks, _wave_count, _spawn_index,
		_reinforcements.duplicate(), _platform_teleport_cooldown, _stood_on, _stand_time, _shake_left, _shake_strength, _portal_clock, _portal_spawn_left]

func rewind_apply(saved: Array) -> void:
	stage = saved[0]
	_elapsed = saved[1]
	_phase_breaks = saved[2]
	_wave_count = saved[3]
	_spawn_index = saved[4]
	_reinforcements.assign(saved[5])
	_platform_teleport_cooldown = saved[6]
	_stood_on = saved[7]
	_stand_time = saved[8]
	_shake_left = saved[9]
	_shake_strength = saved[10]
	_portal_clock = saved[11]
	_portal_spawn_left = saved[12]
	_sync_camera_shake()
	_sync_presentation()
