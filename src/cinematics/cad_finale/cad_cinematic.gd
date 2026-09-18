extends Node
## Only the final platform drop, approach and fade. Opening and rescue
## artwork cutscenes are authored separately; this controller contains neither.

signal walk_finished
const WALK_DURATION := 7.4
const FALL_START := 0.6
const FALL_END := 1.9
const WALK_START := 2.4
const WALK_END := 6.1
const WALK_SPEED := 180.0
const ARRIVAL_DISTANCE := 2.0
const LANDING_TIME := 0.18
const JUMP_DISTANCE := 240.0
var active := false
var elapsed := 0.0
var player: Player
var chamber: Node2D
var camera: Camera2D
var overlay: CanvasLayer
var fade: ColorRect
var start_position := Vector2.ZERO
var _finished := false
var platform: MovingIndustrialPlatform
var platform_start := Vector2.ZERO
var riding_platform := false
var _landed := false
var descent_audio: AudioStreamPlayer
var _descent_started := false
var impact_audio: AudioStreamPlayer2D
var _jump_duration := 0.0
var _jump_started := false
var _jump_from := Vector2.ZERO
var _walk_from := Vector2.ZERO
var _walk_duration := 0.0
var _walk_begins := WALK_START
var _fade_begins := 6.4
var _end_time := WALK_DURATION

func _ready() -> void:
	descent_audio = AudioStreamPlayer.new()
	descent_audio.bus = SettingsManager.SFX_BUS
	descent_audio.stream = preload("res://assets/sounds/cad_owner/platform_drop.wav")
	descent_audio.volume_db = -3.0
	descent_audio.pitch_scale = descent_audio.stream.get_length() / (FALL_END - FALL_START)
	add_child(descent_audio)
	impact_audio = AudioStreamPlayer2D.new()
	impact_audio.bus = SettingsManager.SFX_BUS
	impact_audio.stream = preload("res://assets/sounds/boss/impactMetal_heavy_001.ogg")
	impact_audio.volume_db = -1.0
	add_child(impact_audio)
	camera = Camera2D.new()
	camera.enabled = false
	camera.position_smoothing_enabled = false
	add_child(camera)
	overlay = CanvasLayer.new()
	overlay.layer = 60
	add_child(overlay)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(root)
	for bottom in [false, true]:
		var bar := ColorRect.new()
		root.add_child(bar)
		bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE if bottom else Control.PRESET_TOP_WIDE)
		bar.offset_top = -128 if bottom else 0
		bar.offset_bottom = 0 if bottom else 70
		bar.color = Color(0.025, 0.035, 0.06, 0.94)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade = ColorRect.new()
	root.add_child(fade)
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.color = Color(0, 0, 0, 0)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.hide()

func start(actor: Player, parents_chamber: Node2D) -> void:
	player = actor
	chamber = parents_chamber
	elapsed = 0.0
	active = true
	_finished = false
	start_position = player.global_position
	platform = chamber.get_parent() as MovingIndustrialPlatform
	platform_start = platform.global_position
	riding_platform = absf(player.global_position.y - platform_start.y) < 20.0 and absf(player.global_position.x - platform_start.x) < platform.width_tiles * 32.0
	_landed = false
	_descent_started = false
	descent_audio.stop()
	platform.sync_to_physics = false
	platform.collision_layer = 0
	player.powers.cancel()
	player.clear_combat_effects()
	# Exit crouch before the animator keeps ticking independently of gameplay.
	player.states.travel(&"Idle")
	player.set_crouched(false)
	for child in player.get_children():
		if child is AudioStreamPlayer2D:
			child.stop()
	player.velocity = Vector2.ZERO
	player.process_mode = Node.PROCESS_MODE_DISABLED
	player.sprite.process_mode = Node.PROCESS_MODE_ALWAYS
	player.sprite.play(&"idle")
	var arena := get_parent() as Node2D
	camera.limit_left = roundi(arena.global_position.x)
	camera.limit_right = roundi(arena.global_position.x + 1600)
	camera.limit_top = -160
	camera.limit_bottom = 920
	camera.global_position = chamber.global_position + Vector2(0, -135)
	camera.zoom = Vector2(1.1, 1.1)
	camera.enabled = true
	camera.make_current()
	overlay.show()
	fade.color.a = 0.0
	_set_hud_visible(false)
	MusicManager.stop_music(3.0)
	_prepare_approach()
	_update_scene()

