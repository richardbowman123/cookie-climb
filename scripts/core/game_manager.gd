# Old 3D game manager — no longer used
extends Node3D

## Builds the grid world, player, camera, and lighting.
## PC game: mouse to orbit camera, keyboard for movement and actions.

const GRID_SIZE := 8
const TILE_SIZE := 1.0
const WALL_HEIGHT := 2.0

# Colours
const TILE_LIGHT := Color(0.85, 0.75, 0.55)
const TILE_DARK := Color(0.65, 0.55, 0.40)
const WALL_COLOR := Color(0.45, 0.35, 0.25)
const PLAYER_COLOR := Color(0.2, 0.6, 0.9)
const COOKIE_DARK := Color(0.12, 0.08, 0.06)
const COOKIE_CREAM := Color(0.95, 0.92, 0.85)
const BLOCK_COLOR := Color(0.5, 0.75, 0.5)

var player: CharacterBody3D
var orbit_camera: Node3D
var cookies_parent: Node3D
var blocks_parent: Node3D
var score := 0
var total_cookies := 0
var block_count := 0
const MAX_BLOCKS := 20

var placed_blocks := {}

var _score_label: Label
var _blocks_label: Label
var _controls_label: Label

func _ready() -> void:
	_build_environment()
	_build_grid()
	_build_walls()
	_build_player()
	_build_camera()
	_build_cookies()
	_build_hud()

# --- Environment (lighting + sky) ---

func _build_environment() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, -30, 0)
	sun.light_energy = 0.9
	sun.shadow_enabled = true
	add_child(sun)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.6, 0.8, 1.0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.9, 0.9, 1.0)
	env.ambient_light_energy = 0.4

	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

# --- Grid floor ---

func _build_grid() -> void:
	var grid_parent := Node3D.new()
	grid_parent.name = "Grid"
	add_child(grid_parent)

	for x in range(GRID_SIZE):
		for z in range(GRID_SIZE):
			var tile := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(TILE_SIZE * 0.98, 0.1, TILE_SIZE * 0.98)
			tile.mesh = box

			var mat := StandardMaterial3D.new()
			if (x + z) % 2 == 0:
				mat.albedo_color = TILE_LIGHT
			else:
				mat.albedo_color = TILE_DARK
			tile.material_override = mat

			var offset_x: float = x - GRID_SIZE / 2.0 + 0.5
			var offset_z: float = z - GRID_SIZE / 2.0 + 0.5
			tile.position = Vector3(offset_x * TILE_SIZE, 0.0, offset_z * TILE_SIZE)
			tile.name = "Tile_%d_%d" % [x, z]

			var body := StaticBody3D.new()
			var shape := CollisionShape3D.new()
			var box_shape := BoxShape3D.new()
			box_shape.size = Vector3(TILE_SIZE * 0.98, 0.1, TILE_SIZE * 0.98)
			shape.shape = box_shape
			body.add_child(shape)
			tile.add_child(body)

			grid_parent.add_child(tile)

# --- Walls ---

func _build_walls() -> void:
	var walls_parent := Node3D.new()
	walls_parent.name = "Walls"
	add_child(walls_parent)

	var half_grid: float = GRID_SIZE / 2.0 * TILE_SIZE
	var wall_thickness := 0.2

	var wall_data := [
		[Vector3(0, WALL_HEIGHT / 2.0, half_grid + wall_thickness / 2.0),
		 Vector3(GRID_SIZE * TILE_SIZE + wall_thickness * 2, WALL_HEIGHT, wall_thickness)],
		[Vector3(0, WALL_HEIGHT / 2.0, -half_grid - wall_thickness / 2.0),
		 Vector3(GRID_SIZE * TILE_SIZE + wall_thickness * 2, WALL_HEIGHT, wall_thickness)],
		[Vector3(half_grid + wall_thickness / 2.0, WALL_HEIGHT / 2.0, 0),
		 Vector3(wall_thickness, WALL_HEIGHT, GRID_SIZE * TILE_SIZE + wall_thickness * 2)],
		[Vector3(-half_grid - wall_thickness / 2.0, WALL_HEIGHT / 2.0, 0),
		 Vector3(wall_thickness, WALL_HEIGHT, GRID_SIZE * TILE_SIZE + wall_thickness * 2)],
	]

	var wall_mat := StandardMaterial3D.new()
	wall_mat.albedo_color = WALL_COLOR
	wall_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wall_mat.albedo_color.a = 0.7

	for i in range(wall_data.size()):
		var data: Array = wall_data[i]
		var pos: Vector3 = data[0]
		var sz: Vector3 = data[1]

		var wall := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = sz
		wall.mesh = box
		wall.material_override = wall_mat
		wall.position = pos
		wall.name = "Wall_%d" % i

		# No collision on walls — grid bounds check handles movement limits.
		# Physical wall collision was trapping the CharacterBody3D.
		walls_parent.add_child(wall)

