extends Node
## Simple touch movement for a grid game.
## One-finger drag from a fixed anchor = direction.
## Mouse left-click is emulated to screen touch via project setting,
## so we ONLY handle screen touch events here (no mouse handlers needed).
## When 2+ fingers are down, movement stops (orbit takes over).

var is_active: bool = false
var _anchor: Vector2 = Vector2.ZERO
var _current: Vector2 = Vector2.ZERO
var _touch_index: int = -1
var _touch_count: int = 0
var _exclusion_rects: Array = []

const DRAG_THRESHOLD := 25.0  # pixels before direction registers

func add_exclusion_rect(rect: Rect2) -> void:
	_exclusion_rects.append(rect)

func remove_exclusion_rect(rect: Rect2) -> void:
	_exclusion_rects.erase(rect)

func clear_exclusion_rects() -> void:
	_exclusion_rects.clear()

func _is_in_exclusion_zone(pos: Vector2) -> bool:
	for r in _exclusion_rects:
		if r.has_point(pos):
			return true
	return false

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_count += 1
			if _touch_index == -1 and not _is_in_exclusion_zone(event.position):
				_touch_index = event.index
				is_active = true
				_anchor = event.position
				_current = event.position
		else:
			_touch_count = maxi(_touch_count - 1, 0)
			if event.index == _touch_index:
				_touch_index = -1
				is_active = false

	elif event is InputEventScreenDrag:
		if event.index == _touch_index and is_active:
			_current = event.position

## Returns a normalized direction vector, or Vector2.ZERO if not dragging.
## Movement disabled when 2+ fingers are down (orbit mode).
func get_direction() -> Vector2:
	if not is_active or _touch_count >= 2:
		return Vector2.ZERO
	var delta := _current - _anchor
	if delta.length() < DRAG_THRESHOLD:
		return Vector2.ZERO
	return delta.normalized()
