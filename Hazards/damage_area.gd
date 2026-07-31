class_name DamageArea
extends Area2D

@export var damage: int = 5
@export var death_source_id: StringName = &"falling_object"


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return

	var health := body.get_node_or_null("Health")
	if health != null and health.has_method("take_damage"):
		health.take_damage(damage, self)


func get_death_source_id() -> StringName:
	return death_source_id
