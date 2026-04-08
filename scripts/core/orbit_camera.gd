# Old 3D orbit camera — no longer used
extends Node3D

## Snap camera — 4 viewing angles at 90° apart.
## Q/E to rotate between them. Scroll wheel to zoom.
## At each angle, WASD maps consistently to screen directions.

@export var smooth_speed := 8.0
@export var zoom_min := 6.0
@export var zoom_max := 16.0
@export var zoom_speed := 0.5

const SNAP_ANGLES := [45.0, 135.0, 225.0, 315.0]

var _snap_index := 0
var _target_yaw := 45.0
var _current_yaw := 45.0
var _camera: Camera3D
var _target_zoom := 10.0
var _current_zoom := 10.0

func _ready() -> void:
	for child in get_children():
		if child is Camera3D:
			_camera = child
			break
	if _camera:
		_target_zoom = _camera.position.z
		_current_zoom = _target_zoom
	_target_yaw = SNAP_ANGLES[_snap_index]
	_current_yaw = _target_yaw
	rotation_degrees.y = _current_yaw

func rotate_right() -> void:
	_snap_index = (_snap_index + 1) % 4
	_target_yaw = SNAP_ANGLES[_snap_index]
	# Rotate the short way around (max 90°)
	if _target_yaw - _current_yaw > 180.0:
		_current_yaw += 360.0
	elif _target_yaw - _current_yaw < -180.0:
		_current_yaw -= 360.0

func rotate_left() -> void:
	_snap_index = (_snap_index - 1 + 4) % 4
	_target_yaw = SNAP_ANGLES[_snap_index]
	if _target_yaw - _current_yaw > 180.0:
		_current_yaw += 360.0
	elif _target_yaw - _current_yaw < -180.0:
		_current_yaw -= 360.0

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_target_zoom = clampf(_target_zoom - zoom_speed, zoom_min, zoom_max)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_target_zoom = clampf(_target_zoom + zoom_speed, zoom_min, zoom_max)

func _process(delta: float) -> void:
	_current_yaw = lerpf(_current_yaw, _target_yaw, smooth_speed * delta)
	_current_zoom = lerpf(_current_zoom, _target_zoom, smooth_speed * delta)
	rotation_degrees.y = _current_yaw
	if _camera:
		_camera.position.z = _current_zoom
		_camera.look_at(global_position, Vector3.UP)
