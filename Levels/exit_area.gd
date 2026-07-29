extends Area2D

@export var destination_level_index: int = -1
@export var fade_duration: float = 0.65

@onready var fade_rect: ColorRect = $FadeLayer/FadeRect

var transition_started: bool = false


func _ready() -> void:
	# Connect in code so every exit area using this script works even when its
	# scene does not contain a serialized signal connection.
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

	monitoring = true
	fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade_rect.visible = true
	fade_rect.modulate.a = 0.0
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _on_body_entered(body: Node2D) -> void:
	if transition_started or not body.is_in_group("player"):
		return

	transition_started = true
	set_deferred("monitoring", false)
	await _fade_to_black()

	if destination_level_index >= 0:
		LvlManager.load_level(destination_level_index)
	else:
		LvlManager.load_next_level()


func _fade_to_black() -> void:
	fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(
		fade_rect,
		"modulate:a",
		1.0,
		fade_duration
	)

	await tween.finished