# --- Player ---

func _build_player() -> void:
	player = CharacterBody3D.new()
	player.name = "Player"
	player.position = Vector3(0, 0.05 + 0.45, 0)

	var player_script := load("res://scripts/player/player.gd")
	player.set_script(player_script)

	var mesh_inst := MeshInstance3D.new()
	mesh_inst.name = "MeshInstance3D"
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.3
	capsule.height = 0.9
	mesh_inst.mesh = capsule
	var mat := StandardMaterial3D.new()
	mat.albedo_color = PLAYER_COLOR
	mesh_inst.material_override = mat
	player.add_child(mesh_inst)

	var col := CollisionShape3D.new()
	col.name = "CollisionShape3D"
	var shape := CapsuleShape3D.new()
	shape.radius = 0.3
	shape.height = 0.9
	col.shape = shape
	player.add_child(col)

	add_child(player)

# --- Camera ---

func _build_camera() -> void:
	var pivot := Node3D.new()
	pivot.name = "CameraPivot"
	pivot.position = Vector3(0, 0, 0)

	var cam := Camera3D.new()
	cam.name = "Camera3D"
	cam.position = Vector3(0, 0, 10)
	cam.current = true
	pivot.add_child(cam)

	pivot.rotation_degrees.x = -35
	pivot.rotation_degrees.y = 45

	var script := load("res://scripts/core/orbit_camera.gd")
	pivot.set_script(script)

	add_child(pivot)
	orbit_camera = pivot

	if player:
		player.camera_pivot = pivot
		player.game_manager = self

# --- Cookies (Oreo sandwich: dark-cream-dark) ---

func _build_cookies() -> void:
	cookies_parent = Node3D.new()
	cookies_parent.name = "Cookies"
	add_child(cookies_parent)

	blocks_parent = Node3D.new()
	blocks_parent.name = "Blocks"
	add_child(blocks_parent)

	var cookie_positions := [
		Vector3(-3, 0.7, -3),
		Vector3(3, 0.7, 2),
		Vector3(-2, 0.7, 3),
		Vector3(1, 0.7, -2),
		Vector3(0, 1.7, 3),
		Vector3(-3, 1.7, 0),
		Vector3(2, 2.7, -1),
		Vector3(0, 3.7, 0),
		Vector3(-2, 3.7, -2),
		Vector3(3, 4.7, 3),
	]

	for pos in cookie_positions:
		_spawn_cookie(pos)

	total_cookies = cookie_positions.size()

func _spawn_cookie(pos: Vector3) -> void:
	var cookie_script := load("res://scripts/core/cookie.gd")

	var cookie := Area3D.new()
	cookie.position = pos
	cookie.set_script(cookie_script)

	var dark_mat := StandardMaterial3D.new()
	dark_mat.albedo_color = COOKIE_DARK

	var cream_mat := StandardMaterial3D.new()
	cream_mat.albedo_color = COOKIE_CREAM

	# Bottom disc (dark)
	var bottom := MeshInstance3D.new()
	var bottom_cyl := CylinderMesh.new()
	bottom_cyl.top_radius = 0.3
	bottom_cyl.bottom_radius = 0.3
	bottom_cyl.height = 0.06
	bottom.mesh = bottom_cyl
	bottom.material_override = dark_mat
	bottom.position.y = -0.05
	cookie.add_child(bottom)

	# Cream filling
	var cream := MeshInstance3D.new()
	var cream_cyl := CylinderMesh.new()
	cream_cyl.top_radius = 0.25
	cream_cyl.bottom_radius = 0.25
	cream_cyl.height = 0.04
	cream.mesh = cream_cyl
	cream.material_override = cream_mat
	cream.position.y = 0.0
	cookie.add_child(cream)

	# Top disc (dark)
	var top := MeshInstance3D.new()
	var top_cyl := CylinderMesh.new()
	top_cyl.top_radius = 0.3
	top_cyl.bottom_radius = 0.3
	top_cyl.height = 0.06
	top.mesh = top_cyl
	top.material_override = dark_mat
	top.position.y = 0.05
	cookie.add_child(top)

	var col := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.4
	col.shape = sphere
	cookie.add_child(col)

	cookie.collected.connect(_on_cookie_collected)
	cookies_parent.add_child(cookie)

func _on_cookie_collected() -> void:
	score += 1
	_update_hud()
	if score >= total_cookies:
		_show_win_message()

