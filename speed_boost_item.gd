class_name SpeedBoostItem
extends Area2D

@export var effect_duration: float = 5.0

var _consumed: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if _consumed or not body is PlayerController:
		return

	_consumed = true
	monitoring = false
	monitorable = false
	var player: PlayerController = body as PlayerController
	player.apply_strange_effect(PlayerController.EFFECT_SPEED_BOOST, effect_duration)
	player.add_score(1000)
	queue_free()
