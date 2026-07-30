extends Node

@export var required_correct_answers: int = 8
@export var reward_path: NodePath

var correct_booth_ids: Dictionary[StringName, bool] = {}
var reward_revealed: bool = false


func booth_answered_correctly(booth_id: StringName) -> void:
	if booth_id == &"" or correct_booth_ids.has(booth_id):
		return

	correct_booth_ids[booth_id] = true

	if correct_booth_ids.size() >= required_correct_answers:
		_reveal_reward()


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
