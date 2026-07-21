extends Control


@export_file("*.tscn") var intro_scene_path: String = \
	"res://levels/Intro.tscn"

@export var page_size: Vector2 = Vector2(600.0, 600.0)
@export var open_book_margin: float = 24.0
@export var starting_book_scale: float = 2.6
@export var starting_rotation_degrees: float = -12.0

var spread_size: Vector2
var resting_book_scale: float = 1.0

var open_book_position: Vector2
var closed_book_position: Vector2
var starting_book_position: Vector2

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

@onready var inside_cover: TextureRect = $BookPivot/FrontCoverPivot/InsideCover

@onready var front_cover: TextureRect = $BookPivot/FrontCoverPivot/FrontCover

@onready var cover_content: Control = \
	$BookPivot/FrontCoverPivot/FrontCover/CoverContent

@onready var button_container: VBoxContainer = \
	$BookPivot/FrontCoverPivot/FrontCover/CoverContent/VBoxContainer

@onready var play_button: Button = \
	$BookPivot/FrontCoverPivot/FrontCover/CoverContent/VBoxContainer/PlayButton

@onready var settings_button: Button = \
	$BookPivot/FrontCoverPivot/FrontCover/CoverContent/VBoxContainer/SettingsButton
	
@onready var controls_page: Control = \
$BookPivot/ControlsPage

@onready var controls_continue_button: Button = \
	$BookPivot/ControlsPage/MarginContainer/VBoxContainer/ContinueButton

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
	if not play_button.pressed.is_connected(_on_play_pressed):
		play_button.pressed.connect(_on_play_pressed)

	if not settings_button.pressed.is_connected(
		_on_settings_pressed
	):
		settings_button.pressed.connect(
			_on_settings_pressed
		)

	if not controls_continue_button.pressed.is_connected(
		_on_controls_continue_pressed
	):
		controls_continue_button.pressed.connect(
			_on_controls_continue_pressed
		)

	if (
		settings_back_button != null
		and not settings_back_button.pressed.is_connected(
			_on_settings_back_pressed
		)
	):
		settings_back_button.pressed.connect(
			_on_settings_back_pressed
		)


func _configure_mouse_input() -> void:
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE

	back_and_pages.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back_cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pages.mouse_filter = Control.MOUSE_FILTER_IGNORE

	book_pivot.mouse_filter = Control.MOUSE_FILTER_PASS
	front_cover_pivot.mouse_filter = Control.MOUSE_FILTER_PASS

	inside_cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	front_cover.mouse_filter = Control.MOUSE_FILTER_IGNORE

	cover_content.mouse_filter = Control.MOUSE_FILTER_PASS
	button_container.mouse_filter = Control.MOUSE_FILTER_PASS

	controls_page.mouse_filter = Control.MOUSE_FILTER_PASS

	_configure_button(play_button)
	_configure_button(settings_button)
	_configure_button(controls_continue_button)

	if settings_back_button != null:
		_configure_button(settings_back_button)

	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	book_pivot.clip_contents = false
	front_cover_pivot.clip_contents = false
	cover_content.clip_contents = false
	controls_page.clip_contents = false


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

	spread_size = Vector2(
		page_size.x * 2.0,
		page_size.y
	)

	# BookPivot represents the entire opened book, not one cover.
	book_pivot.set_anchors_preset(Control.PRESET_TOP_LEFT)
	book_pivot.position = Vector2.ZERO
	book_pivot.size = spread_size
	book_pivot.custom_minimum_size = spread_size
	book_pivot.clip_contents = false

	# The stationary pages occupy the right side of the spine.
	back_and_pages.set_anchors_preset(Control.PRESET_TOP_LEFT)
	back_and_pages.position = Vector2(page_size.x, 0.0)
	back_and_pages.size = page_size
	back_and_pages.custom_minimum_size = page_size
	back_and_pages.clip_contents = false

	# The front cover begins directly over the right-side pages.
	front_cover_pivot.set_anchors_preset(Control.PRESET_TOP_LEFT)
	front_cover_pivot.position = Vector2(page_size.x, 0.0)
	front_cover_pivot.size = page_size
	front_cover_pivot.custom_minimum_size = page_size
	front_cover_pivot.clip_contents = false

	_configure_page_rect(back_cover)
	_configure_page_rect(pages)
	_configure_page_rect(front_cover)
	_configure_page_rect(inside_cover)

	# The controls should appear on the exposed right page.
	controls_page.set_anchors_preset(Control.PRESET_TOP_LEFT)
	controls_page.position = Vector2(page_size.x, 0.0)
	controls_page.size = page_size
	controls_page.custom_minimum_size = page_size
	controls_page.clip_contents = false

	fade_rect.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)


