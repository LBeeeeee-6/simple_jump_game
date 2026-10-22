class_name MainGame
extends Node2D

const MUSIC_TRACKS: Array[AudioStream] = [
	preload("res://audio/青韵1.mp3"),
	preload("res://audio/青韵2.mp3"),
]
const HIGH_SCORE_SECTION: String = "score"
const HIGH_SCORE_KEY: String = "high_score"
const SETTINGS_SAVE_PATH: String = "user://save.cfg"
const SETTINGS_SECTION: String = "settings"
const DEATH_BOUNDARY_KEY: String = "death_boundary_enabled"

@export var map_chunk_scene: PackedScene = preload("res://tile_map.scn")
@export var chunk_width: float = 3296.0
@export var initial_chunks: int = 2
@export var generate_ahead: float = 1200.0
@export var recycle_behind: float = 2400.0

@onready var map_chunks: Node2D = $MapChunks
@onready var score_label: Label = $HUD/ScoreLabel
@onready var death_overlay: Control = $HUD/DeathOverlay
@onready var final_score_label: Label = $HUD/DeathOverlay/FinalScoreLabel
@onready var pause_overlay: Control = $HUD/PauseOverlay
@onready var return_menu_button: Button = $HUD/PauseOverlay/Panel/Content/ReturnMenuButton
@onready var resume_button: Button = $HUD/PauseOverlay/Panel/Content/ResumeButton
@onready var quit_button: Button = $HUD/PauseOverlay/Panel/Content/QuitButton
@onready var music_player: AudioStreamPlayer = $MusicPlayer
@onready var effect_status: VBoxContainer = $HUD/EffectStatus
@onready var effect_label: Label = $HUD/EffectStatus/EffectLabel
@onready var effect_timer: ProgressBar = $HUD/EffectStatus/EffectTimer
@onready var death_boundary: DeathBoundary = $DeathBoundary

var _chunks: Array[Node2D] = []
var _player: PlayerController
var _music_index: int = 0
var _next_chunk_x: float = 0.0
var _world_start_x: float = 0.0
var _current_world_index: int = 0
var _normal_collision_tile_set: TileSet
var _inverted_collision_tile_set: TileSet
var _death_boundary_camera: Camera2D

