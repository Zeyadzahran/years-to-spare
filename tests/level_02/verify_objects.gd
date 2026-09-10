extends Node
## Instance-specific sizes must never mutate another object's shared shape resource.
const OBJECTS := "res://src/levels/level_02/objects/"
var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func create(file: String) -> Node2D:
	var object := (load(OBJECTS + file + ".tscn") as PackedScene).instantiate() as Node2D
	object.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(object)
	return object

func _ready() -> void:
	var ledge := create("industrial_ledge")
	var other_ledge := create("industrial_ledge")
	ledge.width_tiles = 5
	ledge.one_way = false
	check(ledge.get_node("Shape").shape.size == Vector2(320,24), "Ledge width did not update collision")
	check(ledge.get_node("Right").position.x == 128, "Ledge end cap did not follow width")
	check(ledge.get_node("Middle").region_rect.size.x == 96, "Ledge middle did not repeat to fit width")
	check(not ledge.get_node("Shape").one_way_collision, "Ledge one-way setting did not update")
	check(other_ledge.get_node("Shape").shape.size == Vector2(192,24), "Editing one ledge resized another")
	check(other_ledge.get_node("Shape").one_way_collision, "Editing one ledge changed another's collision")
	var crate := create("cargo_crate")
	var other_crate := create("cargo_crate")
	crate.collision_size = Vector2(128,64)
	crate.art_width = 128
	crate.collision_offset = Vector2(5,0)
	check(crate.get_node("Shape").position == Vector2(5,-32), "Crate collision no longer aligns to its base")
	check(other_crate.get_node("Shape").shape.size == Vector2(110,70), "Crate sizes are shared between instances")
	check(is_equal_approx(crate.get_node("Cargo").scale.x * 78,128), "Crate art width did not update")
	var ferry := create("freight_shuttle")
	var other_ferry := create("freight_shuttle")
	ferry.size = Vector2(320,24)
	check(other_ferry.get_node("Shape").shape.size == Vector2(240,24), "Freight deck sizes are shared")
	var pulse := create("pulse_trap")
	var emitter := pulse.get_node("Emitter") as AnimatedSprite2D
	check(emitter.visible and emitter.is_playing(), "Electricity must start visibly active")
	check(emitter.sprite_frames.get_animation_speed(&"electricity") == 16.0, "Electricity should animate at 16 FPS")
	var other_pulse := create("pulse_trap")
	pulse.animation_fps = 24.0
	check(other_pulse.get_node("Emitter").sprite_frames.get_animation_speed(&"electricity") == 16.0, "Changing one trap's animation speed changed another")
	pulse.animation_fps = 16.0
	check(pulse.hurts_while_frozen, "Electricity must remain dangerous during time stop")
	pulse.process_mode = Node.PROCESS_MODE_INHERIT
	TimeService.mode = TimeService.Mode.STOPPED
	var initial_frame := emitter.frame + emitter.frame_progress
	await get_tree().create_timer(0.1).timeout
	check(not is_equal_approx(initial_frame, emitter.frame + emitter.frame_progress), "Electricity animation stopped during time stop")
	check(emitter.visible, "Time stop hid the electrical effect")
	# Reproduce a scene/editor buffer that still has the original Sprite2D emitter.
	var legacy_pulse := (load(OBJECTS + "pulse_trap.tscn") as PackedScene).instantiate()
	var original_emitter := legacy_pulse.get_node("Emitter")
	legacy_pulse.remove_child(original_emitter)
	original_emitter.free()
	var sheet := Sprite2D.new()
	sheet.name = "Emitter"
	sheet.texture = load("res://src/levels/level_02/art/animated/Trap.png")
	sheet.hframes = 4
	legacy_pulse.add_child(sheet)
	legacy_pulse.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(legacy_pulse)
	legacy_pulse.animation_fps = 20.0
	legacy_pulse._physics_process(0.05)
	check(sheet.frame == 1, "Original Sprite2D emitter did not animate during time stop")
	legacy_pulse._physics_process(0.2)
	check(sheet.frame == 1, "Original Sprite2D animation did not wrap its sprite sheet")
	TimeService.reset()
	var map := (load("res://src/levels/level_02/level_02.tscn") as PackedScene).instantiate()
	# Do not enter the tree: this check must not start or reset a run.
	for supply in map.get_node("World/Supplies").get_children():
		check(supply.scene_file_path == OBJECTS + "supply_chest.tscn", "Health box is not a shared scene")
		check(supply.has_node("Shape") and supply.has_node("Art"), "Incomplete health box")
	for hazard in map.get_node("World/Hazards").get_children():
		if hazard.name == &"FallReset": continue
		check(hazard.scene_file_path == OBJECTS + "pulse_trap.tscn", "Electrical trap is not a shared scene")
	for prop in map.get_node("World/Decorations").get_children():
		check(prop.scene_file_path.begins_with("res://src/levels/level_02/props/"), "Decoration is not a shared scene")
	check(map.get_node("World/Checkpoints/L2MachineYard").position == Vector2(1680,643), "User's checkpoint placement changed")
	check(not map.has_node("World/Checkpoints/L2Entry"), "Removed opening checkpoint was restored")
	check(map.get_node("World/Obstacles/CargoCrate").collision_size == Vector2(100,49), "Unsaved crate resize was lost")
	check(map.get_node("World/Obstacles/CargoCrate").collision_offset == Vector2(5,0), "Unsaved crate offset was lost")
	map.free()
	for object in get_children(): object.queue_free()
	await get_tree().process_frame
	print("LEVEL_02_OBJECTS_VERIFIED failures=%d" % failures)
	get_tree().quit(0 if failures == 0 else 1)
