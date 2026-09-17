class_name BusinessBoss
extends Gunner
## Combat uses Enemy's clock. Transitions use one separate, rewindable phase;
## no animation callback can bring back a boss whose phase has since changed.

enum Phase { DORMANT, FIGHTING, DISAPPEARING, WAITING, APPEARING, RECOVERING, DYING, DEFEATED }

const LASER_SCENE := preload("res://src/actors/enemy/business_laser.tscn")
const BOSS_HEALTH := 1200.0
const BOSS_DAMAGE := 18.0
const BOSS_ATTACK_RANGE := 1050.0
const BOSS_DETECTION_RANGE := 1100.0
const FIRE_TAIL := 5.0 / 16.0
const BOSS_ATTACK_DURATION := 0.65 + FIRE_TAIL
const BOSS_ATTACK_HIT_TIME := 0.65
const BOSS_ATTACK_RECOVERY := 1.1
const BOSS_MUZZLE_HEIGHT := -94.0
const BOSS_MUZZLE_FORWARD := 53.0
const TRANSITION_DURATION := 8.0 / 12.0
const ARRIVAL_RECOVERY := 0.65

const BURST_GAP := 0.24
const HIT_FX_DURATION := 0.22
const ARRIVAL_FX_DURATION := 0.32
# Atlas margins share a foot anchor at (150, 320) on a 360 x 340 canvas.
# Uniform scaling preserves the adult proportions used by the other actors.
const COMBAT_ART_SCALE := 0.4
# Teleport's larger cells use a fixed (206, 428) anchor, even after feet vanish.
const TELEPORT_ART_SCALE := 110.0 / 383.0

signal defeated
signal reposition_requested
signal major_impact(strength: float)
signal shot_fired(laser: BusinessLaser)

var combat_phase := 1
var _shots_fired := 0
var _visual_time := 0.0
var _hit_fx_left := 0.0
var _arrival_fx_left := 0.0

@onready var charge_audio: AudioStreamPlayer2D = $ChargeAudio
@onready var teleport_audio: AudioStreamPlayer2D = $TeleportAudio
@onready var disappear_audio: AudioStreamPlayer2D = $DisappearAudio
@onready var hurt_audio: AudioStreamPlayer2D = $HurtAudio

var phase := Phase.DORMANT
var _phase_elapsed := 0.0
var _after_disappear := Phase.WAITING
var _arrival_platform: MovingIndustrialPlatform
var _arrival_offset := Vector2.ZERO
var _arrival_fallback := Vector2.ZERO

func _init() -> void:
	speed = 0.0
	detection_range = BOSS_DETECTION_RANGE
	attack_range = BOSS_ATTACK_RANGE
	attack_height_tolerance = 170.0
	detection_height_tolerance = 260.0
	eye_height = BOSS_MUZZLE_HEIGHT
	damage = BOSS_DAMAGE
	attack_duration = BOSS_ATTACK_DURATION
	attack_hit_time = BOSS_ATTACK_HIT_TIME
	attack_recovery = BOSS_ATTACK_RECOVERY
	hurt_duration = 0.28
	knockback = 90.0
	attack_animation = &"shoot"

func _ready() -> void:
	super._ready()
	health.max_health = BOSS_HEALTH
	health.current = BOSS_HEALTH
	_sync_transition_visuals()

func activate() -> void:
	if phase == Phase.DORMANT:
		_enter_phase(Phase.FIGHTING)

