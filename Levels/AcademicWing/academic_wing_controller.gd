class_name AcademicWingController
extends Node

@export var gate_collision_path: NodePath
@export var exit_path: NodePath
@export var objective_label_path: NodePath

var consoles_activated: int = 0
var required_consoles := 3


func _ready() -> void:
	for console in get_tree().get_nodes_in_group("academic_consoles"):
		if console.has_signal("activated"):
			console.activated.connect(_on_console_activated)
	_update_objective("Restore emergency power: 0 / %d" % required_consoles)


func _on_console_activated(_console_id: StringName) -> void:
	consoles_activated += 1
	_update_objective(
		"Restore emergency power: %d / %d" % [consoles_activated, required_consoles]
	)

	if consoles_activated >= required_consoles:
		_open_evacuation_route()


func _open_evacuation_route() -> void:
	var gate_collision := get_node_or_null(gate_collision_path) as CollisionShape2D
	if gate_collision != null:
		gate_collision.set_deferred("disabled", true)

	var exit_area := get_node_or_null(exit_path) as Area2D
	if exit_area != null:
		exit_area.monitoring = true

	_update_objective("Emergency route restored. Reach the maintenance shelter.")


func _update_objective(text: String) -> void:
	var label := get_node_or_null(objective_label_path) as Label
	if label != null:
		label.text = text
