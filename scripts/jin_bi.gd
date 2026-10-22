class_name JinBi
extends Area2D

const SCORE_VALUE: int = 100
var _collected: bool = false

func _on_body_entered(body: Node2D) -> void:
	if _collected or not body is PlayerController:
		return
	_collected = true
	set_deferred("monitoring", false)
	(body as PlayerController).add_score(SCORE_VALUE)
	queue_free()
