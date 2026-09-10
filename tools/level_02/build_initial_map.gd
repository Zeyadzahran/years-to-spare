extends SceneTree
## One-time authoring seed. The saved scene is the editable source of truth.
## Re-running overwrites Level 2; do not run after manual layout edits.
const BASE := "res://src/levels/level_02/"
const ART := BASE + "art/"
var level: Node2D
var terrain: TileMapLayer

func _initialize() -> void:
	build.call_deferred()

func node(parent: Node, child: Node, title: String) -> Node:
	child.name = title
	parent.add_child(child)
	child.owner = level
	return child

func group(parent: Node, title: String) -> Node2D:
	return node(parent, Node2D.new(), title)

func instance(parent: Node, title: String, path: String, at: Vector2) -> Node2D:
	var child := (load(path) as PackedScene).instantiate() as Node2D
	node(parent, child, title)
	child.position = at
	return child

func sprite(parent: Node, title: String, path: String, at: Vector2, factor := 2.0) -> Sprite2D:
	const PROP_SCENES := {
	"power_lines/3.png": "power_pylon",
	"power_lines/4.png": "damaged_pylon",
	"decorations/24.png": "tank_ac3",
	"decorations/25.png": "tank_efg2",
	"decorations/26.png": "transformer",
	"decorations/27.png": "cargo_shed",
	"pipes/4.png": "blue_pipe",
	"pipes/1.png": "red_pipe",
	"pipes/2.png": "green_pipe",
	"decorations/1.png": "scrap_pile_a",
	"decorations/2.png": "scrap_pile_b",
	"decorations/3.png": "scrap_pile_c",
	"decorations/4.png": "scrap_pile_d"
}
	var art: Sprite2D
	if PROP_SCENES.has(path):
		art = instance(parent, title, BASE + "props/" + PROP_SCENES[path] + ".tscn", at) as Sprite2D
	else:
		art = Sprite2D.new()
		art.texture = load(ART + path)
		node(parent, art, title)
	art.position = at
	art.scale = Vector2.ONE * factor
	art.offset.y = -art.texture.get_height() * 0.5
	return art


func box(parent: Node, dimensions: Vector2, at := Vector2.ZERO) -> CollisionShape2D:
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = dimensions
	shape.shape = rectangle
	shape.position = at
	node(parent, shape, "Shape")
	return shape

func label(parent: Node, title: String, copy: String, at: Vector2, font_size := 14) -> Label:
	var text := Label.new()
	text.text = copy
	text.position = at
	text.add_theme_font_override("font", load("res://assets/fonts/prstart.ttf"))
	text.add_theme_font_size_override("font_size", font_size)
	text.add_theme_color_override("font_color", Color("d3edf2"))
	text.add_theme_color_override("font_outline_color", Color("151b31"))
	text.add_theme_constant_override("outline_size", 5)
	node(parent, text, title)
	return text

func ground(x: int, end: int, y: int, bottom := 17) -> void:
	for col in range(x, end):
		for row in range(y, bottom):
			var tile := Vector2i(1, 1)
			if row == y:
				tile = Vector2i(1, 0)
				if col == x: tile = Vector2i(0, 0)
				elif col == end - 1: tile = Vector2i(2, 0)
			elif col == x: tile = Vector2i(0, 1)
			elif col == end - 1: tile = Vector2i(2, 1)
			elif (col * 7 + row * 11) % 13 == 0: tile = Vector2i(4, 4)
			terrain.set_cell(Vector2i(col, row), 0, tile)

func ledge(parent: Node, title: String, x: float, y: float, width: int) -> Node2D:
	var result := instance(parent, title, BASE + "objects/industrial_ledge.tscn", Vector2(x, y))
	result.width_tiles = width
	return result

func chest(parent: Node, title: String, at: Vector2) -> void:
	instance(parent, title, BASE + "objects/supply_chest.tscn", at)

func trap(parent: Node, title: String, at: Vector2) -> void:
	instance(parent, title, BASE + "objects/pulse_trap.tscn", at)

