extends Control


@export_file("*.tscn") var intro_scene_path: String = \
	"res://levels/Intro.tscn"

@export var book_size: Vector2 = Vector2(600.0, 600.0)
@export var starting_book_scale: float = 2.6
@export var starting_rotation_degrees: float = -12.0

@export var book_fall_duration: float = 0.75
@export var cover_half_open_duration: float = 0.30
@export var fade_duration: float = 0.65

@export var impact_squash_scale: Vector2 = Vector2(1.06, 0.94)
@export var impact_stretch_scale: Vector2 = Vector2(0.98, 1.02)


@onready var background: ColorRect = $Background

@onready var book_pivot: Control = $BookPivot
@onready var back_and_pages: Control = $BookPivot/BackAndPages
@onready var back_cover: TextureRect = \
	$BookPivot/BackAndPages/BackCover
@onready var pages: TextureRect = \
	$BookPivot/BackAndPages/Pages

@onready var front_cover_pivot: Control = \
	$BookPivot/FrontCoverPivot

@onready var inside_cover: TextureRect = \
	$BookPivot/FrontCoverPivot/InsideCover

@onready var front_cover: TextureRect = \
	$BookPivot/FrontCoverPivot/FrontCover

@onready var cover_content: Control = \
	$BookPivot/FrontCoverPivot/FrontCover/CoverContent

@onready var button_container: VBoxContainer = \
	$BookPivot/FrontCoverPivot/FrontCover/CoverContent/VBoxContainer

@onready var play_button: Button = \
	$BookPivot/FrontCoverPivot/FrontCover/CoverContent/VBoxContainer/PlayButton

@onready var settings_button: Button = \
	$BookPivot/FrontCoverPivot/FrontCover/CoverContent/VBoxContainer/SettingsButton

@onready var settings_panel: Control = \
	get_node_or_null("SettingsPanel") as Control

@onready var settings_back_button: Button = \
	get_node_or_null(
		"SettingsPanel/VBoxContainer/BackButton"
	) as Button

@onready var fade_rect: ColorRect = \
	$FadeLayer/FadeRect

@onready var book_thud: AudioStreamPlayer = \
	get_node_or_null("BookThud") as AudioStreamPlayer


var final_book_position: Vector2
var transition_started: bool = false
var menu_initialized: bool = false


func _ready() -> void:
	_configure_mouse_input()
	_connect_signals()

	if not resized.is_connected(_on_viewport_resized):
		resized.connect(_on_viewport_resized)

	call_deferred("_initialize_menu")


func _connect_signals() -> void:
	if not play_button.gui_input.is_connected(
		_on_play_button_gui_input
	):
		play_button.gui_input.connect(
			_on_play_button_gui_input
		)

	if not settings_button.gui_input.is_connected(
		_on_settings_button_gui_input
	):
		settings_button.gui_input.connect(
			_on_settings_button_gui_input
		)

	if (
		settings_back_button != null
		and not settings_back_button.gui_input.is_connected(
			_on_settings_back_button_gui_input
		)
	):
		settings_back_button.gui_input.connect(
			_on_settings_back_button_gui_input
		)


func _configure_mouse_input() -> void:
	# Decorative controls should not intercept clicks.
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back_and_pages.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back_cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pages.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inside_cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	front_cover.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Parent UI controls allow events to reach their children.
	book_pivot.mouse_filter = Control.MOUSE_FILTER_PASS
	front_cover_pivot.mouse_filter = Control.MOUSE_FILTER_PASS
	cover_content.mouse_filter = Control.MOUSE_FILTER_PASS
	button_container.mouse_filter = Control.MOUSE_FILTER_PASS

	_configure_button(play_button)
	_configure_button(settings_button)

	if settings_back_button != null:
		_configure_button(settings_back_button)

	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	book_pivot.clip_contents = false
	front_cover_pivot.clip_contents = false
	cover_content.clip_contents = false


func _configure_button(button: Button) -> void:
	button.disabled = false
	button.button_mask = MOUSE_BUTTON_MASK_LEFT
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.focus_mode = Control.FOCUS_ALL

func _initialize_menu() -> void:
	await get_tree().process_frame
	await get_tree().process_frame

	_prepare_layout()
	_set_pivots()
	_calculate_final_book_position()
	_set_initial_state()

	await _play_book_fall()

	menu_initialized = true

	play_button.disabled = false
	settings_button.disabled = false
	play_button.grab_focus()


func _prepare_layout() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	book_pivot.set_anchors_preset(Control.PRESET_TOP_LEFT)
	book_pivot.position = Vector2.ZERO
	book_pivot.size = book_size
	book_pivot.custom_minimum_size = book_size

	fade_rect.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)


