class_name MainMenu
extends Control

const GAME_SCENE_PATH: String = "res://scenes/main.tscn"
const HIGH_SCORE_SECTION: String = "score"
const HIGH_SCORE_KEY: String = "high_score"
const SETTINGS_SAVE_PATH: String = "user://save.cfg"
const SETTINGS_SECTION: String = "settings"
const DEATH_BOUNDARY_KEY: String = "death_boundary_enabled"

@onready var start_button: Button = $Center/Panel/Content/StartButton
@onready var settings_button: Button = $Center/Panel/Content/SettingsButton
@onready var quit_button: Button = $Center/Panel/Content/QuitButton
@onready var high_score_label: Label = $Center/Panel/Content/HighScoreLabel
@onready var main_panel: PanelContainer = $Center/Panel
@onready var settings_center: CenterContainer = $SettingsCenter
@onready var death_boundary_check: CheckButton = $SettingsCenter/Panel/Content/DeathBoundaryCheck
@onready var settings_back_button: Button = $BackButton

func _ready() -> void:
	start_button.pressed.connect(_on_start_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	death_boundary_check.toggled.connect(_on_death_boundary_toggled)
	settings_back_button.pressed.connect(_on_settings_back_pressed)
	high_score_label.text = "历史最高分：%d" % _load_high_score()
	_set_death_boundary_control(_load_death_boundary_setting())
	start_button.grab_focus()

func _load_high_score() -> int:
	var config: ConfigFile = ConfigFile.new()
	if config.load(_get_high_score_save_path()) != OK:
		return 0
	return int(config.get_value(HIGH_SCORE_SECTION, HIGH_SCORE_KEY, 0))

func _get_high_score_save_path() -> String:
	# Keep exported builds separate from the editor's development save.
	return "user://save.cfg" if OS.has_feature("editor") else "user://export_save.cfg"

func _load_death_boundary_setting() -> bool:
	var config: ConfigFile = ConfigFile.new()
	if config.load(SETTINGS_SAVE_PATH) != OK:
		return true
	var value: Variant = config.get_value(SETTINGS_SECTION, DEATH_BOUNDARY_KEY, true)
	return value is bool and value

func _save_death_boundary_setting(enabled: bool) -> void:
	var config: ConfigFile = ConfigFile.new()
	config.load(SETTINGS_SAVE_PATH)
	config.set_value(SETTINGS_SECTION, DEATH_BOUNDARY_KEY, enabled)
	config.save(SETTINGS_SAVE_PATH)

func _set_death_boundary_control(enabled: bool) -> void:
	death_boundary_check.button_pressed = enabled
	var text: String = "死亡边界：开启" if enabled else "死亡边界：关闭"
	death_boundary_check.text = text

func _on_settings_pressed() -> void:
	main_panel.visible = false
	settings_center.visible = true
	settings_back_button.visible = true
	_set_death_boundary_control(_load_death_boundary_setting())
	death_boundary_check.grab_focus()

func _on_death_boundary_toggled(enabled: bool) -> void:
	_set_death_boundary_control(enabled)
	_save_death_boundary_setting(enabled)

func _on_settings_back_pressed() -> void:
	settings_center.visible = false
	settings_back_button.visible = false
	main_panel.visible = true
	settings_button.grab_focus()

func _on_start_pressed() -> void:
	get_tree().change_scene_to_file(GAME_SCENE_PATH)

func _on_quit_pressed() -> void:
	get_tree().quit()
