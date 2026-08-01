class_name ObjectiveConsole
extends Area2D

signal activated(console_id: StringName)

@export var console_id: StringName = &""
@export var prompt_text: String = "Press Enter to interact"
@export var use_reaction_minigame := false
@export_range(16.0, 256.0, 1.0) var interaction_radius := 80.0
@export_range(1, 12) var reaction_sequence_length := 6
@export_range(0.25, 5.0, 0.05) var reaction_time_limit := 0.85
@export_range(1, 10) var mistakes_before_short_circuit := 3
@export_range(1, 10) var short_circuit_damage := 1
@export var short_circuit_death_source_id: StringName = &"Shock"

@onready var prompt: Label = $Prompt

var player_in_range := false
var is_activated := false
var reaction_active := false
var reaction_sequence: Array[Key] = []
var reaction_index := 0
var reaction_mistakes := 0
var reaction_time_remaining := 0.0
var reaction_display: Label
var active_player: Node2D

const REACTION_KEYS: Array[Key] = [KEY_Q, KEY_E, KEY_R, KEY_T]


func _ready() -> void:
	prompt.text = prompt_text
	prompt.visible = false
	_create_reaction_display()
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _process(_delta: float) -> void:
	_refresh_player_proximity()
	if not player_in_range or is_activated:
		return

	if not reaction_active:
		if Input.is_action_just_pressed("ui_accept"):
			if use_reaction_minigame:
				_start_reaction_minigame()
			else:
				activate()
		return

	reaction_time_remaining -= _delta
	if reaction_time_remaining <= 0.0:
		_register_reaction_mistake("Too slow")


func _unhandled_key_input(event: InputEvent) -> void:
	if is_activated or not reaction_active or not player_in_range:
		return
	# A key event can still arrive during the frame that completes the sequence.
	# Ignore it instead of indexing past the final reaction key.
	if reaction_sequence.is_empty() or reaction_index >= reaction_sequence.size():
		reaction_active = false
		return

	var key_event := event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return

	get_viewport().set_input_as_handled()
	if key_event.keycode == reaction_sequence[reaction_index]:
		reaction_index += 1
		if reaction_index >= reaction_sequence.size():
			activate()
		else:
			reaction_time_remaining = reaction_time_limit
			_update_reaction_prompt()
	else:
		_register_reaction_mistake("Wrong key")


func activate() -> void:
	if is_activated:
		return

	is_activated = true
	reaction_active = false
	prompt.visible = false
	reaction_display.visible = false
	monitoring = false
	modulate = Color(0.4, 1.0, 0.55, 1.0)
	activated.emit(console_id)


func _start_reaction_minigame() -> void:
	reaction_active = true
	reaction_index = 0
	reaction_mistakes = 0
	reaction_sequence.clear()

	for step in reaction_sequence_length:
		reaction_sequence.append(
			REACTION_KEYS.pick_random()
		)

	reaction_time_remaining = reaction_time_limit
	prompt.visible = false
	reaction_display.visible = true
	_update_reaction_prompt()


func _register_reaction_mistake(reason: String) -> void:
	reaction_mistakes += 1
	if reaction_mistakes >= mistakes_before_short_circuit:
		_short_circuit()
		return

	reaction_time_remaining = reaction_time_limit
	reaction_display.modulate = Color(1.0, 0.3, 0.2, 1.0)
	reaction_display.text = "%s  %d / %d\n[%s]" % [
		reason.to_upper(),
		reaction_mistakes,
		mistakes_before_short_circuit,
		_key_display_name(reaction_sequence[reaction_index]),
	]


func _short_circuit() -> void:
	reaction_active = false
	modulate = Color(1.0, 0.3, 0.2, 1.0)
	reaction_display.modulate = Color(1.0, 0.2, 0.1, 1.0)
	reaction_display.text = "SHORT CIRCUIT\nSHOCK"
	reaction_display.visible = true

	var player := _get_overlapping_player()
	if player != null:
		var health := player.get_node_or_null("Health")
		if health != null and health.has_method("take_damage"):
			health.take_damage(short_circuit_damage, self)

	await get_tree().create_timer(0.75).timeout
	if not is_activated:
		modulate = Color.WHITE
		reaction_display.visible = false
		if player_in_range:
			prompt.text = prompt_text
			prompt.visible = true


func _update_reaction_prompt() -> void:
	reaction_display.modulate = Color(1.0, 0.85, 0.2, 1.0)
	reaction_display.text = "[%s]\n%d / %d" % [
		_key_display_name(reaction_sequence[reaction_index]),
		reaction_index + 1,
		reaction_sequence.size(),
	]


func _create_reaction_display() -> void:
	var canvas_layer := CanvasLayer.new()
	canvas_layer.layer = 20
	add_child(canvas_layer)

	reaction_display = Label.new()
	reaction_display.set_anchors_preset(Control.PRESET_CENTER)
	reaction_display.offset_left = -180.0
	reaction_display.offset_top = -70.0
	reaction_display.offset_right = 180.0
	reaction_display.offset_bottom = 70.0
	reaction_display.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reaction_display.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	reaction_display.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2, 1.0))
	reaction_display.add_theme_color_override("font_outline_color", Color(0.04, 0.02, 0.01, 1.0))
	reaction_display.add_theme_constant_override("outline_size", 12)
	reaction_display.add_theme_font_size_override("font_size", 64)
	reaction_display.visible = false
	canvas_layer.add_child(reaction_display)


func _key_display_name(key: Key) -> String:
	return OS.get_keycode_string(key)


func _get_overlapping_player() -> Node2D:
	if is_instance_valid(active_player):
		return active_player

	for body in get_overlapping_bodies():
		if body is Node2D and body.is_in_group("player"):
			return body
	return null


func _refresh_player_proximity() -> void:
	if is_activated:
		return

	var nearby_player: Node2D
	var interaction_origin := global_position
	var collision_shape := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision_shape != null:
		interaction_origin = collision_shape.global_position

	for candidate in get_tree().get_nodes_in_group("player"):
		if candidate is Node2D:
			var player_position: Vector2 = candidate.global_position
			var player_collision := candidate.get_node_or_null("StandingCollision") as CollisionShape2D
			if player_collision != null:
				player_position = player_collision.global_position

			if player_position.distance_to(interaction_origin) <= interaction_radius:
				nearby_player = candidate
				break

	if nearby_player != null:
		active_player = nearby_player

	if player_in_range == (nearby_player != null):
		return

	player_in_range = nearby_player != null
	if player_in_range:
		prompt.text = prompt_text
		prompt.visible = not reaction_active
	else:
		reaction_active = false
		prompt.visible = false
		reaction_display.visible = false


func get_death_source_id() -> StringName:
	return short_circuit_death_source_id


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and not is_activated:
		active_player = body
		player_in_range = true
		prompt.text = prompt_text
		prompt.visible = true


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		if body == active_player:
			active_player = null
		player_in_range = false
		reaction_active = false
		prompt.visible = false
		reaction_display.visible = false
