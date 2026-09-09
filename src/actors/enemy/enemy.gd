class_name Enemy
extends TimeBody2D
## Base for every Cad Corp unit: health, death, and the Idle / Chase / Attack /
## Recover / Hurt / Dead machine they all share.
##
## A unit is a set of numbers plus one move. Subclasses set the numbers in
## `_init()` and implement `_attack()`; everything about noticing the boy,
## closing on him, recovering, flinching and dying lives here, so the units
## cannot drift apart the way Guard and Gunner already had.
##
## Everything runs from `_tick(delta)`, and `delta` is already scaled by
## TimeService - stop the world mid-swing and the swing stops with it. Dying is
## the one thing that is not: see `_physics_process`.

const GROUND_FRICTION := 1400.0
const CHASE_ACCELERATION := 1800.0
## How far past `detection_range` the boy has to get before a chase gives up,
## so standing exactly on the edge does not flip the unit between states.
const CHASE_GIVE_UP := 1.35
## `2d_physics/layer_1` in project.godot - terrain, and the only thing that
## counts as cover.
const WORLD_LAYER := 1
## Where a sight line aims on the boy: the middle of his 100-tall body rather
## than his feet, which sit level with the floor.
const TARGET_CHEST_HEIGHT := -50.0
## How far ahead of the feet the ground is tested, and how far down that test
## reaches: about one body width out and a bit over one tile down.
const STEP_AHEAD := 46.0
const GROUND_PROBE := 140.0
## Past 1.0 on purpose: the hit should blow out to white, not merely brighten.
const FLASH_TINT := Color(3.2, 2.7, 2.3)

## Years the player takes back for killing this unit. One apiece: a kill should
## read as a year off, not as a refund big enough to make the powers free.
## AgeComponent.restore floors at his starting age, so no amount of killing
## takes him back below fourteen.
@export var age_reward := 1.0

@export_group("Ranges")
@export var speed := 180.0
@export var detection_range := 430.0
@export var attack_range := 58.0
## Both ranges are bounded vertically as well. Without this a unit chases a boy
## standing on a completely different platform and walks off its own ledge to
## get to him - and a ranged one opens fire through the floor.
@export var detection_height_tolerance := 180.0
@export var attack_height_tolerance := 70.0
## Where this unit looks from, measured up from its feet. The sight line is
## cast from here rather than from the origin, which sits on the ground and
## would graze the floor it is standing on.
@export var eye_height := -70.0

@export_group("Attack")
@export var damage := 34.0
## The whole cycle, and the moment inside it when the blow actually lands.
@export var attack_duration := 0.56
@export var attack_hit_time := 0.25
## Breath between attacks. The GDD's plan is "dodge, then counter", which needs
## a window where the unit is not attacking - and it has to outlast the boy's
## own swing (AttackState.DURATION, 0.5s), or the counter is interrupted before
## it ever lands.
@export var attack_recovery := 0.6
@export var hurt_duration := 0.35
@export var knockback := 200.0

## The clip this unit's attack plays. A baton swing and a shot are the same
## beat with different art.
var attack_animation: StringName = &"attack"

@onready var health: HealthComponent = $Health
@onready var sprite: AnimatedSprite2D = $Sprite
## Optional: the noise this unit makes when its own attack lands on the boy.
## Each scene brings its own take - a baton across the back is not a round going
## into flesh - so the stream lives on the node, not here.
@onready var hit_audio: AudioStreamPlayer2D = get_node_or_null(^"HitAudio")

var target: Player
var facing := -1
var state: StringName = &"Idle"

## Where the unit started, so a body knocked into a pit can be cleaned up.
var _spawn_y := 0.0
var _state_elapsed := 0.0
var _attack_fired := false
var _hurt_from := 1
## Blown white on contact and cooling off over the next tenth of a second, so a
## blow that landed is legible on the unit itself and not only on its health.
var _flash := 0.0
## Resolved once rather than walked for every frame, the way Hazard does it.
var _animated: Array[AnimatedSprite2D] = []
var _audio: Array[AudioStreamPlayer2D] = []

func _ready() -> void:
	add_to_group(&"enemy")
	_spawn_y = global_position.y
	health.died.connect(_on_died)
	health.damaged.connect(_on_damaged)
	sprite.animation_finished.connect(_on_animation_finished)
	for child in get_children():
		if child is AnimatedSprite2D:
			_animated.append(child)
		elif child is AudioStreamPlayer2D:
			_audio.append(child)
	_set_animation(&"idle")


## How far a unit may fall below its post before it counts as gone. The kill
## volumes only watch the player, so without this a trooper shoved off a ledge
## accelerates forever: an invisible node burning physics for the rest of the
## run, and a kill the boy can never collect.
const PIT_DEPTH := 2200.0


