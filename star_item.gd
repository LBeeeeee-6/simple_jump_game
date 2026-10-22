class_name StarItem
extends Area2D

@export var projectile_speed: float = 260.0

var _collected: bool = false
var _launched: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

func _physics_process(delta: float) -> void:
	if not _launched:
		return
	global_position.x -= projectile_speed * delta

func _on_body_entered(body: Node2D) -> void:
	if _collected or _launched or not body is PlayerController:
		return
	_collected = true
	_launched = true
	collision_mask = 4

func _on_area_entered(area: Area2D) -> void:
	if not _launched:
		return
	var angel: AngelBoss = area.get_parent() as AngelBoss
	if angel == null:
		return
	_launched = false
	monitoring = false
	angel.take_damage(angel.star_damage)
	queue_free()
