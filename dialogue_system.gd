extends CanvasLayer


const DialogueButtonPreload = preload("res://dialogue_button.tscn")

enum BoxPlacement {
	AUTO,
	CENTER,
	TOP,
	BOTTOM,
	CUSTOM
}

@onready var DialogueBox: Control = $PanelContainer
@onready var DialogueLabel: RichTextLabel = $PanelContainer/HBoxContainer/VBoxContainer/RichTextLabel
@onready var SpeakerSprite: Sprite2D = $PanelContainer/HBoxContainer/SpeakerMargin/SpeakerParent/Sprite2D
@onready var ButtonContainer: Control = $PanelContainer/HBoxContainer/VBoxContainer/ButtonContainer

var dialogue: Array[DE]
var current_dialogue_item: int = 0
var next_item: bool = true

var player_node: CharacterBody2D


func _ready() -> void:
	DialogueBox.visible = false
	ButtonContainer.visible = false

	for i in get_tree().get_nodes_in_group("player"):
		player_node = i
		break


func set_box_placement(mode: int, pos: Vector2 = Vector2.ZERO) -> void:
	await get_tree().process_frame

	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var box_size: Vector2 = DialogueBox.size

	match mode:
		BoxPlacement.CENTER:
			DialogueBox.position = viewport_size * 0.5 - box_size * 0.5

		BoxPlacement.TOP:
			DialogueBox.position = Vector2(
				(viewport_size.x - box_size.x) * 0.5,
				32
			)

		BoxPlacement.BOTTOM:
			DialogueBox.position = Vector2(
				(viewport_size.x - box_size.x)*0.5,
				viewport_size.y - box_size.y - 32
			)

		BoxPlacement.CUSTOM:
			DialogueBox.position = pos

		_:
			DialogueBox.position = pos


func set_dialogue_position(pos: Vector2) -> void:
	await get_tree().process_frame
	DialogueBox.position = pos


func _process(_delta: float) -> void:
	if current_dialogue_item == dialogue.size():
		if !player_node:
			for i in get_tree().get_nodes_in_group("player"):
				player_node = i
				break
			return

		player_node.controls_enabled = true
		DialogueBus.dialogue_finished.emit()
		queue_free()
		return

	if next_item:
		next_item = false
		var i = dialogue[current_dialogue_item]

		if i is DialogueFunction:
			if i.hide_dialogue_box:
				DialogueBox.visible = false
			else:
				DialogueBox.visible = true
			_function_resource(i)

		elif i is DialogueChoice:
			DialogueBox.visible = true
			_choice_resource(i)

		elif i is DialogueText:
			DialogueBox.visible = true
			_text_resource(i)

		else:
			printerr("You accidentally added a DE resource!")
			current_dialogue_item += 1
			next_item = true


func _function_resource(i: DialogueFunction) -> void:
	var target_node = get_node(i.target_path)
	if target_node.has_method(i.function_name):
		if i.function_arguments.size() == 0:
			target_node.call(i.function_name)
		else:
			target_node.callv(i.function_name, i.function_arguments)

	if i.wait_for_signal_to_continue:
		var signal_name = i.wait_for_signal_to_continue
		if target_node.has_signal(signal_name):
			var signal_state = {"done": false}
			var callable = func(_args): signal_state.done = true
			target_node.connect(signal_name, callable, CONNECT_ONE_SHOT)
			while not signal_state.done:
				await get_tree().process_frame

	current_dialogue_item += 1
	next_item = true


func _choice_resource(i: DialogueChoice) -> void:
	# set speaker name here
	DialogueLabel.text = i.text
	DialogueLabel.visible_characters = -1

	if i.speaker_img:
		$PanelContainer/HBoxContainer/SpeakerParent.visible = true
		SpeakerSprite.texture = i.speaker_img
		SpeakerSprite.hframes = i.speaker_img_Hframes
		SpeakerSprite.frame = i.speaker_img_select_frame
	else:
		$PanelContainer/HBoxContainer/SpeakerParent.visible = false

	ButtonContainer.visible = true

	for item in i.choice_text.size():
		var DialogueButtonVar = DialogueButtonPreload.instantiate()
		DialogueButtonVar.text = i.choice_text[item]

		var function_resource: DialogueFunction = i.choice_function_call[item]
		if function_resource:
			DialogueButtonVar.connect(
				"pressed",
				Callable(get_node(function_resource.target_path), function_resource.function_name).bindv(function_resource.function_arguments),
				CONNECT_ONE_SHOT
			)

			if function_resource.hide_dialogue_box:
				DialogueButtonVar.connect("pressed", hide, CONNECT_ONE_SHOT)

			DialogueButtonVar.connect(
				"pressed",
				_choice_button_pressed.bind(get_node(function_resource.target_path), function_resource.wait_for_signal_to_continue),
				CONNECT_ONE_SHOT
			)
		else:
			DialogueButtonVar.connect("pressed", _choice_button_pressed.bind(null, ""), CONNECT_ONE_SHOT)

		ButtonContainer.add_child(DialogueButtonVar)

	ButtonContainer.get_child(0).grab_focus()


