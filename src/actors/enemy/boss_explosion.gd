class_name BossExplosion
extends AnimatedSprite2D
## One-shot red explosion used for the Level 2 Business Man's death.

signal finished

func _ready() -> void:
	animation_finished.connect(_on_animation_finished)
	play(&"explode")

func _on_animation_finished() -> void:
	finished.emit()
	queue_free()
