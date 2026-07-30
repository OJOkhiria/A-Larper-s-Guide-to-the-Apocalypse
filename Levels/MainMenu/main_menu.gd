extends Control


@export_file("*.tscn") var intro_scene_path: String = \
	"res://Levels/Intro/Intro.tscn"

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

@onready var controls_page: Control = \
$BookPivot/BackAndPages/ControlsPage

@onready var controls_margin: MarginContainer = \
	$BookPivot/BackAndPages/ControlsPage/MarginContainer

@onready var controls_container: VBoxContainer = \
	$BookPivot/BackAndPages/ControlsPage/MarginContainer/VBoxContainer

@onready var controls_continue_button: Button = \
	$BookPivot/BackAndPages/ControlsPage/MarginContainer/VBoxContainer/ContinueButton
	

@onready var hud_page: Control = \
	$BookPivot/BackAndPages/HUDPage

@onready var hud_page_margin: MarginContainer = \
	$BookPivot/BackAndPages/HUDPage/MarginContainer

@onready var hud_page_container: VBoxContainer = \
	$BookPivot/BackAndPages/HUDPage/MarginContainer/VBoxContainer

@onready var hud_page_continue_button: Button = \
	$BookPivot/BackAndPages/HUDPage/MarginContainer/VBoxContainer/ContinueButton
	
@onready var page_turn_pivot: Control = \
	$BookPivot/PageTurnPivot

@onready var turning_page: TextureRect = \
	$BookPivot/PageTurnPivot/TurningPage




@onready var book_thud: AudioStreamPlayer2D = \
	get_node_or_null("BookThud") as AudioStreamPlayer2D

@onready var page_flip: AudioStreamPlayer2D = get_node_or_null("PageFlip") as AudioStreamPlayer2D

var final_book_position: Vector2
var transition_started: bool = false
var menu_initialized: bool = false
var awaiting_controls_continue: bool = false

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

enum MenuPage {
	NONE,
	CONTROLS,
	HUD
}

var current_menu_page: MenuPage = MenuPage.NONE
var page_transition_running: bool = false
# The source page artwork faces right. Once it is resting on the left cover,
# this state drives the TextureRect flip explicitly.
var turning_page_is_reflected: bool = false

func _ready() -> void:
	_configure_mouse_input()
	_connect_signals()

	if not resized.is_connected(_on_viewport_resized):
		resized.connect(_on_viewport_resized)

	call_deferred("_initialize_menu")