func _choice_button_pressed(target_node: Node, wait_for_signal_to_continue: String):
	ButtonContainer.visible = false
	for i in ButtonContainer.get_children():
		i.queue_free()

	# add audio for button press here ig

	if wait_for_signal_to_continue:
		var signal_name = wait_for_signal_to_continue
		if target_node.has_signal(signal_name):
			var signal_state = {"done": false}
			var callable = func(_args): signal_state.done = true
			target_node.connect(signal_name, callable, CONNECT_ONE_SHOT)
			while not signal_state.done:
				await get_tree().process_frame

	current_dialogue_item += 1
	next_item = true


func _text_resource(i: DialogueText) -> void:
	# speaker name here
	$AudioStreamPlayer2D.stream = i.text_sound
	$AudioStreamPlayer2D.volume_db = i.text_volume_db

	var camera: Camera2D = get_viewport().get_camera_2d()
	if camera and i.camera_position != Vector2(999.999, 999.999):
		var camera_tween: Tween = create_tween().set_trans(Tween.TRANS_SINE)
		camera_tween.tween_property(camera, "global_position", i.camera_position, i.camera_transition_time)

	if !i.speaker_img:
		$PanelContainer/HBoxContainer/SpeakerMargin/SpeakerParent.visible = false
	else:
		$PanelContainer/HBoxContainer/SpeakerMargin/SpeakerParent.visible = true
		SpeakerSprite.texture = i.speaker_img
		SpeakerSprite.hframes = i.speaker_img_Hframes
		SpeakerSprite.scale = Vector2(0.25, 0.25)
		SpeakerSprite.frame = 0

	DialogueLabel.visible_characters = 0
	DialogueLabel.text = i.text + "\n\n(Press enter to continue)"

	var text_without_square_brackets: String = _text_without_square_brackets(DialogueLabel.text)
	var total_characters: int = text_without_square_brackets.length()
	var character_timer: float = 0.0

	while DialogueLabel.visible_characters < total_characters - 26:
		if Input.is_action_just_pressed("ui_cancel"):
			DialogueLabel.visible_characters = total_characters
			break

		character_timer += get_process_delta_time()
		if character_timer >= (1.0 / i.text_speed) or text_without_square_brackets[DialogueLabel.visible_characters] == " ":
			var character: String = text_without_square_brackets[DialogueLabel.visible_characters]
			DialogueLabel.visible_characters += 1

			if character != " ":
				$AudioStreamPlayer2D.pitch_scale = randf_range(i.text_volume_pitch_min, i.text_volume_pitch_max)
				$AudioStreamPlayer2D.play()

				if i.speaker_img_Hframes != 1:
					if SpeakerSprite.frame < i.speaker_img_Hframes - 1:
						SpeakerSprite.frame += 1
					else:
						SpeakerSprite.frame = 0

			character_timer = 0.0

		await get_tree().process_frame
	
	DialogueLabel.visible_characters = total_characters
	SpeakerSprite.frame = min(i.speaker_img_rest_frame, i.speaker_img_Hframes - 1)

	while true:
		await get_tree().process_frame
		if DialogueLabel.visible_characters == total_characters:
			if Input.is_action_just_pressed("ui_accept"):
				current_dialogue_item += 1
				next_item = true


func _text_without_square_brackets(text: String) -> String:
	var result: String = ""
	var inside_bracket: bool = false

	for i in text:
		if i == "[":
			inside_bracket = true
			continue

		if i == "]":
			inside_bracket = false
			continue

		if !inside_bracket:
			result += i

	return result
