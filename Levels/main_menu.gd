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
$BookPivot/BackAndPages/ControlsPage

@onready var controls_margin: MarginContainer = \
	$BookPivot/BackAndPages/ControlsPage/MarginContainer

@onready var controls_container: VBoxContainer = \
	$BookPivot/BackAndPages/ControlsPage/MarginContainer/VBoxContainer

@onready var controls_continue_button: Button = \
	$BookPivot/BackAndPages/ControlsPage/MarginContainer/VBoxContainer/ContinueButton

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

const COVER_SIZE := Vector2(410.0, 470.0)
const PAGE_SIZE := Vector2(330.0, 390.0)

const PAGE_INSET := Vector2(
	(COVER_SIZE.x - PAGE_SIZE.x) * 0.5,
	(COVER_SIZE.y - PAGE_SIZE.y) * 0.5
)

const SPREAD_SIZE := Vector2(
	COVER_SIZE.x * 2.0,
	COVER_SIZE.y
)


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
	set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	# The complete open spread.
	_place_control(
		book_pivot,
		Vector2.ZERO,
		SPREAD_SIZE
	)
	book_pivot.clip_contents = false

	# The right-hand cover and pages begin at the spine.
	_place_control(
		back_and_pages,
		Vector2(COVER_SIZE.x, 0.0),
		COVER_SIZE
	)
	back_and_pages.clip_contents = false

	# The front-cover hinge begins at exactly the same spine point.
	_place_control(
		front_cover_pivot,
		Vector2(COVER_SIZE.x, 0.0),
		COVER_SIZE
	)
	front_cover_pivot.clip_contents = false

	_configure_texture_rect(
		back_cover,
		Vector2.ZERO,
		COVER_SIZE
	)

	_configure_texture_rect(
		front_cover,
		Vector2.ZERO,
		COVER_SIZE
	)

	_configure_texture_rect(
		inside_cover,
		Vector2.ZERO,
		COVER_SIZE
	)

	_configure_texture_rect(
		pages,
		PAGE_INSET,
		PAGE_SIZE
	)

	# Controls sit exactly over the visible page artwork.
	_place_control(
		controls_page,
		PAGE_INSET,
		PAGE_SIZE
	)
	controls_page.clip_contents = false
	controls_page.mouse_filter = Control.MOUSE_FILTER_PASS

	controls_margin.set_anchors_and_offsets_preset(
	Control.PRESET_FULL_RECT
	)

	controls_margin.mouse_filter = Control.MOUSE_FILTER_PASS

	controls_container.mouse_filter = Control.MOUSE_FILTER_PASS

	controls_continue_button.mouse_filter = \
	Control.MOUSE_FILTER_STOP

	fade_rect.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)


func _set_pivots() -> void:
	# The center of the open spread is the spine.
	book_pivot.pivot_offset = Vector2(
		COVER_SIZE.x,
		COVER_SIZE.y * 0.5
	)

	# The cover opens around its real visible left edge.
	front_cover_pivot.pivot_offset = Vector2(
		0.0,
		COVER_SIZE.y * 0.5
	)

	front_cover.pivot_offset = Vector2(
		0.0,
		COVER_SIZE.y * 0.5
	)

	inside_cover.pivot_offset = Vector2(
		0.0,
		COVER_SIZE.y * 0.5
	)

	back_cover.pivot_offset = COVER_SIZE * 0.5
	pages.pivot_offset = PAGE_SIZE * 0.5

