class_name StoneTitan
extends TimeBody2D
## The boss-room creature. It advances on the player, but its only attack is a
## clearly telegraphed two-foot stomp; the arena owns the resulting rock wave.
##
## Everything that makes it feel like a creature rather than a sprite that
## slides about is built here in code, so the scene stays as authored:
##
##   - a voice: it roars awake, growls before a stomp, shouts on the slam,
##     grunts when cut and bellows when it dies. The vocal set is real creature
##     recordings pitched down into stone (see assets/sounds/boss/voice);
##   - the slam is cut to the animation, so the foot hits the floor on the
##     frame the art shows it hitting, in every phase;
##   - the body reacts: ground rings under the raised foot, pebbles jumping,
##     an outline that burns cyan while it is open to a hit, chips knocked off
##     it by the sword, and a crumble on death timed to the dying frames;
##   - the health bar carries a ghost of the last hit and changes colour with
##     the phase.

signal awakened
signal stomp_warning(stomp_number: int, phase: int)
signal stomp_impact(stomp_number: int, phase: int)
signal defeated
signal death_finished

const SHEETS := {
	&"idle": [preload("res://assets/sprites/levelOneBoss/Golem_1_idle.png"), 8, 8.0, true],
	&"walk": [preload("res://assets/sprites/levelOneBoss/Golem_1_walk.png"), 10, 10.0, true],
	&"attack": [preload("res://assets/sprites/levelOneBoss/Golem_1_attack.png"), 11, 11.0, false],
	&"hurt": [preload("res://assets/sprites/levelOneBoss/Golem_1_hurt.png"), 4, 12.0, false],
	&"dying": [preload("res://assets/sprites/levelOneBoss/Golem_1_die.png"), 13, 10.0, false],
}
## The attack clip's fist meets the floor on this frame; the wind-up is
## stretched or squeezed so the impact lands exactly here.
const SLAM_FRAME := 6
## Walk frames on which a foot comes down.
const STEP_FRAMES := [2, 7]
## Dying frames on which a piece of it hits the floor, with how hard.
const CRUMBLE_FRAMES := {4: 0.6, 6: 0.75, 8: 0.9, 10: 1.25}

const CHASE_SPEED := 165.0
const CHASE_ACCELERATION := 760.0
const FRICTION := 1100.0
const STOMP_RECOVERY := 1.05
const FIRST_STOMP_DELAY := 1.4
const AWAKEN_DURATION := 2.1
const NORMAL_DAMAGE_MULTIPLIER := 0.72
const VULNERABLE_DAMAGE_MULTIPLIER := 1.65
const IMPACT_SCENE := preload("res://src/levels/level_01/boss_impact_effect.tscn")

const STEP_SOUNDS: Array[AudioStream] = [
	preload("res://assets/sounds/boss/footstep_concrete_000.ogg"),
	preload("res://assets/sounds/boss/footstep_concrete_001.ogg"),
	preload("res://assets/sounds/boss/footstep_concrete_002.ogg"),
	preload("res://assets/sounds/boss/footstep_concrete_003.ogg"),
	preload("res://assets/sounds/boss/footstep_concrete_004.ogg"),
]
const WINDUP_SOUNDS: Array[AudioStream] = [
	preload("res://assets/sounds/boss/creak1.ogg"),
	preload("res://assets/sounds/boss/creak2.ogg"),
	preload("res://assets/sounds/boss/creak3.ogg"),
]
const STOMP_SOUNDS: Array[AudioStream] = [
	preload("res://assets/sounds/boss/impactSoft_heavy_000.ogg"),
	preload("res://assets/sounds/boss/impactSoft_heavy_001.ogg"),
	preload("res://assets/sounds/boss/impactSoft_heavy_002.ogg"),
	preload("res://assets/sounds/boss/impactSoft_heavy_003.ogg"),
	preload("res://assets/sounds/boss/impactSoft_heavy_004.ogg"),
]
const BODY_IMPACTS: Array[AudioStream] = [
	preload("res://assets/sounds/boss/impactMetal_heavy_000.ogg"),
	preload("res://assets/sounds/boss/impactMetal_heavy_001.ogg"),
	preload("res://assets/sounds/boss/impactMetal_heavy_002.ogg"),
	preload("res://assets/sounds/boss/impactMetal_heavy_003.ogg"),
	preload("res://assets/sounds/boss/impactMetal_heavy_004.ogg"),
]
const VOICE_AWAKEN: AudioStream = preload("res://assets/sounds/boss/voice/titan_awaken.ogg")
const VOICE_DEATH: AudioStream = preload("res://assets/sounds/boss/voice/titan_death.ogg")
const VOICE_ROARS: Array[AudioStream] = [
	preload("res://assets/sounds/boss/voice/titan_roar_01.ogg"),
	preload("res://assets/sounds/boss/voice/titan_roar_02.ogg"),
]
const VOICE_GROWLS: Array[AudioStream] = [
	preload("res://assets/sounds/boss/voice/titan_growl_01.ogg"),
	preload("res://assets/sounds/boss/voice/titan_growl_02.ogg"),
	preload("res://assets/sounds/boss/voice/titan_growl_03.ogg"),
]
const VOICE_SHOUTS: Array[AudioStream] = [
	preload("res://assets/sounds/boss/voice/titan_shout_01.ogg"),
	preload("res://assets/sounds/boss/voice/titan_shout_02.ogg"),
	preload("res://assets/sounds/boss/voice/titan_shout_03.ogg"),
]
const VOICE_HURTS: Array[AudioStream] = [
	preload("res://assets/sounds/boss/voice/titan_hurt_01.ogg"),
	preload("res://assets/sounds/boss/voice/titan_hurt_02.ogg"),
	preload("res://assets/sounds/boss/voice/titan_hurt_03.ogg"),
	preload("res://assets/sounds/boss/voice/titan_hurt_04.ogg"),
]
const STOMP_SUB: AudioStream = preload("res://assets/sounds/boss/voice/stomp_sub.ogg")
const GROUND_RUMBLE: AudioStream = preload("res://assets/sounds/boss/voice/ground_rumble.ogg")

