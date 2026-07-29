extends Area2D

@export var destination_level_index: int = -1

var transition_started: bool = false


func _ready() -> void:
	# Connect in code so every exit area using this script works even when its
	# scene does not contain a serialized signal connection.
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

	monitoring = true


func _on_body_entered(body: Node2D) -> void:
	if transition_started or not body.is_in_group("player"):
		return

	transition_started = true
	set_deferred("monitoring", false)
	# Change scenes outside the physics callback to avoid modifying the scene
	# tree while collision queries are being processed.
	if destination_level_index >= 0:
		LvlManager.call_deferred(
			"load_level",
			destination_level_index
		)
	else:
		LvlManager.call_deferred("load_next_level")
