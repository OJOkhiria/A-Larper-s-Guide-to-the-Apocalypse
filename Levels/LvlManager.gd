extends Node

# Define the explicit order of your levels.
const LEVELS: Array[String] = [
	"res://Levels/Intro/Intro.tscn",
	"res://Levels/Lvl1/lvl1.tscn",
	"res://Levels/Lvl2/lvl2.tscn"
]
const MAIN_MENU_PATH := "res://Levels/MainMenu/MainMenu.tscn"
const FADE_DURATION := 0.65

var current_level_index: int = 0
var transition_running: bool = false
var fade_layer: CanvasLayer
var fade_rect: ColorRect


func _ready() -> void:
	# This autoload-owned overlay remains visible while scenes are replaced.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_fade_overlay()


func load_level(index: int) -> void:
	if index >= 0 and index < LEVELS.size():
		await _transition_to_scene(LEVELS[index], index)
	else:
		print("No more levels! Redirecting to Main Menu...")
		await _transition_to_scene(MAIN_MENU_PATH)


func load_next_level() -> void:
	load_level(current_level_index + 1)


func restart_current_level() -> void:
	load_level(current_level_index)


func load_main_menu() -> void:
	await _transition_to_scene(MAIN_MENU_PATH)


func _transition_to_scene(
	scene_path: String,
	new_level_index: int = -1
) -> void:
	if transition_running:
		return

	transition_running = true
	await _fade_to_black()

	var error := get_tree().change_scene_to_file(scene_path)
	if error != OK:
		push_error(
			"Could not load scene '%s'. Error code: %s"
			% [scene_path, error]
		)
		await _fade_from_black()
		transition_running = false
		return

	if new_level_index >= 0:
		current_level_index = new_level_index

	# Let the incoming scene draw behind the persistent overlay first.
	await get_tree().process_frame
	await _fade_from_black()
	transition_running = false


func _ensure_fade_overlay() -> void:
	if is_instance_valid(fade_layer):
		return

	fade_layer = CanvasLayer.new()
	fade_layer.name = "LevelTransitionLayer"
	fade_layer.layer = 100
	fade_layer.process_mode = Node.PROCESS_MODE_ALWAYS

	fade_rect = ColorRect.new()
	fade_rect.name = "FadeRect"
	fade_rect.color = Color.BLACK
	fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade_rect.modulate.a = 0.0
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	fade_layer.add_child(fade_rect)
	get_tree().root.add_child.call_deferred(fade_layer)


func _fade_to_black() -> void:
	_ensure_fade_overlay()
	fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(fade_rect, "modulate:a", 1.0, FADE_DURATION)
	await tween.finished


func _fade_from_black() -> void:
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(fade_rect, "modulate:a", 0.0, FADE_DURATION)
	await tween.finished
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
