class_name BusinessDisappearEffect
extends AnimatedSprite2D

signal finished

func _ready() -> void:
	animation_finished.connect(_on_animation_finished)
	play(&"disappear")

func _on_animation_finished() -> void:
	finished.emit()
	queue_free()
