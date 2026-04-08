class_name CookieTouchControls
extends CanvasLayer

# Touch controls for mobile using Godot's built-in TouchScreenButton.
# Each button triggers an input action directly — Godot handles all
# coordinate transforms, so visuals and hit areas always match exactly.
# Auto-hidden on keyboard-only devices, shown on touchscreens.

var _buttons: Dictionary = {}
var _bungee: Font

func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_font()
	_build_buttons()

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
	var tsb := TouchScreenButton.new()
	tsb.action = action
	tsb.passby_press = true
	tsb.visibility_mode = TouchScreenButton.VISIBILITY_TOUCHSCREEN_ONLY

	# Position at centre of rect (RectangleShape2D extends from its origin)
	tsb.position = rect.position + rect.size / 2.0

	# Touch detection shape — matches the visual exactly
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	tsb.shape = shape

	add_child(tsb)

	# Visual: semi-transparent background
	var bg := ColorRect.new()
	bg.color = Color(1, 1, 1, 0.15)
	bg.size = rect.size
	bg.position = -rect.size / 2.0
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tsb.add_child(bg)

	# Visual: label
	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.size = rect.size
	lbl.position = -rect.size / 2.0
	lbl.add_theme_font_override("font", _bungee)
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	lbl.add_theme_constant_override("outline_size", 3)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.5))
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tsb.add_child(lbl)

	# Highlight on press/release
	tsb.pressed.connect(func(): bg.color = Color(1, 1, 1, 0.35))
	tsb.released.connect(func(): bg.color = Color(1, 1, 1, 0.15))

	_buttons[action] = { "tsb": tsb, "bg": bg, "lbl": lbl }

func set_crate_visible(show: bool) -> void:
	if _buttons.has("place_block"):
		_buttons["place_block"]["tsb"].visible = show
