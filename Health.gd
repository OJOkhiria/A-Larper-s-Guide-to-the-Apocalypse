class_name Health
extends Node

signal health_changed(current_health: int, max_health: int)
signal died(death_source: Node)

@export var max_health: int = 3
@export var maximum_health_cap: int = 10
@export var use_player_data: bool = false

var current_health: int
var is_dead: bool = false


func _ready() -> void:
	if use_player_data:
		max_health = PlayerData.max_health

	current_health = max_health
	health_changed.emit(current_health, max_health)


func take_damage(amount: int, source: Node = null) -> void:
	if amount <= 0 or is_dead:
		return

	current_health = maxi(current_health - amount, 0)
	health_changed.emit(current_health, max_health)

	if current_health <= 0:
		is_dead = true
		died.emit(source)


func heal(amount: int) -> void:
	if amount <= 0 or is_dead:
		return

	current_health = min(current_health + amount, max_health)
	health_changed.emit(current_health, max_health)


func increase_max_health(amount: int = 1, heal_added_health: bool = true) -> void:
	if amount <= 0:
		return

	var old_max_health: int = max_health
	max_health = min(max_health + amount, maximum_health_cap)

	var actual_increase: int = max_health - old_max_health

	if heal_added_health:
		current_health = min(current_health + actual_increase, max_health)

	if use_player_data:
		PlayerData.max_health = max_health

	health_changed.emit(current_health, max_health)


func set_max_health(value: int, heal_to_full: bool = false) -> void:
	max_health = clampi(value, 1, maximum_health_cap)

	if heal_to_full:
		current_health = max_health
	else:
		current_health = min(current_health, max_health)

	health_changed.emit(current_health, max_health)


func restore_full_health() -> void:
	if is_dead:
		return

	current_health = max_health
	health_changed.emit(current_health, max_health)
