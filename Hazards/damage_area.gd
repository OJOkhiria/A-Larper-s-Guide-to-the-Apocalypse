class_name DamageArea
extends Area2D

@export var damage: int = 1
@export var death_source_id: StringName = &"falling_object"
@export_range(0.1, 10.0, 0.1) var damage_interval := 1.0

var damage_cooldowns: Dictionary = {}


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	for body in damage_cooldowns:
		damage_cooldowns[body] = maxf(float(damage_cooldowns[body]) - delta, 0.0)

	if not monitoring:
		return

	for body in get_overlapping_bodies():
		if body.is_in_group("player"):
			_apply_damage(body)


func _on_body_entered(body: Node2D) -> void:
	_apply_damage(body)


func _apply_damage(body: Node2D) -> void:
	if not body.is_in_group("player") or float(damage_cooldowns.get(body, 0.0)) > 0.0:
		return

	var health := body.get_node_or_null("Health")
	if health != null and health.has_method("take_damage"):
		health.take_damage(damage, self)
		damage_cooldowns[body] = damage_interval


func get_death_source_id() -> StringName:
	return death_source_id