func _connect_signals() -> void:
	if not play_button.pressed.is_connected(_on_play_pressed):
		play_button.pressed.connect(_on_play_pressed)


	if not controls_continue_button.pressed.is_connected(
		_on_controls_continue_pressed
	):
		controls_continue_button.pressed.connect(
			_on_controls_continue_pressed
		)


	if not hud_page_continue_button.pressed.is_connected(
	_on_hud_page_continue_pressed
	):
		hud_page_continue_button.pressed.connect(
		_on_hud_page_continue_pressed
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
	_configure_button(controls_continue_button)
	_configure_button(hud_page_continue_button)



	book_pivot.clip_contents = false
	front_cover_pivot.clip_contents = false
	cover_content.clip_contents = false
	controls_page.clip_contents = false

	hud_page.clip_contents = false
	hud_page.mouse_filter = Control.MOUSE_FILTER_IGNORE


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
	play_button.grab_focus()


func _prepare_layout() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

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

	
	_place_control(
	hud_page,
	PAGE_INSET,
	PAGE_SIZE)

	hud_page.clip_contents = false
	hud_page.mouse_filter = Control.MOUSE_FILTER_IGNORE

	hud_page_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	hud_page_margin.mouse_filter = \
	Control.MOUSE_FILTER_PASS

	hud_page_container.mouse_filter = \
	Control.MOUSE_FILTER_PASS

	hud_page_continue_button.mouse_filter = \
	Control.MOUSE_FILTER_STOP
	_configure_page_turn()


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
	
	_set_cover_input_enabled(true)
	_set_controls_input_enabled(false)
	controls_page.position = PAGE_INSET
	controls_page.size = PAGE_SIZE
	controls_page.visible = false
	controls_page.modulate.a = 0.0
	current_menu_page = MenuPage.NONE
	page_transition_running = false

	controls_page.visible = false
	controls_page.modulate = Color(
	1.0,
	1.0,
	1.0,
	0.0
	)

	hud_page.visible = false
	hud_page.modulate = Color(
	1.0,
	1.0,
	1.0,
	0.0
	)

	controls_continue_button.disabled = true
	hud_page_continue_button.disabled = true

	controls_page.mouse_filter = \
	Control.MOUSE_FILTER_IGNORE

	hud_page.mouse_filter = \
	Control.MOUSE_FILTER_IGNORE

	controls_page.z_index = 20
	hud_page.z_index = 21
	
	page_turn_pivot.position = Vector2(
	COVER_SIZE.x,
	PAGE_INSET.y
	)

	page_turn_pivot.pivot_offset = Vector2(
	0.0,
	PAGE_SIZE.y * 0.5
	)

	page_turn_pivot.visible = false
	page_turn_pivot.scale = Vector2.ONE
	page_turn_pivot.z_index = 30

	turning_page.position = Vector2(
	PAGE_INSET.x,
	0.0
	)

	turning_page.size = PAGE_SIZE
	turning_page.texture = pages.texture
	turning_page.visible = true
	_set_turning_page_reflected(false)


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
	awaiting_controls_continue = false

	play_button.disabled = true


	# Immediately stop the front-cover branch from blocking
	# the controls page.
	_set_cover_input_enabled(false)

	await _open_book()
	await _show_controls_page()

func _open_book() -> void:
	page_flip.play()
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




func _restore_menu_after_failed_transition() -> void:
	transition_started = false


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
	awaiting_controls_continue = false
	controls_continue_button.disabled = true
	_set_controls_input_enabled(false)
	_set_cover_input_enabled(true)
	
	current_menu_page = MenuPage.NONE
	page_transition_running = false

	controls_page.visible = false
	controls_page.position = PAGE_INSET
	controls_page.modulate.a = 0.0

	hud_page.visible = false
	hud_page.position = PAGE_INSET
	hud_page.modulate.a = 0.0

	page_turn_pivot.visible = false
	page_turn_pivot.position = Vector2(
		COVER_SIZE.x,
		PAGE_INSET.y
	)
	page_turn_pivot.scale = Vector2.ONE
	turning_page.position = Vector2(PAGE_INSET.x, 0.0)
	_set_turning_page_reflected(false)

	_set_page_input_enabled(
	controls_page,
	controls_continue_button,
	false
	)

	_set_page_input_enabled(
	hud_page,
	hud_page_continue_button,
	false
)



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
	current_menu_page = MenuPage.CONTROLS

	controls_page.visible = true
	controls_page.modulate = Color(
		1.0,
		1.0,
		1.0,
		0.0
	)

	hud_page.visible = false
	hud_page.modulate.a = 0.0

	_set_page_input_enabled(
		controls_page,
		controls_continue_button,
		false
	)

	_set_page_input_enabled(
		hud_page,
		hud_page_continue_button,
		false
	)

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

	_set_page_input_enabled(
		controls_page,
		controls_continue_button,
		true
	)

	controls_continue_button.grab_focus()

func _on_controls_continue_pressed() -> void:
	if current_menu_page != MenuPage.CONTROLS:
		return

	if page_transition_running:
		return

	page_transition_running = true

	_set_page_input_enabled(
		controls_page,
		controls_continue_button,
		false
	)
	page_flip.play()
	await _transition_between_pages(
		controls_page,
		hud_page
	)

	current_menu_page = MenuPage.HUD
	page_transition_running = false

	_set_page_input_enabled(
		hud_page,
		hud_page_continue_button,
		true
	)

	hud_page_continue_button.grab_focus()

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

func _place_control(control: Control, local_position: Vector2, control_size: Vector2) -> void:
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

func _set_cover_input_enabled(enabled: bool) -> void:
	if enabled:
		front_cover_pivot.mouse_behavior_recursive = \
			Control.MOUSE_BEHAVIOR_ENABLED

		front_cover_pivot.mouse_filter = \
			Control.MOUSE_FILTER_PASS

		cover_content.mouse_filter = \
			Control.MOUSE_FILTER_PASS

		button_container.mouse_filter = \
			Control.MOUSE_FILTER_PASS

		play_button.mouse_filter = \
			Control.MOUSE_FILTER_STOP

	else:
		# Disable the entire closed-cover UI branch so its invisible
		# rectangle cannot cover the controls page.
		front_cover_pivot.mouse_behavior_recursive = \
			Control.MOUSE_BEHAVIOR_DISABLED

		front_cover_pivot.mouse_filter = \
			Control.MOUSE_FILTER_IGNORE


func _set_controls_input_enabled(enabled: bool) -> void:
	if enabled:
		back_and_pages.mouse_behavior_recursive = \
			Control.MOUSE_BEHAVIOR_ENABLED

		controls_page.mouse_behavior_recursive = \
			Control.MOUSE_BEHAVIOR_ENABLED

		controls_page.mouse_filter = \
			Control.MOUSE_FILTER_PASS

		controls_margin.mouse_filter = \
			Control.MOUSE_FILTER_PASS

		controls_container.mouse_filter = \
			Control.MOUSE_FILTER_PASS

		controls_continue_button.mouse_filter = \
			Control.MOUSE_FILTER_STOP

		controls_continue_button.disabled = false
	else:
		controls_continue_button.disabled = true
		controls_continue_button.mouse_filter = \
			Control.MOUSE_FILTER_IGNORE

		controls_page.mouse_filter = \
			Control.MOUSE_FILTER_IGNORE

		controls_page.mouse_behavior_recursive = \
			Control.MOUSE_BEHAVIOR_DISABLED


func _set_page_input_enabled(page: Control, button: Button, enabled: bool) -> void:
	if enabled:
		page.mouse_behavior_recursive = \
			Control.MOUSE_BEHAVIOR_ENABLED

		page.mouse_filter = \
			Control.MOUSE_FILTER_PASS

		button.mouse_filter = \
			Control.MOUSE_FILTER_STOP

		button.disabled = false
	else:
		button.disabled = true
		button.mouse_filter = \
			Control.MOUSE_FILTER_IGNORE

		page.mouse_filter = \
			Control.MOUSE_FILTER_IGNORE

		page.mouse_behavior_recursive = \
			Control.MOUSE_BEHAVIOR_DISABLED

func _transition_between_pages(from_page: Control,to_page: Control) -> void:
	from_page.mouse_filter = \
		Control.MOUSE_FILTER_IGNORE

	to_page.visible = true
	to_page.modulate = Color.WHITE
	to_page.position = PAGE_INSET

	# The destination page sits beneath the turning page.
	to_page.z_index = 2
	from_page.z_index = 3

	page_turn_pivot.visible = true
	# Start at the spine so the moving page occupies the right-hand page inset.
	page_turn_pivot.position = Vector2(
		COVER_SIZE.x,
		PAGE_INSET.y
	)

	page_turn_pivot.scale = Vector2.ONE
	turning_page.texture = pages.texture
	turning_page.position = Vector2(PAGE_INSET.x, 0.0)
	_set_turning_page_reflected(false)

	var tween := create_tween()
	# Remove the outgoing instructions as soon as the page starts to move.
	# Previously they remained opaque until the entire turn had finished,
	# briefly leaving two pages' contents visible at once.
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_IN_OUT)

	tween.tween_method(
		_apply_page_turn_progress,
		0.0,
		1.0,
		0.55
	)
	tween.tween_property(
		from_page,
		"modulate:a",
		0.0,
		0.12
	).set_trans(Tween.TRANS_SINE).set_ease(
		Tween.EASE_OUT
	)

	await tween.finished

	# The controls were the source of the turn, not a second visible page.
	# Hide them once the turn has reached the left cover, where the mirrored
	# page texture remains as the visual back of the turned page.
	from_page.visible = false
	from_page.modulate.a = 0.0

	# Lay the final texture directly over the left cover's page inset. This
	# avoids relying on a negative parent scale for its final orientation.
	page_turn_pivot.visible = true
	page_turn_pivot.position = Vector2.ZERO
	page_turn_pivot.scale = Vector2.ONE

	turning_page.visible = true
	turning_page.position = PAGE_INSET
	_set_turning_page_reflected(true)



