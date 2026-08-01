class_name AcademicWingController
extends Node

@export var exit_barrier_collision_path: NodePath
@export var exit_barrier_path: NodePath
@export var electrical_hazard_path: NodePath
@export var exit_path: NodePath
@export var objective_label_path: NodePath

var consoles_activated: int = 0
var required_consoles := 3


func _ready() -> void:
	for console in get_tree().get_nodes_in_group("academic_consoles"):
		if console.has_signal("activated"):
			console.activated.connect(_on_console_activated)
	_update_objective("Shut down the exit circuit: 0 / %d" % required_consoles)


func _on_console_activated(_console_id: StringName) -> void:
	consoles_activated += 1
	_update_objective(
		"Shut down the exit circuit: %d / %d" % [consoles_activated, required_consoles]
	)

	if consoles_activated >= required_consoles:
		_shut_down_exit_hazard()


func _shut_down_exit_hazard() -> void:
	var electrical_hazard := get_node_or_null(electrical_hazard_path) as Area2D
	if electrical_hazard != null:
		electrical_hazard.set_deferred("monitoring", false)
		electrical_hazard.visible = false

	var barrier_collision := get_node_or_null(exit_barrier_collision_path) as CollisionShape2D
	if barrier_collision != null:
		barrier_collision.set_deferred("disabled", true)

	var barrier := get_node_or_null(exit_barrier_path) as StaticBody2D
	if barrier != null:
		for child in barrier.get_children():
			if child is CollisionShape2D:
				child.set_deferred("disabled", true)

	var exit_area := get_node_or_null(exit_path) as Area2D
	if exit_area != null:
		exit_area.monitoring = true

	_update_objective("Exit circuit discharged. Reach the maintenance shelter.")


func _update_objective(text: String) -> void:
	var label := get_node_or_null(objective_label_path) as Label
	if label != null:
		label.text = text
