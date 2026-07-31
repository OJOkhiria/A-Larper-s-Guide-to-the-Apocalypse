class_name SpikeHazard
extends Area2D


@export var damage: int = 3
@export var death_source_id: StringName = &"spikes"
@export var hazard_width: float = 64.0
@export var spike_texture: Texture2D

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var spike_sprite: Sprite2D = $SpikeSprite


func _ready() -> void:
	add_to_group("spikes")
	if spike_texture != null:
		spike_sprite.texture = spike_texture

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

	var hitbox := collision_shape.shape as RectangleShape2D
	if hitbox != null:
		# Scene instances can otherwise share this subresource. Duplicate it so
		# each pit keeps the width configured on its own instance.
		hitbox = hitbox.duplicate() as RectangleShape2D
		collision_shape.shape = hitbox
		hitbox.size = Vector2(hazard_width, 16.0)

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return

	var health := body.get_node_or_null("Health")
	if health != null and health.has_method("take_damage"):
		health.take_damage(damage, self)


func get_death_source_id() -> StringName:
	return death_source_id
