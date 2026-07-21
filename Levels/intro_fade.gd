extends ColorRect

@export var fade_duration: float = 0.65


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	modulate.a = 1.0
	mouse_filter = Control.MOUSE_FILTER_STOP

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)

	tween.tween_property(
		self,
		"modulate:a",
		0.0,
		fade_duration
	)

	await tween.finished

	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_free()