func _physics_process(delta: float) -> void:
	if TimeService.is_rewinding():
		super._physics_process(delta)
		return
	var scaled := world_delta(delta)
	_visual_time += scaled
	_hit_fx_left = maxf(_hit_fx_left - scaled, 0.0)
	_arrival_fx_left = maxf(_arrival_fx_left - scaled, 0.0)
	if phase == Phase.FIGHTING:
		super._physics_process(delta)
		_sync_transition_visuals()
		return
	_sync_to_world_time()
	if is_zero_approx(scaled):
		return
	_phase_elapsed += scaled
	match phase:
		Phase.DISAPPEARING:
			if _phase_elapsed >= TRANSITION_DURATION:
				_enter_phase(_after_disappear)
		Phase.APPEARING:
			global_position = _arrival_position()
			if _phase_elapsed >= TRANSITION_DURATION:
				_enter_phase(Phase.RECOVERING)
		Phase.RECOVERING:
			apply_gravity(scaled)
			move_in_time()
			if _phase_elapsed >= ARRIVAL_RECOVERY:
				_enter_phase(Phase.FIGHTING)
		Phase.DYING:
			if _phase_elapsed >= TRANSITION_DURATION:
				_enter_phase(Phase.DEFEATED)
				EventBus.enemy_died.emit(self, age_reward)
				defeated.emit()
				TimeService.retire(self)
	_sync_transition_visuals()

## Keep the encounter stationary; walking poses are available for future staging.
func _tick_chase(_delta: float) -> void:
	velocity.x = 0.0
	if is_instance_valid(target):
		_face_target_mid_attack()
	_set_animation(&"idle")

func set_combat_phase(number: int) -> void:
	combat_phase = clampi(number, 1, 3)
	attack_hit_time = 0.75 if combat_phase == 3 else BOSS_ATTACK_HIT_TIME
	attack_duration = attack_hit_time + (burst_size() - 1) * BURST_GAP + FIRE_TAIL
	attack_recovery = [1.1, 1.35, 1.25][combat_phase - 1]

func burst_size() -> int:
	return [1, 3, 2][combat_phase - 1]

func _set_animation(name: StringName) -> void:
	sprite.animation = &"idle" if name == &"run" else name
	sprite.stop()
	sprite.flip_h = facing < 0

func _sync_to_world_time() -> void:
	# The combat clock owns every pose, including the muzzle flash.
	sprite.speed_scale = 0.0
	for audio in _audio:
		audio.stream_paused = TimeService.is_world_frozen()

func _attack_clip() -> StringName:
	return &"charge"

func _change_state(next: StringName) -> void:
	if state == next:
		return
	super._change_state(next)
	charge_audio.stop()
	if next == &"Attack":
		_shots_fired = 0
		if is_instance_valid(target):
			_face_target_mid_attack()
		charge_audio.pitch_scale = charge_audio.stream.get_length() / attack_hit_time
		charge_audio.play()

func _tick_attack(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, GROUND_FRICTION * delta)
	if not is_instance_valid(target) or target.is_down():
		_change_state(&"Idle")
		return
	# Facing is committed when the charge begins. Dodging behind him works.
	while _shots_fired < burst_size() and _state_elapsed >= attack_hit_time + _shots_fired * BURST_GAP:
		_shots_fired += 1
		_attack_fired = true
		charge_audio.stop()
		_attack()
	if _state_elapsed >= attack_duration:
		_change_state(&"Recover")

func _tick_recover(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, GROUND_FRICTION * delta)
	if _state_elapsed < attack_recovery:
		return
	if combat_phase == 3:
		# Only reposition after the full counterattack window, then charge the
		# next pair after the visible arrival and its recovery have completed.
		reposition_requested.emit()
		if phase != Phase.FIGHTING:
			return
	_change_state(&"Chase")

func _attack() -> void:
	if phase != Phase.FIGHTING or not is_instance_valid(target) or not has_line_of_sight():
		return
	var laser := LASER_SCENE.instantiate() as BusinessLaser
	get_tree().current_scene.add_child(laser)
	laser.global_position = global_position + Vector2(facing * BOSS_MUZZLE_FORWARD, BOSS_MUZZLE_HEIGHT)
	laser.setup(Vector2(facing, 0.0) * BULLET_SPEED, damage, self)
	_shot_audio.play()
	_sync_combat_pose()
	shot_fired.emit(laser)

func _on_damaged(_amount: float, source: Node) -> void:
	if state == &"Dead":
		return
	_flash = 1.0
	_hit_fx_left = HIT_FX_DURATION
	if is_instance_valid(source):
		_hurt_from = 1 if source.global_position.x > global_position.x else -1
	# Flinch without resetting a burst or shortening the promised recovery.
	if state in [&"Idle", &"Chase"]:
		_change_state(&"Hurt")
	hurt_audio.play()
	_sync_transition_visuals()

