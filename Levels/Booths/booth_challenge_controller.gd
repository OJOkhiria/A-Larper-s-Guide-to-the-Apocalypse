extends Node

const DIALOGUE_SCENE: PackedScene = preload(
	"res://DialogueSystem/Dialogue_System.tscn"
)
const REAL_EXCITED: Texture2D = preload("res://REAL_excited.png")

@export var required_correct_answers: int = 8
@export var reward_path: NodePath

var correct_booth_ids: Dictionary[StringName, bool] = {}
var reward_revealed: bool = false
var perfect_score_dialogue_shown: bool = false


func booth_answered_correctly(booth_id: StringName) -> void:
	if booth_id == &"" or correct_booth_ids.has(booth_id):
		return

	correct_booth_ids[booth_id] = true

	if correct_booth_ids.size() >= required_correct_answers:
		_reveal_reward()
		_show_perfect_score_dialogue()


func _reveal_reward() -> void:
	if reward_revealed:
		return

	var reward: Node = null
	if reward_path != NodePath():
		reward = get_node_or_null(reward_path)
	if reward == null and get_parent() != null:
		reward = get_parent().get_node_or_null("MatchaReward")
	if reward == null:
		push_warning("Booth challenge reward was not found.")
		return

	reward_revealed = true
	if reward.has_method("activate"):
		reward.call("activate")


func _show_perfect_score_dialogue() -> void:
	if perfect_score_dialogue_shown:
		return

	perfect_score_dialogue_shown = true
	# Let the final booth's choice dialogue finish and release its UI first.
	await get_tree().process_frame
	await get_tree().process_frame

	var player := get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("set_controls_enabled"):
		player.call("set_controls_enabled", false)

	var dialogue_ui := DIALOGUE_SCENE.instantiate()
	var success_choice := DialogueChoice.new()
	success_choice.text = (
		"See, I knew you could do it! Way to keep it real. "
	)
	success_choice.speaker_img = REAL_EXCITED
	success_choice.choice_text = ["Continue"]

	var continue_action := DialogueFunction.new()
	continue_action.target_path = NodePath("..")
	continue_action.function_name = "acknowledge_perfect_score"
	success_choice.choice_function_call = []
	success_choice.choice_function_call.append(continue_action)

	var dialogue_entries: Array[DE] = []
	dialogue_entries.append(success_choice)
	dialogue_ui.call("set_dialogue_entries", dialogue_entries)
	add_child(dialogue_ui)


func acknowledge_perfect_score() -> void:
	pass
