class_name InputReverseItem
extends Area2D

const EFFECT_DURATION: float = 5.0

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
	player.apply_strange_effect(
		PlayerController.EFFECT_INPUT_REVERSE,
		EFFECT_DURATION
	)
	player.add_score(1000)
	queue_free()
