extends CharacterBody2D


signal crouch_changed(is_crouching: bool)


@export_group("Movement")

@export var movement_speed: float = 275.0
@export var crouch_speed: float = 200.0

@export var ground_acceleration: float = 2400.0
@export var ground_deceleration: float = 2800.0

@export var jump_velocity: float = -475.0


@export_group("Animations")

@export var idle_animation: StringName = &"idle"
@export var run_animation: StringName = &"run"
@export var jump_animation: StringName = &"jump"
@export var crouch_animation: StringName = &"crouch"


const INPUT_LEFT: StringName = &"Left"
const INPUT_RIGHT: StringName = &"Right"
const INPUT_JUMP: StringName = &"Jump"
const INPUT_CROUCH: StringName = &"Crouch"


@onready var health: Node = get_node_or_null("Health")

@onready var animated_sprite: AnimatedSprite2D = \
	$AnimatedSprite2D

@onready var standing_collision: CollisionShape2D = \
	$StandingCollision

@onready var crouching_collision: CollisionShape2D = \
	$CrouchingCollision

@onready var standing_clearance: ShapeCast2D = \
	$StandingClearance


var controls_enabled: bool = true
var is_crouching: bool = false
var is_dead: bool = false


func _ready() -> void:
	_initialize_crouching()
	_connect_health_signal()
	_validate_animations()


func _physics_process(delta: float) -> void:
	if is_dead:
		_process_dead_state()
		return

	_apply_gravity(delta)

	if not controls_enabled:
		_process_disabled_state(delta)
		return

	_update_crouching()

	var direction: float = Input.get_axis(
		INPUT_LEFT,
		INPUT_RIGHT
	)

	_handle_jump()
	_handle_horizontal_movement(direction, delta)

	move_and_slide()

	_update_animation(direction)


func set_controls_enabled(enabled: bool) -> void:
	controls_enabled = enabled

	if not controls_enabled:
		velocity.x = 0.0


func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta


func _handle_jump() -> void:
	if is_crouching:
		return

	if (
		Input.is_action_just_pressed(INPUT_JUMP)
		and is_on_floor()
	):
		velocity.y = jump_velocity


func _handle_horizontal_movement(
	direction: float,
	delta: float
) -> void:
	var current_speed: float = (
		crouch_speed
		if is_crouching
		else movement_speed
	)

	if not is_zero_approx(direction):
		var target_velocity: float = (
			direction * current_speed
		)

		velocity.x = move_toward(
			velocity.x,
			target_velocity,
			ground_acceleration * delta
		)

		animated_sprite.flip_h = direction < 0.0
	else:
		velocity.x = move_toward(
			velocity.x,
			0.0,
			ground_deceleration * delta
		)


func _process_disabled_state(delta: float) -> void:
	velocity.x = move_toward(
		velocity.x,
		0.0,
		ground_deceleration * delta
	)

	# Physics still runs while controls are disabled. This prevents
	# the player from becoming suspended in midair during dialogue.
	move_and_slide()

	_update_animation(0.0)


func _process_dead_state() -> void:
	velocity = Vector2.ZERO
	_play_animation(idle_animation)


# -------------------------------------------------------------------
# Crouching
# -------------------------------------------------------------------

func _initialize_crouching() -> void:
	is_crouching = false

	_apply_crouch_collision_state(false)

	standing_clearance.enabled = true

	# A zero-length ShapeCast checks for immediate overlap.
	standing_clearance.target_position = Vector2.ZERO


func _update_crouching() -> void:
	var wants_to_crouch: bool = (
		Input.is_action_pressed(INPUT_CROUCH)
	)

	if wants_to_crouch:
		if not is_crouching:
			_set_crouching(true)

		return

	if is_crouching and _can_stand_up():
		_set_crouching(false)


func _can_stand_up() -> bool:
	# Refresh the collision result immediately so the player cannot
	# stand inside a ceiling or another solid object.
	standing_clearance.force_shapecast_update()

	return not standing_clearance.is_colliding()


func _set_crouching(crouching: bool) -> void:
	if is_crouching == crouching:
		return

	is_crouching = crouching

	_apply_crouch_collision_state(is_crouching)

	crouch_changed.emit(is_crouching)


func _apply_crouch_collision_state(
	crouching: bool
) -> void:
	# Collision shapes are changed deferred so they are not modified
	# while Godot is processing the current physics query.
	standing_collision.set_deferred(
		"disabled",
		crouching
	)

	crouching_collision.set_deferred(
		"disabled",
		not crouching
	)


# -------------------------------------------------------------------
# Animation
# -------------------------------------------------------------------

func _update_animation(direction: float) -> void:
	# Crouching takes priority over all regular movement animations.
	if is_crouching:
		_play_animation(crouch_animation)
		return

	if not is_on_floor():
		_play_animation(jump_animation)
		return

	if not is_zero_approx(direction):
		_play_animation(run_animation)
	else:
		_play_animation(idle_animation)


func _play_animation(
	animation_name: StringName
) -> void:
	if animated_sprite.sprite_frames == null:
		return

	if not animated_sprite.sprite_frames.has_animation(
		animation_name
	):
		return

	animated_sprite.play(animation_name)


func _validate_animations() -> void:
	if animated_sprite.sprite_frames == null:
		push_error(
			"Player AnimatedSprite2D has no SpriteFrames resource."
		)
		return

	var required_animations: Array[StringName] = [
		idle_animation,
		run_animation,
		jump_animation,
		crouch_animation
	]

	for animation_name: StringName in required_animations:
		if not animated_sprite.sprite_frames.has_animation(
			animation_name
		):
			push_warning(
				"Player animation '%s' could not be found."
				% animation_name
			)


# -------------------------------------------------------------------
# Health and death
# -------------------------------------------------------------------

func _connect_health_signal() -> void:
	if health == null:
		push_error(
			"Player could not find its Health node."
		)
		return

	if not health.has_signal(&"died"):
		push_error(
			"Player Health node does not have a died signal."
		)
		return

	var death_callback := Callable(
		self,
		"_on_health_died"
	)

	if not health.is_connected(
		&"died",
		death_callback
	):
		health.connect(
			&"died",
			death_callback
		)


func _on_health_died(
	death_source: Node = null
) -> void:
	if is_dead:
		return

	is_dead = true
	controls_enabled = false
	velocity = Vector2.ZERO

	var source_id: StringName = \
		_resolve_death_source_id(death_source)

	PlayerData.set_pending_death_source(
		source_id
	)

	GameOver.show_game_over()

func _resolve_death_source_id(
	death_source: Node
) -> StringName:
	if (
		death_source == null
		or not is_instance_valid(death_source)
	):
		return &"unknown"

	if death_source.has_method(
		&"get_death_source_id"
	):
		var returned_value: Variant = death_source.call(
			&"get_death_source_id"
		)

		return StringName(
			str(returned_value)
		)

	# Optional fallbacks for older hazards that have not yet
	# received get_death_source_id().
	if death_source.is_in_group(
		&"bomber_bombs"
	):
		return &"bomber_bomb"

	if death_source.is_in_group(
		&"spikes"
	):
		return &"spikes"

	return &"unknown"
