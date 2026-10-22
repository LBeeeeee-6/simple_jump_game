class_name DeathBoundary
extends Node2D

@export var speed: float = 60.0
@export var speed_increment_per_world: float = 10.0
@export var max_speed: float = 100.0
@export var player_ahead_speed_bonus: float = 20.0
@export var initial_x: float = 0.0

var _player: PlayerController
var _base_speed: float = 60.0
var _world_speed: float = 60.0

func _ready() -> void:
	_base_speed = speed
	_world_speed = minf(_base_speed, max_speed)
	speed = _world_speed

func setup(player: PlayerController) -> void:
	_player = player
	global_position.x = initial_x
	_world_speed = minf(_base_speed, max_speed)
	speed = _world_speed

func set_world_index(world_index: int) -> void:
	_world_speed = minf(
		_base_speed + speed_increment_per_world * float(maxi(world_index, 0)),
		max_speed
	)
	speed = _world_speed

func set_player_ahead(player_ahead: bool) -> void:
	speed = minf(_world_speed + player_ahead_speed_bonus, max_speed) if player_ahead else _world_speed

func _physics_process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	global_position.x += speed * delta
	if global_position.x > _player.global_position.x:
		_player.die()
