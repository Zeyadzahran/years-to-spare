class_name Player
extends CharacterBody2D
## The boy. Deliberately *not* a TimeBody2D: he keeps moving at full speed while
## his powers hold the world still. That contrast is the whole game.
##
## Movement numbers are first-pass placeholders. Combat lives in a future
## Attack state; the state machine is already the place to hang it.

## For the animator: leaving the ground is not the same as jumping - he also
## reaches Air by walking off a ledge - so the sound hangs off the push itself.
signal jumped

## Everything below is the old feel run at four fifths speed. Slowing a
## platformer by cutting the speed alone shortens every jump and quietly makes
## the level's pits unclearable, so the whole of his motion is scaled instead:
## velocities by 0.8, accelerations and gravity by 0.8 squared, times by 1/0.8.
## Under that transform a trajectory keeps its exact shape - same jump height,
## same distance across a gap - and only takes longer to draw. Nothing in phase
## 1 became harder to reach; the game just stopped rushing.
const GROUND_ACCEL := 3840.0
const AIR_ACCEL := 2112.0
const GROUND_FRICTION := 4608.0
const AIR_FRICTION := 768.0
const COYOTE_TIME := 0.125
const JUMP_BUFFER := 0.15
const ATTACK_BUFFER := 0.15
const ENEMY_SLIDE_SPEED := 300.0

## Safely below every authored playable surface. Unlike a placed death volume,
## This follows the player across the normal level and the isolated boss arena.
const VOID_DEATH_Y := 1200.0

## Three swings to down a Guard, on the 100-point scale.
@export var attack_damage := 34.0

@export var speed := 450.0
@export var jump_velocity := -1000.0
@export var gravity := 2620.0

## Crouched box height, from the sprite: the boy is ~71% of standing height
## while ducked.
const CROUCH_HEIGHT := 70.0

## What ducking costs him in speed. He creeps under the overhang rather than
## being pinned to the spot by it, which is what the crouch-walk frames are for.
const CROUCH_SPEED := 0.42

## Below this he is ducked but not going anywhere, and shows the held pose
## instead of the creep. Set above zero so the last of the friction slide does
## not leave him mouthing the walk cycle in place.
const CRAWL_SPEED := 20.0

## What is left of his top speed at sixty, reached smoothly as he ages. The
## elder frames are drawn as a walk rather than a run and were being played at a
## sprinter's pace; this is what makes the two agree.
##
## It cannot go much below this without breaking the level: phase 1's widest
## spiked pit is 230 px across, and the reach this leaves the old man clears it
## with about 50 px to spare - roughly what a human needs to time the jump.
const ELDER_SPEED := 0.82

@onready var shape: CollisionShape2D = $Shape
@onready var sprite: AnimatedSprite2D = $Sprite
@onready var health: HealthComponent = $Health
@onready var age: AgeComponent = $Age
@onready var powers: TimePowers = $TimePowers
@onready var states: StateMachine = $StateMachine

var input_dir := 0.0
var facing := 1

## Which side the last hit came from, so Hurt knocks him the right way.
var hurt_from := 1

var _coyote_left := 0.0
var _jump_buffered := 0.0
var _attack_buffered := 0.0
var _attack_hit_done := false
var _enemy_slide_direction := 0.0
var _standing_size: Vector2
var _standing_offset: float
## Built rather than instanced: see src/actors/player/sword_effects.gd.
var _effects: SwordEffects
## Whether the last snapshot a rewind put him in had him ducked, so the state
## he is handed back to can keep the low box under an overhang.
var _rewound_crouched := false

func _ready() -> void:
	add_to_group(&"player")
	# The one thing the world's clock never touches is still something a rewind
	# does: a bad jump is his to take back.
	add_to_group(TimeService.REWINDABLE_GROUP)
	# Own the shape so resizing it for crouch cannot leak into other instances.
	shape.shape = shape.shape.duplicate()
	_standing_size = (shape.shape as RectangleShape2D).size
	_standing_offset = shape.position.y
	health.changed.connect(func(c, m): EventBus.player_health_changed.emit(c, m))
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	age.changed.connect(func(a, d): EventBus.player_age_changed.emit(a, d))
	age.died.connect(_on_died)
	# Killing Cad Corp's troops is the only way to buy years back, which is what
	# `age_reward` on a unit has always been for and what nothing was listening
	# for. Wired here rather than in the level: they are his years.
	EventBus.enemy_died.connect(_on_enemy_died)
	_effects = SwordEffects.new()
	add_child(_effects)
	EventBus.player_spawned.emit(self)


func _physics_process(delta: float) -> void:
	if global_position.y > VOID_DEATH_Y:
		die_instantly(null)
		return
	input_dir = Input.get_axis(&"move_left", &"move_right")
	_coyote_left = COYOTE_TIME if is_grounded() else maxf(_coyote_left - delta, 0.0)
	_jump_buffered = maxf(_jump_buffered - delta, 0.0)
	if Input.is_action_just_pressed(&"jump"):
		_jump_buffered = JUMP_BUFFER
	_attack_buffered = maxf(_attack_buffered - delta, 0.0)
	if Input.is_action_just_pressed(&"attack"):
		_attack_buffered = ATTACK_BUFFER


