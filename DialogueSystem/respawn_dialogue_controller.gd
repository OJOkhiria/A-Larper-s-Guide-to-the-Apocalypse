extends Node


@export_group("Dialogue System")

@export var dialogue_system_scene: PackedScene


@export_group("Death Dialogues")

@export var bomber_bomb_dialogue: Array[DE] = []
@export var spikes_dialogue: Array[DE] = []
@export var falling_object_dialogue: Array[DE] = []
@export var generic_death_dialogue: Array[DE] = []


var dialogue_started: bool = false


func _ready() -> void:
	call_deferred(
		&"_play_pending_respawn_dialogue"
	)


func _play_pending_respawn_dialogue() -> void:
	if dialogue_started:
		return

	var source_id: StringName = \
		PlayerData.consume_pending_death_source()

	# A blank source means this was a normal level load.
	if source_id == &"":
		return

	var dialogue_to_play: Array[DE] = \
		_get_dialogue_for_source(source_id)

	if dialogue_to_play.is_empty():
		push_warning(
			"No respawn dialogue was assigned for death "
			+ "source '%s'."
			% source_id
		)
		return

	# Allow the level, player, camera, and HUD to finish entering
	# the scene tree before creating the dialogue interface.
	await get_tree().process_frame
	await get_tree().process_frame

	dialogue_started = true

	_start_dialogue(dialogue_to_play)


func _get_dialogue_for_source(
	source_id: StringName
) -> Array[DE]:
	match source_id:
		&"bomber_bomb":
			return bomber_bomb_dialogue

		&"spikes":
			return spikes_dialogue

		&"falling_object":
			return falling_object_dialogue

		_:
			return generic_death_dialogue


func _start_dialogue(
	dialogue_to_play: Array[DE]
) -> void:
	if dialogue_system_scene == null:
		push_error(
			"RespawnDialogueController has no "
			+ "Dialogue System Scene assigned."
		)
		dialogue_started = false
		return

	if dialogue_to_play.is_empty():
		dialogue_started = false
		return

	var new_dialogue = \
		dialogue_system_scene.instantiate()

	if new_dialogue == null:
		push_error(
			"Dialogue system scene could not be instantiated."
		)
		dialogue_started = false
		return

	# This matches the API used by your existing DialogueArea2D:
	# instantiate the dialogue UI, assign its dialogue array, and
	# then add it to the current scene.
	new_dialogue.dialogue = dialogue_to_play

	get_tree().current_scene.add_child(
		new_dialogue
	)
