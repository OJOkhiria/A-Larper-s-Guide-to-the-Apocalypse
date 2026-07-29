class_name PauseMenuUI
extends CanvasLayer


signal resume_requested
signal menu_requested


@onready var overlay: Control = $BlurRect
@onready var resume_button: Button = \
	$BlurRect/CenterContainer/PanelContainer/VBoxContainer/ResumeButton
@onready var menu_button: Button = \
	$BlurRect/CenterContainer/PanelContainer/VBoxContainer/MainMenuButton


func _ready() -> void:
	# This menu must still receive button input after the gameplay tree pauses.
	process_mode = Node.PROCESS_MODE_ALWAYS

	resume_button.pressed.connect(_on_resume_pressed)
	menu_button.pressed.connect(_on_menu_pressed)
	hide_menu()


func show_menu() -> void:
	overlay.show()
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP


func hide_menu() -> void:
	overlay.hide()
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _on_resume_pressed() -> void:
	resume_requested.emit()


func _on_menu_pressed() -> void:
	menu_requested.emit()
