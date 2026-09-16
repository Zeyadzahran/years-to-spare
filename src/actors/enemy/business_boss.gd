class_name BusinessBoss
extends Gunner
## Level 2's final boss: the Business Man.
##
## He uses the same ranged combat contract as Cad Corp's Gunners, but his
## weapon fires the blue laser projectile shown in the supplied boss sheet.
## Every 1/3 of health starts a reinforcement break: he disappears in the
## supplied blue teleport effect while the arena opens a portal and sends in
## 3-5 robots. The boss returns once that wave is cleared. At zero health he
## uses his separate red death explosion.

const LASER_SCENE := preload("res://src/actors/enemy/business_laser.tscn")
const EXPLOSION_SCENE := preload("res://src/actors/enemy/boss_explosion.tscn")
const DISAPPEAR_SCENE := preload("res://src/actors/enemy/business_disappear_effect.tscn")

const BOSS_HEALTH := 1200.0
const BOSS_DAMAGE := 18.0
const BOSS_ATTACK_RANGE := 1050.0
const BOSS_DETECTION_RANGE := 1100.0
const BOSS_ATTACK_DURATION := 0.72
const BOSS_ATTACK_HIT_TIME := 0.48
const BOSS_ATTACK_RECOVERY := 0.85
const BOSS_MUZZLE_HEIGHT := -68.0
const BOSS_MUZZLE_FORWARD := 52.0

signal defeated

var _in_intermission := false
var _teleporting := false

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

func _physics_process(delta: float) -> void:
	if _in_intermission or _teleporting:
		velocity = Vector2.ZERO
		return
	super._physics_process(delta)

func _attack_clip() -> StringName:
	return &"shoot"

func _attack() -> void:
	if _in_intermission or target == null or not is_instance_valid(target):
		return
	if not has_line_of_sight():
		return

	var laser := LASER_SCENE.instantiate() as Bullet
	get_tree().current_scene.add_child(laser)
	laser.global_position = global_position + Vector2(facing * BOSS_MUZZLE_FORWARD, BOSS_MUZZLE_HEIGHT)
	laser.setup(Vector2(facing, 0.0) * BULLET_SPEED, damage, self)
	if _shot_audio != null:
		_shot_audio.play()

func receive_player_hit(base_damage: float, source: Node) -> void:
	if _in_intermission or state == &"Dead":
		return
	health.take_damage(base_damage, source)

## Hide the boss and play the blue teleport/disappearance effect from the
## supplied 326 sheet. BossArena waits for this to finish before opening the
## reinforcement portal.
func begin_intermission() -> void:
	if _in_intermission or state == &"Dead":
		return
	_in_intermission = true
	_attack_fired = true
	_state_elapsed = 0.0
	velocity = Vector2.ZERO
	collision_layer = 0
	collision_mask = 0
	state = &"Idle"
	_set_animation(&"idle")

	var effect := DISAPPEAR_SCENE.instantiate() as BusinessDisappearEffect
	get_parent().add_child(effect)
	effect.global_position = global_position + Vector2(0.0, -62.0)
	visible = false
	await effect.finished

func resume_after_intermission() -> void:
	if state == &"Dead":
		return
	_in_intermission = false
	visible = true
	collision_layer = 4
	collision_mask = 3
	velocity = Vector2.ZERO
	state = &"Idle"
	_state_elapsed = 0.0
	_attack_fired = false
	_set_animation(&"idle")


## The elevated decks are not a safe shooting perch. The arena calls this when
## the player settles on one: the same blue disappearance effect used for a
## health-break teleport plays, then the boss relocates onto that deck.
func teleport_to_platform(destination: Vector2) -> void:
	if _in_intermission or _teleporting or state == &"Dead":
		return
	_teleporting = true
	velocity = Vector2.ZERO
	collision_layer = 0
	collision_mask = 0
	var effect := DISAPPEAR_SCENE.instantiate() as BusinessDisappearEffect
	get_parent().add_child(effect)
	effect.global_position = global_position + Vector2(0.0, -62.0)
	visible = false
	await effect.finished
	if state == &"Dead":
		return
	global_position = destination
	visible = true
	collision_layer = 4
	collision_mask = 3
	state = &"Idle"
	_state_elapsed = 0.0
	_attack_fired = false
	_set_animation(&"idle")
	_teleporting = false

func _on_died() -> void:
	if state == &"Dead":
		return
	_in_intermission = false
	state = &"Dead"
	_state_elapsed = 0.0
	_attack_fired = true
	collision_layer = 0
	collision_mask = 1
	set_physics_process(true)
	velocity = Vector2.ZERO

	sprite.hide()
	var explosion := EXPLOSION_SCENE.instantiate() as BossExplosion
	get_parent().add_child(explosion)
	explosion.global_position = global_position + Vector2(0.0, -62.0)
	await explosion.finished

	EventBus.enemy_died.emit(self, age_reward)
	defeated.emit()
	TimeService.retire(self)

func _on_animation_finished() -> void:
	pass