func receive_player_hit(base_damage: float, source: Node) -> void:
	if phase in [Phase.FIGHTING, Phase.RECOVERING] and not TimeService.is_rewinding():
		health.take_damage(base_damage, source)

func begin_intermission() -> void:
	if phase in [Phase.DYING, Phase.DEFEATED, Phase.WAITING]:
		return
	_arrival_platform = null
	_after_disappear = Phase.WAITING
	_enter_phase(Phase.DISAPPEARING)

func resume_after_intermission(destination: Vector2) -> void:
	if phase != Phase.WAITING:
		return
	_arrival_platform = null
	_arrival_fallback = destination
	_enter_phase(Phase.APPEARING)

func teleport_to_platform(platform: MovingIndustrialPlatform, offset: Vector2) -> bool:
	if phase != Phase.FIGHTING or not is_instance_valid(platform):
		return false
	_arrival_platform = platform
	_arrival_offset = offset
	_arrival_fallback = platform.global_position + offset
	_after_disappear = Phase.APPEARING
	_enter_phase(Phase.DISAPPEARING)
	return true

func teleport_to_floor(destination: Vector2) -> bool:
	if phase != Phase.FIGHTING:
		return false
	_arrival_platform = null
	_arrival_fallback = destination
	_after_disappear = Phase.APPEARING
	_enter_phase(Phase.DISAPPEARING)
	return true

func _arrival_position() -> Vector2:
	if is_instance_valid(_arrival_platform):
		return _arrival_platform.global_position + _arrival_offset
	return _arrival_fallback

func _enter_phase(next: Phase) -> void:
	phase = next
	charge_audio.stop()
	_phase_elapsed = 0.0
	velocity = Vector2.ZERO
	_state_elapsed = 0.0
	_attack_fired = false
	state = &"Dead" if next in [Phase.DYING, Phase.DEFEATED] else &"Idle"
	_set_animation(&"idle")
	var solid := next in [Phase.DORMANT, Phase.FIGHTING, Phase.RECOVERING]
	collision_layer = 4 if solid else 0
	collision_mask = 3 if solid else 0
	if next == Phase.APPEARING:
		global_position = _arrival_position()
	if next in [Phase.DISAPPEARING, Phase.APPEARING]:
		if next == Phase.DISAPPEARING:
			disappear_audio.play()
		else:
			disappear_audio.stop()
			teleport_audio.play()
		major_impact.emit(8.0 if next == Phase.DISAPPEARING else 7.0)
	if next == Phase.RECOVERING:
		_arrival_fx_left = ARRIVAL_FX_DURATION
		major_impact.emit(6.0)
	elif next == Phase.DYING:
		for audio in _audio:
			audio.stop()
		major_impact.emit(5.0)
	_sync_transition_visuals()

func _on_died() -> void:
	if phase not in [Phase.DYING, Phase.DEFEATED]:
		_enter_phase(Phase.DYING)

func _on_animation_finished() -> void:
	pass

## Sample effects from the phase clock, so pause and rewind restore the same
## frame and opacity without replaying a sound or leaving a callback behind.
func _sync_transition_visuals() -> void:
	_sync_combat_pose()
	$CombatEffects.queue_redraw()
	var progress := clampf(_phase_elapsed / TRANSITION_DURATION, 0.0, 1.0)
	sprite.visible = phase not in [Phase.WAITING, Phase.DEFEATED]
	sprite.self_modulate.a = 1.0
	if phase == Phase.DISAPPEARING:
		# The sheet dissolves the body. Only fade the last few sparks so the
		# actual poses stay readable instead of vanishing halfway through.
		sprite.self_modulate.a = 1.0 - smoothstep(0.875, 1.0, progress)
	elif phase == Phase.APPEARING:
		sprite.self_modulate.a = smoothstep(0.0, 0.125, progress)
	queue_redraw()

