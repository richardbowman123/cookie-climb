class_name CookieCoconut
extends Area2D

const FALL_SPEED := 350.0
const WOBBLE_SPEED := 3.0
const WOBBLE_AMOUNT := 30.0

var _time: float = 0.0
var _base_x: float = 0.0
var _hit := false

func _ready() -> void:
	_base_x = position.x
	_time = randf() * TAU
	_build_visual()
	_setup_collision()
	body_entered.connect(_on_body_entered)

func _build_visual() -> void:
	# Main coconut — brown circle
	var shell := Polygon2D.new()
	shell.color = Color(0.40, 0.25, 0.12)
	shell.polygon = _circle_points(14.0, 12)
	add_child(shell)

	# Lighter brown band around middle
	var band := Polygon2D.new()
	band.color = Color(0.50, 0.32, 0.16)
	band.polygon = _ellipse_points(14.0, 6.0, 10)
	add_child(band)

	# Three dark "eyes" of the coconut
	var eye_positions := [
		Vector2(-5, -3), Vector2(5, -3), Vector2(0, 4)
	]
	for ep in eye_positions:
		var eye := Polygon2D.new()
		eye.color = Color(0.22, 0.13, 0.06)
		eye.polygon = _circle_points(2.5, 6)
		eye.position = ep
		add_child(eye)

	# Hairy fibres at top (small lines)
	for i in range(5):
		var fibre := Polygon2D.new()
		fibre.color = Color(0.55, 0.38, 0.20, 0.6)
		var fx := randf_range(-8, 8)
		fibre.polygon = PackedVector2Array([
			Vector2(fx - 1, -13), Vector2(fx + 1, -13),
			Vector2(fx + randf_range(-2, 2), -18 - randf() * 4),
		])
		add_child(fibre)

func _setup_collision() -> void:
	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 14.0
	col.shape = shape
	add_child(col)

func _process(delta: float) -> void:
	if _hit:
		return
	_time += delta
	position.y += FALL_SPEED * delta
	position.x = _base_x + sin(_time * WOBBLE_SPEED) * WOBBLE_AMOUNT
	# Self-destruct after falling well past the entire visible area
	if _time > 10.0:
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	if _hit:
		return
	if body is CookiePlayer:
		_hit = true
		body.stun(1.5)
		_play_hit_effect()

func _play_hit_effect() -> void:
	# Brief flash then disappear
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color(1, 1, 1, 0), 0.3)
	tween.tween_callback(queue_free)

func _circle_points(radius: float, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in segments:
		var angle := TAU * i / segments
		points.append(Vector2(cos(angle) * radius, sin(angle) * radius))
	return points

func _ellipse_points(rx: float, ry: float, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in segments:
		var angle := TAU * i / segments
		points.append(Vector2(cos(angle) * rx, sin(angle) * ry))
	return points