func _set_pivots() -> void:
	# The entire book scales around its center.
	book_pivot.pivot_offset = book_pivot.size * 0.5

	# The front-cover pieces fold around their left edge.
	front_cover_pivot.pivot_offset = Vector2(
		0.0,
		front_cover_pivot.size.y * 0.5
	)

	front_cover.pivot_offset = Vector2(
		0.0,
		front_cover.size.y * 0.5
	)

	inside_cover.pivot_offset = Vector2(
		0.0,
		inside_cover.size.y * 0.5
	)

	pages.pivot_offset = pages.size * 0.5


func _calculate_final_book_position() -> void:
	var available_size: Vector2 = size

	if available_size == Vector2.ZERO:
		available_size = get_viewport_rect().size

	final_book_position = (
		available_size - book_pivot.size
	) * 0.5


func _set_initial_state() -> void:
	book_pivot.position = final_book_position
	book_pivot.scale = Vector2.ONE * starting_book_scale
	book_pivot.rotation_degrees = starting_rotation_degrees
	book_pivot.modulate.a = 0.0

	front_cover_pivot.scale = Vector2.ONE

	front_cover.visible = true
	front_cover.scale = Vector2.ONE

	inside_cover.visible = true
	inside_cover.scale = Vector2(0.0, 1.0)

	pages.scale = Vector2.ONE

	cover_content.visible = true
	cover_content.modulate.a = 1.0

	inside_cover.z_index = 0
	front_cover.z_index = 1
	cover_content.z_index = 2

	play_button.disabled = true
	settings_button.disabled = true

	if settings_panel != null:
		settings_panel.visible = false

	fade_rect.visible = true
	fade_rect.modulate.a = 0.0
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _play_book_fall() -> void:
	var fall_tween := create_tween()
	fall_tween.set_parallel(true)

	fall_tween.tween_property(
		book_pivot,
		"scale",
		Vector2.ONE,
		book_fall_duration
	).set_trans(Tween.TRANS_QUAD).set_ease(
		Tween.EASE_IN
	)

	fall_tween.tween_property(
		book_pivot,
		"rotation_degrees",
		0.0,
		book_fall_duration
	).set_trans(Tween.TRANS_QUAD).set_ease(
		Tween.EASE_IN_OUT
	)

	fall_tween.tween_property(
		book_pivot,
		"modulate:a",
		1.0,
		minf(0.15, book_fall_duration)
	).set_trans(Tween.TRANS_LINEAR)

	await fall_tween.finished
	await _play_book_impact()


func _play_book_impact() -> void:
	if book_thud != null:
		book_thud.play()

	var squash_tween := create_tween()

	squash_tween.tween_property(
		book_pivot,
		"scale",
		impact_squash_scale,
		0.055
	).set_trans(Tween.TRANS_QUAD).set_ease(
		Tween.EASE_OUT
	)

	squash_tween.tween_property(
		book_pivot,
		"scale",
		impact_stretch_scale,
		0.07
	).set_trans(Tween.TRANS_QUAD).set_ease(
		Tween.EASE_IN_OUT
	)

	squash_tween.tween_property(
		book_pivot,
		"scale",
		Vector2.ONE,
		0.10
	).set_trans(Tween.TRANS_BACK).set_ease(
		Tween.EASE_OUT
	)

	var shake_tween := create_tween()

	shake_tween.tween_property(
		book_pivot,
		"position",
		final_book_position + Vector2(4.0, 2.0),
		0.035
	)

	shake_tween.tween_property(
		book_pivot,
		"position",
		final_book_position + Vector2(-3.0, -1.0),
		0.035
	)

	shake_tween.tween_property(
		book_pivot,
		"position",
		final_book_position,
		0.055
	)

	# Wait for the shorter tween first.
	await shake_tween.finished

	# The squash tween is still running at this point.
	await squash_tween.finished

	book_pivot.position = final_book_position
	book_pivot.scale = Vector2.ONE


func _on_play_pressed() -> void:
	if transition_started or not menu_initialized:
		return

	if intro_scene_path.is_empty():
		push_error("The intro scene path has not been assigned.")
		return

	transition_started = true

	play_button.disabled = true
	settings_button.disabled = true

	if settings_panel != null:
		settings_panel.visible = false

	await _open_book()
	await _fade_to_black()

	var error: Error = get_tree().change_scene_to_file(
		intro_scene_path
	)

	if error != OK:
		push_error(
			"Could not load intro scene: %s. Error code: %s"
			% [intro_scene_path, error]
		)

		_restore_menu_after_failed_transition()


