extends SceneTree
## Export a review draft from the live scene, including manual editor changes.
## Level 01 remains the only authored layout; this tool never rebuilds it.

const OUTPUT := "res://builds/level_01_layout_draft.tscn"


func _initialize() -> void:
	var level := (load("res://src/levels/level_01/level_01.tscn") as PackedScene).instantiate()
	var section := level.get_node(^"World/SalvageYard")
	var authored: Array[Node] = []
	for node in section.find_children("*", "", true, false):
		if node.owner == level:
			authored.append(node)
	section.get_parent().remove_child(section)
	for node in authored:
		node.owner = section
	var draft := PackedScene.new()
	assert(draft.pack(section) == OK)
	assert(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT.get_base_dir())) == OK)
	assert(ResourceSaver.save(draft, OUTPUT) == OK)
	print("LEVEL_LAYOUT_DRAFT_SAVED ", OUTPUT)
	section.free()
	level.free()
	quit()
