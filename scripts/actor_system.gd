extends RefCounted
class_name ActorSystem

const GameDefsRef = preload("res://scripts/game_defs.gd")
const SnakeDataRef = preload("res://scripts/snake_data.gd")
const WorldGenRef = preload("res://scripts/world_gen.gd")
const ProgressionSystemRef = preload("res://scripts/progression_system.gd")

static func spawn_bullet(game, pos: Vector2, dir: Vector2, speed: float, friendly: bool, ttl: float, color: Color, radius: float, damage: int) -> void:
	var bullet = SnakeDataRef.BulletData.new()
	bullet.pos = pos
	bullet.vel = dir.normalized() * speed
	bullet.ttl = ttl
	bullet.friendly = friendly
	bullet.color = color
	bullet.radius = radius
	bullet.damage = damage
	bullet.pierce = game.upgrade_levels.get(GameDefsRef.WeaponUpgrade.DRILL_HEAD, 0) if friendly else 0
	bullet.chain = game.upgrade_levels.get(GameDefsRef.WeaponUpgrade.CHAIN_HEAD, 0) if friendly else 0
	game.bullets.append(bullet)


static func spawn_poison(game, cell: Vector2i, ttl: float = 3.0) -> void:
	if poison_at(game, cell):
		return
	var poison = SnakeDataRef.PoisonPatch.new()
	poison.cell = cell
	poison.ttl = ttl
	game.poisons.append(poison)


static func poison_at(game, cell: Vector2i) -> bool:
	for poison in game.poisons:
		if poison.cell == cell:
			return true
	return false


static func consume_food_at(game, cell: Vector2i) -> int:
	for i in range(game.foods.size() - 1, -1, -1):
		if game.foods[i].cell == cell:
			var value: int = game.foods[i].value
			game.foods.remove_at(i)
			return value
	return 0


static func spawn_food(game, cell: Vector2i, value: int) -> void:
	if cell_occupied(game, cell):
		return
	var food = SnakeDataRef.FoodPickup.new()
	food.cell = cell
	food.value = value
	food.phase = game.rng.randf() * TAU
	food.chunk_coord = GameDefsRef.chunk_for_cell(cell)
	game.foods.append(food)


static func cell_occupied(game, cell: Vector2i) -> bool:
	if cell in game.player_body:
		return true
	var hit: Dictionary = enemy_cell_hit(game, cell)
	if hit["snake_index"] != -1:
		return true
	if prop_at_cell(game, cell) != null:
		return true
	for food in game.foods:
		if food.cell == cell:
			return true
	return false


static func prop_at_cell(game, cell: Vector2i):
	for prop in game.props:
		if prop.cell == cell:
			return prop
	return null


static func enemy_cell_hit(game, cell: Vector2i, ignored_index: int = -1) -> Dictionary:
	for snake_index in range(game.enemy_snakes.size()):
		if snake_index == ignored_index:
			continue
		var segment_index: int = game.enemy_snakes[snake_index].body.find(cell)
		if segment_index != -1:
			return {"snake_index": snake_index, "segment_index": segment_index}
	return {"snake_index": -1, "segment_index": -1}


static func enemy_hit_by_point(game, point: Vector2) -> Dictionary:
	return enemy_cell_hit(game, GameDefsRef.point_to_cell(point))


static func nearest_enemy_segment_except(game, origin: Vector2, ignored_snake: int) -> Dictionary:
	var best := {"snake_index": -1, "segment_index": -1, "distance": INF}
	for snake_index in range(game.enemy_snakes.size()):
		if snake_index == ignored_snake:
			continue
		var snake = game.enemy_snakes[snake_index]
		for segment_index in range(snake.body.size()):
			var center := GameDefsRef.cell_center(snake.body[segment_index])
			var distance := origin.distance_to(center)
			if distance < best["distance"]:
				best = {
					"snake_index": snake_index,
					"segment_index": segment_index,
					"distance": distance,
					"cell": snake.body[segment_index],
				}
	return best


static func find_nearest_food(game, origin: Vector2i, max_distance: int):
	var best = null
	var best_score: float = INF
	for food in game.foods:
		var dist: int = abs(food.cell.x - origin.x) + abs(food.cell.y - origin.y)
		if dist < best_score and dist <= max_distance:
			best_score = dist
			best = food
	return best