func _physics_process(delta: float) -> void:
	if state != &"Dead" and global_position.y > _spawn_y + PIT_DEPTH:
		# Silently, and without paying out years: the pit took him, not the boy.
		queue_free()
		return
	_sync_to_world_time()
	# Raw delta, ahead of the frozen-world return: the boy can still swing while
	# the world is held still, and the unit he hits still has to react.
	if _flash > 0.0:
		_flash = maxf(_flash - delta * 9.0, 0.0)
		sprite.modulate = Color.WHITE.lerp(FLASH_TINT, _flash)
	# A body he has already dropped falls on his clock, not the world's, and
	# move_and_slide directly because move_in_time refuses to move anything
	# while the world is stopped. Cutting a unit down inside the freeze is the
	# one moment the power is doing exactly what it promises; leaving the corpse
	# standing there until time restarts takes the kill away from him.
	if state == &"Dead":
		apply_gravity(delta)
		_tick(delta)
		move_and_slide()
		return
	var scaled := world_delta(delta)
	if is_zero_approx(scaled):
		return
	apply_gravity(scaled)
	_tick(scaled)
	move_in_time()


## Art and sound run on world time, the same pairing Hazard uses. The sprite
## needs saying out loud because an AnimatedSprite2D advances on its own process
## frame rather than on the physics ticks the AI takes, so a frozen unit would
## otherwise keep flipping frames while the boy walks past - time stopping for
## what the unit does but not for what it shows. Audio needs it for the same
## reason in the other channel: a baton crack playing on over a still frame.
func _sync_to_world_time() -> void:
	# The dead are the exception, and they have to be: the dying clip is what
	# clears the body, through `animation_finished`. Held at speed_scale 0 it
	# never finishes, so a unit killed during a freeze would hang on its first
	# dying frame - which is what standing there looking alive amounts to.
	var falling := state == &"Dead"
	# Named away from `scale`: Node2D already owns that property, and shadowing
	# it here would silently read/write the wrong thing.
	var time_scale := 1.0 if falling else TimeService.world_scale
	for animated in _animated:
		animated.speed_scale = time_scale
	var frozen := TimeService.is_world_frozen() and not falling
	for audio in _audio:
		audio.stream_paused = frozen


func _tick(delta: float) -> void:
	_state_elapsed += delta
	if target == null or not is_instance_valid(target):
		target = get_tree().get_first_node_in_group(&"player") as Player

	match state:
		&"Idle":
			_tick_idle(delta)
			if _can_see_player():
				_change_state(&"Chase")
		&"Chase":
			_tick_chase(delta)
			if target == null or global_position.distance_to(target.global_position) > detection_range * CHASE_GIVE_UP:
				_change_state(&"Idle")
			elif _in_attack_range():
				_change_state(&"Attack")
		&"Attack":
			_tick_attack(delta)
		&"Recover":
			_tick_recover(delta)
		&"Hurt":
			_tick_hurt(delta)
		&"Dead":
			_tick_dead(delta)


## What the unit does with itself while nothing is happening. Standing still by
## default; a patrolling unit overrides this.
func _tick_idle(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, GROUND_FRICTION * delta)
	_set_animation(&"idle")


func _tick_chase(delta: float) -> void:
	if target == null:
		return
	var dx := target.global_position.x - global_position.x
	var direction: float = signf(dx)
	facing = 1 if direction > 0.0 else -1 if direction < 0.0 else facing
	# Only a unit with its feet down gets to refuse the step; one already in the
	# air keeps its momentum, or it would stall mid-fall.
	if is_on_floor() and not has_floor_ahead(direction):
		velocity.x = move_toward(velocity.x, 0.0, GROUND_FRICTION * delta)
	else:
		velocity.x = move_toward(velocity.x, direction * speed, CHASE_ACCELERATION * delta)
	_set_animation(&"run")


func _tick_attack(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, GROUND_FRICTION * delta)
	_set_animation(_attack_clip())

	if target == null or target.is_down():
		_change_state(&"Idle")
		return

	_face_target_mid_attack()

	if not _attack_fired and _state_elapsed >= attack_hit_time:
		_attack_fired = true
		_attack()

	if _state_elapsed >= attack_duration:
		_change_state(&"Recover")


## The one move that differs between units: a hitbox check, a spawned round.
func _attack() -> void:
	pass


## Which clip an attack plays. A plain field for most units - Gunner overrides
## this to pick between his standing shot and a kneeling one depending on
## whether the boy is crouched, so the choice can change frame to frame while
## he is lining up rather than being locked in on the way into Attack.
func _attack_clip() -> StringName:
	return attack_animation


