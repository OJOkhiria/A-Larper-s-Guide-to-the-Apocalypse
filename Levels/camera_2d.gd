extends Camera2D

@export var top_left: Marker2D
@export var bottom_right: Marker2D

func _ready() -> void:
	make_current()
	#_set_limits()

func _set_limits() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var half_view := viewport_size / 2.0

	limit_left = int(top_left.global_position.x + half_view.x)
	limit_top = int(top_left.global_position.y + half_view.y)

	limit_right = int(bottom_right.global_position.x - half_view.x)
	limit_bottom = int(bottom_right.global_position.y - half_view.y)
	