func _on_hud_page_continue_pressed() -> void:
	if current_menu_page != MenuPage.HUD:
		return

	if page_transition_running:
		return

	page_transition_running = true

	_set_page_input_enabled(
		hud_page,
		hud_page_continue_button,
		false
	)



	# Route this through the level manager so its persistent transition layer
	# can fade over the scene replacement just like level-to-level changes.
	LvlManager.load_level(0)

func _apply_page_turn_progress(progress: float) -> void:
	if progress < 0.5:
		var fold_progress: float = smoothstep(
			0.0,
			1.0,
			progress * 2.0
		)

		_set_turning_page_reflected(false)

		page_turn_pivot.scale = Vector2(
			lerpf(
				1.0,
				0.015,
				fold_progress
			),
			lerpf(
				1.0,
				0.97,
				fold_progress
			)
		)
	else:
		var unfold_progress: float = smoothstep(
			0.0,
			1.0,
			(progress - 0.5) * 2.0
		)

		_set_turning_page_reflected(false)


		page_turn_pivot.scale = Vector2(
			lerpf(
				-0.015,
				-1.0,
				unfold_progress
			),
			lerpf(
				0.97,
				1.0,
				unfold_progress
			)
		)

func _configure_page_turn() -> void:
	# The pivot's origin is placed directly at the book spine.
	_place_control(
		page_turn_pivot,
		Vector2(
			COVER_SIZE.x,
			PAGE_INSET.y
		),
		Vector2(
			PAGE_SIZE.x + PAGE_INSET.x,
			PAGE_SIZE.y
		)
	)

	# The local origin is already the hinge, so no horizontal
	# pivot offset is needed.
	page_turn_pivot.pivot_offset = Vector2(
		0.0,
		PAGE_SIZE.y * 0.5
	)

	page_turn_pivot.clip_contents = false
	page_turn_pivot.mouse_filter = \
		Control.MOUSE_FILTER_IGNORE
	page_turn_pivot.z_index = 30

	# The actual page art starts PAGE_INSET.x pixels to the right
	# of the cover's physical spine.
	_configure_texture_rect(
		turning_page,
		Vector2(
			PAGE_INSET.x,
			0.0
		),
		PAGE_SIZE
	)

	turning_page.texture = pages.texture
	_set_turning_page_reflected(false)
	turning_page.mouse_filter = \
		Control.MOUSE_FILTER_IGNORE


func _set_turning_page_reflected(reflected: bool) -> void:
	turning_page_is_reflected = reflected
	turning_page.flip_h = turning_page_is_reflected
