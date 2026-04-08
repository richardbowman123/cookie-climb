# Old 3D cookie — no longer used
extends Area3D

## A floating collectible cookie. Bobs up and down and spins slowly.
## When the player touches it, it's collected.

signal collected

const BOB_SPEED := 2.0
const BOB_HEIGHT := 0.15
const SPIN_SPEED := 1.5

var _base_y := 0.0
var _time := 0.0

func _ready() -> void:
	_base_y = position.y
	_time = randf() * TAU

	# Enable monitoring so this Area3D detects bodies entering it
	monitoring = true
	monitorable = false

	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	_time += delta
	# Bob up and down
	position.y = _base_y + sin(_time * BOB_SPEED) * BOB_HEIGHT
	# Spin around Y axis
	rotation.y += SPIN_SPEED * delta

func _on_body_entered(body: Node3D) -> void:
	if body is CookiePlayer:
		collected.emit()
		queue_free()
