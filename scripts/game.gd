extends Node2D

# ─── Constants ───
const GRID := 64
const WALL_WIDTH := 32
const ROW_SPACING := 180
const PLATFORM_MIN_W := 128
const PLATFORM_MAX_W := 384
const COOKIE_CHANCE := 0.5
const CLEANUP_DISTANCE := 1000.0
const TRUNK_X := 640.0

# ─── Level data ───
# [name, target_height_m, danger_speed, danger_ramp, hint, coconuts]
const LEVELS := [
	["LOW BRANCHES", 25, 12.0, 1.0, "COLLECT AS MANY COOKIES AS YOU CAN", false],
	["HIGHER GROUND", 45, 15.0, 1.5, "LEARN HOW TO USE CRATES", false],
	["INTO THE CANOPY", 70, 18.0, 2.0, "WATCH OUT FOR COCONUTS!", true],
	["THE TREETOP", 100, 22.0, 2.5, "GOOD LUCK UP THERE", true],
]

# ─── Persistent state (survives scene reload) ───
static var s_level: int = 0
static var s_tutorial: bool = false

# ─── State machine ───
enum State { TITLE, LEVEL_INTRO, TUTORIAL_INTRO, TUTORIAL, PLAYING, LEVEL_COMPLETE, VICTORY, GAME_OVER }
var state: State = State.TITLE

# ─── Game tracking ───
var cookie_score: int = 0
var cookies_available: int = 0
var highest_y: float = 0.0
var start_y: float = 0.0
var _target_y: float = 0.0  # world-Y of the goal banana

# ─── Danger (rising water) ───
var danger_y: float = 0.0
var danger_speed: float = 12.0
var danger_active: bool = false
var time_since_start: float = 0.0

# ─── Wave animation ───
var _wave_poly: Polygon2D
var _foam_poly: Polygon2D
var _wave_time: float = 0.0

# ─── Trunk generation ───
var _last_trunk_x: float = TRUNK_X
var _last_trunk_y: float = 0.0

# ─── Generation tracking ───
var _next_row_y: float = 0.0
var _generate_ahead := 900.0
var _placed_blocks: Dictionary = {}
var _goal_spawned: bool = false
var _staircase_left: bool = true  # zigzag direction for level 1
var _staircase_x: int = 500       # tracked x for staircase zigzag
var _row_count: int = 0           # counts rows generated (for variety in level 1)
var _last_plat_x: float = 0.0
var _last_plat_w: float = 0.0

# ─── Mobile menu tap ───
var _screen_tapped: bool = false

# ─── Victory bananas ───
var _victory_bananas: Array = []

# ─── Coconut spawning ───
var _coconut_timer: float = 0.0
var _coconut_interval: float = 4.0

# ─── Node refs ───
var player: CookiePlayer
var camera: Camera2D
var touch_controls: CookieTouchControls
var hud: CookieHUD
var danger_rect: ColorRect
var _world: Node2D
var _walls: Node2D

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.55, 0.78, 0.95))

	# Touch controls — auto-hidden on keyboard, auto-shown on touchscreen
	touch_controls = CookieTouchControls.new()
	add_child(touch_controls)

	if s_tutorial:
		_build_tutorial_level()
		return

	_build_world()
	_build_player()
	_build_camera()
	_build_danger()
	_build_hud()
	_build_walls()
	_generate_starting_floor()

	# Calculate goal position for current level
	var level_data: Array = LEVELS[s_level]
	var target_m: int = level_data[1]
	_target_y = start_y - (target_m * GRID)

	_generate_platforms_up_to(camera.global_position.y - _generate_ahead)

	if s_level == 0:
		hud.show_title()
	else:
		_show_level_intro()

func _build_world() -> void:
	_world = Node2D.new()
	_world.name = "World"
	add_child(_world)

func _build_player() -> void:
	player = CookiePlayer.new()
	player.position = Vector2(640, -GRID)
	player.z_index = 2
	start_y = player.position.y
	highest_y = start_y
	_world.add_child(player)

	player.block_placed.connect(_on_block_placed)
	player.blocks_changed.connect(_on_blocks_changed)
	player.set_physics_process(false)

func _build_camera() -> void:
	camera = Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 5.0
	camera.drag_horizontal_enabled = false
	camera.drag_vertical_enabled = false
	player.add_child(camera)
	camera.offset = Vector2(0, -100)

func _build_danger() -> void:
	danger_rect = ColorRect.new()
	danger_rect.color = Color(0.15, 0.35, 0.60, 0.90)
	danger_rect.size = Vector2(1280, 2000)
	danger_rect.z_index = 1
	_world.add_child(danger_rect)

	_wave_poly = Polygon2D.new()
	_wave_poly.color = Color(0.25, 0.50, 0.78, 0.85)
	danger_rect.add_child(_wave_poly)

	_foam_poly = Polygon2D.new()
	_foam_poly.color = Color(0.85, 0.92, 1.0, 0.6)
	danger_rect.add_child(_foam_poly)

	_update_wave(0.0)
	danger_y = 800.0
	danger_rect.position = Vector2(0, danger_y)

func _build_hud() -> void:
	hud = CookieHUD.new()
	add_child(hud)

func _build_walls() -> void:
	_walls = Node2D.new()
	_walls.name = "Walls"
	_world.add_child(_walls)

	# Left wall
	var left_wall := StaticBody2D.new()
	var left_col := CollisionShape2D.new()
	var left_shape := RectangleShape2D.new()
	left_shape.size = Vector2(WALL_WIDTH, 100000)
	left_col.shape = left_shape
	left_col.position = Vector2(WALL_WIDTH / 2.0, 0)
	left_wall.add_child(left_col)
	_walls.add_child(left_wall)

	# No visible wall strips — the tree trunk provides the visual boundary

	# Right wall (invisible collision only)
	var right_wall := StaticBody2D.new()
	var right_col := CollisionShape2D.new()
	var right_shape := RectangleShape2D.new()
	right_shape.size = Vector2(WALL_WIDTH, 100000)
	right_col.shape = right_shape
	right_col.position = Vector2(1280 - WALL_WIDTH / 2.0, 0)
	right_wall.add_child(right_col)
	_walls.add_child(right_wall)

