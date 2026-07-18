class_name Bomb
extends CharacterBody2D

@export var damage: int = 1
@export var throw_speed: float = 300.0
@export var upward_force: float = 350.0
@export var gravity: float = 900.0
@export var fuse_time: float = 1.5
@export var maximum_lifetime: float = 8.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var body_collision: CollisionShape2D = $CollisionShape2D
@onready var explosion_collision: CollisionShape2D = \
	$ExplosionArea/CollisionShape2D
@onready var fuse_timer: Timer = $FuseTimer
@onready var lifetime_timer: Timer = $LifetimeTimer

var has_exploded: bool = false


func _ready() -> void:
	explosion_collision.disabled = true

	fuse_timer.wait_time = fuse_time
	fuse_timer.one_shot = true
	fuse_timer.timeout.connect(explode)
	fuse_timer.start()

	lifetime_timer.wait_time = maximum_lifetime
	lifetime_timer.one_shot = true
	lifetime_timer.timeout.connect(queue_free)
	lifetime_timer.start()

	sprite.animation_finished.connect(_on_animation_finished)
	sprite.play("flying")


func launch(direction: Vector2) -> void:
	velocity.x = direction.x * throw_speed
	velocity.y = -upward_force


func _physics_process(delta: float) -> void:
	if has_exploded:
		return

	velocity.y += gravity * delta
	move_and_slide()

	if is_on_floor():
		velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)

		if sprite.animation != "landed":
			sprite.play("landed")


func explode() -> void:
	if has_exploded:
		return

	has_exploded = true
	velocity = Vector2.ZERO

	body_collision.set_deferred("disabled", true)
	explosion_collision.set_deferred("disabled", false)

	sprite.play("explode")

	# Wait one physics frame so the newly enabled explosion area
	# can detect overlapping bodies.
	await get_tree().physics_frame

	for body in $ExplosionArea.get_overlapping_bodies():
		_damage_body(body)

	# The explosion only damages once.
	explosion_collision.set_deferred("disabled", true)


func _damage_body(body: Node) -> void:
	if not body.is_in_group("player"):
		return

	var health := body.get_node_or_null("Health")

	if health and health.has_method("take_damage"):
		health.take_damage(damage)
	elif body.has_method("take_damage"):
		body.take_damage(damage)


func _on_animation_finished() -> void:
	if sprite.animation == "explode":
		queue_free()
