class_name ConferenceBooth
extends Area2D

const DIALOGUE_SCENE: PackedScene = preload(
	"res://DialogueSystem/Dialogue_System.tscn"
)

@export var booth_id: StringName
@export_multiline var question: String
@export var answers: Array[String] = []
@export_range(0, 2) var correct_answer_index: int = 0
@export var booth_texture: Texture2D

@onready var booth_visual: Node2D = $BoothVisual
@onready var booth_sprite: Sprite2D = $BoothVisual/Sprite2D
@onready var trigger_shape: CollisionShape2D = $TriggerShape

var resolved: bool = false


func _ready() -> void:
	if booth_texture != null:
		booth_sprite.texture = booth_texture

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if resolved or not body.is_in_group("player"):
		return

	resolved = true
	set_deferred("monitoring", false)
	if body.has_method("set_controls_enabled"):
		body.call("set_controls_enabled", false)
	_show_question()


func _show_question() -> void:
	var dialogue_ui := DIALOGUE_SCENE.instantiate()
	var choice := DialogueChoice.new()
	choice.text = question
	choice.choice_text = answers
	choice.choice_function_call = []

	for index in answers.size():
		var answer_action := DialogueFunction.new()
		answer_action.target_path = NodePath("..")
		answer_action.function_name = (
			&"answer_correct"
			if index == correct_answer_index
			else &"answer_wrong"
		)
		choice.choice_function_call.append(answer_action)

	var dialogue_entries: Array[DE] = []
	dialogue_entries.append(choice)
	dialogue_ui.call("set_dialogue_entries", dialogue_entries)
	add_child(dialogue_ui)


func answer_correct() -> void:
	# The Level 3 scene names this controller Lvl3Controller. Keep the legacy
	# name as a fallback so existing variants of the level remain compatible.
	var controller := get_tree().current_scene.get_node_or_null("Lvl3Controller")
	if controller == null:
		controller = get_tree().current_scene.get_node_or_null(
			"BoothChallengeController"
		)
	if controller != null and controller.has_method("booth_answered_correctly"):
		controller.call("booth_answered_correctly", booth_id)


func answer_wrong() -> void:
	trigger_shape.set_deferred("disabled", true)

	var player := get_tree().get_first_node_in_group("player")
	if player != null:
		var health := player.get_node_or_null("Health")
		if health != null and health.has_method("take_damage"):
			health.take_damage(1, self)

	var collapse_tween := create_tween()
	collapse_tween.set_parallel(true)
	collapse_tween.tween_property(
		booth_visual,
		"position:y",
		booth_visual.position.y + 96.0,
		0.45
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	collapse_tween.tween_property(
		booth_visual,
		"rotation_degrees",
		18.0,
		0.45
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func get_death_source_id() -> StringName:
	return &"falling_object"
