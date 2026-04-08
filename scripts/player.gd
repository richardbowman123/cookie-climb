class_name CookiePlayer
extends CharacterBody2D

signal block_placed(grid_pos: Vector2i)
signal blocks_changed(count: int)

const SPEED := 300.0
const JUMP_VELOCITY := -500.0
const JUMP_CUT := 0.45  # multiply velocity when jump released early → ~half-height hop
const GRAVITY := 600.0
const GRID_SIZE := 64
const START_BLOCKS := 5
const MAX_BLOCKS := 15

var block_count: int = START_BLOCKS
var facing_right: bool = true
var _can_place := true
var _mouth_bg: Polygon2D
var _mouth_pink: Polygon2D
var _stunned: bool = false
var _stun_timer: float = 0.0
var _flash_timer: float = 0.0
var _stun_vfx: Array = []

# Mouth shapes
var _mouth_closed := PackedVector2Array([
	Vector2(-4, -33), Vector2(4, -33),
	Vector2(3, -32), Vector2(-3, -32),
])
var _mouth_open := PackedVector2Array([
	Vector2(-7, -36), Vector2(0, -37),
	Vector2(7, -36), Vector2(7, -30),
	Vector2(0, -28), Vector2(-7, -30),
])
var _mouth_open_inner := PackedVector2Array([
	Vector2(-5, -35), Vector2(0, -36),
	Vector2(5, -35), Vector2(5, -31),
	Vector2(0, -29), Vector2(-5, -31),
])

func _ready() -> void:
	_build_visual()
	blocks_changed.emit(block_count)

