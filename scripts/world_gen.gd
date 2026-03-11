extends RefCounted
class_name WorldGen

const GameDefsRef = preload("res://scripts/game_defs.gd")
const SnakeDataRef = preload("res://scripts/snake_data.gd")

static func ensure_chunks(game) -> void:
	var player_chunk := GameDefsRef.chunk_for_cell(game.player_body[0])
	for cy in range(player_chunk.y - GameDefsRef.CHUNK_LOAD_RADIUS, player_chunk.y + GameDefsRef.CHUNK_LOAD_RADIUS + 1):
		for cx in range(player_chunk.x - GameDefsRef.CHUNK_LOAD_RADIUS, player_chunk.x + GameDefsRef.CHUNK_LOAD_RADIUS + 1):
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
	var roll: int = abs(_hash2(chunk_coord.x, chunk_coord.y)) % 5
	match roll:
		0:
			return "orchard"
		1:
			return "forest"
		2:
			return "city"
		3:
			return "swamp"
		_:
			return "desert"


static func spawn_ambient_food(game) -> void:
	var player_chunk := GameDefsRef.chunk_for_cell(game.player_body[0])
	var counts := {1: 0, 3: 0, 5: 0}
	for food in game.foods:
		if food.chunk_coord.distance_to(player_chunk) > GameDefsRef.CHUNK_LOAD_RADIUS:
			continue
		counts[food.value] += 1

	for value in GameDefsRef.FOOD_TARGETS.keys():
		var attempts := 0
		while counts[value] < GameDefsRef.FOOD_TARGETS[value] and attempts < 32:
			attempts += 1
			var food = SnakeDataRef.FoodPickup.new()
			food.cell = random_cell_near_player(game, GameDefsRef.VISIBLE_CELLS_X)
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

	var prop_count := 4
	var food_count := 8
	match chunk.biome:
		"orchard":
			prop_count = 7
			food_count = 12
		"forest":
			prop_count = 10
			food_count = 6
		"city":
			prop_count = 8
			food_count = 5
		"swamp":
			prop_count = 8
			food_count = 6
		"desert":
			prop_count = 5
			food_count = 7

	for _i in range(prop_count):
		var cell := origin + Vector2i(
			chunk_rng.randi_range(0, GameDefsRef.CHUNK_SIZE - 1),
			chunk_rng.randi_range(0, GameDefsRef.CHUNK_SIZE - 1)
		)
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
				prop.hp = 4
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
		if game.cell_occupied(cell):
			continue
		var food: SnakeDataRef.FoodPickup = SnakeDataRef.FoodPickup.new()
		food.cell = cell
		food.phase = chunk_rng.randf() * TAU
		food.chunk_coord = chunk.coord
		food.value = 1
		if chunk.biome == "orchard" and chunk_rng.randf() < 0.35:
			food.value = 3
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