func _physics_process(delta: float) -> void:
	if not active:
		return
	# Cinematics run in real time after cancelling powers. Movement, attacks,
	# time powers, and age costs cannot run on the disabled player.
	elapsed += delta
	player.process_mode = Node.PROCESS_MODE_DISABLED
	_update_scene()
	if elapsed >= _end_time and not _finished:
		_finished = true
		active = false
		walk_finished.emit()

func _update_scene() -> void:
	var fall := clampf((elapsed - FALL_START) / (FALL_END - FALL_START), 0.0, 1.0)
	var floor_y := (get_parent() as Node2D).global_position.y + 640.0
	platform.global_position.y = lerpf(platform_start.y, floor_y, fall * fall)
	if fall > 0.0 and not _descent_started:
		_descent_started = true
		descent_audio.play()
	if fall >= 1.0 and not _landed:
		_landed = true
		descent_audio.stop()
		chamber.land()
		impact_audio.global_position = chamber.global_position
		impact_audio.play()
	if elapsed < WALK_START:
		if riding_platform:
			player.global_position.y = start_position.y + platform.global_position.y - platform_start.y
		_focus_fall()
		return
	var destination := chamber.global_position + Vector2(-155, -1)
	_update_approach(destination)
	camera.offset = Vector2.ZERO
	var walking := clampf((elapsed - _walk_begins) / maxf(_walk_duration, 0.01), 0.0, 1.0)
	camera.global_position = (player.global_position + Vector2(0, -110)).lerp(chamber.global_position + Vector2(-110, -110), walking)
	camera.zoom = Vector2.ONE * lerpf(0.95, 1.35, walking)
	# Finish the jump and ground approach before handing off to the cutscene.
	fade.color.a = smoothstep(_fade_begins, _end_time, elapsed)

func _prepare_approach() -> void:
	var floor_y := (get_parent() as Node2D).global_position.y + 639.0
	var destination := Vector2(chamber.global_position.x - 155.0, floor_y)
	_jump_from = start_position
	if riding_platform:
		_jump_from.y += floor_y + 1.0 - platform_start.y
	_walk_from = Vector2(_jump_from.x, floor_y)
	_jump_duration = 0.0
	_jump_started = false
	if floor_y - _jump_from.y > 8.0:
		# Keep the normal gravity arc; choose horizontal travel separately so
		# the descent clears every ledge, even when starting at its far edge.
		var drop := floor_y - _jump_from.y
		var initial := player.jump_velocity
		_jump_duration = (-initial + sqrt(initial * initial + 2.0 * player.gravity * drop)) / player.gravity
		var horizontal := destination.x - _jump_from.x
		_walk_from.x = _clear_landing_x(_jump_from.x + signf(horizontal) * minf(absf(horizontal), JUMP_DISTANCE))
	_walk_begins = WALK_START + _jump_duration
	if _jump_duration > 0.0:
		_walk_begins += LANDING_TIME
	_walk_duration = absf(destination.x - _walk_from.x) / WALK_SPEED
	if absf(destination.x - _walk_from.x) <= ARRIVAL_DISTANCE:
		_walk_duration = 0.0
	_fade_begins = maxf(6.4, _walk_begins + _walk_duration + 0.3)
	_end_time = _fade_begins + 1.0