func _ready() -> void:
	music_player.finished.connect(_on_music_finished)
	_play_current_music()
	var first_chunk: Node2D = $MapChunks/TileMapChunk
	chunk_width = _get_chunk_width(first_chunk)
	_world_start_x = first_chunk.global_position.x
	_chunks.append(first_chunk)
	_player = first_chunk.get_node_or_null("Development/Player") as PlayerController
	if _player != null:
		# Main uses always-process mode for the pause menu, so the player must
		# explicitly use pausable processing.
		_player.process_mode = Node.PROCESS_MODE_PAUSABLE
		# The player must outlive recycled map chunks.
		_player.reparent(self, true)
		_player.z_as_relative = false
		_player.z_index = 0
		_player.score_changed.connect(_on_score_changed)
		_player.died.connect(_on_player_died)
		_player.gravity_orientation_changed.connect(_on_gravity_orientation_changed)
		_player.strange_effect_changed.connect(_on_strange_effect_changed)
		_on_score_changed(_player.score)
		_prepare_collision_tile_sets(first_chunk)
		_set_collision_orientation(_player.is_gravity_inverted())
		_start_death_boundary_if_enabled()
	return_menu_button.pressed.connect(_on_return_menu_pressed)
	resume_button.pressed.connect(_on_resume_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	_next_chunk_x = first_chunk.position.x + chunk_width
	for _index: int in range(maxi(initial_chunks - 1, 0)):
		_add_chunk()
	_on_strange_effect_changed(-1, 0.0, 0.0)

func _play_current_music() -> void:
	music_player.stream = MUSIC_TRACKS[_music_index]
	music_player.play()

func _on_music_finished() -> void:
	_music_index = (_music_index + 1) % MUSIC_TRACKS.size()
	_play_current_music()

func _is_death_boundary_enabled() -> bool:
	var config: ConfigFile = ConfigFile.new()
	if config.load(SETTINGS_SAVE_PATH) != OK:
		return true
	var value: Variant = config.get_value(SETTINGS_SECTION, DEATH_BOUNDARY_KEY, true)
	return value is bool and value

func _get_high_score_save_path() -> String:
	# Keep exported builds separate from the editor's development save.
	return "user://save.cfg" if OS.has_feature("editor") else "user://export_save.cfg"

func _start_death_boundary_if_enabled() -> void:
	if _player == null:
		return
	if not _is_death_boundary_enabled():
		death_boundary.set_physics_process(false)
		return
	death_boundary.setup(_player)
	death_boundary.set_world_index(_current_world_index)
	death_boundary.set_physics_process(true)
	_setup_death_boundary_camera()

func _setup_death_boundary_camera() -> void:
	var player_camera: Camera2D = _player.get_node_or_null("Camera2D") as Camera2D
	if player_camera == null:
		return
	player_camera.reparent(self, true)
	player_camera.process_mode = Node.PROCESS_MODE_PAUSABLE
	player_camera.anchor_mode = Camera2D.ANCHOR_MODE_DRAG_CENTER
	player_camera.make_current()
	_death_boundary_camera = player_camera
	_update_death_boundary_camera()

func _update_death_boundary_camera() -> void:
	if _death_boundary_camera == null or _player == null:
		return
	var viewport_width: float = _death_boundary_camera.get_viewport().get_visible_rect().size.x
	var half_visible_width: float = viewport_width * 0.5 / _death_boundary_camera.zoom.x
	var player_sprite: Sprite2D = _player.get_node_or_null("Sprite2D") as Sprite2D
	var camera_y: float = player_sprite.global_position.y if player_sprite != null else _player.global_position.y
	_death_boundary_camera.global_position = Vector2(
		death_boundary.global_position.x + half_visible_width,
		camera_y
	)

func _get_chunk_width(chunk: Node2D) -> float:
	var collision_layer: TileMapLayer = chunk.get_node_or_null("Layers/CollisionLayer") as TileMapLayer
	if collision_layer == null or collision_layer.tile_set == null:
		return chunk_width

	var used_rect: Rect2i = collision_layer.get_used_rect()
	var tile_width: int = collision_layer.tile_set.tile_size.x
	return float(used_rect.size.x * tile_width) * collision_layer.scale.x

func _prepare_collision_tile_sets(chunk: Node2D) -> void:
	var collision_layer: TileMapLayer = chunk.get_node_or_null("Layers/CollisionLayer") as TileMapLayer
	if collision_layer == null or collision_layer.tile_set == null:
		return
	_normal_collision_tile_set = collision_layer.tile_set
	_inverted_collision_tile_set = _create_inverted_collision_tile_set(_normal_collision_tile_set)

func _create_inverted_collision_tile_set(source_tile_set: TileSet) -> TileSet:
	var inverted_tile_set: TileSet = source_tile_set.duplicate(true) as TileSet
	for source_index: int in range(inverted_tile_set.get_source_count()):
		var source_id: int = inverted_tile_set.get_source_id(source_index)
		var atlas_source: TileSetAtlasSource = inverted_tile_set.get_source(source_id) as TileSetAtlasSource
		if atlas_source == null:
			continue
		for tile_index: int in range(atlas_source.get_tiles_count()):
			var atlas_coords: Vector2i = atlas_source.get_tile_id(tile_index)
			var tile_data: TileData = atlas_source.get_tile_data(atlas_coords, 0)
			if tile_data == null:
				continue
			for polygon_index: int in range(tile_data.get_collision_polygons_count(0)):
				if not tile_data.is_collision_polygon_one_way(0, polygon_index):
					continue
				var points: PackedVector2Array = tile_data.get_collision_polygon_points(0, polygon_index)
				var reversed_points: PackedVector2Array = PackedVector2Array()
				for point_index: int in range(points.size() - 1, -1, -1):
					reversed_points.append(points[point_index])
				tile_data.set_collision_polygon_points(0, polygon_index, reversed_points)
	return inverted_tile_set

func _on_gravity_orientation_changed(inverted: bool) -> void:
	_set_collision_orientation(inverted)

func _set_collision_orientation(inverted: bool) -> void:
	var active_tile_set: TileSet = _inverted_collision_tile_set if inverted else _normal_collision_tile_set
	if active_tile_set == null:
		return
	for chunk: Node2D in _chunks:
		_apply_collision_tile_set(chunk, active_tile_set)

func _apply_collision_tile_set(chunk: Node2D, tile_set: TileSet) -> void:
	var collision_layer: TileMapLayer = chunk.get_node_or_null("Layers/CollisionLayer") as TileMapLayer
	if collision_layer != null:
		collision_layer.tile_set = tile_set

func _on_score_changed(new_score: int) -> void:
	if score_label != null:
		score_label.text = "分数：%d" % new_score

func _on_strange_effect_changed(effect_type: int, remaining: float, duration: float) -> void:
	if effect_type < 0 or remaining <= 0.0 or duration <= 0.0:
		effect_status.visible = false
		return
	effect_status.visible = true
	if effect_type == PlayerController.EFFECT_INPUT_REVERSE:
		effect_label.text = "左右反转"
	elif effect_type == PlayerController.EFFECT_INVERT_GRAVITY:
		effect_label.text = "重力反转"
	else:
		effect_label.text = "速度提升"
	effect_timer.max_value = duration
	effect_timer.value = remaining

func _on_player_died(final_score: int) -> void:
	_save_high_score(final_score)
	final_score_label.text = "最终分数：%d" % final_score
	death_overlay.visible = true
	get_tree().paused = true

func _save_high_score(final_score: int) -> void:
	var config: ConfigFile = ConfigFile.new()
	config.load(_get_high_score_save_path())
	var high_score: int = int(config.get_value(HIGH_SCORE_SECTION, HIGH_SCORE_KEY, 0))
	if final_score <= high_score:
		return
	config.set_value(HIGH_SCORE_SECTION, HIGH_SCORE_KEY, final_score)
	config.save(_get_high_score_save_path())

func _toggle_pause_menu() -> void:
	if death_overlay.visible:
		return
	var should_pause: bool = not pause_overlay.visible
	pause_overlay.visible = should_pause
	get_tree().paused = should_pause
	if should_pause:
		return_menu_button.grab_focus()

func _on_return_menu_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://main_menu.tscn")

func _on_resume_pressed() -> void:
	pause_overlay.visible = false
	get_tree().paused = false

func _on_quit_pressed() -> void:
	get_tree().quit()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_toggle_pause_menu()
		return
	if not get_tree().paused or not death_overlay.visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		get_tree().paused = false
		get_tree().reload_current_scene()

func _physics_process(_delta: float) -> void:
	if _player == null or get_tree().paused:
		return
	_update_death_boundary_speed()
	_update_death_boundary_player_position()
	while _player.global_position.x + generate_ahead >= _next_chunk_x:
		_add_chunk()
	_recycle_chunks()
	_update_death_boundary_camera()

func _update_death_boundary_speed() -> void:
	if chunk_width <= 0.0:
		return
	var passed_worlds: int = maxi(floori((_player.global_position.x - _world_start_x) / chunk_width), 0)
	if passed_worlds == _current_world_index:
		return
	_current_world_index = passed_worlds
	death_boundary.set_world_index(_current_world_index)

func _update_death_boundary_player_position() -> void:
	if _death_boundary_camera == null:
		return
	death_boundary.set_player_ahead(_player.global_position.x > _death_boundary_camera.global_position.x)

func _add_chunk() -> void:
	var chunk: Node2D = map_chunk_scene.instantiate() as Node2D
	chunk.name = "TileMapChunk_%03d" % _chunks.size()
	chunk.position.x = _next_chunk_x
	map_chunks.add_child(chunk)
	_apply_collision_tile_set(chunk, _inverted_collision_tile_set if _player.is_gravity_inverted() else _normal_collision_tile_set)
	var duplicate_player: Node = chunk.get_node_or_null("Development")
	if duplicate_player != null:
		duplicate_player.queue_free()
	_chunks.append(chunk)
	_next_chunk_x += chunk_width

func _recycle_chunks() -> void:
	while _chunks.size() > 1:
		var first_chunk: Node2D = _chunks[0]
		var first_chunk_end_x: float = first_chunk.global_position.x + chunk_width
		# Keep the current chunk until the player has completely crossed it.
		# Recycling earlier leaves a gap before the next TileMap chunk begins.
		if first_chunk_end_x + recycle_behind >= _player.global_position.x:
			break
		var old_chunk: Node2D = _chunks.pop_front()
		old_chunk.queue_free()
