class_name CookieHUD
extends CanvasLayer

var _bungee: Font
var _touch_mode: bool = false
var _cookie_label: Label
var _height_label: Label
var _blocks_label: Label
var _controls_hint: Label

# Title screen
var _title_overlay: ColorRect
var _title_label: Label
var _start_label: Label

# Level intro
var _intro_overlay: ColorRect
var _intro_level: Label
var _intro_name: Label
var _intro_height: Label
var _intro_hint: Label
var _intro_start: Label

# Level complete
var _complete_overlay: ColorRect
var _complete_title: Label
var _complete_cookies: Label
var _complete_pct: Label
var _complete_height: Label
var _complete_next: Label

# Tutorial
var _tutorial_overlay: ColorRect

# Victory
var _victory_overlay: ColorRect

# Game over
var _gameover_overlay: ColorRect
var _gameover_title: Label
var _gameover_score: Label
var _gameover_pct: Label
var _gameover_height: Label
var _gameover_restart: Label

func _ready() -> void:
	layer = 10
	_touch_mode = DisplayServer.is_touchscreen_available()
	_load_font()
	_build_hud()
	_build_title_screen()
	_build_level_intro()
	_build_level_complete()
	_build_tutorial_screen()
	_build_victory_screen()
	_build_gameover_screen()

func _load_font() -> void:
	_bungee = load("res://fonts/Bungee-Regular.ttf")
	if _bungee == null:
		var sf := SystemFont.new()
		sf.font_names = PackedStringArray(["Impact", "Arial Black"])
		_bungee = sf

func _style(label: Label, size: int, color: Color, outline: int = 3, outline_color := Color(0, 0, 0, 0.8)) -> void:
	label.add_theme_font_override("font", _bungee)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_constant_override("outline_size", outline)
	label.add_theme_color_override("font_outline_color", outline_color)

func _build_hud() -> void:
	_cookie_label = Label.new()
	_cookie_label.text = "COOKIES: 0"
	_cookie_label.position = Vector2(20, 10)
	_style(_cookie_label, 28, Color.WHITE, 3)
	add_child(_cookie_label)

	_height_label = Label.new()
	_height_label.text = "0m / 25m"
	_height_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_height_label.position = Vector2(440, 6)
	_height_label.size = Vector2(400, 50)
	_style(_height_label, 32, Color(1.0, 0.97, 0.88), 4)
	add_child(_height_label)

	_blocks_label = Label.new()
	_blocks_label.text = "CRATES: 5"
	_blocks_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_blocks_label.position = Vector2(960, 10)
	_blocks_label.size = Vector2(300, 50)
	_style(_blocks_label, 28, Color.WHITE, 3)
	add_child(_blocks_label)

	_controls_hint = Label.new()
	_controls_hint.text = "" if _touch_mode else "E = PLACE CRATE"
	_controls_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_controls_hint.position = Vector2(440, 660)
	_controls_hint.size = Vector2(400, 40)
	_style(_controls_hint, 22, Color(1.0, 0.9, 0.3), 3)
	_controls_hint.visible = false
	add_child(_controls_hint)