## Whether the unit is still allowed to turn once the attack has started.
## Unbounded here; a melee unit clamps it so a swing cannot track the boy
## around behind it.
func _face_target_mid_attack() -> void:
	var dx := target.global_position.x - global_position.x
	if not is_zero_approx(dx):
		facing = 1 if dx > 0.0 else -1


## Weapon down, still tracking the boy, briefly unable to attack. Coming back to
## Attack from here is a real state change, which is also what re-arms the timer
## and the fired flag - re-entering Attack directly could not, because
## `_change_state` returns early when the state is unchanged.
func _tick_recover(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, GROUND_FRICTION * delta)
	_set_animation(&"idle")
	if target != null and is_instance_valid(target):
		var dx := target.global_position.x - global_position.x
		if not is_zero_approx(dx):
			facing = 1 if dx > 0.0 else -1
	if _state_elapsed < attack_recovery:
		return
	if _in_attack_range():
		_change_state(&"Attack")
	elif _can_see_player():
		_change_state(&"Chase")
	else:
		_change_state(&"Idle")


func _tick_hurt(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, GROUND_FRICTION * delta)
	_set_animation(&"hurt")
	if _state_elapsed >= hurt_duration:
		_change_state(&"Chase" if _can_see_player() else &"Idle")


func _tick_dead(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, GROUND_FRICTION * delta)
	_set_animation(&"dying")


func _can_see_player() -> bool:
	if target == null or not is_instance_valid(target) or target.is_down():
		return false
	var to := target.global_position - global_position
	if absf(to.x) > detection_range or absf(to.y) > detection_height_tolerance:
		return false
	return has_line_of_sight()


func _in_attack_range() -> bool:
	if target == null or not is_instance_valid(target):
		return false
	var to := target.global_position - global_position
	if absf(to.x) > attack_range or absf(to.y) > attack_height_tolerance:
		return false
	return has_line_of_sight()


## Whether the boy is actually visible from here, or whether there is rock in
## the way. Cast eye to chest against the world layer only: another unit is not
## cover, and the boy is not his own obstacle.
##
## This is what stops a Gunner opening up on someone he cannot see. The round
## already dies against terrain, so a blocked shot cost nothing - it just made
## him look like he was firing at a wall, because he was.
func has_line_of_sight() -> bool:
	if target == null or not is_instance_valid(target):
		return false
	var query := PhysicsRayQueryParameters2D.create(
		global_position + Vector2(0.0, eye_height),
		target.global_position + Vector2(0.0, TARGET_CHEST_HEIGHT),
		WORLD_LAYER)
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()


## Whether the unit's next step lands on anything. Cad Corp hold a line; they do
## not march off a gantry chasing the boy. The fork's tiers and the yard's
## staircase are two tiles wide, so without this a chase walks most of the
## level's troops into the nearest pit - and hands the boy free years for it.
func has_floor_ahead(direction: float) -> bool:
	if is_zero_approx(direction):
		return true
	var from := global_position + Vector2(STEP_AHEAD * signf(direction), -10.0)
	var query := PhysicsRayQueryParameters2D.create(
		from, from + Vector2(0.0, GROUND_PROBE), WORLD_LAYER)
	return not get_world_2d().direct_space_state.intersect_ray(query).is_empty()


func _change_state(next: StringName) -> void:
	if state == next:
		return
	state = next
	_state_elapsed = 0.0
	_attack_fired = false
	match state:
		&"Idle": _set_animation(&"idle")
		&"Chase": _set_animation(&"run")
		&"Attack": _set_animation(_attack_clip())
		&"Recover": _set_animation(&"idle")
		&"Hurt": _set_animation(&"hurt")
		&"Dead": _set_animation(&"dying")


func _set_animation(name: StringName) -> void:
	if sprite.animation != name:
		sprite.play(name)
	sprite.flip_h = facing < 0


## For subclasses to call the moment their attack connects. Restarted rather
## than left to finish, so a second blow sounds like a second blow.
func play_hit_audio() -> void:
	if hit_audio != null:
		hit_audio.play()


func _on_damaged(_amount: float, source: Node) -> void:
	if state == &"Dead":
		return
	_flash = 1.0
	if source != null:
		var from_right: bool = source.global_position.x > global_position.x
		_hurt_from = 1 if from_right else -1
	velocity = Vector2(-_hurt_from * knockback, -180.0)
	_change_state(&"Hurt")


## The body stays up long enough to play its dying clip; `_on_animation_finished`
## is what actually clears it and pays the boy his years.
func _on_died() -> void:
	_change_state(&"Dead")
	collision_layer = 0
	collision_mask = 1


func _on_animation_finished() -> void:
	if sprite.animation == &"dying" and state == &"Dead":
		EventBus.enemy_died.emit(self, age_reward)
		queue_free()
