class_name AngelBoss
extends CharacterBody2D

@export var move_speed: float = 80.0
@export var target_deadzone: float = 2.0
@export var max_health: int = 3
@export var star_damage: int = 1

@onready var sprite: Sprite2D = $Sprite2D
@onready var health_bar: ProgressBar = $HealthBar
@onready var player_detector: Area2D = $PlayerDetector
@onready var hit_receiver: Area2D = $HitReceiver

var _player: PlayerController
var _current_health: int
var _is_defeated: bool = false

func _ready() -> void:
	max_health = maxi(max_health, 1)
	star_damage = maxi(star_damage, 1)
	_current_health = max_health
	health_bar.max_value = _current_health
	health_bar.value = _current_health
	player_detector.body_entered.connect(_on_player_detector_body_entered)
	_player = _find_player()

func _physics_process(_delta: float) -> void:
	if _is_defeated:
		return
	if not is_instance_valid(_player):
		_player = _find_player()

	if not is_instance_valid(_player):
		velocity.x = 0.0
		return

	var horizontal_distance: float = _player.global_position.x - global_position.x
	if absf(horizontal_distance) <= target_deadzone:
		velocity.x = 0.0
	else:
		velocity.x = signf(horizontal_distance) * move_speed
		sprite.flip_h = velocity.x < 0.0

	velocity.y = 0.0
	move_and_slide()

func _find_player() -> PlayerController:
	var grouped_player := get_tree().get_first_node_in_group("player") as PlayerController
	if grouped_player != null:
		return grouped_player

	var players: Array[Node] = get_tree().current_scene.find_children(
		"*", "PlayerController", true, false
	)
	if not players.is_empty():
		return players[0] as PlayerController
	return null

func _on_player_detector_body_entered(body: Node2D) -> void:
	if _is_defeated or not body is PlayerController:
		return
	var player: PlayerController = body as PlayerController
	if player.consume_star_attack():
		take_damage(star_damage)
	else:
		player.die()

func take_damage(amount: int) -> void:
	if _is_defeated or amount <= 0:
		return
	_current_health = maxi(_current_health - amount, 0)
	health_bar.value = _current_health
	if _current_health == 0:
		_defeat()

func _defeat() -> void:
	if _is_defeated:
		return
	_is_defeated = true
	velocity = Vector2.ZERO
	player_detector.set_deferred("monitoring", false)
	hit_receiver.set_deferred("monitoring", false)
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	queue_free()