func _build_title_screen() -> void:
	# Layout check (1280x720):
	# Banana left: y=160, h=120. "COOKIE": y=180, h=100. "CLIMB": y=280, h=100.
	# Banana right: y=200, h=120. "PRESS SPACE": y=420, h=60. Controls: y=500, h=40.
	# Total: 540px max, well within 720px.
	_title_overlay = ColorRect.new()
	_title_overlay.color = Color(0, 0, 0, 0.6)
	_title_overlay.size = Vector2(1280, 720)
	_title_overlay.z_index = 50
	add_child(_title_overlay)

	var banana_yellow := Color(1.0, 0.88, 0.15)
	var black_outline := Color(0, 0, 0, 1.0)

	# Load the banana bunch texture
	var banana_tex: Texture2D = load("res://assets/banana_bunch.png")

	# Left banana bunch — to the left of the title
	if banana_tex:
		var left_banana := TextureRect.new()
		left_banana.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		left_banana.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		left_banana.texture = banana_tex
		left_banana.custom_minimum_size = Vector2(130, 100)
		left_banana.size = Vector2(130, 100)
		left_banana.position = Vector2(200, 195)
		_title_overlay.add_child(left_banana)

	# "COOKIE" — slightly left of centre
	var cookie_label := Label.new()
	cookie_label.text = "COOKIE"
	cookie_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cookie_label.position = Vector2(290, 180)
	cookie_label.size = Vector2(500, 100)
	_style(cookie_label, 90, banana_yellow, 8, black_outline)
	_title_overlay.add_child(cookie_label)

	# "CLIMB" — slightly right of centre
	var climb_label := Label.new()
	climb_label.text = "CLIMB"
	climb_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	climb_label.position = Vector2(440, 280)
	climb_label.size = Vector2(500, 100)
	_style(climb_label, 90, banana_yellow, 8, black_outline)
	_title_overlay.add_child(climb_label)

	# Right banana bunch — to the right of the title
	if banana_tex:
		var right_banana := TextureRect.new()
		right_banana.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		right_banana.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		right_banana.texture = banana_tex
		right_banana.custom_minimum_size = Vector2(130, 100)
		right_banana.size = Vector2(130, 100)
		right_banana.position = Vector2(930, 235)
		right_banana.flip_h = true
		_title_overlay.add_child(right_banana)

	_start_label = Label.new()
	_start_label.text = "TAP TO START" if _touch_mode else "PRESS SPACE TO START"
	_start_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_start_label.position = Vector2(290, 420)
	_start_label.size = Vector2(700, 60)
	_style(_start_label, 28, Color.WHITE, 3)
	_title_overlay.add_child(_start_label)

	if not _touch_mode:
		var controls := Label.new()
		controls.text = "LEFT / RIGHT = MOVE    SPACE = JUMP"
		controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		controls.position = Vector2(90, 500)
		controls.size = Vector2(1100, 40)
		_style(controls, 18, Color(0.8, 0.8, 0.8), 2)
		_title_overlay.add_child(controls)

func _build_level_intro() -> void:
	_intro_overlay = ColorRect.new()
	_intro_overlay.color = Color(0, 0, 0, 0.7)
	_intro_overlay.size = Vector2(1280, 720)
	_intro_overlay.z_index = 50
	_intro_overlay.visible = false
	add_child(_intro_overlay)

	_intro_level = Label.new()
	_intro_level.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_intro_level.position = Vector2(190, 160)
	_intro_level.size = Vector2(900, 60)
	_style(_intro_level, 36, Color(0.9, 0.87, 0.78), 4, Color(0.30, 0.16, 0.05))
	_intro_overlay.add_child(_intro_level)

	_intro_name = Label.new()
	_intro_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_intro_name.position = Vector2(190, 230)
	_intro_name.size = Vector2(900, 80)
	_style(_intro_name, 52, Color(0.98, 0.94, 0.86), 5, Color(0.30, 0.16, 0.05))
	_intro_overlay.add_child(_intro_name)

	_intro_height = Label.new()
	_intro_height.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_intro_height.position = Vector2(190, 330)
	_intro_height.size = Vector2(900, 50)
	_style(_intro_height, 28, Color(0.9, 0.9, 0.9), 3)
	_intro_overlay.add_child(_intro_height)

	_intro_hint = Label.new()
	_intro_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_intro_hint.position = Vector2(190, 390)
	_intro_hint.size = Vector2(900, 50)
	_style(_intro_hint, 22, Color(0.7, 0.85, 1.0), 2)
	_intro_overlay.add_child(_intro_hint)

	_intro_start = Label.new()
	_intro_start.text = "TAP TO CLIMB" if _touch_mode else "PRESS SPACE TO CLIMB"
	_intro_start.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_intro_start.position = Vector2(290, 480)
	_intro_start.size = Vector2(700, 50)
	_style(_intro_start, 26, Color.WHITE, 3)
	_intro_overlay.add_child(_intro_start)

func _build_level_complete() -> void:
	_complete_overlay = ColorRect.new()
	_complete_overlay.color = Color(0, 0, 0, 0.75)
	_complete_overlay.size = Vector2(1280, 720)
	_complete_overlay.z_index = 50
	_complete_overlay.visible = false
	add_child(_complete_overlay)

	_complete_title = Label.new()
	_complete_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_complete_title.position = Vector2(190, 140)
	_complete_title.size = Vector2(900, 80)
	_style(_complete_title, 52, Color(0.3, 1.0, 0.4), 5)
	_complete_overlay.add_child(_complete_title)

	_complete_cookies = Label.new()
	_complete_cookies.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_complete_cookies.position = Vector2(290, 260)
	_complete_cookies.size = Vector2(700, 50)
	_style(_complete_cookies, 34, Color(1.0, 0.95, 0.7), 4)
	_complete_overlay.add_child(_complete_cookies)

	_complete_pct = Label.new()
	_complete_pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_complete_pct.position = Vector2(290, 320)
	_complete_pct.size = Vector2(700, 50)
	_style(_complete_pct, 28, Color(0.9, 0.9, 0.9), 3)
	_complete_overlay.add_child(_complete_pct)

	_complete_height = Label.new()
	_complete_height.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_complete_height.position = Vector2(290, 375)
	_complete_height.size = Vector2(700, 50)
	_style(_complete_height, 28, Color(0.9, 0.9, 0.9), 3)
	_complete_overlay.add_child(_complete_height)

	_complete_next = Label.new()
	_complete_next.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_complete_next.position = Vector2(290, 460)
	_complete_next.size = Vector2(700, 50)
	_style(_complete_next, 26, Color.WHITE, 3)
	_complete_overlay.add_child(_complete_next)