const VULNERABLE := Color(0.34, 0.86, 1.0)
const WARNING := Color(1.0, 0.36, 0.06)
const PHASE_FILL := {
	1: [Color(0.86, 0.27, 0.08), Color(1.0, 0.62, 0.18)],
	2: [Color(0.95, 0.42, 0.06), Color(1.0, 0.78, 0.3)],
	3: [Color(0.82, 0.1, 0.08), Color(1.0, 0.4, 0.25)],
}

## Outline, flash and tint on the sprite. Neighbour samples are clamped to
## the current frame so the outline cannot pick up the frame next door on
## the sheet.
const SPRITE_SHADER := """
shader_type canvas_item;

uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0, 0.93, 0.8, 1.0);
uniform float outline : hint_range(0.0, 1.0) = 0.0;
uniform vec4 outline_color : source_color = vec4(0.34, 0.86, 1.0, 1.0);
uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 0.0);
uniform vec4 region = vec4(0.0, 0.0, 1.0, 1.0);

varying vec4 modulate;

void vertex() {
	modulate = COLOR;
}

void fragment() {
	vec4 col = texture(TEXTURE, UV);
	float edge = 0.0;
	if (outline > 0.001) {
		vec2 px = TEXTURE_PIXEL_SIZE;
		vec2 lo = region.xy + px * 0.5;
		vec2 hi = region.zw - px * 0.5;
		// Two texels deep: at the room's zoom one texel is a hairline.
		for (int ring = 1; ring <= 2; ring++) {
			vec2 step = px * float(ring);
			edge = max(edge, texture(TEXTURE, clamp(UV + vec2(step.x, 0.0), lo, hi)).a);
			edge = max(edge, texture(TEXTURE, clamp(UV - vec2(step.x, 0.0), lo, hi)).a);
			edge = max(edge, texture(TEXTURE, clamp(UV + vec2(0.0, step.y), lo, hi)).a);
			edge = max(edge, texture(TEXTURE, clamp(UV - vec2(0.0, step.y), lo, hi)).a);
			edge = max(edge, texture(TEXTURE, clamp(UV + step, lo, hi)).a);
			edge = max(edge, texture(TEXTURE, clamp(UV - step, lo, hi)).a);
			edge = max(edge, texture(TEXTURE, clamp(UV + vec2(step.x, -step.y), lo, hi)).a);
			edge = max(edge, texture(TEXTURE, clamp(UV - vec2(step.x, -step.y), lo, hi)).a);
		}
	}
	vec3 rgb = mix(col.rgb, col.rgb * tint.rgb, tint.a);
	rgb = mix(rgb, flash_color.rgb, flash);
	float rim = (1.0 - col.a) * edge * outline * outline_color.a;
	vec3 out_rgb = mix(outline_color.rgb, rgb, col.a);
	COLOR = vec4(out_rgb, max(col.a, rim)) * modulate;
}
"""

@onready var health: HealthComponent = $Health
@onready var sprite: AnimatedSprite2D = $Sprite
@onready var warning_ring: Line2D = $WarningRing
@onready var boss_hud: CanvasLayer = $BossHUD
@onready var health_bar: ProgressBar = $BossHUD/Panel/Bar
@onready var step_audio: AudioStreamPlayer2D = $StepAudio
@onready var windup_audio: AudioStreamPlayer2D = $WindupAudio
@onready var stomp_audio: AudioStreamPlayer2D = $StompAudio
@onready var stomp_body_audio: AudioStreamPlayer2D = $StompBodyAudio
@onready var hurt_audio: AudioStreamPlayer2D = $HurtAudio
@onready var death_audio: AudioStreamPlayer2D = $DeathAudio

