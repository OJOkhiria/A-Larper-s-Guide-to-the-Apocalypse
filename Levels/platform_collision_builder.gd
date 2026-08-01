extends TileMapLayer

# Rebuilds walkable surfaces from the painted tile cells. The tile texture was
# re-imported without physics data, so TileMapLayer no longer makes them itself.
const COLLISION_DEPTH := 16.0


func _ready() -> void:
	call_deferred("_build_platform_collisions")


func _build_platform_collisions() -> void:
	var used_cells := get_used_cells()
	if used_cells.is_empty():
		return

	var occupied := {}
	for cell in used_cells:
		occupied[cell] = true

	# Only cells without another cell directly above them form a walkable top.
	# This keeps the painted stairs and separated platforms intact.
	var rows := {}
	for cell in used_cells:
		if not occupied.has(cell + Vector2i.UP):
			if not rows.has(cell.y):
				rows[cell.y] = []
			rows[cell.y].append(cell.x)

	var collision_body := StaticBody2D.new()
	collision_body.name = "GeneratedPlatformCollisions"
	add_child(collision_body)

	for y in rows:
		var xs: Array = rows[y]
		xs.sort()
		var run_start: int = xs[0]
		var previous: int = run_start
		for index in range(1, xs.size() + 1):
			var at_end := index == xs.size()
			var x: int = previous + 2 if at_end else xs[index]
			if at_end or x != previous + 1:
				_add_platform(collision_body, run_start, previous, y)
				run_start = x
			previous = x


func _add_platform(body: StaticBody2D, start_x: int, end_x: int, y: int) -> void:
	var width := float(end_x - start_x + 1) * tile_set.tile_size.x
	var shape := RectangleShape2D.new()
	shape.size = Vector2(width, COLLISION_DEPTH)
	var collision := CollisionShape2D.new()
	collision.shape = shape
	collision.position = Vector2(
		start_x * tile_set.tile_size.x + width * 0.5,
		y * tile_set.tile_size.y + COLLISION_DEPTH * 0.5
	)
	body.add_child(collision)