func _generate_starting_floor() -> void:
	# Collision at ground level
	var floor_body := StaticBody2D.new()
	var floor_col := CollisionShape2D.new()
	var floor_shape := RectangleShape2D.new()
	floor_shape.size = Vector2(1280, GRID)
	floor_col.shape = floor_shape
	floor_col.position = Vector2(640, GRID / 2.0)
	floor_body.add_child(floor_col)
	_world.add_child(floor_body)

	# Thick ground — fills the whole bottom third of the view
	# Camera starts at player y=-64 with offset -100 → center y=-164
	# Screen bottom at y=-164+360 = y=196, so ground needs to reach y~200+
	var ground_height := 400
	var floor_vis := ColorRect.new()
	floor_vis.color = Color(0.42, 0.30, 0.16)
	floor_vis.size = Vector2(1280, ground_height)
	floor_vis.position = Vector2(0, 0)
	floor_vis.z_index = 0
	_world.add_child(floor_vis)

	# Darker earth layer below surface
	var deep_earth := ColorRect.new()
	deep_earth.color = Color(0.35, 0.24, 0.12)
	deep_earth.size = Vector2(1280, ground_height - 40)
	deep_earth.position = Vector2(0, 40)
	deep_earth.z_index = 0
	_world.add_child(deep_earth)

	# Grass strip on top
	var grass := ColorRect.new()
	grass.color = Color(0.30, 0.55, 0.20)
	grass.size = Vector2(1280, 8)
	grass.position = Vector2(0, -4)
	grass.z_index = 1
	_world.add_child(grass)

	# Trunk starts well inside the ground (hidden)
	_last_trunk_x = TRUNK_X
	_last_trunk_y = ground_height + 100
	_next_row_y = -ROW_SPACING
	# Starting floor is full width — tell the overlap checker so the first row
	# is properly placed (not forced to one corner)
	_last_plat_x = float(WALL_WIDTH)
	_last_plat_w = float(1280 - WALL_WIDTH * 2)

# ─── Procedural Generation ───

func _generate_platforms_up_to(target_y: float) -> void:
	while _next_row_y > target_y:
		# Spawn goal when we reach its height, then stop generating above it
		if _next_row_y < _target_y and not _goal_spawned:
			# Approach platform — must stick out past the goal edge so the
			# player has a clear lane to jump up without hitting the goal from below.
			# Goal is 600px wide centered at x=640, spanning x=340..940.
			var approach_y := _target_y + 140
			var approach_w := 250
			var goal_left := 340
			var goal_right := 940
			var approach_x: int
			if _staircase_left:
				# Approach sticks out past goal's LEFT edge
				approach_x = goal_left - approach_w + 60
			else:
				# Approach sticks out past goal's RIGHT edge
				approach_x = goal_right - 60
			approach_x = clampi(approach_x, WALL_WIDTH, 1280 - WALL_WIDTH - approach_w)

			# Also check approach doesn't lid the last regular branch
			var prev_l := int(_last_plat_x)
			var prev_r := int(_last_plat_x + _last_plat_w)
			if approach_x <= prev_l and approach_x + approach_w >= prev_r:
				# Lid! Shift approach so previous branch sticks out
				if _staircase_left:
					approach_x = prev_l + 80
				else:
					approach_x = prev_r - 80 - approach_w
				approach_x = clampi(approach_x, WALL_WIDTH, 1280 - WALL_WIDTH - approach_w)

			_spawn_platform(approach_x, approach_y, approach_w, _last_trunk_x)

			_spawn_goal(_target_y)
			_goal_spawned = true
			break
		_generate_row(_next_row_y)
		# Level 1: closer platforms (140px) so jumps are easy
		# Other levels: standard spacing (180px)
		var spacing := 140 if s_level == 0 else ROW_SPACING
		_next_row_y -= spacing

func _no_lid(plat_x: int, w: int) -> int:
	# Prevent the new platform from being a "lid" over the previous one.
	# If new platform covers previous on BOTH sides, the player's head hits
	# the new platform and they can't jump up. Shift so at least 80px of the
	# previous branch is exposed on one side.
	var prev_l := int(_last_plat_x)
	var prev_r := int(_last_plat_x + _last_plat_w)
	if prev_r <= prev_l:
		return plat_x  # no previous platform data
	if plat_x <= prev_l and plat_x + w >= prev_r:
		# Lid detected — shift platform
		var escape := 80
		if randf() < 0.5:
			plat_x = prev_l + escape
		else:
			plat_x = prev_r - escape - w
		plat_x = clampi(plat_x, WALL_WIDTH, 1280 - WALL_WIDTH - w)
	return plat_x