var target: Player
var active := false
var phase := 1
var stomp_count := 0
var movement_left := 0.0
var movement_right := 0.0

var _state: StringName = &"inactive"
var _state_time := 0.0
var _attack_cooldown := FIRST_STOMP_DELAY
var _impact_fired := false
var _facing := -1
var _flash := 0.0
var _flash_color := Color(1.0, 0.93, 0.8)
var _glow := 0.0
var _stomp_pose: Tween
var _rest_sprite_scale := Vector2.ONE
var _hurt_audio_cooldown := 0.0
var _vulnerable := false
var _vulnerable_time := 0.0
var _sprite_material: ShaderMaterial
var _ground_marks: Node2D
var _tremor: CPUParticles2D
var _voice: AudioStreamPlayer2D
var _voice_layer: AudioStreamPlayer2D
var _sub_audio: AudioStreamPlayer2D
var _ghost_bar: ColorRect
var _ghost_ratio := 1.0
var _ghost_hold := 0.0
var _crumbled_frames := {}
var _windup_ring := 0.0


func _ready() -> void:
	add_to_group(&"enemy")
	_build_frames()
	_build_sprite_material()
	_build_ground_marks()
	_build_voice()
	_build_ghost_bar()
	health.changed.connect(_on_health_changed)
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	sprite.animation_finished.connect(_on_animation_finished)
	sprite.frame_changed.connect(_on_frame_changed)
	sprite.animation_changed.connect(_update_sprite_region)
	health_bar.max_value = health.max_health
	health_bar.value = health.current
	boss_hud.hide()
	# The authored ring is superseded by the drawn ground marks; it stays in
	# the scene so nothing that looks it up breaks.
	warning_ring.hide()
	_rest_sprite_scale = sprite.scale
	_apply_phase_fill(1)
	_play(&"idle")
	_update_sprite_region()


func activate(player: Player, left_edge: float, right_edge: float) -> void:
	if active or not health.is_alive():
		return
	target = player
	movement_left = left_edge
	movement_right = right_edge
	active = true
	_attack_cooldown = FIRST_STOMP_DELAY
	_change_state(&"awaken")
	_begin_awakening()


func _physics_process(delta: float) -> void:
	if _state == &"dead":
		apply_gravity(delta)
		move_and_slide()
		sprite.speed_scale = 1.0
		_tick_flash(delta)
		_ground_marks.queue_redraw()
		return

	var scaled := world_delta(delta)
	sprite.speed_scale = TimeService.world_scale * _animation_rate()
	BossVfx.tick(_tremor, TimeService.world_scale)
	if is_zero_approx(scaled):
		return

	_tick_flash(scaled)
	_hurt_audio_cooldown = maxf(_hurt_audio_cooldown - scaled, 0.0)

	apply_gravity(scaled)
	_state_time += scaled
	if _state != &"awaken":
		_attack_cooldown -= scaled

	match _state:
		&"inactive":
			velocity.x = move_toward(velocity.x, 0.0, FRICTION * scaled)
			_play(&"idle")
		&"awaken":
			velocity.x = move_toward(velocity.x, 0.0, FRICTION * scaled)
			_tick_awaken(scaled)
		&"chase":
			_tick_chase(scaled)
		&"windup":
			_tick_windup(scaled)
		&"recover":
			velocity.x = move_toward(velocity.x, 0.0, FRICTION * scaled)
			if not _is_flinching():
				_play(&"idle")
			_vulnerable_time += scaled
			_update_vulnerability_visual()
			if _state_time >= _recovery_duration():
				_change_state(&"chase")

	_ground_marks.queue_redraw()
	move_in_time()
	if active:
		global_position.x = clampf(global_position.x, movement_left, movement_right)


func _process(delta: float) -> void:
	# HUD only: the ghost bar trails the real one on the raw clock, because the
	# bar is the player's, not the world's.
	if _ghost_bar == null:
		return
	var ratio := health.current / health.max_health if health.max_health > 0.0 else 0.0
	if _ghost_hold > 0.0:
		_ghost_hold -= delta
	else:
		_ghost_ratio = move_toward(_ghost_ratio, ratio, delta * 0.45)
	_ghost_ratio = maxf(_ghost_ratio, ratio)
	_ghost_bar.anchor_left = ratio
	_ghost_bar.anchor_right = _ghost_ratio
	_ghost_bar.visible = _ghost_ratio - ratio > 0.002


func _tick_flash(delta: float) -> void:
	_flash = maxf(_flash - delta * 5.5, 0.0)
	# A hit flash wins over the open-window glow; the glow is what remains.
	var hit := _flash * 0.7
	if hit >= _glow:
		_sprite_material.set_shader_parameter(&"flash", hit)
		_sprite_material.set_shader_parameter(&"flash_color", _flash_color)
	else:
		_sprite_material.set_shader_parameter(&"flash", _glow)
		_sprite_material.set_shader_parameter(&"flash_color", VULNERABLE)


