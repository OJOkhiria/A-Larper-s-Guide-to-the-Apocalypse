extends Node


var max_health: int = 3

var _pending_death_source: StringName = &""


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