func _generate_row(y: float) -> void:
	# Trunk segment
	var new_trunk_x := clampf(
		_last_trunk_x + randf_range(-25, 25),
		TRUNK_X - 60, TRUNK_X + 60
	)
	_add_trunk_segment(_last_trunk_x, _last_trunk_y, new_trunk_x, y)
	var trunk_x_for_row := new_trunk_x
	_last_trunk_x = new_trunk_x
	_last_trunk_y = y

	var play_left := WALL_WIDTH
	var play_right := 1280 - WALL_WIDTH

	# ── Level 1: wide branches, GUARANTEED reachable, no crates needed ──
	#
	# Each row has one main branch (350-550px).
	# TWO hard rules enforced every row:
	#   1. OVERLAP: new branch overlaps previous by >= 150px (can reach it)
	#   2. NO LID: new branch must NOT cover both edges of previous branch.
	#      At least 80px of the previous branch must stick out on one side,
	#      giving the player a clear path to jump up without hitting their head.
	# 140px row spacing — well within 208px max jump height.
	#
	if s_level == 0:
		_row_count += 1

		var prev_left := int(_last_plat_x)
		var prev_right := int(_last_plat_x + _last_plat_w)

		# Width slightly smaller than before to reduce lid probability
		var w := randi_range(350, 550)

		# --- RULE 1: overlap previous by >= 150px ---
		var min_start := maxi(play_left, prev_left - w + 150)
		var max_start := mini(play_right - w, prev_right - 150)
		if min_start > max_start:
			min_start = maxi(play_left, prev_right - w)
			max_start = mini(play_right - w, prev_left)
			if min_start > max_start:
				min_start = max_start
		var plat_x := randi_range(min_start, max_start)
		plat_x = clampi(plat_x, play_left, play_right - w)

		# --- RULE 2: no lid ---
		plat_x = _no_lid(plat_x, w)

		_spawn_platform(plat_x, y, w, trunk_x_for_row)
		_last_plat_x = float(plat_x)
		_last_plat_w = float(w)

		# Cookie on most branches
		if y > _target_y + 300 and randf() < 0.70:
			_spawn_cookie(plat_x + w / 2.0, y - 30)
			cookies_available += 1

		# 40% chance of a bonus branch on the opposite side (extra cookies)
		if randf() < 0.40:
			var bw := randi_range(180, 280)
			var bx: int
			if plat_x + w / 2 > 640:
				bx = randi_range(play_left, maxi(play_left, plat_x - bw - 60))
			else:
				bx = randi_range(mini(play_right - bw, plat_x + w + 60), play_right - bw)
			bx = clampi(bx, play_left, play_right - bw)
			_spawn_platform(bx, y, bw, trunk_x_for_row)
			if y > _target_y + 300 and randf() < 0.65:
				_spawn_cookie(bx + bw / 2.0, y - 30)
				cookies_available += 1

		_staircase_left = (_last_plat_x + _last_plat_w / 2.0) > 640
		return

	# ── Level 2: requires crate use — deliberate challenge patterns ──
	#
	# Every 5th row is SKIPPED (no platforms) creating a 360px gap.
	# Max jump = 208px < 360px, so the player MUST use crates.
	# Other rows alternate between normal platforms and challenge rows
	# with long horizontal gaps, opposite-side placements, and small targets.
	#
	if s_level == 1:
		_row_count += 1
		var pattern := _row_count % 5

		if pattern == 0:
			# SKIP ROW — no platforms, creates 360px gap requiring a crate
			return

		if pattern == 2:
			# OPPOSITE SIDE — single platform on the far side from last
			var w := randi_range(160, 280)
			var x: int
			if _last_plat_x + _last_plat_w / 2.0 > 640:
				x = randi_range(play_left, play_left + 200)
			else:
				x = randi_range(play_right - w - 200, play_right - w)
			x = clampi(x, play_left, play_right - w)
			x = _no_lid(x, w)
			_spawn_platform(x, y, w, trunk_x_for_row)
			_last_plat_x = float(x)
			_last_plat_w = float(w)
			if y > _target_y + 300 and randf() < 0.6:
				_spawn_cookie(x + w / 2.0, y - 30)
				cookies_available += 1
			_staircase_left = (x + w / 2.0) > 640
			return

		if pattern == 4:
			# SMALL TARGET — tiny platform, tests precision
			var w := randi_range(100, 160)
			var x := randi_range(play_left + 150, play_right - w - 150)
			x = _no_lid(x, w)
			_spawn_platform(x, y, w, trunk_x_for_row)
			_last_plat_x = float(x)
			_last_plat_w = float(w)
			# Reward the tricky landing with a cookie
			if y > _target_y + 300:
				_spawn_cookie(x + w / 2.0, y - 30)
				cookies_available += 1
			_staircase_left = (x + w / 2.0) > 640
			return

		# NORMAL ROWS (patterns 1, 3) — 1-2 platforms, moderate difficulty
		var num := 2 if randf() < 0.35 else 1
		for i in num:
			var w := randi_range(150, 300)
			var x := randi_range(play_left, play_right - w)
			x = _no_lid(x, w)
			_spawn_platform(x, y, w, trunk_x_for_row)
			_last_plat_x = float(x)
			_last_plat_w = float(w)
			if y > _target_y + 300 and randf() < COOKIE_CHANCE:
				_spawn_cookie(x + w / 2.0, y - 30)
				cookies_available += 1
		_staircase_left = (_last_plat_x + _last_plat_w / 2.0) > 640
		return

	# Levels 3+: random platform generation with difficulty ramp
	var climb := absf(y)
	var max_plats := clampi(3 - int(climb / 5000), 1, 3)
	var num_platforms := randi_range(1, max_plats)
	var width_max := clampi(PLATFORM_MAX_W - int(climb / 20), PLATFORM_MIN_W, PLATFORM_MAX_W)

	for i in num_platforms:
		var w := randi_range(PLATFORM_MIN_W, width_max)
		var x := randi_range(play_left, play_right - w)
		x = _no_lid(x, w)
		_spawn_platform(x, y, w, trunk_x_for_row)

		# No cookies near the goal — bananas and milk are the prize
		if y > _target_y + 300 and randf() < COOKIE_CHANCE:
			_spawn_cookie(x + w / 2.0, y - 30)
			cookies_available += 1

# ─── Trunk ───

func _add_trunk_segment(x1: float, y1: float, x2: float, y2: float) -> void:
	var hw := 28.0

	var poly := Polygon2D.new()
	poly.color = Color(0.48, 0.32, 0.17)
	poly.position = Vector2(0, y1)
	poly.polygon = PackedVector2Array([
		Vector2(x1 - hw, 0),
		Vector2(x1 + hw, 0),
		Vector2(x2 + hw - 2, y2 - y1),
		Vector2(x2 - hw + 2, y2 - y1),
	])
	poly.z_index = -2
	_world.add_child(poly)

	# Bark detail stripes
	var sx := randf_range(-10, 10)
	var sw := randf_range(3, 7)
	var detail := Polygon2D.new()
	detail.color = Color(0.38, 0.24, 0.12, 0.5)
	detail.position = Vector2(0, y1)
	detail.polygon = PackedVector2Array([
		Vector2(x1 + sx - sw, 0),
		Vector2(x1 + sx + sw, 0),
		Vector2(x2 + sx + sw, y2 - y1),
		Vector2(x2 + sx - sw, y2 - y1),
	])
	detail.z_index = -2
	_world.add_child(detail)

	var sx2 := randf_range(-16, 16)
	var sw2 := randf_range(2, 5)
	var detail2 := Polygon2D.new()
	detail2.color = Color(0.42, 0.28, 0.14, 0.35)
	detail2.position = Vector2(0, y1)
	detail2.polygon = PackedVector2Array([
		Vector2(x1 + sx2 - sw2, 0),
		Vector2(x1 + sx2 + sw2, 0),
		Vector2(x2 + sx2 + sw2, y2 - y1),
		Vector2(x2 + sx2 - sw2, y2 - y1),
	])
	detail2.z_index = -2
	_world.add_child(detail2)

# ─── Platforms (branches) ───

