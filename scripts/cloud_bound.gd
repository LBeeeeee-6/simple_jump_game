class_name CloudBound
extends Area2D

@export var bounce_height_multiplier: float = 0.7

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var sprite: Sprite2D = $Sprite2D

var _player_inside: bool = false
var _is_reappearing: bool = false

const RESPAWN_DELAY: float = 3.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if _player_inside:
		return

	var player: PlayerController = body as PlayerController
	if player == null or player.velocity.y < 0.0:
		return

	var cloud_top_y: float = collision_shape.global_position.y
	if collision_shape.shape is RectangleShape2D:
		cloud_top_y -= (collision_shape.shape as RectangleShape2D).size.y * 0.5

	if player.global_position.y > cloud_top_y:
		return

	_player_inside = true
	player.launch_cloud_bounce(player.max_jump_height * bounce_height_multiplier)
	_hide_and_respawn()

func _on_body_exited(body: Node2D) -> void:
	if body is PlayerController:
		_player_inside = false

func _hide_and_respawn() -> void:
	if _is_reappearing:
		return

	_is_reappearing = true
	sprite.visible = false
	collision_shape.set_deferred("disabled", true)
	set_deferred("monitoring", false)
	await get_tree().create_timer(RESPAWN_DELAY).timeout
	sprite.visible = true
	collision_shape.set_deferred("disabled", false)
	set_deferred("monitoring", true)
	_player_inside = false
	_is_reappearing = false