## Platforms are stationary during the ending. Each one rules out landing
## positions whose straight horizontal path overlaps it on the way down.
## Include the player's full body until his head clears the platform art.
func _clear_landing_x(preferred: float) -> float:
	var body := (player.shape.shape as RectangleShape2D).size
	var margin := body.x * 0.5 + 4.0
	var forbidden: Array[Vector2] = []
	var candidates: Array[float] = [preferred]
	for ledge: MovingIndustrialPlatform in platform.get_parent().get_children():
		if ledge == platform:
			continue # The chamber platform has already dropped to ground level.
		var discriminant := player.jump_velocity ** 2 + 2.0 * player.gravity * (ledge.global_position.y - _jump_from.y)
		if discriminant < 0.0:
			continue # This ledge is above the jump's apex.
		var enter := (-player.jump_velocity + sqrt(discriminant)) / player.gravity
		if enter >= _jump_duration:
			continue
		var leave := minf(_jump_duration, (-player.jump_velocity + sqrt(discriminant + 2.0 * player.gravity * (64.0 + body.y))) / player.gravity)
		var left := ledge.global_position.x - ledge.width_tiles * 32.0 - margin - _jump_from.x
		var right := ledge.global_position.x + ledge.width_tiles * 32.0 + margin - _jump_from.x
		var interval := Vector2(
			_jump_from.x + minf(left / enter, left / leave) * _jump_duration,
			_jump_from.x + maxf(right / enter, right / leave) * _jump_duration)
		forbidden.append(interval)
		candidates.append(interval.x - 1.0)
		candidates.append(interval.y + 1.0)
	var room_left := (get_parent() as Node2D).global_position.x + margin
	var room_right := room_left + 1600.0 - 2.0 * margin
	candidates.append(room_left)
	candidates.append(room_right)
	var best := preferred
	var distance := INF
	for candidate in candidates:
		if candidate < room_left or candidate > room_right:
			continue
		var clear := true
		for interval in forbidden:
			if candidate >= interval.x and candidate <= interval.y:
				clear = false
				break
		if clear and absf(candidate - preferred) < distance:
			best = candidate
			distance = absf(candidate - preferred)
	assert(is_finite(distance), "Final arena needs a clear jump path to the ground")
	return best

func _update_approach(destination: Vector2) -> void:
	var jump_time := elapsed - WALK_START
	var clip: StringName = &"idle"
	if _jump_duration > 0.0 and jump_time < _jump_duration:
		if not _jump_started:
			_jump_started = true
			player.jumped.emit()
		player.global_position.x = lerpf(_jump_from.x, _walk_from.x, jump_time / _jump_duration)
		player.global_position.y = _jump_from.y + player.jump_velocity * jump_time + 0.5 * player.gravity * jump_time * jump_time
		clip = &"jump"
	elif elapsed < _walk_begins:
		player.global_position = _walk_from
		clip = &"land"
	else:
		var walk := 1.0 if is_zero_approx(_walk_duration) else clampf((elapsed - _walk_begins) / _walk_duration, 0.0, 1.0)
		player.global_position = _walk_from.lerp(destination, walk)
		if walk < 1.0:
			clip = &"run"
	var facing_x := _walk_from.x if clip == &"jump" else destination.x
	player.facing = -1 if facing_x < player.global_position.x else 1
	player.sprite.flip_h = player.facing < 0
	player.sprite.play(clip)

func _focus_fall() -> void:
	camera.global_position = chamber.global_position + Vector2(-110, -110)
	camera.zoom = Vector2(0.95, 0.95)
	var shake := maxf(1.0 - (elapsed - FALL_END) / 0.35, 0.0) if _landed else 0.0
	camera.offset = Vector2(sin(elapsed * 91.0), cos(elapsed * 73.0)) * 3.0 * shake

func _set_hud_visible(value: bool) -> void:
	var level := get_parent().get_parent().get_parent()
	var hud := level.get_node_or_null("HUD") as CanvasLayer
	if hud != null:
		hud.visible = value