func _spawn_platform(x: float, y: float, w: float, trunk_x: float) -> void:
	var plat := StaticBody2D.new()
	plat.name = "Platform"

	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(w, 18)
	col.shape = shape
	col.position = Vector2(w / 2.0, 9)
	plat.add_child(col)

	# Brown bark branch
	var bark := ColorRect.new()
	bark.color = Color(0.43, 0.28, 0.14)
	bark.size = Vector2(w, 14)
	bark.position = Vector2(0, 4)
	plat.add_child(bark)

	# Leafy canopy on top
	var leaves := Polygon2D.new()
	var green_r := 0.20 + randf() * 0.12
	var green_g := 0.48 + randf() * 0.16
	var green_b := 0.12 + randf() * 0.10
	leaves.color = Color(green_r, green_g, green_b)
	leaves.polygon = _make_leaf_shape(w)
	plat.add_child(leaves)

	# Extra leaf blobs
	var blobs := randi_range(2, 4)
	for b in blobs:
		var bx := randf() * w
		var blob := Polygon2D.new()
		blob.color = Color(green_r + 0.05, green_g + 0.08, green_b + 0.03)
		blob.polygon = _ellipse_points(10 + randf() * 8, 6 + randf() * 3, 8)
		blob.position = Vector2(bx, -6 - randf() * 4)
		plat.add_child(blob)

	plat.position = Vector2(x, y)
	_world.add_child(plat)

	# Tapered branch connector — lighter pastel beige-brown
	var trunk_hw := 28.0
	var trunk_left := trunk_x - trunk_hw
	var trunk_right := trunk_x + trunk_hw
	var plat_left := x
	var plat_right := x + w

	if plat_right < trunk_left:
		_draw_tapered_branch(trunk_left, plat_right, y + 8)
	elif plat_left > trunk_right:
		_draw_tapered_branch(trunk_right, plat_left, y + 8)

func _draw_tapered_branch(trunk_end_x: float, plat_end_x: float, y: float) -> void:
	var thick := 7.0
	var thin := 3.0

	var poly := Polygon2D.new()
	# Lighter pastel beige-brown — distinct from dark platform bark
	poly.color = Color(0.72, 0.58, 0.42, 0.7)
	poly.position = Vector2(0, y)
	poly.polygon = PackedVector2Array([
		Vector2(trunk_end_x, -thick),
		Vector2(plat_end_x, -thin),
		Vector2(plat_end_x, thin),
		Vector2(trunk_end_x, thick),
	])
	poly.z_index = -1
	_world.add_child(poly)

