class_name ToxicWater
extends Hazard
## A pool of toxic runoff sized to fill a pit. Damage and cooldown are
## inherited from Hazard untouched; this only advances the water shader's
## clock, and on TimeService's clock rather than the raw delta, so Stop Time
## stills the ripples the same way it stills a saw or a ceiling spike.

@export var wave_speed := 1.0

var _material: ShaderMaterial
var _time := 0.0

func _ready() -> void:
	super()
	var body := $Body as Polygon2D
	# Duplicated so two pools in the same level don't share one clock.
	_material = body.material.duplicate() as ShaderMaterial
	body.material = _material


func _physics_process(delta: float) -> void:
	super(delta)
	_time += TimeService.world_delta(delta) * wave_speed
	_material.set_shader_parameter(&"time", _time)
