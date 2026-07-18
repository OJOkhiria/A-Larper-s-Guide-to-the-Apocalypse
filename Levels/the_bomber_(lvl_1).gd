extends CharacterBody2D

@export var bomb_scene: PackedScene
@export var throw_interval: float = 2.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var bomb_spawn_point: Marker2D = $BombSpawnPoint
@onready var throw_cooldown: Timer = $ThrowCooldown

var player: Node2D
var player_detected: bool = false


func _ready() -> void:
	$DetectionArea.body_entered.connect(_on_detection_area_body_entered)
	$DetectionArea.body_exited.connect(_on_detection_area_body_exited)

	throw_cooldown.wait_time = throw_interval
	throw_cooldown.one_shot = false
	throw_cooldown.timeout.connect(_throw_bomb)


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return

	player = body
	player_detected = true
	throw_cooldown.start()

	_throw_bomb()


func _on_detection_area_body_exited(body: Node2D) -> void:
	if body != player:
		return

	player = null
	player_detected = false
	throw_cooldown.stop()


func _throw_bomb() -> void:
	if not player_detected or not is_instance_valid(player):
		return

	if bomb_scene == null:
		push_warning("No bomb scene assigned to enemy.")
		return

	sprite.play("throw")

	var bomb := bomb_scene.instantiate() as Bomb
	get_tree().current_scene.add_child(bomb)

	bomb.global_position = bomb_spawn_point.global_position

	var direction := global_position.direction_to(player.global_position)
	bomb.launch(direction)


func _on_detection_area_body_entered(body: Node2D) -> void:
	pass # Replace with function body.
