extends RefCounted
## Isolates the later sections from the actual level for focused physics checks.
## Detach before entering the tree so the level lifecycle and player do not run.

static func late_sections() -> Node2D:
	var level := (load("res://src/levels/level_01.tscn") as PackedScene).instantiate()
	var sections := level.get_node(^"World/FiveActExtension") as Node2D
	sections.get_parent().remove_child(sections)
	level.free()
	return sections