func _animation_rate() -> float:
	if _state == &"windup":
		var clip_fps: float = SHEETS[&"attack"][2]
		return (float(SLAM_FRAME) / clip_fps) / _windup_duration()
	return 1.0


## The wake-up: it has been standing in the dark as scenery, and now it is
## not. Roar, tremor, dust off its shoulders, the camera pulled onto it and
## the bar filling in.
func _begin_awakening() -> void:
	boss_hud.show()
	health_bar.value = 0.0
	var fill := create_tween()
	fill.tween_interval(0.45)
	fill.tween_property(health_bar, ^"value", health.current, 1.3).set_trans(Tween.TRANS_SINE)
	_ghost_ratio = 0.0
	_ghost_hold = 1.8
	_say(VOICE_AWAKEN, -1.0, 1.0)
	_rumble(-6.0, 0.9)
	_tremor.emitting = true
	_burst_at_feet(0.9, true)
	_flash_color = Color(1.0, 0.75, 0.45)
	_flash = 0.7
	var rig := BossCameraRig.find(get_tree())
	if rig != null:
		rig.focus_on(global_position + Vector2(0.0, -80.0), 0.5, 2.4)
		rig.punch_zoom(0.04, 1.6)
		rig.add_trauma(0.55)
	var fx := BossScreenFx.find(get_tree())
	if fx != null:
		fx.set_vignette(0.42, 1.6)
		fx.flash(Color(1.0, 0.6, 0.3), 0.12, 3.0)


func _tick_awaken(delta: float) -> void:
	_play(&"idle")
	# A slow rise through the roar, and a shiver on top of it.
	var progress := clampf(_state_time / AWAKEN_DURATION, 0.0, 1.0)
	var shiver := sin(_state_time * 46.0) * (1.0 - progress) * 2.2
	sprite.position = Vector2(shiver, -lerpf(0.0, 6.0, ease(progress, 0.5)) + absf(shiver) * 0.4)
	var rig := BossCameraRig.find(get_tree())
	if rig != null and _state_time < AWAKEN_DURATION * 0.7:
		rig.add_trauma(0.32 * delta * (1.0 - progress))
	if _state_time >= AWAKEN_DURATION:
		sprite.position = Vector2.ZERO
		_tremor.emitting = false
		if rig != null:
			rig.release_focus()
		var fx := BossScreenFx.find(get_tree())
		if fx != null:
			fx.set_vignette(0.0, 1.2)
		_change_state(&"chase")
		awakened.emit()


func _tick_chase(delta: float) -> void:
	if target == null or not is_instance_valid(target) or target.is_down():
		velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)
		_play(&"idle")
		return
	var dx := target.global_position.x - global_position.x
	if not is_zero_approx(dx):
		_facing = 1 if dx > 0.0 else -1
	velocity.x = move_toward(velocity.x, float(_facing) * CHASE_SPEED, CHASE_ACCELERATION * delta)
	_play(&"walk")
	if _attack_cooldown <= 0.0:
		_begin_stomp()


func _begin_stomp() -> void:
	stomp_count += 1
	_impact_fired = false
	_change_state(&"windup")
	_windup_ring = 0.0
	_tremor.emitting = true
	_raise_foot_for_stomp()
	_play_variant(windup_audio, WINDUP_SOUNDS, -8.0, randf_range(0.68, 0.78))
	_say_variant(VOICE_GROWLS, -4.0, randf_range(0.94, 1.04))
	var fx := BossScreenFx.find(get_tree())
	if fx != null:
		# The frame braces with it: edges close in a little until the slam.
		fx.set_vignette(0.2, 2.5)
	stomp_warning.emit(stomp_count, phase)


func _tick_windup(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)
	_play(&"attack")
	_windup_ring = clampf(_state_time / _windup_duration(), 0.0, 1.0)
	if not _impact_fired and _state_time >= _windup_duration():
		_impact_fired = true
		_tremor.emitting = false
		_slam_feet_down()
		_play_stomp_audio()
		var fx := BossScreenFx.find(get_tree())
		if fx != null:
			fx.set_vignette(0.0, 3.0)
		stomp_impact.emit(stomp_count, phase)
		_attack_cooldown = _stomp_interval()
		_change_state(&"recover")


func _change_state(next: StringName) -> void:
	if next != &"recover":
		_set_vulnerable(false)
	_state = next
	_state_time = 0.0
	match next:
		&"awaken": _play(&"idle")
		&"chase": _play(&"walk")
		&"windup": _play(&"attack")
		&"recover":
			_play(&"idle")
			_set_vulnerable(true)
		&"dead": _play(&"dying")


func _stomp_interval() -> float:
	match phase:
		2: return 2.75
		3: return 2.35
		_: return 3.2


func _recovery_duration() -> float:
	return STOMP_RECOVERY - float(phase - 1) * 0.12


