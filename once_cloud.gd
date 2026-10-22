class_name OnceCloud
extends Area2D

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var platform_collision: CollisionShape2D = $StaticBody2D/CollisionShape2D

const DISAPPEAR_DELAY: float = 0.6
const RESPAWN_DELAY: float = 2.0

var _triggered: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _physics_process(_delta: float) -> void:
	if _triggered:
		return

	for body: Node2D in get_overlapping_bodies():
		if body is PlayerController:
			_on_body_entered(body)
			return

func _on_body_entered(body: Node2D) -> void:
	if _triggered or not body is PlayerController:
		return

	var player := body as PlayerController
	# Only activate when the player is falling onto the cloud from above.
	if player.global_position.y >= global_position.y or player.velocity.y < 0.0:
		return

	_triggered = true
	await get_tree().create_timer(DISAPPEAR_DELAY).timeout
	sprite.visible = false
	collision_shape.set_deferred("disabled", true)
	platform_collision.set_deferred("disabled", true)
	monitoring = false
	await get_tree().create_timer(RESPAWN_DELAY).timeout
	sprite.visible = true
	collision_shape.set_deferred("disabled", false)
	platform_collision.set_deferred("disabled", false)
	monitoring = true
	_triggered = false
