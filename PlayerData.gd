extends Node


var max_health: int = 3

var _pending_death_source: StringName = &""
# Dialogue areas are recreated when a level reloads. Keep their completed
# state here so one-time dialogue can survive respawns during the current run.
var _completed_dialogue_ids: Dictionary[StringName, bool] = {}
var _collected_item_ids: Dictionary[StringName, bool] = {}


func set_pending_death_source(
	source_id: StringName
) -> void:
	_pending_death_source = source_id


func consume_pending_death_source() -> StringName:
	var source_id: StringName = _pending_death_source
	_pending_death_source = &""

	return source_id


func clear_pending_death_source() -> void:
	_pending_death_source = &""


func has_completed_dialogue(dialogue_id: StringName) -> bool:
	return dialogue_id != &"" and _completed_dialogue_ids.has(dialogue_id)


func mark_dialogue_completed(dialogue_id: StringName) -> void:
	if dialogue_id == &"":
		return

	_completed_dialogue_ids[dialogue_id] = true


func clear_completed_dialogue(dialogue_id: StringName) -> void:
	_completed_dialogue_ids.erase(dialogue_id)


func has_collected_item(item_id: StringName) -> bool:
	return item_id != &"" and _collected_item_ids.has(item_id)


func mark_item_collected(item_id: StringName) -> void:
	if item_id != &"":
		_collected_item_ids[item_id] = true