func _windup_duration() -> float:
	match phase:
		2: return 0.66
		3: return 0.56
		_: return 0.78


func is_vulnerable() -> bool:
	return _vulnerable


func receive_player_hit(base_damage: float, source: Node) -> void:
	var multiplier := VULNERABLE_DAMAGE_MULTIPLIER if _vulnerable \
		else NORMAL_DAMAGE_MULTIPLIER
	var from := global_position + Vector2(float(-_facing) * 40.0, -80.0)
	if source is Node2D:
		from = source.global_position
	_show_hit(from, _vulnerable)
	health.take_damage(base_damage * multiplier, source)


func _play(animation: StringName) -> void:
	if sprite.animation != animation:
		sprite.play(animation)
	sprite.flip_h = _facing < 0


func _is_flinching() -> bool:
	return sprite.animation == &"hurt" and sprite.is_playing()


func _on_health_changed(current: float, maximum: float) -> void:
	if _state != &"awaken":
		health_bar.max_value = maximum
		health_bar.value = current
	var ratio := current / maximum if maximum > 0.0 else 0.0
	var next_phase := 3 if ratio <= 0.33 else 2 if ratio <= 0.66 else 1
	if next_phase > phase and _state != &"dead":
		phase = next_phase
		_enter_phase(next_phase)
	else:
		phase = next_phase


func _on_damaged(_amount: float, _source: Node) -> void:
	if _state == &"dead":
		return
	_flash_color = Color(1.0, 0.93, 0.8)
	_flash = 1.0
	_ghost_hold = 0.55
	if _hurt_audio_cooldown <= 0.0:
		_play_variant(hurt_audio, BODY_IMPACTS, -7.0, randf_range(0.78, 0.9))
		_say_variant(VOICE_HURTS, -6.0, randf_range(0.92, 1.08), false)
		_hurt_audio_cooldown = 0.22
	if _state == &"recover":
		# Open and cut: it flinches. Never while walking or winding up, or the
		# stomp's timing would drift with every hit.
		sprite.play(&"hurt")
		sprite.flip_h = _facing < 0