func apply_gravity(delta: float) -> void:
	velocity.y += gravity * delta


## Enemy bodies block the sides, but their heads never grant footing or jumps.
func is_grounded() -> bool:
	if not is_on_floor():
		return false
	for index in get_slide_collision_count():
		var contact := get_slide_collision(index)
		if contact.get_normal().dot(up_direction) >= cos(floor_max_angle):
			var body := contact.get_collider() as Node
			if body == null or not body.is_in_group(&"enemy"):
				return true
	return false


func _enemy_underfoot() -> Node2D:
	if is_grounded():
		return null
	for index in get_slide_collision_count():
		var contact := get_slide_collision(index)
		var body := contact.get_collider() as Node2D
		if body != null and body.is_in_group(&"enemy") \
				and contact.get_normal().dot(up_direction) >= cos(floor_max_angle):
			return body
	return null


## Slide off the nearest side, including while time is stopped. Sweep the
## motion so a nearby wall cannot be crossed; try the other side if blocked.
func move_with_enemy_slide() -> void:
	if _enemy_underfoot() != null:
		velocity.x = 0.0
	move_and_slide()
	var enemy := _enemy_underfoot()
	if enemy == null:
		_enemy_slide_direction = 0.0
		return
	_coyote_left = 0.0
	if is_zero_approx(_enemy_slide_direction):
		_enemy_slide_direction = signf(global_position.x - enemy.global_position.x)
		if is_zero_approx(_enemy_slide_direction):
			_enemy_slide_direction = float(facing)
	var motion := Vector2(_enemy_slide_direction * ENEMY_SLIDE_SPEED * get_physics_process_delta_time(), 0.0)
	if test_move(global_transform, motion):
		_enemy_slide_direction = -_enemy_slide_direction
		motion.x = -motion.x
	move_and_collide(motion)
	velocity.x = signf(motion.x) * ENEMY_SLIDE_SPEED


## Top speed for the age he is at. `frailty` runs 0 at fourteen and 1 at sixty,
## which is the "older and weaker" falloff AgeComponent was written for and
## nothing had used yet. Continuous rather than stepped at the body changes: the
## years are spent a few at a time, and the legs should go the same way.
func top_speed() -> float:
	return speed * lerpf(1.0, ELDER_SPEED, age.frailty())


## `speed_scale` is how much of that the state allows. Only the target is
## scaled: however slowly he is going, stopping should feel the same.
func apply_horizontal(delta: float, speed_scale := 1.0) -> void:
	var grounded := is_grounded()
	var rate := (GROUND_ACCEL if grounded else AIR_ACCEL) if not is_zero_approx(input_dir) \
		else (GROUND_FRICTION if grounded else AIR_FRICTION)
	velocity.x = move_toward(velocity.x, input_dir * top_speed() * speed_scale, rate * delta)
	if not is_zero_approx(input_dir):
		facing = 1 if input_dir > 0.0 else -1


## Ducked and actually covering ground. Crouch is one state and two poses, and
## this is what separates them - a question about his speed, not his state.
func is_crawling() -> bool:
	return absf(velocity.x) > CRAWL_SPEED


## Buffered like the jump, so a press is never lost to frame timing.
func wants_attack() -> bool:
	return _attack_buffered > 0.0


func consume_attack() -> void:
	_attack_buffered = 0.0
	_attack_hit_done = false


## The blade going out, fired as the swing starts rather than when it lands: a
## miss is still an attack and still has to look like one, and the lance has to
## be most of the way out by the time the hit is actually tested.
func begin_swing() -> void:
	_effects.thrust(global_position, facing)


func clear_combat_effects() -> void:
	if _effects != null:
		_effects.clear()


func has_combat_effects() -> bool:
	return _effects != null and _effects.is_active()


func perform_attack_hit() -> void:
	if _attack_hit_done:
		return
	_attack_hit_done = true
	for enemy in get_tree().get_nodes_in_group(&"enemy"):
		if not is_instance_valid(enemy) or not enemy.has_node("Health"):
			continue
		var offset: Vector2 = enemy.global_position - global_position
		# `offset.x * facing >= 0` rather than comparing signs: an enemy standing
		# exactly level with the boy has signf(offset.x) == 0, which matched
		# neither facing and let the swing pass straight through it.
		if absf(offset.x) <= 78.0 and absf(offset.y) <= 75.0 and offset.x * facing >= 0.0:
			if enemy.has_method(&"receive_player_hit"):
				enemy.receive_player_hit(attack_damage, self)
			else:
				enemy.health.take_damage(attack_damage, self)
			# On the blade line rather than on the unit's middle: a thrust
			# connects where the sword is, which is chest height off the floor
			# the boy is standing on, not off wherever the unit's feet are.
			_effects.impact(Vector2(enemy.global_position.x,
				global_position.y + SwordEffects.THRUST_Y))


