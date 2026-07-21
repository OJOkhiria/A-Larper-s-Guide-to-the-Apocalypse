extends CanvasLayer

@onready var respawn_button: Button = $BlurRect/CenterContainer/PanelContainer/VBoxContainer/RespawnButton
@onready var menu_button: Button = $BlurRect/CenterContainer/PanelContainer/VBoxContainer/MenuButton

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	respawn_button.pressed.connect(_on_respawn_pressed)
	menu_button.pressed.connect(_on_menu_pressed)

func _on_respawn_pressed() -> void:
	GameOver.respawn_current_level()

func _on_menu_pressed() -> void:
	PlayerData.clear_pending_death_source()

	get_tree().paused = false

	get_tree().change_scene_to_file(
		"res://menus/MainMenu.tscn"
	)
