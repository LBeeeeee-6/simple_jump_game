class_name PlayerController
extends CharacterBody2D

signal score_changed(new_score: int)
signal died(final_score: int)
signal gravity_orientation_changed(inverted: bool)
signal strange_effect_changed(effect_type: int, remaining: float, duration: float)

const EFFECT_INPUT_REVERSE: int = 0
const EFFECT_INVERT_GRAVITY: int = 1
const EFFECT_SPEED_BOOST: int = 2

@export_group("Movement")
@export var move_speed: float = 100.0
@export var speed_boost_multiplier: float = 1.5
@export var gravity: float = 1500.0
@export var jump_velocity: float = -300.0
@export var jump_hold_acceleration: float = 1000.0
@export var jump_hold_duration: float = 0.2
@export var max_jump_height: float = 180.0
@export var max_jumps: int = 1

@export_group("Dash")
@export var dash_speed: float = 300.0
@export var dash_duration: float = 0.2
@export var dash_cooldown: float = 1.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_polygon: CollisionPolygon2D = $CollisionPolygon2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer

var _spawn_position: Vector2
var _jumps_remaining: int
var _facing_direction: float = 1.0
var _collision_scale: Vector2
var _collision_position: Vector2
var _dash_direction: float = 1.0
var _dash_time_remaining: float = 0.0
var _dash_cooldown_remaining: float = 0.0
var _has_dashed_since_jump: bool = false
var _has_double_jump: bool = false
var _jump_hold_time: float = 0.0
var _jump_start_height: float = 0.0
var _jump_hold_active: bool = false
var score: int = 0
var _is_dead: bool = false
var _has_star_attack: bool = false
var _active_strange_effect: int = -1
var _strange_effect_time_remaining: float = 0.0
var _strange_effect_duration: float = 0.0

const IDLE_ANIMATION: StringName = &"idle"
const RUN_ANIMATION: StringName = &"run"

func add_score(amount: int) -> void:
	score += amount
	score_changed.emit(score)

func grant_star_attack() -> void:
	_has_star_attack = true

func has_star_attack() -> bool:
	return _has_star_attack

func consume_star_attack() -> bool:
	if not _has_star_attack:
		return false
	_has_star_attack = false
	return true

func _ready() -> void:
	_spawn_position = global_position
	_jumps_remaining = 1
	_collision_scale = collision_polygon.scale
	_collision_position = collision_polygon.position
	_reset_strange_effect()
	_apply_facing()

func apply_strange_effect(effect_type: int, duration: float) -> void:
	_active_strange_effect = effect_type
	_strange_effect_time_remaining = maxf(duration, 0.0)
	_strange_effect_duration = _strange_effect_time_remaining
	_update_gravity_orientation()
	strange_effect_changed.emit(
		_active_strange_effect,
		_strange_effect_time_remaining,
		_strange_effect_duration
	)
	if effect_type == EFFECT_INVERT_GRAVITY and _strange_effect_time_remaining > 0.0:
		# Break the previous grounded state immediately so the reversal is visible on contact.
		velocity.y = -maxf(absf(velocity.y), absf(jump_velocity) * 0.5)

func _reset_strange_effect() -> void:
	_active_strange_effect = -1
	_strange_effect_time_remaining = 0.0
	_strange_effect_duration = 0.0
	_update_gravity_orientation()
	strange_effect_changed.emit(-1, 0.0, 0.0)

func _update_gravity_orientation() -> void:
	var inverted: bool = _active_strange_effect == EFFECT_INVERT_GRAVITY and _strange_effect_time_remaining > 0.0
	var orientation_changed: bool = (up_direction == Vector2.DOWN) != inverted
	up_direction = Vector2.DOWN if inverted else Vector2.UP
	if orientation_changed:
		gravity_orientation_changed.emit(inverted)
	if not is_node_ready():
		return
	sprite.flip_v = inverted
	collision_polygon.scale = Vector2(
		-_collision_scale.x if _facing_direction < 0.0 else _collision_scale.x,
		-_collision_scale.y if inverted else _collision_scale.y
	)

func _is_gravity_inverted() -> bool:
	return _active_strange_effect == EFFECT_INVERT_GRAVITY

func is_gravity_inverted() -> bool:
	return _is_gravity_inverted()

func _is_effect_active() -> bool:
	return _active_strange_effect >= 0 and _strange_effect_time_remaining > 0.0

func _get_current_move_speed() -> float:
	if _active_strange_effect == EFFECT_SPEED_BOOST and _is_effect_active():
		return move_speed * speed_boost_multiplier
	return move_speed

func unlock_double_jump() -> void:
	_has_double_jump = true
	max_jumps = 2
	_jumps_remaining = max_jumps

func launch_cloud_bounce(height: float) -> void:
	var bounce_height: float = maxf(height, 0.0)
	var bounce_direction: float = 1.0 if _is_gravity_inverted() else -1.0
	velocity.y = bounce_direction * sqrt(2.0 * gravity * bounce_height)
	_jump_hold_time = 0.0
	_jump_hold_active = false
	_dash_cooldown_remaining = 0.0
	_has_dashed_since_jump = false