func _build_visual() -> void:
	var fur := Color(0.55, 0.33, 0.15)
	var light_tan := Color(0.82, 0.65, 0.42)
	var face_tan := Color(0.78, 0.60, 0.38)
	var ear_pink := Color(0.82, 0.52, 0.48)
	var foot_brown := Color(0.40, 0.22, 0.10)

	# --- Tail (behind everything) ---
	var tail := Polygon2D.new()
	tail.color = Color(0.52, 0.32, 0.14)
	tail.polygon = PackedVector2Array([
		Vector2(12, -6), Vector2(17, -12),
		Vector2(24, -20), Vector2(28, -26),
		Vector2(26, -28), Vector2(22, -22),
		Vector2(16, -14), Vector2(10, -8),
	])
	add_child(tail)

	# --- Legs (behind body) ---
	var left_leg := Polygon2D.new()
	left_leg.color = fur
	left_leg.polygon = PackedVector2Array([
		Vector2(-9, -5), Vector2(-4, -5),
		Vector2(-3, 2), Vector2(-10, 2),
	])
	add_child(left_leg)

	var right_leg := Polygon2D.new()
	right_leg.color = fur
	right_leg.polygon = PackedVector2Array([
		Vector2(4, -5), Vector2(9, -5),
		Vector2(10, 2), Vector2(3, 2),
	])
	add_child(right_leg)

	# Feet (darker brown ovals)
	var left_foot := Polygon2D.new()
	left_foot.color = foot_brown
	left_foot.polygon = _ellipse_points(6.0, 3.5, 8)
	left_foot.position = Vector2(-6, 3)
	add_child(left_foot)

	var right_foot := Polygon2D.new()
	right_foot.color = foot_brown
	right_foot.polygon = _ellipse_points(6.0, 3.5, 8)
	right_foot.position = Vector2(6, 3)
	add_child(right_foot)

	# --- Body (main oval) ---
	var body := Polygon2D.new()
	body.color = fur
	body.polygon = _ellipse_points(16.0, 20.0, 16)
	body.position = Vector2(0, -20)
	add_child(body)

	# --- Arms ---
	var left_arm := Polygon2D.new()
	left_arm.color = fur
	left_arm.polygon = PackedVector2Array([
		Vector2(-15, -30), Vector2(-20, -27),
		Vector2(-22, -19), Vector2(-20, -14),
		Vector2(-15, -16),
	])
	add_child(left_arm)

	var right_arm := Polygon2D.new()
	right_arm.color = fur
	right_arm.polygon = PackedVector2Array([
		Vector2(15, -30), Vector2(20, -27),
		Vector2(22, -19), Vector2(20, -14),
		Vector2(15, -16),
	])
	add_child(right_arm)

	# --- Tummy ---
	var tummy := Polygon2D.new()
	tummy.color = light_tan
	tummy.polygon = _ellipse_points(10.0, 13.0, 12)
	tummy.position = Vector2(0, -18)
	add_child(tummy)

	# --- Head ---
	var head := Polygon2D.new()
	head.color = fur
	head.polygon = _circle_points(16.0, 16)
	head.position = Vector2(0, -42)
	add_child(head)

	# --- Ears ---
	var left_ear := Polygon2D.new()
	left_ear.color = fur
	left_ear.polygon = _circle_points(8.0, 10)
	left_ear.position = Vector2(-19, -46)
	add_child(left_ear)

	var left_inner := Polygon2D.new()
	left_inner.color = ear_pink
	left_inner.polygon = _circle_points(4.5, 8)
	left_inner.position = Vector2(-19, -46)
	add_child(left_inner)

	var right_ear := Polygon2D.new()
	right_ear.color = fur
	right_ear.polygon = _circle_points(8.0, 10)
	right_ear.position = Vector2(19, -46)
	add_child(right_ear)

	var right_inner := Polygon2D.new()
	right_inner.color = ear_pink
	right_inner.polygon = _circle_points(4.5, 8)
	right_inner.position = Vector2(19, -46)
	add_child(right_inner)

	# --- Face patch ---
	var face := Polygon2D.new()
	face.color = face_tan
	face.polygon = _circle_points(12.0, 12)
	face.position = Vector2(0, -40)
	add_child(face)

	# --- Eyes ---
	var left_eye := Polygon2D.new()
	left_eye.color = Color.WHITE
	left_eye.polygon = _circle_points(4.5, 10)
	left_eye.position = Vector2(-6, -44)
	add_child(left_eye)

	var right_eye := Polygon2D.new()
	right_eye.color = Color.WHITE
	right_eye.polygon = _circle_points(4.5, 10)
	right_eye.position = Vector2(6, -44)
	add_child(right_eye)

	var left_pupil := Polygon2D.new()
	left_pupil.color = Color(0.1, 0.05, 0.0)
	left_pupil.polygon = _circle_points(2.5, 8)
	left_pupil.position = Vector2(-6, -43)
	add_child(left_pupil)

	var right_pupil := Polygon2D.new()
	right_pupil.color = Color(0.1, 0.05, 0.0)
	right_pupil.polygon = _circle_points(2.5, 8)
	right_pupil.position = Vector2(6, -43)
	add_child(right_pupil)

	# --- Nose ---
	var nose := Polygon2D.new()
	nose.color = Color(0.3, 0.18, 0.1)
	nose.polygon = _ellipse_points(3.0, 2.5, 8)
	nose.position = Vector2(0, -38)
	add_child(nose)

	# --- Mouth (two layers: dark outline + pink interior) ---
	_mouth_bg = Polygon2D.new()
	_mouth_bg.color = Color(0.25, 0.12, 0.06)
	_mouth_bg.polygon = _mouth_closed
	add_child(_mouth_bg)

	_mouth_pink = Polygon2D.new()
	_mouth_pink.color = Color(0.88, 0.45, 0.52)
	_mouth_pink.polygon = _mouth_open_inner
	_mouth_pink.visible = false
	add_child(_mouth_pink)

	# --- Collision ---
	var col := CollisionShape2D.new()
	var shape := CapsuleShape2D.new()
	shape.radius = 14.0
	shape.height = 50.0
	col.shape = shape
	col.position = Vector2(0, -26)
	add_child(col)

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

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta

	# Stun — no player control, drift left/right, wobble, flash
	if _stunned:
		_stun_timer -= delta
		_flash_timer += delta * 10.0
		# Drift left and right — increases chance of falling off branches
		velocity.x = sin(_flash_timer * 3.0) * 180.0
		move_and_slide()
		# Flash between transparent and normal
		modulate.a = 0.35 + absf(sin(_flash_timer)) * 0.65
		# Wobble tilt
		rotation = sin(_flash_timer * 2.5) * 0.35
		# Orbit X's and Z's around head
		for idx in _stun_vfx.size():
			var vfx: Label = _stun_vfx[idx]
			if is_instance_valid(vfx):
				var a := _flash_timer * 2.5 + TAU * idx / _stun_vfx.size()
				vfx.position = Vector2(cos(a) * 28, sin(a) * 14 - 55)
		if _stun_timer <= 0.0:
			_stunned = false
			modulate.a = 1.0
			rotation = 0.0
			_clear_stun_vfx()
		return

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Variable jump: release early = short hop, hold = full jump
	if Input.is_action_just_released("jump") and velocity.y < 0:
		velocity.y *= JUMP_CUT

	var direction := 0.0
	if Input.is_action_pressed("move_left"):
		direction -= 1.0
	if Input.is_action_pressed("move_right"):
		direction += 1.0

	if direction != 0.0:
		velocity.x = direction * SPEED
		facing_right = direction > 0
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED * 0.3)

	move_and_slide()

	# Mouth — pink open when airborne, closed line when grounded
	if _mouth_bg:
		if is_on_floor():
			_mouth_bg.polygon = _mouth_closed
			_mouth_pink.visible = false
		else:
			_mouth_bg.polygon = _mouth_open
			_mouth_pink.visible = true

	if Input.is_action_just_pressed("place_block"):
		_try_place_block()
	if Input.is_action_just_released("place_block"):
		_can_place = true

