extends SceneTree
## Offline authoring tool for the phase-one parallax backdrop.
##
## Parallax2D.scroll_scale is the fraction of world speed a layer travels at:
## 0.0 pins it to the viewport (infinitely far), 1.0 moves it exactly like
## gameplay geometry. Measured against a fixed camera, a layer set to 0.88
## tracks at 0.88 x 1.6 screen px per world px, so the mapping is direct.
##
## Three things were wrong before: the sky plate was mirrored with flip_v, which
## put desert above the horizon; ForegroundScrap was duplicated as two identical
## layers; and the whole scene was instanced under a parent scaled to 0.5, which
## Parallax2D folds into its own offset. The parent is identity now, and the
## art is scaled on the plates instead.

const OUTPUT := "res://src/levels/level_01/background.tscn"
const SKY := "res://src/levels/level_01/art/background/sky.png"
const RUINS := "res://src/levels/level_01/art/background/distant_ruins.png"
const SCRAP := "res://src/levels/level_01/art/background/scrap.png"

## All three plates are this size; the horizon in the sky plate sits at y 560.
const PLATE := Vector2(1672.0, 941.0)
## Each plate gets its own size, not one shared scale. Drawn at a common 0.5 the
## scrap sheet is 752 screen px tall - a wall across the play area rather than a
## band on the horizon - and the nearer layers ended up sitting HIGHER on screen
## than the sky's horizon, which reads as the depth order running backwards.
## Smaller as they come forward, and each anchored so its base lands just below
## the layer behind it.
##
## The scale lives on the plate itself, never on a parent: Parallax2D derives its
## offset from its own transform, so a scaled ancestor silently crushes the
## effect - which is what the old Background instance's 0.5 scale was doing.
const SKY_SCALE := 0.5
const RUINS_SCALE := 0.38
const SCRAP_SCALE := 0.30
## Vertical anchors, tuned against a fixed camera so the sky's horizon (plate
## row 560) lands just below screen centre, with the ruins band sitting on it
## and the scrap silhouette below that.
const SKY_TOP := 197.0
const RUINS_TOP := 211.0
const SCRAP_TOP := 221.0
## Editor repeats cover the authored level with room for the camera.
const COVERAGE_RIGHT := 42000.0


var _root: Node2D


func _init() -> void:
	call_deferred(&"_build")


func _build() -> void:
	_root = Node2D.new()
	_root.name = "PhaseOneBackground"
	_root.z_index = -100

	# Farthest: the only opaque plate, so it is the one that may never run out.
	# Solid bleeds above and below extend its top and bottom rows to cover a
	# level that spans far more vertical distance than one plate is tall.
	var sky := _layer("Sky", Vector2(0.08, 0.04), 14, SKY_SCALE)
	_bleed(sky, "AboveFill", Rect2(0.0, SKY_TOP - 2400.0, PLATE.x * SKY_SCALE, 2400.0), Color("e4a777"))
	_plate(sky, SKY, Vector2(0.0, SKY_TOP), SKY_SCALE)
	_bleed(sky, "BelowFill", Rect2(0.0, SKY_TOP + PLATE.y * SKY_SCALE, PLATE.x * SKY_SCALE, 2400.0), Color("b68664"))

	# Middle and near plates are transparent bands, so they are free to drift
	# off-screen vertically - the sky behind them is what keeps the frame filled.
	var ruins := _layer("DistantRuins", Vector2(0.25, 0.07), 12, RUINS_SCALE)
	_plate(ruins, RUINS, Vector2(0.0, RUINS_TOP), RUINS_SCALE)

	var scrap := _layer("ForegroundScrap", Vector2(0.45, 0.10), 10, SCRAP_SCALE)
	_plate(scrap, SCRAP, Vector2(0.0, SCRAP_TOP), SCRAP_SCALE)
	# Extend the existing rubble below the silhouette instead of a flat colour.
	_bleed(scrap, "BaseFill",
		Rect2(0.0, SCRAP_TOP + PLATE.y * SCRAP_SCALE - 2.0,
			PLATE.x * SCRAP_SCALE, 2400.0), Color.WHITE)
	var depth := ShaderMaterial.new()
	depth.shader = load("res://src/levels/level_01/shaders/scrap_depth.gdshader")
	depth.set_shader_parameter("scrap_texture", load(SCRAP))
	depth.set_shader_parameter("top", SCRAP_TOP + PLATE.y * SCRAP_SCALE - 2.0)
	depth.set_shader_parameter("tile_width", PLATE.x * SCRAP_SCALE)
	(scrap.get_node(^"BaseFill") as Polygon2D).material = depth

	var packed := PackedScene.new()
	assert(packed.pack(_root) == OK)
	assert(ResourceSaver.save(packed, OUTPUT) == OK)
	print("BACKGROUND_BUILT layers=%d" % _root.get_child_count())
	quit()


func _layer(layer_name: String, scroll: Vector2, times: int, plate_scale: float) -> Parallax2D:
	var layer := Parallax2D.new()
	layer.name = layer_name
	layer.scroll_scale = scroll
	# Horizontal tiling only. A vertical repeat would stack a second horizon on
	# top of the first, which is what the old mirrored plates were doing.
	layer.repeat_size = Vector2(PLATE.x * plate_scale, 0.0)
	# Copies spread on both sides of the origin. Cover the entire level even
	# when viewing its full layout in the editor, as well as the runtime camera.
	layer.repeat_times = maxi(times, 2 * ceili(COVERAGE_RIGHT / layer.repeat_size.x) - 1)
	_own(layer, _root)
	return layer


func _plate(parent: Parallax2D, path: String, at: Vector2, plate_scale: float) -> void:
	var sprite := Sprite2D.new()
	sprite.name = "Plate"
	sprite.texture = load(path)
	sprite.centered = false
	sprite.position = at
	sprite.scale = Vector2(plate_scale, plate_scale)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_own(sprite, parent)


func _bleed(parent: Parallax2D, bleed_name: String, rect: Rect2, color: Color) -> void:
	var fill := Polygon2D.new()
	fill.name = bleed_name
	fill.color = color
	fill.polygon = PackedVector2Array([
		rect.position,
		rect.position + Vector2(rect.size.x, 0.0),
		rect.end,
		rect.position + Vector2(0.0, rect.size.y),
	])
	_own(fill, parent)


func _own(node: Node, parent: Node) -> void:
	parent.add_child(node)
	node.owner = _root
