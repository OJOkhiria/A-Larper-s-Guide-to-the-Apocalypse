class_name MatchaPickup
extends Area2D


@export var max_health_increase: int = 1
@export var persistent_item_id: StringName = &""

var collected: bool = false


func _ready() -> void:
	if (
		persistent_item_id != &""
		and PlayerData.has_collected_item(persistent_item_id)
	):
		queue_free()
		return

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if collected or not body.is_in_group("player"):
		return

	var health := body.get_node_or_null("Health")
	if health == null or not health.has_method("increase_max_health"):
		return

	collected = true
	# Area2D state cannot be changed while body_entered is emitting.
	set_deferred("monitoring", false)
	health.increase_max_health(max_health_increase)

	if persistent_item_id != &"":
		PlayerData.mark_item_collected(persistent_item_id)

	# Defer removal until the Area2D collision callback has completed.
	call_deferred("queue_free")
