class_name CookieCrunchCookie
extends Area2D

signal collected

const BOB_SPEED := 2.0
const BOB_AMOUNT := 6.0

var _base_y: float
var _time: float = 0.0

func _ready() -> void:
	_base_y = position.y
	_time = randf() * TAU
	_build_visual()
	_setup_collision()
	body_entered.connect(_on_body_entered)

func _build_visual() -> void:
	# Oreo cookie: rounded dark wafers + square-edged cream filling

	# Top dark wafer (rounded ellipse)
	var top_wafer := Polygon2D.new()
	top_wafer.color = Color(0.13, 0.09, 0.04)
	top_wafer.polygon = _ellipse_points(16.0, 8.0, 14)
	top_wafer.position = Vector2(0, -8)
	add_child(top_wafer)

	# Cream filling (square-edged rectangle)
	var cream := ColorRect.new()
	cream.color = Color(0.95, 0.92, 0.85)
	cream.size = Vector2(26, 7)
	cream.position = Vector2(-13, -3.5)
	add_child(cream)

	# Bottom dark wafer (rounded ellipse)
	var bottom_wafer := Polygon2D.new()
	bottom_wafer.color = Color(0.13, 0.09, 0.04)
	bottom_wafer.polygon = _ellipse_points(16.0, 8.0, 14)
	bottom_wafer.position = Vector2(0, 8)
	add_child(bottom_wafer)

func _ellipse_points(rx: float, ry: float, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in segments:
		var angle := TAU * i / segments
		points.append(Vector2(cos(angle) * rx, sin(angle) * ry))
	return points

func _setup_collision() -> void:
	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 16.0
	col.shape = shape
	add_child(col)

func _process(delta: float) -> void:
	_time += delta
	position.y = _base_y + sin(_time * BOB_SPEED) * BOB_AMOUNT

func _on_body_entered(body: Node2D) -> void:
	if body is CookiePlayer:
		_play_collect_effect()
		collected.emit()
		set_deferred("monitoring", false)

func _play_collect_effect() -> void:
	var label := Label.new()
	label.text = "+1!"
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.3))
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.z_index = 100
	get_parent().add_child(label)
	label.global_position = global_position + Vector2(-15, -50)

	var tween := label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 60, 0.8).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.8).set_delay(0.3)
	tween.chain().tween_callback(label.queue_free)

	var pop := create_tween()
	pop.tween_property(self, "scale", Vector2(1.5, 1.5), 0.1)
	pop.tween_property(self, "modulate:a", 0.0, 0.15)
	pop.tween_callback(queue_free)