func _set_pivots() -> void:
	# This is both the spread center and the spine center.
	book_pivot.pivot_offset = Vector2(
		page_size.x,
		page_size.y * 0.5
	)

	# FrontCoverPivot itself is hinged at its local left edge.
	front_cover_pivot.pivot_offset = Vector2(
		0.0,
		page_size.y * 0.5
	)

	front_cover.pivot_offset = Vector2(
		0.0,
		page_size.y * 0.5
	)

	inside_cover.pivot_offset = Vector2(
		0.0,
		page_size.y * 0.5
	)

	pages.pivot_offset = page_size * 0.5
	back_cover.pivot_offset = page_size * 0.5

	pages.pivot_offset = pages.size * 0.5


func _calculate_final_book_position() -> void:
	var viewport_size: Vector2 = size

	if viewport_size == Vector2.ZERO:
		viewport_size = get_viewport_rect().size

	var available_width: float = maxf(
		viewport_size.x - open_book_margin * 2.0,
		1.0
	)

	var available_height: float = maxf(
		viewport_size.y - open_book_margin * 2.0,
		1.0
	)

	resting_book_scale = minf(
		
		available_width / spread_size.x,
		available_height / spread_size.y
	)

	var viewport_center: Vector2 = viewport_size * 0.5

	# The local spine point must land at the viewport center.
	var spine_local_position := Vector2(
		page_size.x,
		page_size.y * 0.5
	)

	open_book_position = (
		viewport_center - spine_local_position
	)

	# While closed, only the right half is visible. Shift the entire
	# spread left so that the closed cover itself remains centered.
	closed_book_position = (
		open_book_position
		- Vector2(
			page_size.x * 0.5 * resting_book_scale,
			0.0
		)
	)

	# Compensate for the larger scale at the start of the falling
	# animation so the closed cover remains centered while shrinking.
	starting_book_position = (
		open_book_position
		- Vector2(
			page_size.x * 0.5 * starting_book_scale,
			0.0
		)
	)


func _set_initial_state() -> void:
	book_pivot.position = starting_book_position
	book_pivot.scale = (
		Vector2.ONE * starting_book_scale
	)
	book_pivot.rotation_degrees = (
		starting_rotation_degrees
	)
	book_pivot.modulate.a = 0.0

	front_cover_pivot.position = Vector2(
		page_size.x,
		0.0
	)
	front_cover_pivot.scale = Vector2.ONE

	front_cover.position = Vector2.ZERO
	front_cover.visible = true
	front_cover.scale = Vector2.ONE

	inside_cover.position = Vector2.ZERO
	inside_cover.visible = true
	inside_cover.scale = Vector2(0.0, 1.0)

	pages.position = Vector2.ZERO
	pages.scale = Vector2.ONE

	cover_content.visible = true
	cover_content.modulate.a = 1.0

	controls_page.visible = false
	controls_page.modulate.a = 0.0
	controls_continue_button.disabled = true

	play_button.disabled = true
	settings_button.disabled = true

	if settings_panel != null:
		settings_panel.visible = false

	fade_rect.visible = true
	fade_rect.modulate.a = 0.0
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _play_book_fall() -> void:
	var resting_scale := (
		Vector2.ONE * resting_book_scale
	)

	var fall_tween := create_tween()
	fall_tween.set_parallel(true)

	fall_tween.tween_property(
		book_pivot,
		"scale",
		resting_scale,
		book_fall_duration
	).set_trans(Tween.TRANS_QUAD).set_ease(
		Tween.EASE_IN
	)

	fall_tween.tween_property(
		book_pivot,
		"position",
		closed_book_position,
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
	)

	await fall_tween.finished
	await _play_book_impact()