## Sparks and chips at the point of contact, and a shove of the sprite away
## from it. Bigger when it lands in the open window, which is the fight's
## whole lesson.
func _show_hit(from: Vector2, open: bool) -> void:
	var parent := get_parent()
	if parent == null:
		return
	var side := signf(global_position.x - from.x)
	if is_zero_approx(side):
		side = float(-_facing)
	# The sword lands at chest height off the boy's feet (SwordEffects.THRUST_Y),
	# not at his feet, which is where his position is measured.
	var contact := Vector2(global_position.x - side * 34.0,
		clampf(from.y - 74.0, global_position.y - 130.0, global_position.y - 40.0))
	var strength := 1.15 if open else 0.7
	var sparks := BossVfx.spark_burst(parent, contact, 10 if open else 5, strength, 16)
	sparks.direction = Vector2(side, -0.6)
	sparks.spread = 40.0
	var chips := BossVfx.debris_burst(parent, contact, 6 if open else 3, strength * 0.8, false, 16)
	chips.direction = Vector2(side, -0.8)
	chips.spread = 45.0
	var puff := BossVfx.dust_burst(parent, contact, strength * 0.5, false, 15)
	puff.color_ramp = null
	puff.color = Color(0.55, 0.62, 0.72, 0.6)
	var rig := BossCameraRig.find(get_tree())
	if rig != null:
		rig.add_trauma(0.18 if open else 0.08)
	if _stomp_pose != null and _stomp_pose.is_valid() and _state == &"windup":
		return
	var nudge := create_tween()
	nudge.tween_property(sprite, ^"position", Vector2(side * (7.0 if open else 4.0), 0.0), 0.05)
	nudge.tween_property(sprite, ^"position", Vector2.ZERO, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _enter_phase(new_phase: int) -> void:
	_apply_phase_fill(new_phase)
	_say_variant(VOICE_ROARS, -1.0, 1.0 if new_phase == 2 else 0.92)
	_rumble(-9.0, 1.0)
	_flash_color = Color(1.0, 0.45, 0.15)
	_flash = 1.0
	_burst_at_feet(1.0, true)
	var rig := BossCameraRig.find(get_tree())
	if rig != null:
		rig.add_trauma(0.5)
		rig.punch_zoom(0.05, 0.9)
	var fx := BossScreenFx.find(get_tree())
	if fx != null:
		fx.pulse_vignette(0.45)
		fx.flash(Color(1.0, 0.35, 0.15), 0.14, 3.5)
		fx.shockwave(global_position, 0.6)
	# The title shudders with the roar.
	var title := boss_hud.get_node_or_null(^"Panel/Title") as Label
	if title != null:
		var shudder := create_tween()
		for step in 6:
			shudder.tween_property(title, ^"position:x", (3.0 if step % 2 == 0 else -3.0), 0.04)
		shudder.tween_property(title, ^"position:x", 0.0, 0.04)


func _on_died() -> void:
	active = false
	velocity.x = 0.0
	collision_layer = 0
	collision_mask = 1
	warning_ring.hide()
	_tremor.emitting = false
	_reset_stomp_pose()
	boss_hud.hide()
	_crumbled_frames.clear()
	_play_variant(death_audio, BODY_IMPACTS, -1.5, 0.64)
	_say(VOICE_DEATH, 0.0, 1.0)
	_rumble(-3.0, 0.8)
	_flash_color = Color(1.0, 0.95, 0.85)
	_flash = 1.0
	_sprite_material.set_shader_parameter(&"outline", 0.0)
	var rig := BossCameraRig.find(get_tree())
	if rig != null:
		rig.add_trauma(0.75)
		rig.punch_zoom(0.07, 1.4)
		rig.focus_on(global_position + Vector2(0.0, -60.0), 0.45, 2.0)
	var fx := BossScreenFx.find(get_tree())
	if fx != null:
		fx.flash(Color(1.0, 0.9, 0.75), 0.55, 2.4)
		fx.shockwave(global_position, 1.0)
		fx.set_vignette(0.5, 1.5)
	# It goes grey as it comes apart: the light leaves the stone.
	var fade := create_tween()
	fade.tween_method(func(amount: float) -> void:
		_sprite_material.set_shader_parameter(&"tint", Color(0.42, 0.42, 0.48, amount)),
		0.0, 1.0, 1.3)
	_change_state(&"dead")
	defeated.emit()


func _raise_foot_for_stomp() -> void:
	if _stomp_pose != null and _stomp_pose.is_valid():
		_stomp_pose.kill()
	var lean := -1.0 if stomp_count % 2 == 0 else 1.0
	sprite.position = Vector2.ZERO
	sprite.rotation = 0.0
	sprite.scale = _rest_sprite_scale
	_stomp_pose = create_tween().set_parallel(true)
	_stomp_pose.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_stomp_pose.tween_property(sprite, ^"position", Vector2(lean * 5.0, -11.0),
		_windup_duration() * 0.58)
	_stomp_pose.tween_property(sprite, ^"rotation", lean * 0.055,
		_windup_duration() * 0.58)
	_stomp_pose.tween_property(sprite, ^"scale", _rest_sprite_scale * Vector2(0.97, 1.04),
		_windup_duration() * 0.58)


func _slam_feet_down() -> void:
	if _stomp_pose != null and _stomp_pose.is_valid():
		_stomp_pose.kill()
	_stomp_pose = create_tween()
	_stomp_pose.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_stomp_pose.tween_property(sprite, ^"position", Vector2(0.0, 3.0), 0.05)
	_stomp_pose.parallel().tween_property(sprite, ^"rotation", 0.0, 0.05)
	_stomp_pose.parallel().tween_property(sprite, ^"scale",
		_rest_sprite_scale * Vector2(1.08, 0.92), 0.05)
	_stomp_pose.set_ease(Tween.EASE_OUT)
	_stomp_pose.tween_property(sprite, ^"scale", _rest_sprite_scale, 0.18).set_trans(Tween.TRANS_BACK)
	_stomp_pose.parallel().tween_property(sprite, ^"position", Vector2.ZERO, 0.18)


func _reset_stomp_pose() -> void:
	if _stomp_pose != null and _stomp_pose.is_valid():
		_stomp_pose.kill()
	sprite.position = Vector2.ZERO
	sprite.rotation = 0.0
	sprite.scale = _rest_sprite_scale


func _set_vulnerable(value: bool) -> void:
	_vulnerable = value
	_vulnerable_time = 0.0
	warning_ring.hide()
	if not value:
		_glow = 0.0
		_sprite_material.set_shader_parameter(&"outline", 0.0)
		return
	# The window opens with a snap: a hard cyan flash that settles into the
	# pulse, so the moment to strike is announced and not just shown.
	_flash_color = VULNERABLE
	_flash = maxf(_flash, 0.6)
	_sprite_material.set_shader_parameter(&"outline_color", VULNERABLE)
	_sprite_material.set_shader_parameter(&"outline", 1.0)


func _update_vulnerability_visual() -> void:
	var remaining := 1.0 - clampf(_state_time / _recovery_duration(), 0.0, 1.0)
	# The pulse quickens as the window closes.
	var pulse := (sin(_vulnerable_time * (9.0 + (1.0 - remaining) * 9.0)) + 1.0) * 0.5
	_sprite_material.set_shader_parameter(&"outline", lerpf(0.45, 1.0, pulse) * (0.4 + 0.6 * remaining))
	# The body itself takes on the colour too, so the window reads even with
	# the slam's dust still hanging in front of it.
	_glow = lerpf(0.12, 0.3, pulse) * (0.5 + 0.5 * remaining)


func _play_stomp_audio() -> void:
	_play_variant(stomp_audio, STOMP_SOUNDS, -1.5, randf_range(0.72, 0.8))
	_play_variant(stomp_body_audio, BODY_IMPACTS, -5.0, randf_range(0.62, 0.7))
	_say_variant(VOICE_SHOUTS, -3.0, randf_range(0.95, 1.05))
	_sub_audio.stream = STOMP_SUB
	_sub_audio.volume_db = 1.0
	_sub_audio.pitch_scale = randf_range(0.92, 1.0)
	_sub_audio.play()


func _play_variant(player: AudioStreamPlayer2D, streams: Array[AudioStream],
		volume_db: float, pitch_scale: float) -> void:
	if streams.is_empty():
		return
	player.stream = streams[randi() % streams.size()]
	player.volume_db = volume_db
	player.pitch_scale = pitch_scale
	player.play()


## The voice is one throat: a new line cuts the old one off, except that a
## grunt never interrupts a roar.
func _say(stream: AudioStream, volume_db: float, pitch_scale: float, interrupt := true) -> void:
	if _voice.playing and not interrupt:
		return
	_voice.stream = stream
	_voice.volume_db = volume_db
	_voice.pitch_scale = pitch_scale
	_voice.play()


func _say_variant(streams: Array[AudioStream], volume_db: float, pitch_scale: float,
		interrupt := true) -> void:
	if streams.is_empty():
		return
	_say(streams[randi() % streams.size()], volume_db, pitch_scale, interrupt)


func _rumble(volume_db: float, pitch_scale: float) -> void:
	_voice_layer.stream = GROUND_RUMBLE
	_voice_layer.volume_db = volume_db
	_voice_layer.pitch_scale = pitch_scale
	_voice_layer.play()


func _burst_at_feet(strength: float, wide: bool) -> void:
	var parent := get_parent()
	if parent == null:
		return
	var burst := IMPACT_SCENE.instantiate() as BossImpactEffect
	parent.add_child(burst)
	burst.configure(global_position, strength, wide)


func _on_frame_changed() -> void:
	_update_sprite_region()
	match sprite.animation:
		&"walk":
			if _state == &"chase" and sprite.frame in STEP_FRAMES:
				_play_variant(step_audio, STEP_SOUNDS, -10.0, randf_range(0.72, 0.82))
				var parent := get_parent()
				if parent != null:
					var foot := global_position + Vector2(float(_facing) * (14.0 if sprite.frame == STEP_FRAMES[0] else -14.0), 0.0)
					BossVfx.dust_burst(parent, foot, 0.45, false, 7)
				var rig := BossCameraRig.find(get_tree())
				if rig != null:
					rig.add_trauma_at(0.09, global_position, 260.0, 1100.0)
		&"dying":
			if CRUMBLE_FRAMES.has(sprite.frame) and not _crumbled_frames.has(sprite.frame):
				_crumbled_frames[sprite.frame] = true
				var strength: float = CRUMBLE_FRAMES[sprite.frame]
				_burst_at_feet(strength, strength >= 0.9)
				_play_variant(hurt_audio, BODY_IMPACTS, -4.0, randf_range(0.6, 0.72))
				var rig := BossCameraRig.find(get_tree())
				if rig != null:
					rig.add_trauma(0.25 * strength)
					rig.kick(Vector2(0.0, 6.0 * strength))


func _on_animation_finished() -> void:
	if _state == &"dead" and sprite.animation == &"dying":
		var rig := BossCameraRig.find(get_tree())
		if rig != null:
			rig.release_focus(1.4)
		var fx := BossScreenFx.find(get_tree())
		if fx != null:
			fx.set_vignette(0.0, 0.8)
		death_finished.emit()
		return
	if sprite.animation == &"hurt" and _state == &"recover":
		_play(&"idle")


func _update_sprite_region() -> void:
	if _sprite_material == null or sprite.sprite_frames == null:
		return
	var frame := sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame) as AtlasTexture
	if frame == null or frame.atlas == null:
		_sprite_material.set_shader_parameter(&"region", Vector4(0.0, 0.0, 1.0, 1.0))
		return
	var sheet_size := frame.atlas.get_size()
	var region := frame.region
	_sprite_material.set_shader_parameter(&"region", Vector4(
		region.position.x / sheet_size.x, region.position.y / sheet_size.y,
		region.end.x / sheet_size.x, region.end.y / sheet_size.y))


