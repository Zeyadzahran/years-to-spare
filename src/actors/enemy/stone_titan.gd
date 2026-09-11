class_name StoneTitan
extends TimeBody2D
## The boss-room creature. It advances on the player, but its only attack is a
## clearly telegraphed two-foot stomp; the arena owns the resulting rock wave.

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

const CHASE_SPEED := 165.0
const CHASE_ACCELERATION := 760.0
const FRICTION := 1100.0
const STOMP_WINDUP := 0.86
const STOMP_RECOVERY := 1.05
const FIRST_STOMP_DELAY := 1.4

@onready var health: HealthComponent = $Health
@onready var sprite: AnimatedSprite2D = $Sprite
@onready var warning_ring: Line2D = $WarningRing
@onready var boss_hud: CanvasLayer = $BossHUD
@onready var health_bar: ProgressBar = $BossHUD/Panel/Bar

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
var _stomp_pose: Tween
var _rest_sprite_scale := Vector2.ONE


func _ready() -> void:
	add_to_group(&"enemy")
	_build_frames()
	health.changed.connect(_on_health_changed)
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	sprite.animation_finished.connect(_on_animation_finished)
	health_bar.max_value = health.max_health
	health_bar.value = health.current
	boss_hud.hide()
	warning_ring.hide()
	_rest_sprite_scale = sprite.scale
	_play(&"idle")


func activate(player: Player, left_edge: float, right_edge: float) -> void:
	if active or not health.is_alive():
		return
	target = player
	movement_left = left_edge
	movement_right = right_edge
	active = true
	_state = &"chase"
	_state_time = 0.0
	_attack_cooldown = FIRST_STOMP_DELAY
	boss_hud.show()


func _physics_process(delta: float) -> void:
	if _state == &"dead":
		apply_gravity(delta)
		move_and_slide()
		sprite.speed_scale = 1.0
		return

	var scaled := world_delta(delta)
	sprite.speed_scale = TimeService.world_scale
	if is_zero_approx(scaled):
		return

	if _flash > 0.0:
		_flash = maxf(_flash - scaled * 5.5, 0.0)
		sprite.modulate = Color.WHITE.lerp(Color(2.7, 2.1, 1.45), _flash)

	apply_gravity(scaled)
	_state_time += scaled
	_attack_cooldown -= scaled

	match _state:
		&"inactive":
			velocity.x = move_toward(velocity.x, 0.0, FRICTION * scaled)
			_play(&"idle")
		&"chase":
			_tick_chase(scaled)
		&"windup":
			_tick_windup(scaled)
		&"recover":
			velocity.x = move_toward(velocity.x, 0.0, FRICTION * scaled)
			_play(&"idle")
			if _state_time >= _recovery_duration():
				_change_state(&"chase")

	move_in_time()
	if active:
		global_position.x = clampf(global_position.x, movement_left, movement_right)


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
	warning_ring.show()
	warning_ring.scale = Vector2(0.35, 0.35)
	warning_ring.modulate.a = 0.95
	_raise_foot_for_stomp()
	stomp_warning.emit(stomp_count, phase)


func _tick_windup(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)
	_play(&"attack")
	var warning_progress := clampf(_state_time / STOMP_WINDUP, 0.0, 1.0)
	warning_ring.scale = Vector2.ONE * lerpf(0.35, 1.45, warning_progress)
	warning_ring.modulate.a = lerpf(0.95, 0.18, warning_progress)
	if not _impact_fired and _state_time >= STOMP_WINDUP:
		_impact_fired = true
		warning_ring.hide()
		_slam_feet_down()
		stomp_impact.emit(stomp_count, phase)
		_attack_cooldown = _stomp_interval()
		_change_state(&"recover")


func _change_state(next: StringName) -> void:
	_state = next
	_state_time = 0.0
	match next:
		&"chase": _play(&"walk")
		&"windup": _play(&"attack")
		&"recover": _play(&"idle")
		&"dead": _play(&"dying")


func _stomp_interval() -> float:
	match phase:
		2: return 2.75
		3: return 2.35
		_: return 3.2


func _recovery_duration() -> float:
	return STOMP_RECOVERY - float(phase - 1) * 0.12


func _play(animation: StringName) -> void:
	if sprite.animation != animation:
		sprite.play(animation)
	sprite.flip_h = _facing < 0


func _on_health_changed(current: float, maximum: float) -> void:
	health_bar.max_value = maximum
	health_bar.value = current
	var ratio := current / maximum if maximum > 0.0 else 0.0
	phase = 3 if ratio <= 0.33 else 2 if ratio <= 0.66 else 1


func _on_damaged(_amount: float, _source: Node) -> void:
	if _state == &"dead":
		return
	_flash = 1.0


func _on_died() -> void:
	active = false
	velocity.x = 0.0
	collision_layer = 0
	collision_mask = 1
	warning_ring.hide()
	_reset_stomp_pose()
	boss_hud.hide()
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
		STOMP_WINDUP * 0.58)
	_stomp_pose.tween_property(sprite, ^"rotation", lean * 0.055,
		STOMP_WINDUP * 0.58)


func _slam_feet_down() -> void:
	if _stomp_pose != null and _stomp_pose.is_valid():
		_stomp_pose.kill()
	_stomp_pose = create_tween()
	_stomp_pose.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_stomp_pose.tween_property(sprite, ^"position", Vector2.ZERO, 0.065)
	_stomp_pose.parallel().tween_property(sprite, ^"rotation", 0.0, 0.065)
	_stomp_pose.parallel().tween_property(sprite, ^"scale",
		_rest_sprite_scale * Vector2(1.055, 0.945), 0.065)
	_stomp_pose.set_ease(Tween.EASE_OUT)
	_stomp_pose.tween_property(sprite, ^"scale", _rest_sprite_scale, 0.14)


func _reset_stomp_pose() -> void:
	if _stomp_pose != null and _stomp_pose.is_valid():
		_stomp_pose.kill()
	sprite.position = Vector2.ZERO
	sprite.rotation = 0.0
	sprite.scale = _rest_sprite_scale


func _on_animation_finished() -> void:
	if _state == &"dead" and sprite.animation == &"dying":
		death_finished.emit()
		return


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