func _physics_process(delta: float) -> void:
	if _is_dead:
		return

	if _is_effect_active():
		_strange_effect_time_remaining = maxf(_strange_effect_time_remaining - delta, 0.0)
		strange_effect_changed.emit(
			_active_strange_effect,
			_strange_effect_time_remaining,
			_strange_effect_duration
		)
		if is_zero_approx(_strange_effect_time_remaining):
			_reset_strange_effect()

	_dash_cooldown_remaining = maxf(_dash_cooldown_remaining - delta, 0.0)

	var direction: float = Input.get_axis("move_left", "move_right")
	if _active_strange_effect == EFFECT_INPUT_REVERSE:
		direction = -direction
	if not is_zero_approx(direction):
		_facing_direction = direction
		_apply_facing()

	if Input.is_action_just_pressed("dash") and _can_dash():
		_start_dash(direction)

	if _dash_time_remaining > 0.0:
		_dash_time_remaining = maxf(_dash_time_remaining - delta, 0.0)
		velocity.x = _dash_direction * dash_speed
		velocity.y = 0.0
		move_and_slide()
		_check_ocean_collision()
		if absf(global_position.y - _spawn_position.y) > 800.0:
			die()
		return

	velocity.x = direction * _get_current_move_speed()
	_update_animation(direction)

	var gravity_inverted: bool = _is_gravity_inverted()
	var is_supported: bool = is_on_floor()
	var gravity_sign: float = -1.0 if gravity_inverted else 1.0
	if not is_supported:
		velocity.y += gravity * gravity_sign * delta
	else:
		velocity.y = minf(velocity.y, 0.0) if gravity_inverted else maxf(velocity.y, 0.0)
		_jumps_remaining = max_jumps
		_jump_hold_active = false
		_jump_hold_time = 0.0

	if Input.is_action_just_pressed("jump") and _jumps_remaining > 0:
		velocity.y = -jump_velocity if gravity_inverted else jump_velocity
		_jumps_remaining -= 1
		_jump_start_height = global_position.y
		_jump_hold_time = 0.0
		_jump_hold_active = true
		_dash_cooldown_remaining = 0.0
		_has_dashed_since_jump = false

	_update_jump_hold(delta)

	move_and_slide()
	_clamp_jump_height()
	_check_ocean_collision()
	if absf(global_position.y - _spawn_position.y) > 800.0:
		die()

func _check_ocean_collision() -> void:
	for collision_index: int in range(get_slide_collision_count()):
		var collision: KinematicCollision2D = get_slide_collision(collision_index)
		var tile_map_layer: TileMapLayer = collision.get_collider() as TileMapLayer
		if tile_map_layer == null:
			continue
		var tile_position: Vector2i = tile_map_layer.local_to_map(
			tile_map_layer.to_local(collision.get_position())
		)
		if tile_map_layer.get_cell_source_id(tile_position) == 0:
			die()
			return

func die() -> void:
	if _is_dead:
		return
	_is_dead = true
	velocity = Vector2.ZERO
	died.emit(score)

func _reset_to_spawn() -> void:
	global_position = _spawn_position
	velocity = Vector2.ZERO
	_reset_strange_effect()
	_jumps_remaining = max_jumps if _has_double_jump else 1
	_dash_time_remaining = 0.0
	_dash_cooldown_remaining = 0.0
	_has_dashed_since_jump = false
	_jump_hold_time = 0.0
	_jump_hold_active = false
	_is_dead = false

func _update_jump_hold(delta: float) -> void:
	if not _jump_hold_active:
		return

	if Input.is_action_just_released("jump"):
		_jump_hold_active = false
		velocity.y = maxf(velocity.y, jump_velocity * 0.5)
		return

	_jump_hold_time += delta
	if (
		_jump_hold_time >= jump_hold_duration
		or _has_reached_jump_height()
	):
		_jump_hold_active = false
		return

	velocity.y -= jump_hold_acceleration * delta

func _clamp_jump_height() -> void:
	if not _jump_hold_active:
		return

	var highest_allowed_y: float = _jump_start_height + max_jump_height if _is_gravity_inverted() else _jump_start_height - max_jump_height
	var reached_limit: bool = global_position.y >= highest_allowed_y if _is_gravity_inverted() else global_position.y <= highest_allowed_y
	if reached_limit:
		global_position.y = highest_allowed_y
		velocity.y = 0.0
		_jump_hold_active = false

func _has_reached_jump_height() -> bool:
	if _is_gravity_inverted():
		return global_position.y >= _jump_start_height + max_jump_height
	return global_position.y <= _jump_start_height - max_jump_height

func _can_dash() -> bool:
	return (
		_dash_time_remaining <= 0.0
		and _dash_cooldown_remaining <= 0.0
		and (is_on_floor() or not _has_dashed_since_jump)
	)

func _start_dash(direction: float) -> void:
	_dash_direction = direction if not is_zero_approx(direction) else _facing_direction
	if not is_zero_approx(_dash_direction):
		_facing_direction = _dash_direction
		_apply_facing()
	_dash_time_remaining = dash_duration
	_dash_cooldown_remaining = dash_cooldown
	if not is_on_floor():
		_has_dashed_since_jump = true

func _update_animation(direction: float) -> void:
	if not is_zero_approx(direction):
		_play_animation(RUN_ANIMATION)
	else:
		_play_animation(IDLE_ANIMATION)

func _apply_facing() -> void:
	var facing_left: bool = _facing_direction < 0.0
	sprite.flip_h = facing_left
	collision_polygon.scale = Vector2(
		-_collision_scale.x if facing_left else _collision_scale.x,
		-_collision_scale.y if _is_gravity_inverted() else _collision_scale.y
	)
	# Mirror the collision around the sprite pivot so an offset polygon follows the flipped art.
	collision_polygon.position = Vector2(
		2.0 * sprite.position.x - _collision_position.x if facing_left else _collision_position.x,
		_collision_position.y
	)

func _play_animation(animation_name: StringName) -> void:
	if animation_player.current_animation != animation_name:
		animation_player.play(animation_name)