var _tutorial_hint: Label
var _tutorial_sub: Label

func _build_tutorial_screen() -> void:
	# Tutorial hint labels — shown during the playable tutorial mini-level
	_tutorial_overlay = ColorRect.new()
	_tutorial_overlay.color = Color(0, 0, 0, 0)  # transparent
	_tutorial_overlay.size = Vector2(1280, 720)
	_tutorial_overlay.z_index = 50
	_tutorial_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tutorial_overlay.visible = false
	add_child(_tutorial_overlay)

	_tutorial_hint = Label.new()
	_tutorial_hint.text = "TAP CRATE TO PLACE ONE" if _touch_mode else "PLACE A CRATE WITH E"
	_tutorial_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tutorial_hint.position = Vector2(190, 50)
	_tutorial_hint.size = Vector2(900, 60)
	_style(_tutorial_hint, 42, Color(1.0, 0.88, 0.15), 5, Color(0, 0, 0, 1.0))
	_tutorial_overlay.add_child(_tutorial_hint)

	_tutorial_sub = Label.new()
	_tutorial_sub.text = "THEN JUMP ON IT!"
	_tutorial_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tutorial_sub.position = Vector2(190, 110)
	_tutorial_sub.size = Vector2(900, 40)
	_style(_tutorial_sub, 24, Color.WHITE, 3)
	_tutorial_overlay.add_child(_tutorial_sub)

func _build_victory_screen() -> void:
	# Layout check (1280x720):
	# "YOU DID IT!": y=80, h=80. Stars: y=170, h=50. "COOKIE CLIMB": y=240, h=60.
	# "CHAMPION": y=300, h=50. Cookies: y=390, h=50. Pct: y=440, h=40.
	# "PRESS SPACE": y=540, h=50. Total max: 590px, within 720px.
	_victory_overlay = ColorRect.new()
	_victory_overlay.color = Color(0.05, 0.02, 0.15, 0.85)
	_victory_overlay.size = Vector2(1280, 720)
	_victory_overlay.z_index = 50
	_victory_overlay.visible = false
	add_child(_victory_overlay)

	var gold := Color(1.0, 0.85, 0.1)
	var warm_white := Color(1.0, 0.97, 0.9)

	# Big celebration title
	var title := Label.new()
	title.text = "YOU DID IT!"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(140, 80)
	title.size = Vector2(1000, 80)
	_style(title, 72, gold, 6, Color(0, 0, 0, 1.0))
	_victory_overlay.add_child(title)

	# Star decorations
	var stars := Label.new()
	stars.text = "~ ~ ~ ~ ~ ~ ~"
	stars.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stars.position = Vector2(290, 170)
	stars.size = Vector2(700, 50)
	_style(stars, 32, gold, 3)
	_victory_overlay.add_child(stars)

	# "COOKIE CLIMB CHAMPION"
	var sub1 := Label.new()
	sub1.text = "COOKIE CLIMB"
	sub1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub1.position = Vector2(190, 240)
	sub1.size = Vector2(900, 60)
	_style(sub1, 48, warm_white, 5, Color(0.3, 0.15, 0.0))
	_victory_overlay.add_child(sub1)

	var sub2 := Label.new()
	sub2.text = "CHAMPION"
	sub2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub2.position = Vector2(190, 300)
	sub2.size = Vector2(900, 50)
	_style(sub2, 40, gold, 4, Color(0.3, 0.15, 0.0))
	_victory_overlay.add_child(sub2)

	# Total cookies collected across all levels
	var _vic_cookies := Label.new()
	_vic_cookies.name = "VicCookies"
	_vic_cookies.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_vic_cookies.position = Vector2(290, 390)
	_vic_cookies.size = Vector2(700, 50)
	_style(_vic_cookies, 32, warm_white, 4)
	_victory_overlay.add_child(_vic_cookies)

	var _vic_pct := Label.new()
	_vic_pct.name = "VicPct"
	_vic_pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_vic_pct.position = Vector2(290, 440)
	_vic_pct.size = Vector2(700, 40)
	_style(_vic_pct, 24, Color(0.85, 0.85, 0.85), 3)
	_victory_overlay.add_child(_vic_pct)

	# Banana image if available
	var banana_tex: Texture2D = load("res://assets/banana_bunch.png")
	if banana_tex:
		var banana := TextureRect.new()
		banana.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		banana.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		banana.texture = banana_tex
		banana.custom_minimum_size = Vector2(100, 80)
		banana.size = Vector2(100, 80)
		banana.position = Vector2(590, 490)
		_victory_overlay.add_child(banana)

	var replay := Label.new()
	replay.text = "TAP TO PLAY AGAIN" if _touch_mode else "PRESS SPACE TO PLAY AGAIN"
	replay.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	replay.position = Vector2(290, 590)
	replay.size = Vector2(700, 50)
	_style(replay, 24, Color(0.8, 0.8, 0.8), 3)
	_victory_overlay.add_child(replay)

