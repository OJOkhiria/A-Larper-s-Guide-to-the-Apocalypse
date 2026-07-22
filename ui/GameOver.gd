extends Node


const GAME_OVER_SCENE: PackedScene = preload(
	"res://ui/game_over_overlay.tscn"
)

const MAIN_MENU_PATH: String = \
	"res://Levels/MainMenu.tscn"


var overlay: GameOverOverlayUI = null
var changing_scene: bool = false


func _ready() -> void:
	# Keep the manager operational while the game is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS


func show_game_over() -> void:
	if changing_scene:
		return

	# Reuse an existing overlay if one somehow remains alive.
	if is_instance_valid(overlay):
		overlay.show_overlay()
		get_tree().paused = true
		return

	var instance: Node = GAME_OVER_SCENE.instantiate()

	overlay = instance as GameOverOverlayUI

	if overlay == null:
		push_error(
			"game_over_overlay.tscn must use "
			+ "game_over_overlay.gd on its root CanvasLayer."
		)

		if is_instance_valid(instance):
			instance.queue_free()

		return

	overlay.respawn_requested.connect(
		_on_respawn_requested
	)

	overlay.menu_requested.connect(
		_on_menu_requested
	)

	get_tree().root.add_child(overlay)

	# _ready() has now completed, so explicitly show the overlay.
	overlay.show_overlay()

	get_tree().paused = true


func _on_respawn_requested() -> void:
	if changing_scene:
		return

	changing_scene = true

	# Preserve the pending death source. The reloaded level
	# will consume it and select the appropriate dialogue.
	get_tree().paused = false
	_remove_overlay()

	var error: Error = get_tree().reload_current_scene()

	if error != OK:
		push_error(
			"Could not reload the current level. "
			+ "Error code: %s"
			% error
		)

		changing_scene = false
		call_deferred(&"show_game_over")
		return

	changing_scene = false


func _on_menu_requested() -> void:
	if changing_scene:
		return

	if not ResourceLoader.exists(
		MAIN_MENU_PATH,
		"PackedScene"
	):
		push_error(
			"Main Menu scene was not found at: %s"
			% MAIN_MENU_PATH
		)
		return

	changing_scene = true

	# The player is not respawning, so discard the pending
	# death-source dialogue.
	PlayerData.clear_pending_death_source()

	get_tree().paused = false
	_remove_overlay()

	var error: Error = get_tree().change_scene_to_file(
		MAIN_MENU_PATH
	)

	if error != OK:
		push_error(
			"Could not load Main Menu at '%s'. "
			+ "Error code: %s"
			% [MAIN_MENU_PATH, error]
		)

		changing_scene = false
		call_deferred(&"show_game_over")
		return

	changing_scene = false


func _remove_overlay() -> void:
	if is_instance_valid(overlay):
		overlay.queue_free()

	overlay = null