func _calculate_final_book_position() -> void:
	var viewport_size: Vector2 = size

	if viewport_size == Vector2.ZERO:
		viewport_size = get_viewport_rect().size

	var viewport_center := viewport_size * 0.5
	var spine_local := Vector2(
		COVER_SIZE.x,
		COVER_SIZE.y * 0.5
	)

	# Open book: spine exactly at viewport center.
	open_book_position = (
		viewport_center - spine_local
	)

	# Center of the visible closed right-hand cover.
	var closed_cover_center := Vector2(
		COVER_SIZE.x + COVER_SIZE.x * 0.5,
		COVER_SIZE.y * 0.5
	)

	closed_book_position = (
		viewport_center
		- spine_local
		- (
			closed_cover_center - spine_local
		) * resting_book_scale
	)

	starting_book_position = (
		viewport_center
		- spine_local
		- (
			closed_cover_center - spine_local
		) * starting_book_scale
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
	
	back_and_pages.z_index = 0

	back_cover.z_index = 0
	pages.z_index = 1
	controls_page.z_index = 2

	front_cover_pivot.z_index = 10
	inside_cover.z_index = 0
	front_cover.z_index = 1
	cover_content.z_index = 2
	
	front_cover_pivot.position = Vector2(
	COVER_SIZE.x,
	0.0)
	
	back_and_pages.z_index = 0
	back_cover.z_index = 0
	pages.z_index = 1

	controls_page.z_index = 20
	controls_page.z_as_relative = true

	front_cover_pivot.z_index = 10

	front_cover.position = Vector2.ZERO
	front_cover.size = COVER_SIZE
	front_cover.visible = true
	front_cover.scale = Vector2.ONE

	inside_cover.position = Vector2.ZERO
	inside_cover.size = COVER_SIZE
	inside_cover.visible = false
	inside_cover.scale = Vector2(-0.001, 1.0)

	back_cover.position = Vector2.ZERO
	back_cover.size = COVER_SIZE

	pages.position = PAGE_INSET
	pages.size = PAGE_SIZE
	pages.scale = Vector2.ONE

	controls_page.position = PAGE_INSET
	controls_page.size = PAGE_SIZE
	controls_page.visible = false
	controls_page.modulate.a = 0.0


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
	inside_cover.visible = false

	var opening_tween := create_tween()

	opening_tween.tween_method(
		_apply_book_open_progress,
		0.0,
		1.0,
		cover_half_open_duration * 2.0
	).set_trans(Tween.TRANS_CUBIC).set_ease(
		Tween.EASE_IN_OUT
	)

	await opening_tween.finished

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
	controls_page.z_index = 20
	controls_page.move_to_front()

	controls_page.visible = true
	controls_page.modulate = Color(
		1.0,
		1.0,
		1.0,
		0.0
	)

	controls_continue_button.disabled = true

	# Let Containers recalculate their child layouts.
	await get_tree().process_frame

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)

	tween.tween_property(
		controls_page,
		"modulate",
		Color.WHITE,
		0.35
	)

	await tween.finished

	controls_continue_button.disabled = false
	controls_continue_button.grab_focus()

func _on_controls_continue_pressed() -> void:
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

func _configure_page_rect(rect: TextureRect) -> void:
	rect.set_anchors_preset(Control.PRESET_TOP_LEFT)
	rect.position = Vector2.ZERO
	rect.size = page_size
	rect.custom_minimum_size = page_size

	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _apply_book_open_progress(
	progress: float
) -> void:
	var movement_progress := smoothstep(
		0.0,
		1.0,
		progress
	)

	book_pivot.position = closed_book_position.lerp(
		open_book_position,
		movement_progress
	)

	if progress < 0.5:
		var fold_progress := smoothstep(
			0.0,
			1.0,
			progress * 2.0
		)

		front_cover.visible = true
		inside_cover.visible = false

		front_cover.scale = Vector2(
			lerpf(1.0, 0.001, fold_progress),
			lerpf(1.0, 0.98, fold_progress)
		)
	else:
		var unfold_progress := smoothstep(
			0.0,
			1.0,
			(progress - 0.5) * 2.0
		)

		front_cover.visible = false
		inside_cover.visible = true

		inside_cover.scale = Vector2(
			lerpf(-0.001, -1.0, unfold_progress),
			lerpf(0.98, 1.0, unfold_progress)
		)

func _configure_cover_rect(rect: TextureRect) -> void:
	rect.set_anchors_preset(Control.PRESET_TOP_LEFT)
	rect.position = Vector2.ZERO
	rect.size = COVER_SIZE
	rect.custom_minimum_size = COVER_SIZE
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = (
		TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _place_control(
	control: Control,
	local_position: Vector2,
	control_size: Vector2
) -> void:
	control.set_anchors_preset(
		Control.PRESET_TOP_LEFT
	)

	control.position = local_position
	control.size = control_size
	control.custom_minimum_size = Vector2.ZERO


func _configure_texture_rect(
	rect: TextureRect,
	local_position: Vector2,
	rect_size: Vector2 ) -> void:
	_place_control(
		rect,
		local_position,
		rect_size
	)

	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.clip_contents = false