func _sync_combat_pose() -> void:
	var clip: StringName = &"idle"
	var frame := int(_visual_time * 5.0) % 4
	if phase == Phase.FIGHTING:
		match state:
			&"Attack":
				if _shots_fired == 0:
					clip = &"charge"
					frame = mini(int(_state_elapsed / attack_hit_time * 6.0), 5)
				else:
					clip = &"fire"
					var since_shot := _state_elapsed - attack_hit_time - (_shots_fired - 1) * BURST_GAP
					frame = clampi(int(since_shot * 16.0), 0, 4)
			&"Recover":
				clip = &"recover"
				frame = mini(int(_state_elapsed * 8.0), 4)
			&"Hurt":
				clip = &"hurt"
				frame = mini(int(_state_elapsed / hurt_duration * 4.0), 3)
	elif phase in [Phase.DISAPPEARING, Phase.APPEARING]:
		clip = &"teleport"
		var last := sprite.sprite_frames.get_frame_count(clip) - 1
		frame = clampi(int(_phase_elapsed / TRANSITION_DURATION * (last + 1)), 0, last)
		if phase == Phase.APPEARING:
			frame = last - frame
	elif phase == Phase.RECOVERING:
		clip = &"recover"
		frame = 4
	elif phase == Phase.DYING:
		clip = &"dying"
		frame = clampi(int(_phase_elapsed / TRANSITION_DURATION * 4.0), 0, 3)
	# Sample the four-pose flinch from saved combat clocks. It never cancels
	# a burst or shortens the counterattack window.
	if _hit_fx_left > 0.0 and state != &"Attack" and phase in [Phase.FIGHTING, Phase.RECOVERING]:
		clip = &"hurt"
		frame = mini(int((1.0 - _hit_fx_left / HIT_FX_DURATION) * 4.0), 3)
	sprite.animation = clip
	sprite.set_frame_and_progress(frame, 0.0)
	sprite.flip_h = facing < 0
	# Atlas margins align the feet; no per-frame stretching or body warping.
	if clip == &"teleport":
		sprite.scale = Vector2.ONE * TELEPORT_ART_SCALE
		sprite.position = Vector2(facing * 16.0 * TELEPORT_ART_SCALE, -206.0 * TELEPORT_ART_SCALE)
	else:
		sprite.scale = Vector2.ONE * COMBAT_ART_SCALE
		sprite.position = Vector2(facing * 30.0 * COMBAT_ART_SCALE, -150.0 * COMBAT_ART_SCALE)
	sprite.rotation = 0.0

func rewind_began() -> void:
	for audio in _audio:
		audio.stop()

func _draw() -> void:
	if phase == Phase.DISAPPEARING and _after_disappear == Phase.APPEARING:
		draw_set_transform(to_local(_arrival_position()), 0.0, Vector2(1.0, 0.3))
		draw_arc(Vector2.ZERO, 36.0, 0.0, TAU, 40, Color(0.2, 0.8, 1.0, 0.9), 4.0, true)
		draw_arc(Vector2.ZERO, 24.0, 0.0, TAU, 40, Color(0.6, 0.95, 1.0, 0.6), 2.0, true)

func rewind_capture() -> Array:
	var saved := super()
	saved.append([phase, _phase_elapsed, _after_disappear, _arrival_platform, _arrival_offset, _arrival_fallback,
		combat_phase, _shots_fired, _visual_time, _hit_fx_left, _arrival_fx_left])
	return saved

func rewind_apply(saved: Array) -> void:
	super(saved)
	var transition: Array = saved[-1]
	phase = transition[0]
	_phase_elapsed = transition[1]
	_after_disappear = transition[2]
	_arrival_platform = transition[3]
	_arrival_offset = transition[4]
	_arrival_fallback = transition[5]
	set_combat_phase(transition[6])
	_shots_fired = transition[7]
	_visual_time = transition[8]
	_hit_fx_left = transition[9]
	_arrival_fx_left = transition[10]
	_sync_transition_visuals()
