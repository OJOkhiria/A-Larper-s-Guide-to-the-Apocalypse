extends ColorRect

func _ready() -> void:
	modulate.a = 1.0

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "modulate:a", 0.0, 0.65)

	await tween.finished
	queue_free()
