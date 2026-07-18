extends CharacterBody2D

const SPEED: float = 300.0
const JUMP_VELOCITY: float = -475.0

@onready var health: Node = $Health

@onready var animated_sprite: AnimatedSprite2D = $Sprite2D

var controls_enabled: bool = true
var is_dead: bool = false


func _ready() -> void:
	health.died.connect(_on_health_died)


func set_controls_enabled(enabled: bool) -> void:
	controls_enabled = enabled


func _physics_process(delta: float) -> void:
	if is_dead:
		velocity = Vector2.ZERO
		animated_sprite.play("idle")
		return

	if not controls_enabled:
		velocity.x = move_toward(velocity.x, 0.0, SPEED)
		animated_sprite.play("idle")
		move_and_slide()
		return

	if not is_on_floor():
		velocity += get_gravity() * delta

	if Input.is_action_just_pressed("Jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var direction: float = Input.get_axis("Left", "Right")

	if direction != 0.0:
		velocity.x = direction * SPEED
		animated_sprite.flip_h = direction < 0.0
	else:
		velocity.x = move_toward(velocity.x, 0.0, SPEED)

	_update_animation(direction)
	move_and_slide()

func _update_animation(direction: float) -> void:
	if not is_on_floor():
		animated_sprite.play("jump")
	elif direction != 0.0:
		animated_sprite.play("run")
	else:
		animated_sprite.play("idle")


func _on_health_died(death_source: Node = null) -> void:
	if is_dead:
		return

	is_dead = true
	controls_enabled = false
	velocity = Vector2.ZERO

	GameOver.show_game_over()


func _on_detection_area_body_exited(body: Node2D) -> void:
	pass # Replace with function body.
