extends Node

@onready var intro_dialogue: Area2D = $DialogueArea2D
@onready var player: CharacterBody2D = $Player


func _ready() -> void:
	DialogueBus.dialogue_finished.connect(on_dialogue_finished)
	call_deferred("_start_intro_cutscene")

func _start_intro_cutscene() -> void:
	intro_dialogue.play_dialogue()

func on_dialogue_finished() -> void:
	LvlManager.call_deferred("load_level", 1)
