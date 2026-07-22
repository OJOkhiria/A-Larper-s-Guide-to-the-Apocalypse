class_name GameOverOverlayUI
extends CanvasLayer


signal respawn_requested
signal menu_requested


@onready var blur_rect: Control = \
	$BlurRect

@onready var respawn_button: Button = \
	$BlurRect/CenterContainer/PanelContainer/VBoxContainer/RespawnButton

@onready var menu_button: Button = \
	$BlurRect/CenterContainer/PanelContainer/VBoxContainer/MenuButton


var input_locked: bool = false


func _ready() -> void:
	# The overlay and its buttons must continue operating
	# while the gameplay scene is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS

	_connect_buttons()

	# The GameOver manager explicitly shows it after instantiation.
	hide_overlay()


func _connect_buttons() -> void:
	if not respawn_button.pressed.is_connected(
		_on_respawn_pressed
	):
		respawn_button.pressed.connect(
			_on_respawn_pressed
		)

	if not menu_button.pressed.is_connected(
		_on_menu_pressed
	):
		menu_button.pressed.connect(
			_on_menu_pressed
		)


func show_overlay() -> void:
	input_locked = false

	blur_rect.show()
	blur_rect.mouse_filter = Control.MOUSE_FILTER_STOP

	_set_buttons_enabled(true)

	respawn_button.grab_focus()


func hide_overlay() -> void:
	input_locked = true

	blur_rect.hide()
	blur_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_set_buttons_enabled(false)


func _on_respawn_pressed() -> void:
	if input_locked:
		return

	input_locked = true
	_set_buttons_enabled(false)

	respawn_requested.emit()


func _on_menu_pressed() -> void:
	if input_locked:
		return

	input_locked = true
	_set_buttons_enabled(false)

	menu_requested.emit()


func _set_buttons_enabled(enabled: bool) -> void:
	respawn_button.disabled = not enabled
	menu_button.disabled = not enabled

	var filter: Control.MouseFilter = (
		Control.MOUSE_FILTER_STOP
		if enabled
		else Control.MOUSE_FILTER_IGNORE
	)

	respawn_button.mouse_filter = filter
	menu_button.mouse_filter = filter
