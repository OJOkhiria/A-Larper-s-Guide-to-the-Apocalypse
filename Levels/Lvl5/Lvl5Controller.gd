class_name BombShelterController
extends Node

@export var bomb_scene: PackedScene
@export var spawn_point_paths: Array[NodePath] = []
@export var blast_door_collision_path: NodePath
@export var confrontation_area_path: NodePath
@export var exit_path: NodePath
@export var objective_label_path: NodePath
@export var blast_door_visual_path: NodePath
@export_range(0.0, 15.0, 0.5) var bomb_start_delay := 5.0

var consoles_activated := 0
var required_consoles := 3
var encounter_active := true
var next_spawn_index := 0
var spawn_points: Array[Marker2D] = []

@onready var bomb_timer: Timer = $BombTimer


func _ready() -> void:
	for spawn_path in spawn_point_paths:
		var spawn_point := get_node_or_null(spawn_path) as Marker2D
		if spawn_point != null:
			spawn_points.append(spawn_point)

	for console in get_tree().get_nodes_in_group("shelter_consoles"):
		if console.has_signal("activated"):
			console.activated.connect(_on_console_activated)

	bomb_timer.timeout.connect(_spawn_bomb)
	_update_objective("Disarm the shelter controls: 0 / %d" % required_consoles)
	await get_tree().create_timer(bomb_start_delay).timeout
	if encounter_active:
		bomb_timer.start()


func _spawn_bomb() -> void:
	if not encounter_active or bomb_scene == null or spawn_points.is_empty():
		return

	var bomb := bomb_scene.instantiate() as Bomb
	if bomb == null:
		return

	var spawn_point := spawn_points[next_spawn_index % spawn_points.size()]
	next_spawn_index += 1
	get_tree().current_scene.add_child(bomb)
	bomb.global_position = spawn_point.global_position
	bomb.launch(-1.0)


func _on_console_activated(_console_id: StringName) -> void:
	consoles_activated += 1
	_update_objective("Disarm the shelter controls: %d / %d" % [consoles_activated, required_consoles])

	if consoles_activated >= required_consoles:
		_unlock_confrontation()


func _unlock_confrontation() -> void:
	encounter_active = false
	bomb_timer.stop()

	var door_collision := get_node_or_null(blast_door_collision_path) as CollisionShape2D
	if door_collision != null:
		door_collision.set_deferred("disabled", true)

	var door_visual := get_node_or_null(blast_door_visual_path) as CanvasItem
	if door_visual != null:
		door_visual.hide()

	var confrontation_area := get_node_or_null(confrontation_area_path) as Area2D
	if confrontation_area != null:
		confrontation_area.monitoring = true

	_update_objective("The blast door is open. Confront the bomber.")


func choose_boundary() -> void:
	_finish_confrontation("You stopped the final bomb without turning away from the harm it caused.")


func choose_connection() -> void:
	_finish_confrontation("You stopped the final bomb and refused to leave someone alone with their worst choice.")


func _finish_confrontation(summary: String) -> void:
	encounter_active = false
	bomb_timer.stop()

	for bomb in get_tree().get_nodes_in_group("bomber_bombs"):
		bomb.queue_free()

	var exit_area := get_node_or_null(exit_path) as Area2D
	if exit_area != null:
		exit_area.monitoring = true

	_update_objective(summary + " Reach the evacuation exit.")


func _update_objective(text: String) -> void:
	var label := get_node_or_null(objective_label_path) as Label
	if label != null:
		label.text = text
