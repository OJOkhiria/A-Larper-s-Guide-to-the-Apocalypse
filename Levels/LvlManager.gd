extends Node

# Define the explicit order of your levels
const LEVELS : Array[String] = [
	"res://Levels/Intro.tscn",
	"res://Levels/lvl1.tscn",
]

var current_level_index: int = 0

func load_level(index: int) -> void:
	if index >= 0 and index < LEVELS.size():
		current_level_index = index
		get_tree().change_scene_to_file(LEVELS[index])
	else:
		print("No more levels! Redirecting to Main Menu...")
		get_tree().change_scene_to_file("res://Levels/MainMenu.tscn")

func load_next_level() -> void:
	load_level(current_level_index + 1)

func restart_current_level() -> void:
	load_level(current_level_index)
	

func load_main_menu() -> void:
	call_deferred("_change_scene", "res://Levels/MainMenu.tscn")