func can_jump() -> bool:
	return _jump_buffered > 0.0 and _coyote_left > 0.0


func consume_jump() -> void:
	_jump_buffered = 0.0
	_coyote_left = 0.0
	velocity.y = jump_velocity
	jumped.emit()


func set_crouched(crouched: bool) -> void:
	var box := shape.shape as RectangleShape2D
	box.size = Vector2(_standing_size.x, CROUCH_HEIGHT if crouched else _standing_size.y)
	shape.position.y = -CROUCH_HEIGHT * 0.5 if crouched else _standing_offset


## False when a ceiling would trap the standing box, so crouch cannot pop the
## boy through an overhang.
func can_stand() -> bool:
	var box := shape.shape as RectangleShape2D
	var size := box.size
	var offset := shape.position.y
	box.size = _standing_size
	shape.position.y = _standing_offset
	var blocked := test_move(global_transform, Vector2.ZERO)
	box.size = size
	shape.position.y = offset
	return not blocked


func is_down() -> bool:
	return states.current_name == &"Dead"


## A remaining heart returns him to the same live encounter. Age and power
## cooldowns stay spent; only health, movement and the death pose reset.
func respawn_at(destination: Vector2) -> void:
	powers.cancel()
	global_position = destination
	velocity = Vector2.ZERO
	input_dir = 0.0
	_coyote_left = 0.0
	_jump_buffered = 0.0
	_attack_buffered = 0.0
	_attack_hit_done = false
	_rewound_crouched = false
	_enemy_slide_direction = 0.0
	set_crouched(false)
	clear_combat_effects()
	health.restore_to(health.max_health)
	states.travel(&"Idle")
	var camera := get_node_or_null(^"Camera2D") as Camera2D
	if camera != null:
		camera.reset_smoothing()
		camera.force_update_scroll()


## Whether the boy is currently in the held duck, standing pose or creeping.
## A Gunner reads this to decide whether to fire the standing shot or drop to
## a knee for the low one - ducking shrinks the boy's box but not where he
## stands, so without this a Gunner keeps shooting over a crouched head.
func is_crouched() -> bool:
	return states.current_name == &"Crouch"


## Routes environmental fatalities through HealthComponent and the existing
## Dead state instead of maintaining a second game-over path. Spikes, saws and
## the void all end up here, so they all cost a heart and respawn at the last
## checkpoint exactly like a combat death does - see Level._on_player_died.
func die_instantly(source: Node = null) -> void:
	if is_down():
		return
	health.kill(source)


func _on_damaged(_amount: float, source: Node) -> void:
	if is_down():
		return
	hurt_from = 1 if source != null and source.global_position.x > global_position.x else -1
	states.travel(&"Hurt")


func _on_enemy_died(_enemy: Node2D, age_reward: float) -> void:
	age.restore(age_reward)


func _on_died() -> void:
	# A rewind under way is left alone: pressed on the way into the spikes, it
	# is about to pull him back out, and it has already been paid for.
	if not powers.is_casting(GameState.ABILITY_REWIND):
		powers.cancel()
	states.travel(&"Dead")


## What a rewind needs to put him back: where and how fast, which way he was
## looking, what he was doing, how hurt he was and which frame of it he was on.
## See TimeService for who calls this and when.
func rewind_capture() -> Array:
	return [
		global_position, velocity, facing, hurt_from, states.current_name,
		health.current, sprite.animation, sprite.frame, sprite.frame_progress,
		is_crouched(), _enemy_slide_direction,
	]


func rewind_apply(state: Array) -> void:
	global_position = state[0]
	velocity = state[1]
	facing = state[2]
	hurt_from = state[3]
	health.restore_to(state[5])
	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(state[6]):
		sprite.animation = state[6]
		sprite.set_frame_and_progress(state[7], state[8])
	_rewound_crouched = state[9]
	_enemy_slide_direction = state[10]
	set_crouched(_rewound_crouched)


## The world has started running backward. He is a passenger in it: no input,
## no physics, no state ticking - the snapshots are what move him now.
func rewind_began() -> void:
	set_physics_process(false)
	states.set_physics_process(false)
	states.set_process(false)
	_jump_buffered = 0.0
	_attack_buffered = 0.0
	_coyote_left = 0.0
	clear_combat_effects()


## Time runs forward again from wherever the last snapshot left him. He is put
## into a plain state rather than the one recorded: Attack, Hurt and Dead all
## do something on entry, and none of it is what a boy who has just been
## handed back a few seconds should be doing. The clip is the animator's to
## sort out; it listens for the mode change that follows this.
func rewind_ended() -> void:
	set_physics_process(true)
	states.set_physics_process(true)
	states.set_process(true)
	var next: StringName = &"Idle"
	if _rewound_crouched:
		next = &"Crouch"
	elif not is_grounded():
		next = &"Air"
	states.travel(next)