# --- Block placement (keyboard E / Q) ---

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			get_tree().quit()
		elif event.keycode == KEY_Q:
			if orbit_camera:
				orbit_camera.rotate_left()
		elif event.keycode == KEY_E:
			if orbit_camera:
				orbit_camera.rotate_right()
		elif event.keycode == KEY_R:
			_place_block()
		elif event.keycode == KEY_F:
			_remove_block()

func _place_block() -> void:
	if block_count >= MAX_BLOCKS:
		return
	if not player:
		return

	var gx: int = player._grid_x
	var gz: int = player._grid_z

	var by := 0
	while placed_blocks.has(Vector3i(gx, by, gz)):
		by += 1

	var player_foot_y := player.position.y - 0.45
	var block_top_y: float = 0.05 + (by + 1) * TILE_SIZE
	if block_top_y > player_foot_y + 0.1:
		return

	_spawn_block(gx, by, gz)
	block_count += 1
	_update_hud()

func _remove_block() -> void:
	if block_count <= 0:
		return
	if not player:
		return

	var gx: int = player._grid_x
	var gz: int = player._grid_z

	var by := 0
	var highest := -1
	while placed_blocks.has(Vector3i(gx, by, gz)):
		highest = by
		by += 1

	if highest < 0:
		return

	var key := Vector3i(gx, highest, gz)
	var block_node: Node3D = placed_blocks[key]
	block_node.queue_free()
	placed_blocks.erase(key)
	block_count -= 1
	_update_hud()

func _spawn_block(gx: int, by: int, gz: int) -> void:
	var block := StaticBody3D.new()
	var world_y: float = 0.05 + by * TILE_SIZE + TILE_SIZE / 2.0
	block.position = Vector3(gx * TILE_SIZE, world_y, gz * TILE_SIZE)
	block.name = "Block_%d_%d_%d" % [gx, by, gz]

	var mesh_inst := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(TILE_SIZE * 0.95, TILE_SIZE * 0.95, TILE_SIZE * 0.95)
	mesh_inst.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = BLOCK_COLOR
	mesh_inst.material_override = mat
	block.add_child(mesh_inst)

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(TILE_SIZE * 0.95, TILE_SIZE * 0.95, TILE_SIZE * 0.95)
	col.shape = shape
	block.add_child(col)

	blocks_parent.add_child(block)
	placed_blocks[Vector3i(gx, by, gz)] = block

# --- HUD (landscape 1280x720) ---

func _build_hud() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "HUD"
	add_child(canvas)

	_score_label = Label.new()
	_score_label.position = Vector2(20, 15)
	_score_label.add_theme_font_size_override("font_size", 32)
	_score_label.add_theme_color_override("font_color", Color.WHITE)
	_score_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	_score_label.add_theme_constant_override("shadow_offset_x", 2)
	_score_label.add_theme_constant_override("shadow_offset_y", 2)
	canvas.add_child(_score_label)

	_blocks_label = Label.new()
	_blocks_label.position = Vector2(20, 55)
	_blocks_label.add_theme_font_size_override("font_size", 24)
	_blocks_label.add_theme_color_override("font_color", Color.WHITE)
	_blocks_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	_blocks_label.add_theme_constant_override("shadow_offset_x", 2)
	_blocks_label.add_theme_constant_override("shadow_offset_y", 2)
	canvas.add_child(_blocks_label)

	# Controls hint — bottom-left
	_controls_label = Label.new()
	_controls_label.position = Vector2(20, 660)
	_controls_label.add_theme_font_size_override("font_size", 18)
	_controls_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	_controls_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.3))
	_controls_label.add_theme_constant_override("shadow_offset_x", 1)
	_controls_label.add_theme_constant_override("shadow_offset_y", 1)
	_controls_label.text = "WASD = Move    Space = Jump    Q/E = Rotate view    R = Place block    F = Remove block    Scroll = Zoom    ESC = Quit"
	canvas.add_child(_controls_label)

	_update_hud()

func _update_hud() -> void:
	if _score_label:
		_score_label.text = "Cookies: %d / %d" % [score, total_cookies]
	if _blocks_label:
		_blocks_label.text = "Blocks: %d / %d" % [block_count, MAX_BLOCKS]

func _show_win_message() -> void:
	var canvas: CanvasLayer = get_node("HUD")
	var win := Label.new()
	win.text = "ALL COOKIES COLLECTED!"
	win.add_theme_font_size_override("font_size", 48)
	win.add_theme_color_override("font_color", Color(1, 0.85, 0))
	win.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	win.add_theme_constant_override("shadow_offset_x", 3)
	win.add_theme_constant_override("shadow_offset_y", 3)
	win.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	win.anchors_preset = Control.PRESET_CENTER_TOP
	win.position = Vector2(640, 150)
	win.pivot_offset = Vector2(win.size.x / 2, 0)
	canvas.add_child(win)