func _build_sprite_material() -> void:
	var shader := Shader.new()
	shader.code = SPRITE_SHADER
	_sprite_material = ShaderMaterial.new()
	_sprite_material.shader = shader
	_sprite_material.set_shader_parameter(&"outline_color", VULNERABLE)
	sprite.material = _sprite_material


## Rings on the floor under it, drawn on their own node so they sit above the
## tiles and under the body without moving the sprite's own z.
func _build_ground_marks() -> void:
	_ground_marks = Node2D.new()
	_ground_marks.name = &"GroundMarks"
	_ground_marks.z_index = 7
	_ground_marks.draw.connect(_draw_ground_marks)
	add_child(_ground_marks)
	_tremor = BossVfx.tremor(self, global_position, 48.0, 7)
	_tremor.emitting = false


func _build_voice() -> void:
	_voice = AudioStreamPlayer2D.new()
	_voice.name = &"VoiceAudio"
	_voice.max_distance = 3200.0
	_voice.attenuation = 0.6
	add_child(_voice)
	_voice_layer = AudioStreamPlayer2D.new()
	_voice_layer.name = &"RumbleAudio"
	_voice_layer.max_distance = 3200.0
	_voice_layer.attenuation = 0.5
	add_child(_voice_layer)
	_sub_audio = AudioStreamPlayer2D.new()
	_sub_audio.name = &"StompSubAudio"
	_sub_audio.max_distance = 3200.0
	_sub_audio.attenuation = 0.5
	add_child(_sub_audio)