func show_victory(cookies: int, total: int) -> void:
	var cookie_label: Label = _victory_overlay.get_node("VicCookies")
	var pct_label: Label = _victory_overlay.get_node("VicPct")
	cookie_label.text = "TOTAL COOKIES: %d" % cookies
	if total > 0:
		var pct := int(float(cookies) / float(total) * 100.0)
		pct_label.text = "%d%% OF ALL COOKIES COLLECTED" % pct
	else:
		pct_label.text = ""
	_victory_overlay.visible = true
	_complete_overlay.visible = false
	_controls_hint.visible = false

func hide_victory() -> void:
	_victory_overlay.visible = false

func _build_gameover_screen() -> void:
	_gameover_overlay = ColorRect.new()
	_gameover_overlay.color = Color(0, 0, 0, 0.75)
	_gameover_overlay.size = Vector2(1280, 720)
	_gameover_overlay.z_index = 50
	_gameover_overlay.visible = false
	add_child(_gameover_overlay)

	_gameover_title = Label.new()
	_gameover_title.text = "GAME OVER"
	_gameover_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gameover_title.position = Vector2(190, 140)
	_gameover_title.size = Vector2(900, 80)
	_style(_gameover_title, 64, Color(1.0, 0.3, 0.3), 5)
	_gameover_overlay.add_child(_gameover_title)

	_gameover_score = Label.new()
	_gameover_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gameover_score.position = Vector2(290, 270)
	_gameover_score.size = Vector2(700, 50)
	_style(_gameover_score, 36, Color(1.0, 0.95, 0.7), 4)
	_gameover_overlay.add_child(_gameover_score)

	_gameover_pct = Label.new()
	_gameover_pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gameover_pct.position = Vector2(290, 325)
	_gameover_pct.size = Vector2(700, 50)
	_style(_gameover_pct, 26, Color(0.9, 0.9, 0.9), 3)
	_gameover_overlay.add_child(_gameover_pct)

	_gameover_height = Label.new()
	_gameover_height.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gameover_height.position = Vector2(290, 375)
	_gameover_height.size = Vector2(700, 50)
	_style(_gameover_height, 28, Color(0.9, 0.9, 0.9), 3)
	_gameover_overlay.add_child(_gameover_height)

	_gameover_restart = Label.new()
	_gameover_restart.text = "TAP TO RETRY" if _touch_mode else "PRESS SPACE TO RETRY"
	_gameover_restart.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gameover_restart.position = Vector2(290, 460)
	_gameover_restart.size = Vector2(700, 50)
	_style(_gameover_restart, 24, Color(0.85, 0.85, 0.85), 3)
	_gameover_overlay.add_child(_gameover_restart)

# ─── Public API ───

func update_cookies(count: int) -> void:
	_cookie_label.text = "COOKIES: %d" % count

func update_height(current_m: int, target_m: int) -> void:
	_height_label.text = "%dm / %dm" % [current_m, target_m]

func update_blocks(count: int) -> void:
	_blocks_label.text = "CRATES: %d" % count

func set_crates_visible(visible: bool) -> void:
	_blocks_label.visible = visible

