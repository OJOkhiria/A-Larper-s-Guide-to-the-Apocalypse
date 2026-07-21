extends Node

const GAME_OVER_SCENE := preload("res://ui/game_over_overlay.tscn")

var overlay: CanvasLayer = null

func show_game_over() -> void:
	if overlay and is_instance_valid(overlay):
		return

	overlay = GAME_OVER_SCENE.instantiate()
	get_tree().root.add_child(overlay)
	get_tree().paused = true

func respawn_current_level() -> void:
	_cleanup_and_resume()
	LvlManager.call_deferred("restart_current_level")

func return_to_main_menu() -> void:
	_cleanup_and_resume()
	LvlManager.call_deferred("load_main_menu")

func _cleanup_and_resume() -> void:
	get_tree().paused = false
	if overlay and is_instance_valid(overlay):
		overlay.queue_free()
	overlay = null