func stun(duration: float) -> void:
	_stunned = true
	_stun_timer = duration
	_flash_timer = 0.0
	_spawn_stun_vfx()

func _spawn_stun_vfx() -> void:
	_clear_stun_vfx()
	var symbols := ["X", "Z", "X", "Z"]
	for i in range(4):
		var lbl := Label.new()
		lbl.text = symbols[i]
		lbl.add_theme_font_size_override("font_size", 18)
		lbl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.2))
		lbl.add_theme_constant_override("outline_size", 2)
		lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
		var angle := TAU * i / 4.0
		lbl.position = Vector2(cos(angle) * 28, sin(angle) * 14 - 55)
		add_child(lbl)
		_stun_vfx.append(lbl)

func _clear_stun_vfx() -> void:
	for vfx in _stun_vfx:
		if is_instance_valid(vfx):
			vfx.queue_free()
	_stun_vfx.clear()

func _try_place_block() -> void:
	if not _can_place or block_count <= 0:
		return
	_can_place = false

	var player_grid_x := int(floor(global_position.x / GRID_SIZE))
	var target_x := player_grid_x + (1 if facing_right else -1)

	var target_y: int
	if is_on_floor():
		# On ground: crate one cell ABOVE feet — creates a step to jump onto
		target_y = int(floor(global_position.y / GRID_SIZE)) - 1
	else:
		# In air: crate at foot level — a platform to land on
		target_y = int(floor((global_position.y + 10.0) / GRID_SIZE))

	block_count -= 1
	blocks_changed.emit(block_count)
	block_placed.emit(Vector2i(target_x, target_y))

func add_blocks(amount: int) -> void:
	block_count = mini(block_count + amount, MAX_BLOCKS)
	blocks_changed.emit(block_count)

func reset_blocks() -> void:
	block_count = START_BLOCKS
	blocks_changed.emit(block_count)
