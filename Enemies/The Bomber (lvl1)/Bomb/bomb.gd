class_name Bomb
extends CharacterBody2D

@export var damage: int = 1
@export var throw_speed: float = 300.0
@export var upward_force: float = 350.0
@export var gravity: float = 900.0
@export var ground_friction: float = 600.0
@export var fuse_time: float = 1.5
@export var maximum_lifetime: float = 8.0
@export var explosion_duration: float = 0.15

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var fuse_timer: Timer = $FuseTimer
@onready var lifetime_timer: Timer = $LifetimeTimer

@onready var flying_collision: CollisionShape2D = \
	$FlyingCollision

@onready var landed_collision: CollisionShape2D = \
	$LandedCollision

@onready var explosion_area: Area2D = \
	$ExplosionArea

@onready var explosion_collision: CollisionShape2D = \
	$ExplosionArea/ExplosionCollision
	
@export var starting_explosion_radius: float = 8.0
@export var maximum_explosion_radius: float = 72.0

@onready var explosion_shape: CircleShape2D = \
	explosion_collision.shape as CircleShape2D

var has_exploded: bool = false
var damaged_bodies: Array[Node] = []

enum BombState {
	FLYING,
	LANDED,
	EXPLODING
}

var current_state: BombState = BombState.FLYING

func _ready() -> void:
	current_state = BombState.FLYING

	flying_collision.set_deferred("disabled", false)
	landed_collision.set_deferred("disabled", true)
	explosion_collision.set_deferred("disabled", true)

	explosion_area.body_entered.connect(
		_on_explosion_area_body_entered
	)

	fuse_timer.wait_time = fuse_time
	fuse_timer.one_shot = true
	fuse_timer.timeout.connect(explode)
	fuse_timer.start()

	lifetime_timer.wait_time = maximum_lifetime
	lifetime_timer.one_shot = true
	lifetime_timer.timeout.connect(queue_free)
	lifetime_timer.start()

	sprite.animation_finished.connect(
		_on_animation_finished
	)

	sprite.play("flying")


func launch(horizontal_direction: float) -> void:
	horizontal_direction = sign(horizontal_direction)

	if horizontal_direction == 0.0:
		horizontal_direction = 1.0

	velocity = Vector2(
		horizontal_direction * throw_speed,
		-upward_force
	)


func _physics_process(delta: float) -> void:
	if current_state == BombState.EXPLODING:
		return

	velocity.y += gravity * delta
	move_and_slide()

	if is_on_floor():
		velocity.x = move_toward(
			velocity.x,
			0.0,
			ground_friction * delta
		)

		if current_state == BombState.FLYING:
			_set_bomb_state(BombState.LANDED)
			sprite.play("landed")


func explode() -> void:
	if current_state == BombState.EXPLODING:
		return

	_set_bomb_state(BombState.EXPLODING)

	velocity = Vector2.ZERO
	damaged_bodies.clear()

	explosion_shape.radius = starting_explosion_radius
	sprite.play("explode")

	await get_tree().physics_frame

	var radius_tween := create_tween()
	radius_tween.tween_property(
		explosion_shape,
		"radius",
		maximum_explosion_radius,
		explosion_duration
	).set_trans(Tween.TRANS_QUAD).set_ease(
		Tween.EASE_OUT
	)

	await radius_tween.finished

	for body in explosion_area.get_overlapping_bodies():
		_damage_body(body)

	explosion_collision.set_deferred(
		"disabled",
		true
	)


func _on_explosion_area_body_entered(
	body: Node2D
) -> void:
	if current_state != BombState.EXPLODING:
		return

	_damage_body(body)


func _damage_body(body: Node) -> void:
	if body in damaged_bodies:
		return

	if not body.is_in_group("player"):
		return

	damaged_bodies.append(body)

	var health := body.get_node_or_null("Health")

	if health != null and health.has_method("take_damage"):
		health.take_damage(damage)
	elif body.has_method("take_damage"):
		body.take_damage(damage)


func _on_animation_finished() -> void:
	if sprite.animation == "explode":
		queue_free()

func _set_bomb_state(new_state: BombState) -> void:
	if current_state == new_state:
		return

	current_state = new_state

	match current_state:
		BombState.FLYING:
			flying_collision.set_deferred(
				"disabled",
				false
			)
			landed_collision.set_deferred(
				"disabled",
				true
			)
			explosion_collision.set_deferred(
				"disabled",
				true
			)

		BombState.LANDED:
			flying_collision.set_deferred(
				"disabled",
				true
			)
			landed_collision.set_deferred(
				"disabled",
				false
			)
			explosion_collision.set_deferred(
				"disabled",
				true
			)

		BombState.EXPLODING:
			flying_collision.set_deferred(
				"disabled",
				true
			)
			landed_collision.set_deferred(
				"disabled",
				true
			)
			explosion_collision.set_deferred(
				"disabled",
				false
			)