## A pale band between where the bar is and where it was, that catches up
## after a beat: how much the last hit took.
func _build_ghost_bar() -> void:
	_ghost_bar = ColorRect.new()
	_ghost_bar.name = &"Ghost"
	_ghost_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ghost_bar.color = Color(1.0, 0.9, 0.7, 0.82)
	_ghost_bar.anchor_top = 0.0
	_ghost_bar.anchor_bottom = 1.0
	_ghost_bar.offset_top = 3.0
	_ghost_bar.offset_bottom = -3.0
	_ghost_bar.anchor_left = 1.0
	_ghost_bar.anchor_right = 1.0
	_ghost_bar.hide()
	health_bar.add_child(_ghost_bar)


func _apply_phase_fill(new_phase: int) -> void:
	var fill := health_bar.get_theme_stylebox(&"fill")
	if fill is StyleBoxFlat:
		var styled := (fill as StyleBoxFlat).duplicate() as StyleBoxFlat
		var colors: Array = PHASE_FILL[new_phase]
		styled.bg_color = colors[0]
		styled.border_color = colors[1]
		health_bar.add_theme_stylebox_override(&"fill", styled)


func _draw_ground_marks() -> void:
	var canvas := _ground_marks
	if _state == &"windup":
		# Rings closing on the foot as the wind-up runs, brighter as they come.
		var progress := _windup_ring
		var color := WARNING
		for ring in 3:
			var ring_progress := fposmod(progress * 1.6 + float(ring) / 3.0, 1.0)
			var radius := lerpf(150.0, 42.0, ring_progress)
			var alpha := lerpf(0.05, 0.85, ring_progress) * (0.5 + progress * 0.5)
			canvas.draw_set_transform(Vector2(0.0, -4.0), 0.0, Vector2(1.0, 0.32))
			canvas.draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, Color(color, alpha),
				lerpf(2.0, 6.0, ring_progress), true)
			canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		canvas.draw_set_transform(Vector2(0.0, -4.0), 0.0, Vector2(1.0, 0.32))
		canvas.draw_circle(Vector2.ZERO, 44.0 + progress * 8.0, Color(color, 0.12 + progress * 0.25))
		canvas.draw_arc(Vector2.ZERO, 46.0, 0.0, TAU, 40, Color(color, 0.6 + progress * 0.4), 4.0, true)
		canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	elif _state == &"recover" and _vulnerable:
		# Turning dashes: it is open, and the clock is running.
		var remaining := 1.0 - clampf(_state_time / _recovery_duration(), 0.0, 1.0)
		var spin := _vulnerable_time * 3.2
		canvas.draw_set_transform(Vector2(0.0, -4.0), 0.0, Vector2(1.0, 0.32))
		canvas.draw_circle(Vector2.ZERO, 62.0, Color(VULNERABLE, 0.1 + remaining * 0.1))
		for dash in 6:
			var start := spin + float(dash) * TAU / 6.0
			canvas.draw_arc(Vector2.ZERO, 66.0, start, start + TAU / 6.0 * remaining * 0.8, 10,
				Color(VULNERABLE, 0.9), 5.0, true)
		canvas.draw_arc(Vector2.ZERO, 50.0, 0.0, TAU, 40, Color(VULNERABLE, 0.35 + remaining * 0.3), 2.0, true)
		canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _build_frames() -> void:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	for animation: StringName in SHEETS:
		var specification: Array = SHEETS[animation]
		var sheet := specification[0] as Texture2D
		var frame_count := int(specification[1])
		frames.add_animation(animation)
		frames.set_animation_speed(animation, float(specification[2]))
		frames.set_animation_loop(animation, bool(specification[3]))
		for index in frame_count:
			var frame := AtlasTexture.new()
			frame.atlas = sheet
			frame.region = Rect2(index * 90, 0, 90, 64)
			frames.add_frame(animation, frame)
	sprite.sprite_frames = frames
