extends CanvasLayer

@export var full_heart_texture: Texture2D
@export var empty_heart_texture: Texture2D
@export var heart_size: Vector2 = Vector2(32, 32)

@onready var hearts_container: HBoxContainer = $HealthHUD/Hearts

var health: Node


func _ready() -> void:
	var player := get_tree().get_first_node_in_group("player")

	if not player:
		push_warning("Health HUD could not find the player.")
		return

	health = player.get_node_or_null("Health")

	if not health:
		push_warning("Health HUD could not find the player's Health node.")
		return

	health.health_changed.connect(_on_health_changed)

	# Draw the initial hearts immediately.
	_on_health_changed(health.current_health, health.max_health)


func _on_health_changed(current_health: int, max_health: int) -> void:
	_set_heart_count(max_health)

	for index in range(hearts_container.get_child_count()):
		var heart := hearts_container.get_child(index) as TextureRect

		if not heart:
			continue

		if index < current_health:
			heart.texture = full_heart_texture
		else:
			heart.texture = empty_heart_texture


func _set_heart_count(required_count: int) -> void:
	while hearts_container.get_child_count() < required_count:
		_create_heart()

	while hearts_container.get_child_count() > required_count:
		var last_index := hearts_container.get_child_count() - 1
		var last_heart := hearts_container.get_child(last_index)

		hearts_container.remove_child(last_heart)
		last_heart.queue_free()


func _create_heart() -> void:
	var heart := TextureRect.new()

	heart.custom_minimum_size = heart_size
	heart.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	heart.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	heart.mouse_filter = Control.MOUSE_FILTER_IGNORE

	hearts_container.add_child(heart)