func build() -> void:
	if FileAccess.file_exists(BASE + "level_02.tscn") and "--replace" not in OS.get_cmdline_user_args():
		push_error("Level 2 already exists. Edit its scene, or pass --replace to deliberately regenerate it.")
		quit(1)
		return
	level = Node2D.new()
	level.name = "Level02"
	level.set_script(load("res://src/levels/level.gd"))
	level.level_id = &"phase_2"
	level.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	instance(level, "Background", BASE + "background.tscn", Vector2.ZERO)
	var world := group(level, "World")
	var terrain_group := group(world, "Terrain")
	terrain = TileMapLayer.new()
	terrain.scale = Vector2(2, 2)
	var tiles := TileSet.new()
	tiles.tile_size = Vector2i(32, 32)
	tiles.add_physics_layer()
	tiles.set_physics_layer_collision_layer(0, 1)
	var atlas := TileSetAtlasSource.new()
	atlas.texture = load(ART + "terrain/Tileset.png")
	atlas.texture_region_size = Vector2i(32, 32)
	tiles.add_source(atlas, 0)
	for y in 8:
		for x in 8:
			var cell := Vector2i(x, y)
			atlas.create_tile(cell)
			var data := atlas.get_tile_data(cell, 0)
			data.set_collision_polygons_count(0, 1)
			data.set_collision_polygon_points(0, 0, PackedVector2Array([Vector2(-16,-16),Vector2(16,-16),Vector2(16,16),Vector2(-16,16)]))
	ResourceSaver.save(tiles, BASE + "terrain_tileset.tres")
	terrain.tile_set = tiles
	node(terrain_group, terrain, "IndustrialTiles")
	# Broad combat floors alternate with short jumps and a freight crossing.
	ground(0, 22, 10)
	ground(25, 45, 10)
	ground(43, 45, 9)
	ground(48, 69, 8)
	ground(78, 97, 8)
	ground(100, 117, 10)
	ground(120, 140, 10)
	var platforms := group(world, "Platforms")
	ledge(platforms, "StreetStep", 784, 544, 3)
	ledge(platforms, "StreetCache", 1040, 448, 4)
	ledge(platforms, "MachineStep", 2112, 512, 3)
	ledge(platforms, "MachineRoof", 2400, 384, 4)
	ledge(platforms, "RoofStep", 3552, 416, 3)
	ledge(platforms, "RoofCache", 3856, 320, 5)
	ledge(platforms, "OverlookStep", 5280, 416, 3)
	ledge(platforms, "Overlook", 5536, 320, 5)
	ledge(platforms, "CourtyardStep", 6920, 512, 3)
	ledge(platforms, "CourtyardRoof", 7192, 384, 4)
	instance(platforms, "FreightShuttle", BASE + "objects/freight_shuttle.tscn", Vector2(4512, 524))
	# Visible rail under the moving deck.
	var rail := Line2D.new()
	rail.points = PackedVector2Array([Vector2(4416,560),Vector2(4992,560)])
	rail.width = 6
	rail.default_color = Color("627d96")
	node(platforms, rail, "FreightRail")
	var collisions := group(world, "Obstacles")
	for item in [["CargoCrate", Vector2(1800,640), Vector2(110,70)], ["CourtyardCrate",Vector2(6656,640),Vector2(128,64)]]:
		var body := instance(collisions, item[0], BASE + "objects/cargo_crate.tscn", item[1])
		body.collision_size = item[2]
		body.art_width = item[2].x
	var boundary := StaticBody2D.new()
	node(collisions,boundary,"LeftBoundary")
	box(boundary,Vector2(64,1600),Vector2(-32,400))
	var right_boundary := StaticBody2D.new()
	node(collisions,right_boundary,"RightBoundary")
	box(right_boundary,Vector2(64,1600),Vector2(8992,400))
	var decorations := group(world, "Decorations")
	decorations.z_index = -2
	# Large industrial silhouettes establish each district; small props mark paths.
	for item in [[160,640,3],[1280,640,4],[2650,640,3],[3310,512,4],[4220,512,3],[5110,512,4],[5950,512,3],[6500,640,4],[7540,640,3],[8650,640,4]]:
		sprite(decorations,"Pylon%d"%item[0],"power_lines/%d.png"%item[2],Vector2(item[0],item[1]),2.6)
	for item in [[480,640,24],[820,640,26],[1930,640,25],[2280,640,24],[3430,512,26],[4020,512,25],[5380,512,24],[5760,512,27],[6790,640,26],[7070,640,25],[7930,640,24],[8350,640,26]]:
		sprite(decorations,"Machinery%d"%item[0],"decorations/%d.png"%item[2],Vector2(item[0],item[1]),2.0)
	for item in [[600,640,4],[2580,640,1],[3550,512,2],[5220,512,4],[7350,640,1],[8180,640,4]]:
		sprite(decorations,"Pipe%d"%item[0],"pipes/%d.png"%item[2],Vector2(item[0],item[1]),2.0)
	for i in range(26):
		var x := 260 + i * 320
		var y := 512 if x >= 3072 and x < 6208 else 640
		if x > 4350 and x < 5050 or x > 7400 and x < 7700 or x > 1380 and x < 1620 or x > 2800 and x < 3080 or x > 6150 and x < 6440: continue
		sprite(decorations,"Scrap%02d"%i,"decorations/%d.png"%(1 + i % 4),Vector2(x,y))
	var signs := group(world,"Wayfinding")
	label(signs,"PulseHint","LIVE ELECTRICITY.\nJUMP OVER THE BEAM.",Vector2(2310,475),11)
	label(signs,"FerryHint","FREIGHT CROSSING  >\nRIDE THE DECK. [K] HOLDS IT.",Vector2(4040,265),11)
	label(signs,"CourtyardSign","EAST COURTYARD  >",Vector2(6500,325),14)
	var checkpoints := group(world,"Checkpoints")
	for item in [["L2Entry",240,640],["L2MachineYard",1664,640],["L2Rooftops",3200,512],["L2FreightLanding",5120,512],["L2Courtyard",6520,640],["L2ExitApproach",7872,640]]:
		instance(checkpoints,item[0],"res://src/world/checkpoints/checkpoint.tscn",Vector2(item[1],item[2]))
	var pickups := group(world,"Supplies")
	for item in [["StreetCache",1040,448],["YardSupply",2000,640],["RoofCache",3856,320],["LandingSupply",5260,512],["CourtyardCache",7192,384],["ExitSupply",7960,640]]:
		chest(pickups,item[0],Vector2(item[1],item[2]))
	var hazards := group(world,"Hazards")
	trap(hazards,"YardPulse",Vector2(2530,640))
	trap(hazards,"RooftopPulse",Vector2(3630,512))
	trap(hazards,"LandingPulse",Vector2(5890,512))
	trap(hazards,"ExitPulse",Vector2(8240,640))
	var fall := Area2D.new()
	fall.set_script(load("res://src/world/hazards/hazard.gd"))
	fall.damage = 1000.0
	fall.collision_layer = 0
	fall.collision_mask = 2
	node(hazards,fall,"FallReset")
	box(fall,Vector2(10000,300),Vector2(4480,1060))
	var enemies := group(level,"Enemies")
	for item in [["StreetPatrol",740,640,"guard"],["YardGuard",2110,640,"guard"],["YardGunner",2720,640,"gunner"],["RoofPatrol",3370,512,"guard"],["RoofGunner",4120,512,"gunner"],["FreightGuard",5490,512,"guard"],["LandingGunner",6080,512,"gunner"],["CourtyardGuard",6970,640,"guard"],["CourtyardGunner",7300,640,"gunner"],["ExitGuard",8440,640,"guard"],["ExitGunner",8700,640,"gunner"]]:
		var enemy := instance(enemies,item[0],"res://src/actors/enemy/%s.tscn"%item[3],Vector2(item[1],item[2]))
		enemy.detection_range = 340.0
		if item[3] == "guard":
			enemy.patrol_distance = 95.0
			enemy.territory = 360.0
	var entities := group(level,"Entities")
	var player := instance(entities,"Player","res://src/actors/player/player.tscn",Vector2(240,640))
	var camera := player.get_node("Camera2D") as Camera2D
	camera.limit_left = 0
	camera.limit_right = 8960
	camera.limit_top = -160
	camera.limit_bottom = 920
	camera.position = Vector2(100,-130)
	var exits := group(world,"Exit")
	var gate := instance(exits,"LevelExit","res://src/world/exits/level_exit.tscn",Vector2(8840,640))
	gate.get_node("Completion/Panel/Copy/Kicker").text = ""
	gate.get_node("Completion/Panel/Copy/Kicker").visible = false
	gate.get_node("Completion/Panel/Copy/Title").text = "LEVEL 2 COMPLETE"
	# These instance overrides are stored explicitly in the packed level scene.
	level.set_editable_instance(gate, true)
	level.set_editable_instance(player, true)
	sprite(exits,"ExitFrame","decorations/27.png",Vector2(8840,640),2.8)
	sprite(exits,"ExitBeacon","decorations/9.png",Vector2(8840,520),2.0)
	node(level, (load("res://src/ui/hud.tscn") as PackedScene).instantiate(), "HUD")
	var packed := PackedScene.new()
	assert(packed.pack(level) == OK)
	assert(ResourceSaver.save(packed,BASE + "level_02.tscn") == OK)
	print("LEVEL_02_AUTHORED tiles=%d" % terrain.get_used_cells().size())
	level.free()
	quit()
