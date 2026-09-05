extends Area2D
## A level exit. The destination is configured by the level that places it.

@export_file("*.tscn") var destination: String
var _triggered := false

func _on_body_entered(body: Node2D) -> void:
	if _triggered or not body.is_in_group("player"):
		return
	_triggered = true
	get_tree().change_scene_to_file(destination)