func _play_book_impact() -> void:
	if book_thud != null:
		book_thud.play()

	var base_scale := (
		Vector2.ONE * resting_book_scale
	)

	var impact_tween := create_tween()

	impact_tween.tween_property(
		book_pivot,
		"scale",
		base_scale * impact_squash_scale,
		0.055
	)

	impact_tween.tween_property(
		book_pivot,
		"scale",
		base_scale * impact_stretch_scale,
		0.07
	)

	impact_tween.tween_property(
		book_pivot,
		"scale",
		base_scale,
		0.10
	).set_trans(Tween.TRANS_BACK).set_ease(
		Tween.EASE_OUT
	)

	await impact_tween.finished

	book_pivot.position = closed_book_position
	book_pivot.scale = base_scale

func _on_play_pressed() -> void:
	if transition_started or not menu_initialized:
		return

	transition_started = true

	play_button.disabled = true
	settings_button.disabled = true

	if settings_panel != null:
		settings_panel.visible = false

	await _open_book()
	await _show_controls_page()

func _open_book() -> void:
	var content_tween := create_tween()

	content_tween.tween_property(
		cover_content,
		"modulate:a",
		0.0,
		0.15
	).set_trans(Tween.TRANS_QUAD).set_ease(
		Tween.EASE_OUT
	)

	await content_tween.finished

	front_cover.visible = true
	inside_cover.visible = true

	var open_tween := create_tween()
	open_tween.set_trans(Tween.TRANS_CUBIC)
	open_tween.set_ease(Tween.EASE_IN_OUT)

	open_tween.tween_method(
		_apply_book_open_progress,
		0.0,
		1.0,
		cover_half_open_duration * 2.0
	)

	await open_tween.finished

	_apply_book_open_progress(1.0)


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

	controls_page.visible = false
	controls_page.modulate.a = 0.0
	controls_continue_button.disabled = true

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
	if transition_started:
		return

	_calculate_final_book_position()

	book_pivot.scale = (
		Vector2.ONE * resting_book_scale
	)

	if inside_cover.scale.x < -0.9:
		book_pivot.position = open_book_position
	else:
		book_pivot.position = closed_book_position

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
	
func _show_controls_page() -> void:
	controls_page.visible = true
	controls_page.modulate.a = 0.0
	controls_page.move_to_front()

	controls_continue_button.disabled = true

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)

	tween.tween_property(
		controls_page,
		"modulate:a",
		1.0,
		0.35
	)

	await tween.finished

	controls_continue_button.disabled = false
	controls_continue_button.grab_focus()

func _on_controls_continue_pressed() -> void:
	if not transition_started:
		return

	if not controls_page.visible:
		return

	controls_continue_button.disabled = true

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

func _configure_page_rect(rect: TextureRect) -> void:
	rect.set_anchors_preset(Control.PRESET_TOP_LEFT)
	rect.position = Vector2.ZERO
	rect.size = page_size
	rect.custom_minimum_size = page_size

	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _apply_book_open_progress(value: float) -> void:
	var overall_progress := smoothstep(
		0.0,
		1.0,
		value
	)

	# Shift the complete book so the spine arrives at the exact
	# center while the left side unfolds.
	book_pivot.position = closed_book_position.lerp(
		open_book_position,
		overall_progress
	)

	if value < 0.5:
		var first_half := smoothstep(
			0.0,
			1.0,
			value * 2.0
		)

		front_cover.visible = true
		inside_cover.visible = false

		# The outer cover collapses into a thin vertical edge.
		front_cover.scale = Vector2(
			lerpf(1.0, 0.02, first_half),
			lerpf(1.0, 0.96, first_half)
		)
	else:
		var second_half := smoothstep(
			0.0,
			1.0,
			(value - 0.5) * 2.0
		)

		front_cover.visible = false
		inside_cover.visible = true

		# The inner face expands leftward from that same hinge.
		inside_cover.scale = Vector2(
			lerpf(-0.02, -1.0, second_half),
			lerpf(0.96, 1.0, second_half)
		)
