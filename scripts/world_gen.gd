extends RefCounted
class_name WorldGen

const GameDefsRef = preload("res://scripts/game_defs.gd")
const SnakeDataRef = preload("res://scripts/snake_data.gd")

static func ensure_chunks(game) -> void:
	var visible_rect: Rect2 = game.visible_world_rect().grow(GameDefsRef.CHUNK_SIZE * GameDefsRef.CELL_SIZE * 1.5)
	var min_cell: Vector2i = GameDefsRef.point_to_cell(visible_rect.position)
	var max_cell: Vector2i = GameDefsRef.point_to_cell(visible_rect.end)
	var min_chunk: Vector2i = GameDefsRef.chunk_for_cell(min_cell)
	var max_chunk: Vector2i = GameDefsRef.chunk_for_cell(max_cell)
	var player_chunk := GameDefsRef.chunk_for_cell(game.player_body[0])
	for cy in range(min_chunk.y, max_chunk.y + 1):
		for cx in range(min_chunk.x, max_chunk.x + 1):
			var coord := Vector2i(cx, cy)
			var key := GameDefsRef.chunk_key(coord)
			if game.chunks.has(key):
				continue
			var chunk = SnakeDataRef.WorldChunk.new()
			chunk.coord = coord
			chunk.biome = biome_for_chunk(coord)
			game.chunks[key] = chunk
			_spawn_chunk_content(game, chunk)

	_cleanup_far_food(game, player_chunk)
	_cleanup_far_props(game, player_chunk)
	_cleanup_far_chunks(game, player_chunk)


static func biome_for_chunk(chunk_coord: Vector2i) -> String:
	var biome_value: float = game_biome_value(chunk_coord)
	var moisture: float = game_moisture_value(chunk_coord)
	if biome_value < -0.35:
		return "swamp" if moisture > 0.1 else "forest"
	if biome_value > 0.62 and abs(moisture) < 0.18:
		return "end"
	if biome_value > 0.45 and moisture > 0.3:
		return "carnival"
	if biome_value < 0.05:
		return "orchard"
	if biome_value < 0.38:
		return "city" if moisture < -0.1 else "forest"
	return "desert"


static func game_biome_value(chunk_coord: Vector2i) -> float:
	var noise := FastNoiseLite.new()
	noise.seed = 9137
	noise.frequency = 0.085
	noise.fractal_octaves = 3
	noise.fractal_gain = 0.55
	return noise.get_noise_2d(float(chunk_coord.x), float(chunk_coord.y))


static func game_moisture_value(chunk_coord: Vector2i) -> float:
	var noise := FastNoiseLite.new()
	noise.seed = 23117
	noise.frequency = 0.12
	noise.fractal_octaves = 2
	noise.fractal_gain = 0.6
	return noise.get_noise_2d(float(chunk_coord.x), float(chunk_coord.y))


static func spawn_ambient_food(game) -> void:
	var player_chunk := GameDefsRef.chunk_for_cell(game.player_body[0])
	var visible_half: Vector2i = game.visible_half_cells()
	var visible_chunk_radius: int = int(ceili(float(max(visible_half.x, visible_half.y)) / float(GameDefsRef.CHUNK_SIZE))) + 1
	var counts := {1: 0, 3: 0, 5: 0}
	for food in game.foods:
		if food.chunk_coord.distance_to(player_chunk) > visible_chunk_radius:
			continue
		counts[food.value] += 1

	for value in GameDefsRef.FOOD_TARGETS.keys():
		var attempts := 0
		var spawn_radius: int = max(visible_half.x, visible_half.y)
		while counts[value] < GameDefsRef.FOOD_TARGETS[value] and attempts < 32:
			attempts += 1
			var food = SnakeDataRef.FoodPickup.new()
			food.cell = random_cell_near_player(game, spawn_radius)
			if game.cell_occupied(food.cell):
				continue
			food.value = value
			food.phase = game.rng.randf() * TAU
			food.chunk_coord = GameDefsRef.chunk_for_cell(food.cell)
			game.foods.append(food)
			counts[value] += 1


static func random_cell_near_player(game, radius_cells: int) -> Vector2i:
	var center: Vector2i = game.player_body[0]
	return center + Vector2i(
		game.rng.randi_range(-radius_cells, radius_cells),
		game.rng.randi_range(-radius_cells, radius_cells)
	)


