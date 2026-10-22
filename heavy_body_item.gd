class_name HeavyBodyItem
extends Area2D

@export var effect_duration: float = 5.0
@export_range(0.1, 1.0, 0.05) var jump_height_multiplier: float = 0.6

@onready var effect_timer: Timer = $EffectTimer
@onready var effect_status: VBoxContainer = $EffectStatus/Panel
@onready var effect_label: Label = $EffectStatus/Panel/EffectLabel
@onready var effect_timer_bar: ProgressBar = $EffectStatus/Panel/EffectTimer

var _consumed: bool = false
var _affected_player: PlayerController
var _original_jump_velocity: float = 0.0
var _original_jump_hold_acceleration: float = 0.0
var _original_max_jump_height: float = 0.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	effect_timer.timeout.connect(_on_effect_timer_timeout)
	set_process(false)

func _on_body_entered(body: Node2D) -> void:
	if _consumed or not body is PlayerController:
		return

	_consumed = true
	monitoring = false
	monitorable = false
	_affected_player = body as PlayerController
	$Sprite2D.visible = false
	effect_status.visible = true
	effect_label.text = "身体沉重"
	effect_timer_bar.max_value = maxf(effect_duration, 0.0)
	effect_timer_bar.value = maxf(effect_duration, 0.0)
	set_process(true)
	_original_jump_velocity = _affected_player.jump_velocity
	_original_jump_hold_acceleration = _affected_player.jump_hold_acceleration
	_original_max_jump_height = _affected_player.max_jump_height
	var height_multiplier: float = clampf(jump_height_multiplier, 0.1, 1.0)
	_affected_player.jump_velocity = _original_jump_velocity * sqrt(height_multiplier)
	_affected_player.jump_hold_acceleration = _original_jump_hold_acceleration * height_multiplier
	_affected_player.max_jump_height = _original_max_jump_height * height_multiplier
	_affected_player.add_score(1000)
	effect_timer.start(maxf(effect_duration, 0.0))

func _process(_delta: float) -> void:
	effect_timer_bar.value = effect_timer.time_left

func _on_effect_timer_timeout() -> void:
	if is_instance_valid(_affected_player):
		_affected_player.jump_velocity = _original_jump_velocity
		_affected_player.jump_hold_acceleration = _original_jump_hold_acceleration
		_affected_player.max_jump_height = _original_max_jump_height
	effect_status.visible = false
	queue_free()
