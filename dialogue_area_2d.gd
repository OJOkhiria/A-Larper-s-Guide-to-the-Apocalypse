extends Area2D

const DialogueSystemPreload = preload("res://Dialogue_System.tscn")
var active_camera: Camera2D

enum BoxPlacement {
	AUTO,
	CENTER,
	TOP,
	BOTTOM,
	CUSTOM
}

@export var activate_instant: bool = false
@export var only_activate_once: bool = false
@export var override_dialogue_position: bool = false
@export var override_position: Vector2 = Vector2.ZERO
@export var box_placement: BoxPlacement = BoxPlacement.AUTO
@export var dialogue: Array[DE] = []
@export var camera_target_path: Marker2D
@export var camera_pan_time: float = 0.7
@export var pan_before_dialogue: bool = true

var dialogue_top_pos: Vector2 = Vector2(160, 48)
var dialogue_bottom_pos: Vector2 = Vector2(160, 92)

var player_body_in: bool = false
var has_activated_already: bool = false
var desired_dialogue_pos: Vector2 = Vector2.ZERO

var player_node: CharacterBody2D = null
var camera_home_local_position: Vector2


func play_dialogue() -> void:
	_activate_dialogue()


func _process(_delta: float) -> void:
	if not player_node:
		for i in get_tree().get_nodes_in_group("player"):
			player_node = i
			break
		return

	if not activate_instant and player_body_in:
		if only_activate_once and has_activated_already:
			set_process(false)
			return

		if Input.is_action_just_pressed("ui_accept"):
			_activate_dialogue()
			player_body_in = false


func _activate_dialogue() -> void:
	if not player_node:
		for i in get_tree().get_nodes_in_group("player"):
			player_node = i
			break

	if not player_node:
		push_warning("No player found!")
		return

	player_node.set_controls_enabled(false)
	has_activated_already = true


	var new_dialogue = DialogueSystemPreload.instantiate()
	new_dialogue.dialogue = dialogue

	if pan_before_dialogue:
		await _pan_camera_to_target()

	# UI-root dialogue scenes should not be moved with global_position.
	# Instead, pass a placement hint to the dialogue scene if it supports it.
	if box_placement == BoxPlacement.CENTER:
		desired_dialogue_pos = get_viewport().get_visible_rect().size * 0.5
	elif box_placement == BoxPlacement.TOP:
		desired_dialogue_pos = dialogue_top_pos
	elif box_placement == BoxPlacement.BOTTOM:
		desired_dialogue_pos = dialogue_bottom_pos
	elif box_placement == BoxPlacement.CUSTOM:
		desired_dialogue_pos = override_position
	else:
		if override_dialogue_position:
			desired_dialogue_pos = override_position
		else:
			var camera := get_viewport().get_camera_2d()
			if camera and player_node.global_position.y > camera.get_screen_center_position().y:
				desired_dialogue_pos = dialogue_top_pos
			else:
				desired_dialogue_pos = dialogue_bottom_pos

	get_parent().add_child(new_dialogue)
	if pan_before_dialogue:
		DialogueBus.dialogue_finished.connect(
		_return_camera,
		CONNECT_ONE_SHOT
	)
	
	if new_dialogue.has_method("set_box_placement"):
		new_dialogue.call("set_box_placement", box_placement, desired_dialogue_pos)
	elif new_dialogue.has_method("set_dialogue_position"):
		new_dialogue.call("set_dialogue_position", desired_dialogue_pos)


func _on_body_entered(body: Node2D) -> void:
	if only_activate_once and has_activated_already:
		return

	if body.is_in_group("player"):
		player_body_in = true
		if activate_instant:
			_activate_dialogue()


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_body_in = false
		
func _pan_camera_to_target() -> void:
	active_camera = get_viewport().get_camera_2d()
	if not active_camera:
		return

	if not camera_target_path:
		return

	# Save where the camera normally lives under the player
	camera_home_local_position = active_camera.position

	# Detach from the player before moving it independently
	active_camera.top_level = true

	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(
		active_camera,
		"global_position",
		camera_target_path.global_position,
		camera_pan_time
	)

	await tween.finished

func _return_camera() -> void:
	if not active_camera or not player_node:
		return

	var return_target := player_node.to_global(camera_home_local_position)

	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(
		active_camera,
		"global_position",
		return_target,
		0.7
	)

	await tween.finished

	active_camera.position = camera_home_local_position
	active_camera.top_level = false
	active_camera.reset_smoothing()