static func damage_enemy_segment(game, snake_index: int, segment_index: int, damage: int) -> void:
	if snake_index < 0 or snake_index >= game.enemy_snakes.size():
		return
	var snake = game.enemy_snakes[snake_index]
	snake.damage_flash = 0.8
	if segment_index == 0:
		snake.head_hp -= damage
		if snake.head_hp > 0:
			game.enemy_snakes[snake_index] = snake
			return
		kill_enemy_snake(game, snake_index, snake.body, snake.is_boss)
		return

	var tail: Array = snake.body.slice(segment_index + 1)
	snake.body = snake.body.slice(0, segment_index)
	if snake.body.size() <= 1:
		kill_enemy_snake(game, snake_index, snake.body + tail, snake.is_boss)
		return
	game.enemy_snakes[snake_index] = snake
	game.score += int(snake.score_value / 3)
	ProgressionSystemRef.gain_xp(game, 1)
	spawn_food(game, snake.body[snake.body.size() - 1], 1)
	if game.upgrade_levels[GameDefsRef.WeaponUpgrade.HARVESTER] > 0:
		spawn_food(game, snake.body[snake.body.size() - 1], 3 if game.rng.randf() < 0.5 else 1)
	if snake.split_on_cut and tail.size() >= 3:
		var split = SnakeDataRef.SnakeActor.new()
		split.body = tail
		split.dir = snake.dir
		split.queued_dir = snake.dir
		split.color = snake.color.lightened(0.1)
		split.split_on_cut = false
		split.can_shoot = snake.can_shoot
		split.biome = snake.biome
		split.poison_body = snake.poison_body
		split.score_value = max(10, snake.score_value / 2)
		split.head_hp = max(1, snake.head_hp)
		game.enemy_snakes.append(split)
	else:
		for segment in tail:
			spawn_food(game, segment, 1 if game.rng.randf() < 0.7 else 3)


static func kill_enemy_snake(game, index: int, cells: Array, was_boss: bool) -> void:
	if index >= 0 and index < game.enemy_snakes.size():
		game.enemy_snakes.remove_at(index)
	var best_food_value := 3 if game.upgrade_levels[GameDefsRef.WeaponUpgrade.BOSS_BOUNTY] > 0 and was_boss else 1
	if game.upgrade_levels[GameDefsRef.WeaponUpgrade.HARVESTER] > 0:
		best_food_value = max(best_food_value, 3)
	for segment in cells:
		var drop_value := 1 if game.rng.randf() < 0.7 else (5 if was_boss and game.rng.randf() < 0.25 else 3)
		spawn_food(game, segment, max(drop_value, best_food_value))
	game.score += 260 if was_boss and game.upgrade_levels[GameDefsRef.WeaponUpgrade.BOSS_BOUNTY] > 0 else (160 if was_boss else 40)
	ProgressionSystemRef.gain_xp(game, (7 if game.upgrade_levels[GameDefsRef.WeaponUpgrade.BOSS_BOUNTY] > 0 else 5) if was_boss else 2)


static func damage_prop(game, prop, damage: int) -> void:
	prop.damage_flash = 0.9
	prop.hp -= damage
	if prop.hp > 0:
		return
	var cell: Vector2i = prop.cell
	match prop.kind:
		"tree":
			game.wood += 1 + game.upgrade_levels[GameDefsRef.WeaponUpgrade.HARVESTER]
			for _i in range(3):
				spawn_food(game, cell + Vector2i(game.rng.randi_range(-1, 1), game.rng.randi_range(-1, 1)), 1 if game.rng.randf() < 0.7 else 3)
		"building":
			game.scrap += 2 + game.upgrade_levels[GameDefsRef.WeaponUpgrade.HARVESTER]
			for _i in range(4):
				spawn_food(game, cell + Vector2i(game.rng.randi_range(-1, 1), game.rng.randi_range(-1, 1)), 3 if game.rng.randf() < 0.8 else 5)
		"swamp_pool":
			game.rot += 1 + game.upgrade_levels[GameDefsRef.WeaponUpgrade.HARVESTER]
		"ender_spire":
			game.crystal += 2 + game.upgrade_levels[GameDefsRef.WeaponUpgrade.HARVESTER]
			for _i in range(3):
				spawn_food(game, cell + Vector2i(game.rng.randi_range(-1, 1), game.rng.randi_range(-1, 1)), 5)
		"tent":
			game.scrap += 1 + game.upgrade_levels[GameDefsRef.WeaponUpgrade.HARVESTER]
			for _i in range(3):
				spawn_food(game, cell + Vector2i(game.rng.randi_range(-1, 1), game.rng.randi_range(-1, 1)), 3)
		_:
			game.crystal += 1
			spawn_food(game, cell, 1)
	game.props.erase(prop)
	game.score += 12


static func cut_player_at(game, cell: Vector2i) -> void:
	var segment_index: int = game.player_body.find(cell)
	if segment_index == -1:
		return
	if segment_index > 0 and game.player_armor_charges > 0:
		game.player_armor_charges -= 1
		return
	if segment_index == 0:
		kill_player(game)
		return
	var tail: Array = game.player_body.slice(segment_index + 1)
	game.player_body = game.player_body.slice(0, segment_index)
	if game.player_body.size() <= 1:
		kill_player(game)
		return
	for segment in tail:
		spawn_food(game, segment, 1)


static func kill_player(game) -> void:
	game.game_state = GameDefsRef.GameState.GAME_OVER


static func boss_exists(game) -> bool:
	for snake in game.enemy_snakes:
		if snake.is_boss:
			return true
	return false


static func current_boss_name(game) -> String:
	for snake in game.enemy_snakes:
		if snake.is_boss:
			return "%s  HP:%d" % [snake.name, snake.head_hp]
	return ""


static func biome_for_cell(_game, cell: Vector2i) -> String:
	return WorldGenRef.biome_for_chunk(GameDefsRef.chunk_for_cell(cell))