func _make_leaf_shape(w: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var bumps := maxi(int(w / 40), 3)
	var step_count := bumps * 4

	for i in range(step_count + 1):
		var t := float(i) / float(step_count)
		var lx := t * (w + 16) - 8
		var ly := -absf(sin(t * bumps * PI)) * 9 - 5
		points.append(Vector2(lx, ly))

	points.append(Vector2(w + 8, 2))
	points.append(Vector2(-8, 2))
	return points

# ─── Detailed wooden crate visual ───

func _build_crate_visual(block: Node2D) -> void:
	# Rough outer frame — slightly uneven polygon for worn look
	var frame := Polygon2D.new()
	frame.color = Color(0.45, 0.30, 0.13)
	frame.polygon = PackedVector2Array([
		Vector2(1, 2), Vector2(3, 0), Vector2(61, 1), Vector2(63, 3),
		Vector2(64, 5), Vector2(63, 61), Vector2(62, 63), Vector2(60, 64),
		Vector2(4, 63), Vector2(2, 62), Vector2(0, 59), Vector2(0, 4),
	])
	block.add_child(frame)

	# Three horizontal planks with colour variation and slight wobble
	for i in range(3):
		var plank := Polygon2D.new()
		var shade := 0.58 + randf() * 0.12
		plank.color = Color(shade, shade * 0.68, shade * 0.34)
		var py := 3 + i * 19
		var w1 := randf_range(-1.5, 1.5)
		var w2 := randf_range(-1.5, 1.5)
		plank.polygon = PackedVector2Array([
			Vector2(4 + w1, py + 1),
			Vector2(60 + w2, py),
			Vector2(60 + w2, py + 17),
			Vector2(4 + w1, py + 18),
		])
		block.add_child(plank)

		# Wood grain lines per plank (2-3 thin wavy lines)
		for g in range(randi_range(2, 3)):
			var gy := py + 4 + g * 5 + randf_range(-1, 1)
			var grain := Polygon2D.new()
			grain.color = Color(0.48, 0.30, 0.13, 0.35)
			var gw1 := randf_range(-2, 2)
			var gw2 := randf_range(-2, 2)
			grain.polygon = PackedVector2Array([
				Vector2(6, gy + gw1),
				Vector2(32, gy + gw2),
				Vector2(58, gy + gw1 * 0.5),
				Vector2(58, gy + gw1 * 0.5 + 1.5),
				Vector2(32, gy + gw2 + 1.5),
				Vector2(6, gy + gw1 + 1.5),
			])
			block.add_child(grain)

	# Plank gaps (dark lines between planks)
	for i in range(2):
		var gap := ColorRect.new()
		gap.color = Color(0.25, 0.15, 0.06, 0.6)
		gap.size = Vector2(56, 2)
		gap.position = Vector2(4, 20 + i * 19)
		block.add_child(gap)

	# Cross braces (two diagonal strips forming an X)
	var brace1 := Polygon2D.new()
	brace1.color = Color(0.50, 0.34, 0.16, 0.55)
	brace1.polygon = PackedVector2Array([
		Vector2(7, 5), Vector2(11, 3),
		Vector2(59, 57), Vector2(55, 59),
	])
	block.add_child(brace1)

	var brace2 := Polygon2D.new()
	brace2.color = Color(0.50, 0.34, 0.16, 0.55)
	brace2.polygon = PackedVector2Array([
		Vector2(53, 3), Vector2(57, 5),
		Vector2(9, 59), Vector2(5, 57),
	])
	block.add_child(brace2)

	# Rusty nails at corners and mid-edges
	var nail_spots := [
		Vector2(8, 7), Vector2(56, 7),
		Vector2(8, 57), Vector2(56, 57),
		Vector2(32, 4), Vector2(32, 60),
	]
	for np in nail_spots:
		# Rust stain (behind the nail)
		var stain := Polygon2D.new()
		stain.color = Color(0.50, 0.20, 0.08, 0.35)
		stain.polygon = _circle_points(3.5, 6)
		stain.position = np + Vector2(randf_range(-1, 1), 1.5)
		block.add_child(stain)
		# Nail head
		var nail := Polygon2D.new()
		nail.color = Color(0.45, 0.22, 0.10)
		nail.polygon = _circle_points(2.2, 6)
		nail.position = np
		block.add_child(nail)
		# Nail shine (tiny highlight)
		var shine := Polygon2D.new()
		shine.color = Color(0.65, 0.40, 0.22, 0.5)
		shine.polygon = _circle_points(0.8, 4)
		shine.position = np + Vector2(-0.5, -0.5)
		block.add_child(shine)

	# Random knot hole (60% chance)
	if randf() < 0.6:
		var kx := 18 + randf() * 28
		var ky := 14 + randf() * 32
		var knot_ring := Polygon2D.new()
		knot_ring.color = Color(0.42, 0.28, 0.12, 0.5)
		knot_ring.polygon = _ellipse_points(5.5, 4.0, 8)
		knot_ring.position = Vector2(kx, ky)
		block.add_child(knot_ring)
		var knot := Polygon2D.new()
		knot.color = Color(0.32, 0.20, 0.08)
		knot.polygon = _ellipse_points(3.5, 2.5, 8)
		knot.position = Vector2(kx, ky)
		block.add_child(knot)

# ─── Goal (bananas + warm milk at treetop) ───

func _spawn_goal(y: float) -> void:
	# Center the goal at screen center (640) so it's always reachable
	var goal_cx := 640.0
	var goal_w := 600.0  # nice wide landing platform

	# Final trunk segment up to the goal (so the tree connects)
	_add_trunk_segment(_last_trunk_x, _last_trunk_y, goal_cx, y)

	var goal := Area2D.new()
	goal.name = "Goal"
	goal.position = Vector2(goal_cx, y)
	goal.z_index = 3

	# Wide platform at the goal so you can land on it
	var goal_plat := StaticBody2D.new()
	var goal_col := CollisionShape2D.new()
	var goal_shape := RectangleShape2D.new()
	goal_shape.size = Vector2(goal_w, 20)
	goal_col.shape = goal_shape
	goal_col.position = Vector2(0, 10)
	goal_plat.add_child(goal_col)
	goal_plat.position = Vector2(goal_cx, y)

	# Big leafy platform visual
	var goal_bark := ColorRect.new()
	goal_bark.color = Color(0.43, 0.28, 0.14)
	goal_bark.size = Vector2(goal_w, 16)
	goal_bark.position = Vector2(-goal_w / 2, 4)
	goal_plat.add_child(goal_bark)
	var goal_leaves := Polygon2D.new()
	goal_leaves.color = Color(0.25, 0.55, 0.18)
	goal_leaves.polygon = _make_leaf_shape(goal_w)
	goal_leaves.position = Vector2(-goal_w / 2, 0)
	goal_plat.add_child(goal_leaves)
	_world.add_child(goal_plat)

	# ── Treetop crown — big leafy canopy above the goal to cap the tree ──
	var crown := Polygon2D.new()
	crown.color = Color(0.22, 0.52, 0.15)
	var crown_pts := PackedVector2Array()
	var crown_r := 120.0
	var crown_bumps := 8
	for seg in range(crown_bumps * 3 + 1):
		var t := float(seg) / float(crown_bumps * 3)
		var a := PI + t * PI  # top semicircle only
		var bump := absf(sin(t * crown_bumps * PI)) * 18
		crown_pts.append(Vector2(
			cos(a) * (crown_r + bump),
			sin(a) * (crown_r * 0.7 + bump) - 60
		))
	crown_pts.append(Vector2(crown_r + 10, -60))
	crown_pts.append(Vector2(-crown_r - 10, -60))
	crown.polygon = crown_pts
	crown.z_index = -1
	goal.add_child(crown)

	# Extra leaf blobs on the crown
	for i in range(6):
		var blob := Polygon2D.new()
		blob.color = Color(0.18 + randf() * 0.1, 0.48 + randf() * 0.12, 0.12 + randf() * 0.08)
		blob.polygon = _ellipse_points(18 + randf() * 14, 10 + randf() * 6, 10)
		blob.position = Vector2(randf_range(-90, 90), -70 - randf() * 50)
		blob.z_index = -1
		goal.add_child(blob)

	# ── Banana bunch image (left side) ──
	var prize_y := -50.0
	var banana_tex: Texture2D = load("res://assets/banana_bunch.png")
	if banana_tex:
		var banana_img := Sprite2D.new()
		banana_img.texture = banana_tex
		banana_img.scale = Vector2(0.15, 0.15)  # 600x455 → ~90x68
		banana_img.position = Vector2(-50, prize_y + 10)
		goal.add_child(banana_img)

	# ── Glass of warm milk (right side) ──
	var milk_x := 45.0

	# Glass body — tapered trapezoid (wider at top)
	var glass := Polygon2D.new()
	glass.color = Color(0.78, 0.85, 0.92, 0.35)  # transparent glass
	glass.polygon = PackedVector2Array([
		Vector2(milk_x - 14, prize_y - 5),   # top-left
		Vector2(milk_x + 14, prize_y - 5),   # top-right
		Vector2(milk_x + 11, prize_y + 30),  # bottom-right
		Vector2(milk_x - 11, prize_y + 30),  # bottom-left
	])
	goal.add_child(glass)

	# Milk inside — warm creamy white
	var milk := Polygon2D.new()
	milk.color = Color(0.98, 0.95, 0.88, 0.9)
	milk.polygon = PackedVector2Array([
		Vector2(milk_x - 13, prize_y),     # milk surface left
		Vector2(milk_x + 13, prize_y),     # milk surface right
		Vector2(milk_x + 10, prize_y + 28), # bottom-right
		Vector2(milk_x - 10, prize_y + 28), # bottom-left
	])
	goal.add_child(milk)

	# Glass rim highlight
	var rim := Polygon2D.new()
	rim.color = Color(1.0, 1.0, 1.0, 0.5)
	rim.polygon = PackedVector2Array([
		Vector2(milk_x - 15, prize_y - 7),
		Vector2(milk_x + 15, prize_y - 7),
		Vector2(milk_x + 14, prize_y - 4),
		Vector2(milk_x - 14, prize_y - 4),
	])
	goal.add_child(rim)

	# Glass shine streak (vertical highlight)
	var shine := Polygon2D.new()
	shine.color = Color(1.0, 1.0, 1.0, 0.25)
	shine.polygon = PackedVector2Array([
		Vector2(milk_x + 7, prize_y - 3),
		Vector2(milk_x + 10, prize_y - 3),
		Vector2(milk_x + 8, prize_y + 25),
		Vector2(milk_x + 5, prize_y + 25),
	])
	goal.add_child(shine)

	# Steam wisps above the milk (three curvy lines)
	for s in range(3):
		var sx := milk_x - 8 + s * 8
		var wisp := Polygon2D.new()
		wisp.color = Color(1.0, 1.0, 1.0, 0.2 + randf() * 0.1)
		var wo := randf_range(-3, 3)
		wisp.polygon = PackedVector2Array([
			Vector2(sx, prize_y - 8),
			Vector2(sx + 2, prize_y - 8),
			Vector2(sx + 3 + wo, prize_y - 16),
			Vector2(sx + 1 + wo, prize_y - 20),
			Vector2(sx - 1 + wo, prize_y - 20),
			Vector2(sx + wo, prize_y - 16),
		])
		goal.add_child(wisp)

	# Glow effect behind both prizes
	var glow := Polygon2D.new()
	glow.color = Color(1.0, 0.95, 0.7, 0.2)
	glow.polygon = _ellipse_points(55.0, 35.0, 16)
	glow.position = Vector2(0, prize_y + 10)
	glow.z_index = -1
	goal.add_child(glow)

	# Goal collision — thin strip at the platform surface (y=0 to y=10)
	# Player must actually land on the platform to trigger level complete
	var area_col := CollisionShape2D.new()
	var area_shape := RectangleShape2D.new()
	area_shape.size = Vector2(goal_w - 100, 20)
	area_col.shape = area_shape
	area_col.position = Vector2(0, -5)
	goal.add_child(area_col)
	goal.body_entered.connect(_on_goal_reached)

	_world.add_child(goal)

# ─── Playable Tutorial Mini-Level ───

func _build_tutorial_level() -> void:
	# TWO-STAGE TUTORIAL on a full-width ground floor (can't fall off!)
	#
	# STAGE 1: Place crate on ground → jump to Branch 1 (right side)
	#   Ground floor y=-64. Branch 1 y=-300 (236px up).
	#   Max jump 208 < 236 → needs crate. With crate (top at -128): reach -336 > -300 ✓
	#
	# STAGE 2: From Branch 1, jump + place crate MID-AIR → land on it → jump to Branch 2
	#   Branch 1 y=-300. Branch 2 y=-620 (320px above Branch 1).
	#   Ground crate on Branch 1: crate at -384, reach -592. Can't reach -620 (28px short) ✗
	#   Mid-air crate: crate ~-448, reach -656. Clears -620 ✓ — forces mid-air placement
	#
	# LAYOUT (1280x720):
	#   Ground floor: full width, y=-64
	#   Branch 1: x=750..1100 (w=350), y=-300 — right side
	#   Branch 2: x=100..450 (w=350), y=-620 — left side, flag here

	_build_world()

	# Ground visuals
	var ground_vis := ColorRect.new()
	ground_vis.color = Color(0.42, 0.30, 0.16)
	ground_vis.size = Vector2(1280, 400)
	ground_vis.position = Vector2(0, 0)
	_world.add_child(ground_vis)
	var deep := ColorRect.new()
	deep.color = Color(0.35, 0.24, 0.12)
	deep.size = Vector2(1280, 360)
	deep.position = Vector2(0, 40)
	_world.add_child(deep)
	var grass := ColorRect.new()
	grass.color = Color(0.30, 0.55, 0.20)
	grass.size = Vector2(1280, 8)
	grass.position = Vector2(0, -4)
	grass.z_index = 1
	_world.add_child(grass)

	# Full-width ground floor collision
	var floor_y := -GRID  # y = -64
	var floor_body := StaticBody2D.new()
	var floor_col := CollisionShape2D.new()
	var floor_shape := RectangleShape2D.new()
	floor_shape.size = Vector2(1280, 18)
	floor_col.shape = floor_shape
	floor_col.position = Vector2(640, 9)
	floor_body.add_child(floor_col)
	floor_body.position = Vector2(0, floor_y)
	_world.add_child(floor_body)
	var floor_bark := ColorRect.new()
	floor_bark.color = Color(0.43, 0.28, 0.14)
	floor_bark.size = Vector2(1280, 14)
	floor_bark.position = Vector2(0, floor_y + 4)
	_world.add_child(floor_bark)
	var floor_leaves := Polygon2D.new()
	floor_leaves.color = Color(0.24, 0.52, 0.16)
	floor_leaves.polygon = _make_leaf_shape(1280.0)
	floor_leaves.position = Vector2(0, floor_y)
	_world.add_child(floor_leaves)

	# Branch 1 (stage 1 target) — right side, 236px above ground
	var b1_y := -300
	var b1_x := 750
	var b1_w := 350
	_spawn_tutorial_platform(b1_x, b1_y, b1_w)

	# Branch 2 (stage 2 target) — left side, 320px above Branch 1 (forces mid-air crate)
	var b2_y := -620
	var b2_x := 100
	var b2_w := 350
	_spawn_tutorial_platform(b2_x, b2_y, b2_w)

	# Walls
	_build_walls()

	# HUD
	_build_hud()

	# Player — starts on the left side of ground
	player = CookiePlayer.new()
	player.position = Vector2(200, floor_y - 10)
	player.z_index = 2
	start_y = player.position.y
	highest_y = start_y
	_world.add_child(player)
	player.block_placed.connect(_on_block_placed)
	player.blocks_changed.connect(_on_blocks_changed)
	player.reset_blocks()  # 5 crates
	player.set_physics_process(true)

	# Camera — smooth follow with room for both branches
	camera = Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 5.0
	player.add_child(camera)
	camera.offset = Vector2(0, -100)
	camera.limit_top = int(b2_y - 350)
	camera.limit_bottom = int(floor_y + 300)

	# Stage 1 trigger on Branch 1 — switches hint to stage 2
	var trigger1 := Area2D.new()
	trigger1.name = "Stage1Trigger"
	trigger1.position = Vector2(b1_x + b1_w / 2.0, b1_y - 20)
	var t1_col := CollisionShape2D.new()
	var t1_shape := RectangleShape2D.new()
	t1_shape.size = Vector2(float(b1_w) - 40, 50)
	t1_col.shape = t1_shape
	trigger1.add_child(t1_col)
	trigger1.body_entered.connect(_on_tutorial_stage1)
	_world.add_child(trigger1)

	# Stage 2 trigger on Branch 2 — completes tutorial
	var trigger2 := Area2D.new()
	trigger2.name = "TutorialTrigger"
	trigger2.position = Vector2(b2_x + b2_w / 2.0, b2_y - 20)
	var t2_col := CollisionShape2D.new()
	var t2_shape := RectangleShape2D.new()
	t2_shape.size = Vector2(float(b2_w) - 40, 50)
	t2_col.shape = t2_shape
	trigger2.add_child(t2_col)
	trigger2.body_entered.connect(_on_tutorial_complete)
	_world.add_child(trigger2)

	# Green flag on Branch 2
	var flag_x := b2_x + b2_w / 2.0
	var flag_pole := ColorRect.new()
	flag_pole.color = Color(0.35, 0.25, 0.10)
	flag_pole.size = Vector2(4, 50)
	flag_pole.position = Vector2(flag_x - 2, b2_y - 54)
	_world.add_child(flag_pole)
	var flag := Polygon2D.new()
	flag.color = Color(0.2, 0.85, 0.3)
	flag.polygon = PackedVector2Array([
		Vector2(flag_x, b2_y - 54),
		Vector2(flag_x + 40, b2_y - 42),
		Vector2(flag_x, b2_y - 30),
	])
	_world.add_child(flag)

	# Yellow arrow near Branch 1 — shows where to build for stage 1
	var arrow_x := float(b1_x) + 30.0
	var arrow := Polygon2D.new()
	arrow.color = Color(1.0, 0.88, 0.15, 0.8)
	arrow.polygon = PackedVector2Array([
		Vector2(arrow_x, floor_y - 80),
		Vector2(arrow_x - 15, floor_y - 50),
		Vector2(arrow_x + 15, floor_y - 50),
	])
	_world.add_child(arrow)

	# Show tutorial intro screen first (like level intros)
	hud.show_tutorial_intro()
	player.set_physics_process(false)  # freeze player until space pressed

	state = State.TUTORIAL_INTRO

func _spawn_tutorial_platform(x: float, y: float, w: float) -> void:
	var plat := StaticBody2D.new()
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(w, 18)
	col.shape = shape
	col.position = Vector2(w / 2.0, 9)
	plat.add_child(col)

	# Brown bark branch visual
	var bark := ColorRect.new()
	bark.color = Color(0.43, 0.28, 0.14)
	bark.size = Vector2(w, 14)
	bark.position = Vector2(0, 4)
	plat.add_child(bark)

	# Leaves on top
	var leaves := Polygon2D.new()
	leaves.color = Color(0.24, 0.52, 0.16)
	leaves.polygon = _make_leaf_shape(w)
	plat.add_child(leaves)

	plat.position = Vector2(x, y)
	_world.add_child(plat)

func _on_tutorial_stage1(body: Node2D) -> void:
	if body is CookiePlayer and state == State.TUTORIAL:
		hud.show_tutorial_stage2()

func _on_tutorial_complete(body: Node2D) -> void:
	if body is CookiePlayer and state == State.TUTORIAL:
		player.set_physics_process(false)
		s_tutorial = false
		# Brief celebration then load level 2
		hud.show_tutorial_complete()
		await get_tree().create_timer(1.5).timeout
		get_tree().reload_current_scene()

func _on_goal_reached(body: Node2D) -> void:
	if body is CookiePlayer and state == State.PLAYING:
		_level_complete()

# ─── Cookies ───

func _spawn_cookie(x: float, y: float) -> void:
	var cookie := CookieCrunchCookie.new()
	cookie.position = Vector2(x, y)
	cookie.collected.connect(_on_cookie_collected)
	_world.add_child(cookie)

# ─── Placed blocks (wooden crates) ───

func _on_block_placed(grid_pos: Vector2i) -> void:
	if _placed_blocks.has(grid_pos):
		player.add_blocks(1)
		return

	var world_x := grid_pos.x * GRID
	if world_x < WALL_WIDTH or world_x + GRID > 1280 - WALL_WIDTH:
		player.add_blocks(1)
		return

	var block := StaticBody2D.new()
	block.name = "Block"

	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(60, 60)
	col.shape = shape
	col.position = Vector2(GRID / 2.0, GRID / 2.0)
	col.one_way_collision = true  # can jump through from below, land on top
	block.add_child(col)

	_build_crate_visual(block)

	block.position = Vector2(world_x, grid_pos.y * GRID)
	_world.add_child(block)
	_placed_blocks[grid_pos] = block

func _on_blocks_changed(count: int) -> void:
	hud.update_blocks(count)

func _on_cookie_collected() -> void:
	cookie_score += 1
	player.add_blocks(2)
	hud.update_cookies(cookie_score)

# ─── Main Loop ───

func _input(event: InputEvent) -> void:
	# Track screen taps for mobile menu navigation
	if event is InputEventScreenTouch and event.pressed:
		_screen_tapped = true

func _process(delta: float) -> void:
	var tapped := _screen_tapped
	_screen_tapped = false

	match state:
		State.TITLE:
			if Input.is_action_just_pressed("jump") or tapped:
				_show_level_intro()
			if Input.is_action_just_pressed("quit"):
				get_tree().quit()

		State.LEVEL_INTRO:
			if Input.is_action_just_pressed("jump") or tapped:
				_start_playing()
			if Input.is_action_just_pressed("quit"):
				get_tree().quit()

		State.TUTORIAL_INTRO:
			if Input.is_action_just_pressed("jump") or tapped:
				hud.hide_tutorial_intro()
				hud.show_tutorial_hint()
				player.set_physics_process(true)
				state = State.TUTORIAL
			if Input.is_action_just_pressed("quit"):
				get_tree().quit()

		State.TUTORIAL:
			# Player physics are active — they can move, jump, place crates freely
			if Input.is_action_just_pressed("quit"):
				get_tree().quit()

		State.PLAYING:
			_process_playing(delta)

		State.LEVEL_COMPLETE:
			if Input.is_action_just_pressed("jump") or tapped:
				_next_level()
			if Input.is_action_just_pressed("quit"):
				get_tree().quit()

		State.VICTORY:
			_update_victory_bananas(delta)
			if Input.is_action_just_pressed("jump") or tapped:
				s_level = 0
				get_tree().reload_current_scene()
			if Input.is_action_just_pressed("quit"):
				get_tree().quit()

		State.GAME_OVER:
			if Input.is_action_just_pressed("jump") or tapped:
				# Replay current level (not back to Level 1)
				get_tree().reload_current_scene()
			if Input.is_action_just_pressed("quit"):
				get_tree().quit()
			if danger_active:
				_update_wave(delta)

func _process_playing(delta: float) -> void:
	if Input.is_action_just_pressed("quit"):
		get_tree().quit()

	time_since_start += delta

	# Track highest point
	if player.position.y < highest_y:
		highest_y = player.position.y

	var level_data: Array = LEVELS[s_level]
	var target_m: int = level_data[1]
	var height_m := int(absf(highest_y - start_y) / GRID)
	hud.update_height(height_m, target_m)

	camera.limit_bottom = int(start_y + 400)

	# Generate more
	var cam_top := camera.get_screen_center_position().y - 400
	_generate_platforms_up_to(cam_top - _generate_ahead)

	# Rising water
	if danger_active:
		var base_speed: float = level_data[2]
		var ramp: float = level_data[3]
		danger_speed = base_speed + (time_since_start / 30.0) * ramp
		danger_y -= danger_speed * delta
		danger_rect.position.y = danger_y

		if player.position.y > danger_y + 10:
			_game_over()

		_update_wave(delta)

	# Coconut drops (level 3 onwards)
	var has_coconuts: bool = level_data[5]
	if has_coconuts:
		_coconut_timer -= delta
		if _coconut_timer <= 0.0:
			_spawn_coconut()
			_coconut_timer = randf_range(1.5, 3.0)

	_cleanup_below(danger_y + CLEANUP_DISTANCE)

func _update_wave(delta: float) -> void:
	_wave_time += delta * 2.0
	var w := 1280.0
	var wave_h := 10.0
	var wave_len := 100.0
	var step := 15.0

	var wave_pts := PackedVector2Array()
	var x := 0.0
	while x <= w:
		var wy := sin(x / wave_len * TAU + _wave_time) * wave_h - 5
		wave_pts.append(Vector2(x, wy))
		x += step
	wave_pts.append(Vector2(w, 30))
	wave_pts.append(Vector2(0, 30))
	_wave_poly.polygon = wave_pts

	var foam_pts := PackedVector2Array()
	x = 0.0
	while x <= w:
		var fy := sin(x / wave_len * TAU + _wave_time) * wave_h - 7
		foam_pts.append(Vector2(x, fy))
		x += step
	x = w
	while x >= 0:
		var fy := sin(x / wave_len * TAU + _wave_time) * wave_h - 3
		foam_pts.append(Vector2(x, fy))
		x -= step
	_foam_poly.polygon = foam_pts

# ─── State Changes ───

func _show_level_intro() -> void:
	state = State.LEVEL_INTRO
	hud.hide_title()
	var level_data: Array = LEVELS[s_level]
	hud.show_level_intro(s_level + 1, level_data[0], level_data[1], level_data[4])

func _start_playing() -> void:
	state = State.PLAYING
	hud.hide_level_intro()
	if s_level == 0:
		# Level 1: no crates — player doesn't know about them yet
		hud.set_crates_visible(false)
		touch_controls.set_crate_visible(false)
		player.block_count = 0  # can't place any
	else:
		hud.set_crates_visible(true)
		touch_controls.set_crate_visible(true)
		hud.show_controls_hint()
	player.set_physics_process(true)
	time_since_start = 0.0
	danger_active = true
	danger_y = start_y + 250
	danger_rect.position.y = danger_y

func _level_complete() -> void:
	player.set_physics_process(false)
	var is_final := (s_level >= LEVELS.size() - 1)
	if is_final:
		state = State.VICTORY
		hud.show_victory(cookie_score, cookies_available)
		_spawn_victory_bananas()
	else:
		state = State.LEVEL_COMPLETE
		var height_m := int(absf(highest_y - start_y) / GRID)
		hud.show_level_complete(cookie_score, cookies_available, height_m, false)

func _next_level() -> void:
	if s_level >= LEVELS.size() - 1:
		s_level = 0
		get_tree().reload_current_scene()
		return
	# Playable tutorial before level 2 (first level that needs crates)
	if s_level == 0:
		s_level = 1
		s_tutorial = true
		get_tree().reload_current_scene()
		return
	s_level += 1
	get_tree().reload_current_scene()

func _game_over() -> void:
	state = State.GAME_OVER
	player.set_physics_process(false)
	var height_m := int(absf(highest_y - start_y) / GRID)
	hud.show_game_over(cookie_score, cookies_available, height_m)

# ─── Victory celebration ───

func _spawn_victory_bananas() -> void:
	var banana_tex: Texture2D = load("res://assets/banana_bunch.png")
	if not banana_tex:
		return
	# Spawn 12 bananas at random x positions above the screen
	for i in range(12):
		var b := TextureRect.new()
		b.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		b.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		b.texture = banana_tex
		var sz := randf_range(50, 90)
		b.custom_minimum_size = Vector2(sz, sz)
		b.size = Vector2(sz, sz)
		b.position = Vector2(randf_range(40, 1200), randf_range(-800, -100))
		b.pivot_offset = Vector2(sz / 2, sz / 2)
		b.z_index = 45  # behind the victory overlay text (z=50) but above the game
		hud.add_child(b)
		# Store banana + its fall speed and spin speed
		_victory_bananas.append({
			"node": b,
			"speed": randf_range(80, 180),
			"spin": randf_range(-2.5, 2.5),
		})

func _update_victory_bananas(delta: float) -> void:
	for data in _victory_bananas:
		var b: TextureRect = data["node"]
		if not is_instance_valid(b):
			continue
		b.position.y += data["speed"] * delta
		b.rotation += data["spin"] * delta
		# Loop back to top when off screen
		if b.position.y > 780:
			b.position.y = randf_range(-150, -50)
			b.position.x = randf_range(40, 1200)

# ─── Coconut drops ───

func _spawn_coconut() -> void:
	var cam_center := camera.get_screen_center_position()
	var coconut := CookieCoconut.new()
	# Spawn well above the visible screen — falls all the way through
	var spawn_x := randf_range(WALL_WIDTH + 30, 1280 - WALL_WIDTH - 30)
	coconut.position = Vector2(spawn_x, cam_center.y - 600)
	_world.add_child(coconut)

func _cleanup_below(y_threshold: float) -> void:
	for child in _world.get_children():
		if child == player or child == danger_rect or child == _walls:
			continue
		if child.position.y > y_threshold:
			if child.name == "Block":
				var gx := int(child.position.x / GRID)
				var gy := int(child.position.y / GRID)
				_placed_blocks.erase(Vector2i(gx, gy))
			child.queue_free()

# ─── Helpers ───

func _ellipse_points(rx: float, ry: float, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in segments:
		var angle := TAU * i / segments
		points.append(Vector2(cos(angle) * rx, sin(angle) * ry))
	return points

func _circle_points(radius: float, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in segments:
		var angle := TAU * i / segments
		points.append(Vector2(cos(angle) * radius, sin(angle) * radius))
	return points