func _open_book() -> void:
	# Remove the title and buttons before folding the cover.
	var content_tween := create_tween()
	content_tween.set_trans(Tween.TRANS_QUAD)
	content_tween.set_ease(Tween.EASE_OUT)

	content_tween.tween_property(
		cover_content,
		"modulate:a",
		0.0,
		0.15
	)

	await content_tween.finished

	# Collapse the outside face toward the spine.
	var front_half_tween := create_tween()
	front_half_tween.set_parallel(true)

	front_half_tween.tween_property(
		front_cover,
		"scale:x",
		0.0,
		cover_half_open_duration
	).set_trans(Tween.TRANS_QUAD).set_ease(
		Tween.EASE_IN
	)

	front_half_tween.tween_property(
		pages,
		"scale",
		Vector2(1.015, 0.985),
		cover_half_open_duration
	).set_trans(Tween.TRANS_SINE).set_ease(
		Tween.EASE_IN_OUT
	)

	await front_half_tween.finished

	front_cover.visible = false

	# Unfold the inside face toward the left.
	var inside_half_tween := create_tween()
	inside_half_tween.set_parallel(true)

	inside_half_tween.tween_property(
		inside_cover,
		"scale:x",
		-1.0,
		cover_half_open_duration
	).set_trans(Tween.TRANS_QUAD).set_ease(
		Tween.EASE_OUT
	)

	inside_half_tween.tween_property(
		pages,
		"scale",
		Vector2.ONE,
		cover_half_open_duration
	).set_trans(Tween.TRANS_SINE).set_ease(
		Tween.EASE_IN_OUT
	)

	await inside_half_tween.finished

	var settle_tween := create_tween()

	settle_tween.tween_property(
		book_pivot,
		"scale",
		Vector2(1.015, 0.985),
		0.06
	)

	settle_tween.tween_property(
		book_pivot,
		"scale",
		Vector2.ONE,
		0.10
	).set_trans(Tween.TRANS_BACK).set_ease(
		Tween.EASE_OUT
	)

	await settle_tween.finished


func _fade_to_black() -> void:
	fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP

	var fade_tween := create_tween()
	fade_tween.set_trans(Tween.TRANS_SINE)
	fade_tween.set_ease(Tween.EASE_IN_OUT)

	fade_tween.tween_property(
		fade_rect,
		"modulate:a",
		1.0,
		fade_duration
	)

	await fade_tween.finished


func _restore_menu_after_failed_transition() -> void:
	transition_started = false

	fade_rect.modulate.a = 0.0
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	front_cover.visible = true
	front_cover.scale = Vector2.ONE

	inside_cover.scale = Vector2(0.0, 1.0)
	pages.scale = Vector2.ONE

	cover_content.visible = true
	cover_content.modulate.a = 1.0

	book_pivot.scale = Vector2.ONE
	book_pivot.position = final_book_position

	play_button.disabled = false
	settings_button.disabled = false


func _on_settings_pressed() -> void:
	if transition_started or not menu_initialized:
		return

	if settings_panel == null:
		push_warning(
			"SettingsPanel could not be found."
		)
		return

	settings_panel.visible = true
	settings_panel.move_to_front()

	play_button.disabled = true
	settings_button.disabled = true

	if settings_back_button != null:
		settings_back_button.disabled = false
		settings_back_button.grab_focus()


func _on_settings_back_pressed() -> void:
	if settings_panel == null:
		return

	settings_panel.visible = false

	play_button.disabled = false
	settings_button.disabled = false
	settings_button.grab_focus()


func _on_viewport_resized() -> void:
	if not menu_initialized or transition_started:
		return

	_calculate_final_book_position()
	book_pivot.position = final_book_position

func _on_play_button_gui_input(event: InputEvent) -> void:
	if not _is_button_activation_event(event):
		return

	play_button.accept_event()
	_on_play_pressed()


func _on_settings_button_gui_input(event: InputEvent) -> void:
	if not _is_button_activation_event(event):
		return

	settings_button.accept_event()
	_on_settings_pressed()


func _on_settings_back_button_gui_input(event: InputEvent) -> void:
	if not _is_button_activation_event(event):
		return

	settings_back_button.accept_event()
	_on_settings_back_pressed()

func _is_button_activation_event(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		return (
			event.button_index == MOUSE_BUTTON_LEFT
			and event.pressed
		)

	if event is InputEventKey and event.echo:
		return false

	return event.is_action_pressed("ui_accept")
