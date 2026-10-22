class_name LevelGenerator
extends Node2D

@export var player_path: NodePath = NodePath("../Development/Player")
@export var segment_width: float = 320.0
@export var platform_height: float = 171.0
@export var initial_segments: int = 5
@export var generation_ahead: float = 900.0
@export var cleanup_behind: float = 900.0
@export var ocean_probability: float = 0.25
@export var random_seed: int = 1337

const GRASS_TEXTURE: String = "res://pictureResource/草原地形.png"
const OCEAN_TEXTURE: String = "res://pictureResource/海洋.png"

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _next_segment_x: float = 0.0
var _active_segments: Array[Node2D] = []
var _player: PlayerController

func _ready() -> void:
	_player = get_node_or_null(player_path) as PlayerController
	_rng.seed = random_seed
	_next_segment_x = 0.0
	for _index: int in range(initial_segments):
		_generate_segment()

func _physics_process(_delta: float) -> void:
	if _player == null:
		return
	while _next_segment_x < _player.global_position.x + generation_ahead:
		_generate_segment()
	_cleanup_segments()

func reset_run() -> void:
	for segment: Node2D in _active_segments:
		segment.queue_free()
	_active_segments.clear()
	_rng.seed = random_seed
	_next_segment_x = 0.0
	for _index: int in range(initial_segments):
		_generate_segment()

func _generate_segment() -> void:
	var segment: Node2D = Node2D.new()
	segment.name = "GeneratedSegment_%03d" % _active_segments.size()
	segment.position = Vector2(_next_segment_x, platform_height)
	add_child(segment)
	_active_segments.append(segment)

	var make_ocean: bool = _active_segments.size() > 2 and _rng.randf() < ocean_probability
	if make_ocean:
		_create_ocean(segment)
	else:
		_create_grass_platform(segment)
	_next_segment_x += segment_width

func _create_grass_platform(segment: Node2D) -> void:
	var sprite: Sprite2D = Sprite2D.new()
	sprite.texture = load(GRASS_TEXTURE) as Texture2D
	sprite.region_enabled = true
	sprite.region_rect = Rect2(0.0, 0.0, segment_width * 2.0, 64.0)
	sprite.scale = Vector2(0.5, 0.5)
	segment.add_child(sprite)

	var body: StaticBody2D = StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 2
	segment.add_child(body)
	var shape_node: CollisionShape2D = CollisionShape2D.new()
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = Vector2(segment_width, 32.0)
	shape_node.shape = shape
	shape_node.position = Vector2.ZERO
	body.add_child(shape_node)

func _create_ocean(segment: Node2D) -> void:
	var sprite: Sprite2D = Sprite2D.new()
	sprite.texture = load(OCEAN_TEXTURE) as Texture2D
	sprite.region_enabled = true
	sprite.region_rect = Rect2(0.0, 0.0, segment_width * 2.0, 64.0)
	sprite.scale = Vector2(0.5, 0.5)
	segment.add_child(sprite)

	var hazard: OceanHazard = OceanHazard.new()
	hazard.collision_layer = 4
	hazard.collision_mask = 2
	segment.add_child(hazard)
	var shape_node: CollisionShape2D = CollisionShape2D.new()
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = Vector2(segment_width, 96.0)
	shape_node.shape = shape
	shape_node.position = Vector2(0.0, 32.0)
	hazard.add_child(shape_node)

func _cleanup_segments() -> void:
	while not _active_segments.is_empty():
		var first: Node2D = _active_segments[0]
		if first.global_position.x > _player.global_position.x - cleanup_behind:
			break
		_active_segments.pop_front()
		first.queue_free()