static func _spawn_chunk_content(game, chunk) -> void:
	var chunk_rng := RandomNumberGenerator.new()
	chunk_rng.seed = int(abs(_hash2(chunk.coord.x * 43, chunk.coord.y * 29)))
	var origin: Vector2i = GameDefsRef.chunk_origin(chunk.coord)
	var biome_strength: float = abs(game_biome_value(chunk.coord))
	var moisture: float = game_moisture_value(chunk.coord)

	var prop_count := 4
	var food_count := 8
	match chunk.biome:
		"orchard":
			prop_count = 5 + int(round(4.0 + moisture * 3.0))
			food_count = 11 + int(round(5.0 * (1.0 - biome_strength)))
		"forest":
			prop_count = 9 + int(round(3.0 * moisture))
			food_count = 6 + int(round(2.0 * max(0.0, moisture)))
		"city":
			prop_count = 12 + int(round(5.0 * biome_strength))
			food_count = 4 + int(round(2.0 * max(0.0, moisture + 0.3)))
		"carnival":
			prop_count = 9 + int(round(4.0 * moisture))
			food_count = 8 + int(round(3.0 * max(0.0, moisture)))
		"end":
			prop_count = 8 + int(round(4.0 * biome_strength))
			food_count = 5 + int(round(2.0 * biome_strength))
		"swamp":
			prop_count = 7 + int(round(3.0 * moisture))
			food_count = 5 + int(round(3.0 * max(0.0, moisture)))
		"desert":
			prop_count = 4 + int(round(2.0 * biome_strength))
			food_count = 5 + int(round(2.0 * max(0.0, -moisture)))

	for _i in range(prop_count):
		var cell := origin + Vector2i(
			chunk_rng.randi_range(0, GameDefsRef.CHUNK_SIZE - 1),
			chunk_rng.randi_range(0, GameDefsRef.CHUNK_SIZE - 1)
		)
		if chunk.biome == "city":
			var local: Vector2i = cell - origin
			if local.x % 5 == 2 or local.y % 5 == 2:
				continue
		if game.cell_occupied(cell):
			continue
		var prop: SnakeDataRef.WorldProp = SnakeDataRef.WorldProp.new()
		prop.cell = cell
		prop.biome = chunk.biome
		prop.chunk_coord = chunk.coord
		match chunk.biome:
			"orchard":
				prop.kind = "tree"
				prop.hp = 2
			"forest":
				prop.kind = "tree"
				prop.hp = 3
			"city":
				prop.kind = "building"
				prop.hp = 4 + int(chunk_rng.randf() < 0.35)
			"carnival":
				prop.kind = "tent"
				prop.hp = 3
			"end":
				prop.kind = "ender_spire"
				prop.hp = 5
			"swamp":
				prop.kind = "swamp_pool"
				prop.hp = 1
			_:
				prop.kind = "rock"
				prop.hp = 3
		game.props.append(prop)

	for _i in range(food_count):
		var cell := origin + Vector2i(
			chunk_rng.randi_range(0, GameDefsRef.CHUNK_SIZE - 1),
			chunk_rng.randi_range(0, GameDefsRef.CHUNK_SIZE - 1)
		)
		if chunk.biome == "city":
			var local: Vector2i = cell - origin
			if local.x % 5 != 2 and local.y % 5 != 2 and chunk_rng.randf() < 0.7:
				continue
		if game.cell_occupied(cell):
			continue
		var food: SnakeDataRef.FoodPickup = SnakeDataRef.FoodPickup.new()
		food.cell = cell
		food.phase = chunk_rng.randf() * TAU
		food.chunk_coord = chunk.coord
		food.value = 1
		if chunk.biome == "orchard" and chunk_rng.randf() < 0.35:
			food.value = 3
		elif chunk.biome == "carnival" and chunk_rng.randf() < 0.25:
			food.value = 5
		elif chunk.biome == "end" and chunk_rng.randf() < 0.3:
			food.value = 5
		elif chunk.biome == "city" and chunk_rng.randf() < 0.18:
			food.value = 5
		elif chunk_rng.randf() < 0.08:
			food.value = 3
		game.foods.append(food)


static func _cleanup_far_food(game, player_chunk: Vector2i) -> void:
	for i in range(game.foods.size() - 1, -1, -1):
		var food = game.foods[i]
		if food.chunk_coord.distance_to(player_chunk) > GameDefsRef.FOOD_DESPAWN_CHUNK_RADIUS:
			game.foods.remove_at(i)


static func _cleanup_far_props(game, player_chunk: Vector2i) -> void:
	for i in range(game.props.size() - 1, -1, -1):
		var prop = game.props[i]
		if prop.chunk_coord.distance_to(player_chunk) > GameDefsRef.FOOD_DESPAWN_CHUNK_RADIUS:
			game.props.remove_at(i)


static func _cleanup_far_chunks(game, player_chunk: Vector2i) -> void:
	for key in game.chunks.keys():
		var chunk = game.chunks[key]
		if chunk.coord.distance_to(player_chunk) > GameDefsRef.FOOD_DESPAWN_CHUNK_RADIUS:
			game.chunks.erase(key)


static func _hash2(x: int, y: int) -> int:
	return (x * 73856093) ^ (y * 19349663)
