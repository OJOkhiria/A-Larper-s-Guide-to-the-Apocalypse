class_name ObjectiveConsole
extends Area2D

signal activated(console_id: StringName)

@export var console_id: StringName = &""
@export var prompt_text: String = "Press Enter to interact"

@onready var prompt: Label = $Prompt

var player_in_range := false
var is_activated := false


func _ready() -> void:
	prompt.text = prompt_text
	prompt.visible = false
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _process(_delta: float) -> void:
	if player_in_range and not is_activated and Input.is_action_just_pressed("ui_accept"):
		activate()


func activate() -> void:
	if is_activated:
		return

	is_activated = true
	prompt.visible = false
	monitoring = false
	modulate = Color(0.4, 1.0, 0.55, 1.0)
	activated.emit(console_id)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and not is_activated:
		player_in_range = true
		prompt.visible = true


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = false
		prompt.visible = false
