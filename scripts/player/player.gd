# Old 3D player — no longer used
extends CharacterBody3D

## Grid-based player movement with smooth sliding and jumping.
## WASD / arrow keys to move. Space to jump.
## Camera-relative: at 45° camera, each key maps to a diagonal on the grid.
## Wall-sliding: if a diagonal hits the edge, the player slides along it.

const MOVE_SPEED := 5.0
const JUMP_VELOCITY := 7.0
const GRAVITY := 18.0
const GRID_SIZE := 8
const TILE_SIZE := 1.0
const PLAYER_HALF_HEIGHT := 0.45

var _target_pos := Vector3.ZERO
var _is_moving := false
var _grid_x := 0
var _grid_z := 0

# Set by GameManager
var camera_pivot: Node3D
var game_manager: Node3D

func _ready() -> void:
	_target_pos = position
	_grid_x = 0
	_grid_z = 0

func _physics_process(delta: float) -> void:
	# Gravity — keep a small downward push when on floor to prevent
	# is_on_floor() flickering (Godot needs contact each frame)
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = -0.5

	# Jump
	if is_on_floor() and Input.is_action_just_pressed("ui_accept"):
		velocity.y = JUMP_VELOCITY

	# Grid movement — only start a new move when not already sliding
	if not _is_moving:
		var dir := _get_camera_relative_input()
		if dir != Vector2i.ZERO:
			_try_move(dir)

	# Smooth slide toward target
	if _is_moving:
		var current_xz := Vector2(position.x, position.z)
		var target_xz := Vector2(_target_pos.x, _target_pos.z)
		var dist := current_xz.distance_to(target_xz)

		if dist < 0.05:
			position.x = _target_pos.x
			position.z = _target_pos.z
			_is_moving = false
			velocity.x = 0
			velocity.z = 0
		else:
			var move_dir := (target_xz - current_xz).normalized()
			velocity.x = move_dir.x * MOVE_SPEED
			velocity.z = move_dir.y * MOVE_SPEED

	move_and_slide()

func _get_camera_relative_input() -> Vector2i:
	var raw := Vector2.ZERO
	if Input.is_action_pressed("ui_up") or Input.is_key_pressed(KEY_W):
		raw.y -= 1
	if Input.is_action_pressed("ui_down") or Input.is_key_pressed(KEY_S):
		raw.y += 1
	if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A):
		raw.x -= 1
	if Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D):
		raw.x += 1

	if raw == Vector2.ZERO:
		return Vector2i.ZERO

	var yaw := 0.0
	if camera_pivot:
		yaw = camera_pivot.rotation.y
	var rotated := raw.rotated(-yaw)

	# Allow diagonals — both axes contribute if above threshold.
	# At 45° camera, single keys produce diagonals (correct for isometric view).
	# Two keys pressed together produce cardinals.
	var result := Vector2i.ZERO
	if absf(rotated.x) > 0.3:
		result.x = signi(roundi(rotated.x))
	if absf(rotated.y) > 0.3:
		result.y = signi(roundi(rotated.y))
	return result

func _try_move(dir: Vector2i) -> bool:
	var new_x := _grid_x + dir.x
	var new_z := _grid_z + dir.y

	var half := GRID_SIZE / 2
	var x_valid := new_x >= -half and new_x < half
	var z_valid := new_z >= -half and new_z < half

	# Wall-sliding: if a diagonal hits the boundary on one axis,
	# slide along the wall using the other axis instead.
	if dir.x != 0 and dir.y != 0:
		if not x_valid and not z_valid:
			return false  # corner — both axes blocked
		if not x_valid:
			return _try_move(Vector2i(0, dir.y))
		if not z_valid:
			return _try_move(Vector2i(dir.x, 0))
	elif not x_valid or not z_valid:
		return false  # cardinal move, out of bounds

	# Height check — can step up at most 1 block
	var target_floor_y := _get_floor_height(new_x, new_z)
	var current_floor_y := _get_floor_height(_grid_x, _grid_z)

	if target_floor_y > current_floor_y + TILE_SIZE + 0.1:
		# Diagonal blocked by height — try each axis separately
		if dir.x != 0 and dir.y != 0:
			if _try_move(Vector2i(dir.x, 0)):
				return true
			return _try_move(Vector2i(0, dir.y))
		return false

	_grid_x = new_x
	_grid_z = new_z
	_target_pos.x = new_x * TILE_SIZE
	_target_pos.z = new_z * TILE_SIZE
	_target_pos.y = target_floor_y + PLAYER_HALF_HEIGHT
	_is_moving = true
	return true

func _get_floor_height(gx: int, gz: int) -> float:
	var base_floor := 0.05
	if not game_manager:
		return base_floor
	var by := 0
	while game_manager.placed_blocks.has(Vector3i(gx, by, gz)):
		by += 1
	if by == 0:
		return base_floor
	return base_floor + by * TILE_SIZE
