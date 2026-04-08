class_name CookieTouchControls
extends CanvasLayer

# Touch controls for mobile — auto-detected, hidden on keyboard devices.
#
# Layout (1280x720 landscape, thumbs at bottom corners):
#   Bottom-left:  [<] [>]    — move left/right
#   Bottom-right: [CRATE] above [JUMP]   — actions
#
# Touch buttons simulate the same input actions as the keyboard,
# so the player code doesn't need any changes.

var _buttons: Dictionary = {}  # action_name → { rect: Rect2, bg: ColorRect, lbl: Label }
var _touches: Dictionary = {}  # touch_index → action_name
var _active := false
var _bungee: Font

func _ready() -> void:
	layer = 20  # above HUD (layer 10)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_font()
	_build_buttons()
	# Auto-detect: show touch controls on touchscreen devices
	if DisplayServer.is_touchscreen_available():
		_show()
	else:
		_hide()

func _load_font() -> void:
	_bungee = load("res://fonts/Bungee-Regular.ttf")
	if _bungee == null:
		var sf := SystemFont.new()
		sf.font_names = PackedStringArray(["Impact", "Arial Black"])
		_bungee = sf

func _build_buttons() -> void:
	# Move buttons — bottom-left, big for easy thumb hits
	_add_button("move_left", Rect2(0, 460, 200, 260), "<", 60)
	_add_button("move_right", Rect2(200, 460, 200, 260), ">", 60)

	# Action buttons — bottom-right
	_add_button("jump", Rect2(860, 460, 420, 260), "JUMP", 40)
	_add_button("place_block", Rect2(860, 270, 300, 180), "CRATE", 28)

func _add_button(action: String, rect: Rect2, text: String, font_size: int) -> void:
	# Semi-transparent rounded background
	var bg := ColorRect.new()
	bg.color = Color(1, 1, 1, 0.15)
	bg.size = rect.size
	bg.position = rect.position
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# Label
	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.size = rect.size
	lbl.position = rect.position
	lbl.add_theme_font_override("font", _bungee)
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	lbl.add_theme_constant_override("outline_size", 3)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.5))
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(lbl)

	_buttons[action] = { "rect": rect, "bg": bg, "lbl": lbl }

func _input(event: InputEvent) -> void:
	# Auto-switch between touch and keyboard modes
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		if not _active:
			_show()
	elif event is InputEventKey and event.pressed:
		if _active:
			_hide()
		return

	# Handle touch start/end
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event
		var pos := _to_viewport(touch.position)
		if touch.pressed:
			_on_touch_start(touch.index, pos)
		else:
			_on_touch_end(touch.index)

	# Handle touch drag (finger slides between buttons)
	elif event is InputEventScreenDrag:
		var drag: InputEventScreenDrag = event
		var pos := _to_viewport(drag.position)
		_on_touch_move(drag.index, pos)

func _to_viewport(screen_pos: Vector2) -> Vector2:
	# Convert screen coordinates to viewport coordinates (1280x720).
	# Compute manually for reliability across desktop and mobile web.
	var vp_size := Vector2(1280, 720)
	var win_size := Vector2(DisplayServer.window_get_size())
	if win_size.x <= 0 or win_size.y <= 0:
		return screen_pos
	var scale := minf(win_size.x / vp_size.x, win_size.y / vp_size.y)
	var offset := (win_size - vp_size * scale) * 0.5
	return (screen_pos - offset) / scale

func _on_touch_start(index: int, pos: Vector2) -> void:
	var btn := _button_at(pos)
	if btn != "":
		_touches[index] = btn
		Input.action_press(btn)
		_set_highlight(btn, true)
	# No fallback — tapping empty space does nothing during gameplay.
	# Menu screens use Input.is_action_just_pressed("jump") which
	# catches the first touch via emulate_mouse_from_touch.

func _on_touch_end(index: int) -> void:
	if _touches.has(index):
		var btn: String = _touches[index]
		Input.action_release(btn)
		_set_highlight(btn, false)
		_touches.erase(index)

func _on_touch_move(index: int, pos: Vector2) -> void:
	var new_btn := _button_at(pos)
	if not _touches.has(index):
		return
	var old_btn: String = _touches[index]
	if new_btn == old_btn:
		return
	# Finger moved to a different button (or off all buttons)
	Input.action_release(old_btn)
	_set_highlight(old_btn, false)
	if new_btn != "":
		_touches[index] = new_btn
		Input.action_press(new_btn)
		_set_highlight(new_btn, true)
	else:
		_touches.erase(index)

func _button_at(pos: Vector2) -> String:
	for action in _buttons:
		# Skip hidden buttons
		var bg: ColorRect = _buttons[action]["bg"]
		if not bg.visible:
			continue
		var rect: Rect2 = _buttons[action]["rect"]
		if rect.has_point(pos):
			return action
	return ""

func _set_highlight(action: String, on: bool) -> void:
	if _buttons.has(action):
		var bg: ColorRect = _buttons[action]["bg"]
		bg.color = Color(1, 1, 1, 0.35) if on else Color(1, 1, 1, 0.15)

func set_crate_visible(show: bool) -> void:
	if _buttons.has("place_block"):
		var bg: ColorRect = _buttons["place_block"]["bg"]
		var lbl: Label = _buttons["place_block"]["lbl"]
		bg.visible = show
		lbl.visible = show

func _show() -> void:
	_active = true
	visible = true

func _hide() -> void:
	_active = false
	visible = false
	# Release any held actions
	for index in _touches:
		var btn: String = _touches[index]
		Input.action_release(btn)
		_set_highlight(btn, false)
	_touches.clear()
