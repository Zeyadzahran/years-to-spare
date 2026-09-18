class_name Robot
extends Enemy
## A planted beam turret. Its attack clock, health and death are already part
## of Enemy's rewind snapshot; the chest effect is derived from that clock.

const BEAM_SCENE := preload("res://src/actors/enemy/robot_beam.tscn")
const MUZZLE := Vector2(10.0, -70.0)

@export var beam_speed := 1200.0

@onready var charge: AnimatedSprite2D = $Charge
@onready var shot_audio: AudioStreamPlayer2D = $ShotAudio
@onready var hurt_audio: AudioStreamPlayer2D = $HurtAudio
@onready var death_audio: AudioStreamPlayer2D = $DeathAudio

func _init() -> void:
	speed = 0.0
	detection_range = 320.0
	attack_range = 320.0
	detection_height_tolerance = 110.0
	attack_height_tolerance = 110.0
	eye_height = MUZZLE.y
	attack_hit_time = 0.65
	attack_duration = 1.0
	attack_recovery = 1.25
	hurt_duration = 0.4
	knockback = 0.0
	attack_animation = &"shoot"


func _physics_process(delta: float) -> void:
	super(delta)
	_sync_charge()


func _tick_chase(_delta: float) -> void:
	velocity.x = 0.0
	if target != null and is_instance_valid(target):
		var dx := target.global_position.x - global_position.x
		if not is_zero_approx(dx):
			facing = 1 if dx > 0.0 else -1
	_set_animation(&"idle")


## Commit to a side during the warning, so jumping over the robot does not
## make the charged shot suddenly turn around. The next cycle can turn.
func _face_target_mid_attack() -> void:
	pass


func _attack() -> void:
	var beam := BEAM_SCENE.instantiate() as RobotBeam
	beam.setup(facing, beam_speed)
	get_tree().current_scene.add_child(beam)
	beam.global_position = global_position + Vector2(MUZZLE.x * facing, MUZZLE.y)
	shot_audio.play()


func _on_damaged(_amount: float, _source: Node) -> void:
	if state == &"Dead":
		return
	_flash = 1.0
	velocity.x = 0.0
	_change_state(&"Hurt")
	_sync_charge()
	if health.is_alive():
		hurt_audio.play()


func _on_died() -> void:
	super()
	_sync_charge()
	shot_audio.stop()
	hurt_audio.stop()
	death_audio.stream_paused = false
	death_audio.play()


## Discard sounds from the abandoned future. TimeService calls this even on
## retired robots, whose longer death clip may still be finishing offscreen.
func rewind_began() -> void:
	for audio in _audio:
		audio.stop()


## Sample the supplied spawn sheet instead of running a second animation
## timer. A freeze, interrupted charge, or rewind therefore stays in sync.
func _sync_charge() -> void:
	charge.visible = state == &"Attack"
	if not charge.visible:
		return
	charge.position = Vector2(MUZZLE.x * facing, MUZZLE.y)
	charge.flip_h = facing < 0
	if not _attack_fired:
		charge.frame = mini(int(_state_elapsed / attack_hit_time * 7.0), 6)
	else:
		var after_shot := (_state_elapsed - attack_hit_time) / maxf(attack_duration - attack_hit_time, 0.01)
		charge.frame = mini(7 + int(after_shot * 6.0), 12)


## An ambush robot exists in the level before it activates. Keep that hidden,
## disabled state alongside Enemy's combat history so rewind cannot wake it
## early or leave a visible robot with its dormant collision layer.
func rewind_capture() -> Array:
	var saved := super()
	saved.append([visible, process_mode])
	return saved


func rewind_apply(saved: Array) -> void:
	super(saved)
	visible = saved[16][0]
	process_mode = saved[16][1]
	_sync_charge()
