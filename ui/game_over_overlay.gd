extends CanvasLayer

@onready var respawn_button: Button = $CenterContainer/PanelContainer/VBoxContainer/RespawnButton
@onready var menu_button: Button = $CenterContainer/PanelContainer/VBoxContainer/MenuButton

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	respawn_button.pressed.connect(_on_respawn_pressed)
	menu_button.pressed.connect(_on_menu_pressed)

func _on_respawn_pressed() -> void:
	GameOver.respawn_current_level()

func _on_menu_pressed() -> void:
	GameOver.return_to_main_menu()