func show_title() -> void:
	_title_overlay.visible = true
	_intro_overlay.visible = false
	_complete_overlay.visible = false
	_tutorial_overlay.visible = false
	_gameover_overlay.visible = false
	_controls_hint.visible = false

func hide_title() -> void:
	_title_overlay.visible = false

func show_level_intro(level_num: int, level_name: String, target_m: int, hint: String) -> void:
	_intro_level.text = "LEVEL %d" % level_num
	_intro_name.text = level_name
	_intro_height.text = "CLIMB TO %dm" % target_m
	_intro_hint.text = hint
	_intro_start.text = "TAP TO CLIMB" if _touch_mode else "PRESS SPACE TO CLIMB"
	_intro_overlay.visible = true
	_gameover_overlay.visible = false
	_complete_overlay.visible = false
	_controls_hint.visible = false

func hide_level_intro() -> void:
	_intro_overlay.visible = false

func show_tutorial_intro() -> void:
	# Big intro screen like level intros — "TUTORIAL" / "LEARN HOW TO USE CRATES"
	_intro_level.text = "TUTORIAL"
	_intro_name.text = "CRATE TRAINING"
	_intro_height.text = "LEARN HOW TO USE CRATES"
	_intro_hint.text = "USE THE CRATE BUTTON" if _touch_mode else "PRESS E TO PLACE A CRATE"
	_intro_start.text = "TAP TO BEGIN" if _touch_mode else "PRESS SPACE TO BEGIN"
	_intro_overlay.visible = true
	_title_overlay.visible = false
	_gameover_overlay.visible = false
	_complete_overlay.visible = false
	_controls_hint.visible = false

func hide_tutorial_intro() -> void:
	_intro_overlay.visible = false

func show_tutorial_hint() -> void:
	# Show hint labels during playable tutorial — no overlays, game is visible
	_tutorial_overlay.visible = true
	_title_overlay.visible = false
	_intro_overlay.visible = false
	_complete_overlay.visible = false
	_gameover_overlay.visible = false
	_controls_hint.visible = false
	# Hide the height label during tutorial (no climbing target)
	_height_label.visible = false

func hide_tutorial_hint() -> void:
	_tutorial_overlay.visible = false

func show_tutorial_stage2() -> void:
	_tutorial_hint.text = "JUMP, THEN QUICKLY TAP CRATE!" if _touch_mode else "JUMP, THEN QUICKLY PRESS E!"
	_tutorial_sub.text = "A CRATE APPEARS IN THE AIR - LAND ON IT, THEN JUMP AGAIN!"

func show_tutorial_complete() -> void:
	# Brief "NICE!" message when they cross the gap
	_tutorial_overlay.visible = false
	var nice := Label.new()
	nice.text = "NICE!"
	nice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nice.position = Vector2(290, 300)
	nice.size = Vector2(700, 80)
	_style(nice, 64, Color(0.3, 1.0, 0.4), 6, Color(0, 0, 0, 1.0))
	add_child(nice)

func show_controls_hint() -> void:
	_controls_hint.visible = true

func show_level_complete(cookies: int, total: int, height_m: int, is_final: bool) -> void:
	if is_final:
		_complete_title.text = "YOU WIN!"
		_complete_next.text = "TAP TO PLAY AGAIN" if _touch_mode else "PRESS SPACE TO PLAY AGAIN"
	else:
		_complete_title.text = "LEVEL COMPLETE!"
		_complete_next.text = "TAP FOR NEXT LEVEL" if _touch_mode else "PRESS SPACE FOR NEXT LEVEL"
	_complete_cookies.text = "COOKIES: %d" % cookies
	if total > 0:
		var pct := int(float(cookies) / float(total) * 100.0)
		_complete_pct.text = "%d%% COLLECTED" % pct
	else:
		_complete_pct.text = ""
	_complete_height.text = "HEIGHT: %dm" % height_m
	_complete_overlay.visible = true
	_controls_hint.visible = false

func hide_level_complete() -> void:
	_complete_overlay.visible = false

func show_game_over(cookies: int, total: int, height_m: int) -> void:
	_gameover_score.text = "COOKIES: %d" % cookies
	if total > 0:
		var pct := int(float(cookies) / float(total) * 100.0)
		_gameover_pct.text = "%d%% COLLECTED" % pct
	else:
		_gameover_pct.text = ""
	_gameover_height.text = "HEIGHT: %dm" % height_m
	_gameover_overlay.visible = true
	_controls_hint.visible = false

func hide_game_over() -> void:
	_gameover_overlay.visible = false
