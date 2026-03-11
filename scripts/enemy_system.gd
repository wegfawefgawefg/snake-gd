extends RefCounted
class_name EnemySystem

const GameDefsRef = preload("res://scripts/game_defs.gd")
const SnakeDataRef = preload("res://scripts/snake_data.gd")

static func update(game, delta: float) -> void:
	game.enemy_spawn_timer += delta
	game.boss_spawn_timer -= delta

	if game.enemy_spawn_timer >= 1.8:
		game.enemy_spawn_timer = 0.0
		spawn_enemy(game)

	if game.boss_spawn_timer <= 0.0 and not game.boss_exists():
		game.boss_spawn_timer = 26.0
		spawn_boss(game)

	for enemy in game.enemy_snakes:
		enemy.damage_flash = max(enemy.damage_flash - delta * 4.0, 0.0)
		enemy.shot_cooldown -= delta


static func step(game) -> void:
	for i in range(game.enemy_snakes.size() - 1, -1, -1):
		var enemy = game.enemy_snakes[i]
		var dir: Vector2i = choose_direction(game, enemy, i)
		enemy.dir = dir
		enemy.queued_dir = dir
		var new_head: Vector2i = enemy.body[0] + dir

		if new_head == game.player_body[0]:
			game.kill_player()
			return

		if new_head in game.player_body:
			game.cut_player_at(new_head)
			game.kill_enemy_snake(i, enemy.body, false)
			continue

		var prop = game.prop_at_cell(new_head)
		if prop != null and prop.kind != "swamp_pool":
			enemy.dir = _pick_detour(game, enemy, i)
			new_head = enemy.body[0] + enemy.dir

		var first_hit: Dictionary = game.enemy_cell_hit(new_head, i)
		if first_hit["snake_index"] != -1 or new_head in enemy.body:
			enemy.dir = _pick_detour(game, enemy, i)
			new_head = enemy.body[0] + enemy.dir

		var second_hit: Dictionary = game.enemy_cell_hit(new_head, i)
		if second_hit["snake_index"] != -1 or new_head in enemy.body:
			game.kill_enemy_snake(i, enemy.body, false)
			continue

		enemy.body.push_front(new_head)
		var ate_food: int = game.consume_food_at(new_head)
		if ate_food == 0:
			enemy.body.pop_back()

		if enemy.can_shoot and enemy.shot_cooldown <= 0.0:
			var aim: Vector2 = (GameDefsRef.cell_center(game.player_body[0]) - GameDefsRef.cell_center(enemy.body[0])).normalized()
			if aim.length() > 0.0:
				game.spawn_bullet(
					GameDefsRef.cell_center(enemy.body[0]),
					aim,
					72.0 if enemy.is_boss else 58.0,
					false,
					1.8,
					enemy.color.lightened(0.15),
					2.6 if enemy.is_boss else 2.1,
					1
				)
			enemy.shot_cooldown = 0.55 if enemy.is_boss else 1.3

		if enemy.poison_body:
			game.spawn_poison(enemy.body[enemy.body.size() - 1], 2.4)

		game.enemy_snakes[i] = enemy


static func choose_direction(game, enemy, enemy_index: int) -> Vector2i:
	var target: Vector2i = game.player_body[0]
	var nearest_food = game.find_nearest_food(enemy.body[0], 18)
	if nearest_food != null and not enemy.is_boss:
		target = nearest_food.cell
	elif enemy.is_boss:
		target = game.player_body[max(0, min(game.player_body.size() - 1, game.player_body.size() / 3))]

	var options: Array[Vector2i] = [enemy.dir, Vector2i(-enemy.dir.y, enemy.dir.x), Vector2i(enemy.dir.y, -enemy.dir.x)]
	var best: Vector2i = enemy.dir
	var best_score: float = INF
	for option in options:
		if GameDefsRef.is_reverse_dir(enemy.dir, option):
			continue
		var cell: Vector2i = enemy.body[0] + option
		var hit: Dictionary = game.enemy_cell_hit(cell, enemy_index)
		if hit["snake_index"] != -1 or cell in enemy.body:
			continue
		var prop = game.prop_at_cell(cell)
		if prop != null and prop.kind != "swamp_pool":
			continue
		var score: float = abs(cell.x - target.x) + abs(cell.y - target.y)
		if prop != null and prop.kind == "swamp_pool":
			score += 8
		if score < best_score:
			best_score = score
			best = option
	return best


static func spawn_enemy(game) -> void:
	if game.enemy_snakes.size() >= 18:
		return
	var head := _spawn_ring_cell(game)
	var dir := _dir_toward_player(game, head)
	var snake = SnakeDataRef.SnakeActor.new()
	var length: int = game.rng.randi_range(4, 7)
	for i in range(length):
		snake.body.append(head - dir * i)
	snake.dir = dir
	snake.queued_dir = dir
	snake.color = GameDefsRef.ENEMY_COLORS[game.rng.randi_range(0, GameDefsRef.ENEMY_COLORS.size() - 1)]
	snake.split_on_cut = game.rng.randf() < 0.35
	snake.biome = game.biome_for_cell(head)
	snake.can_shoot = snake.biome == "city"
	snake.poison_body = snake.biome == "swamp" and game.rng.randf() < 0.2
	snake.score_value = 20 + length * 3
	game.enemy_snakes.append(snake)


static func spawn_boss(game) -> void:
	var head := _spawn_ring_cell(game, 18)
	var dir := _dir_toward_player(game, head)
	var biome: String = game.biome_for_cell(head)
	var snake = SnakeDataRef.SnakeActor.new()
	var length: int = game.rng.randi_range(12, 17)
	for i in range(length):
		snake.body.append(head - dir * i)
	snake.dir = dir
	snake.queued_dir = dir
	snake.color = GameDefsRef.BOSS_COLOR
	snake.is_boss = true
	snake.split_on_cut = true
	snake.can_shoot = biome == "city" or biome == "desert"
	snake.poison_body = biome == "swamp"
	snake.biome = biome
	snake.score_value = 180
	snake.head_hp = 4
	match biome:
		"orchard":
			snake.name = "Orchard King"
		"city":
			snake.name = "Warden Coil"
		"swamp":
			snake.name = "Ashmouth"
		_:
			snake.name = "Spiral Maw"
	game.enemy_snakes.append(snake)


static func _spawn_ring_cell(game, extra_padding: int = 0) -> Vector2i:
	var center: Vector2i = game.player_body[0]
	var half_x: int = GameDefsRef.VISIBLE_CELLS_X / 2 + GameDefsRef.SPAWN_RING_PADDING + extra_padding
	var half_y: int = GameDefsRef.VISIBLE_CELLS_Y / 2 + GameDefsRef.SPAWN_RING_PADDING + extra_padding
	var side: int = game.rng.randi_range(0, 3)
	match side:
		0:
			return center + Vector2i(-half_x, game.rng.randi_range(-half_y, half_y))
		1:
			return center + Vector2i(half_x, game.rng.randi_range(-half_y, half_y))
		2:
			return center + Vector2i(game.rng.randi_range(-half_x, half_x), -half_y)
		_:
			return center + Vector2i(game.rng.randi_range(-half_x, half_x), half_y)


static func _dir_toward_player(game, head: Vector2i) -> Vector2i:
	var delta: Vector2i = game.player_body[0] - head
	if abs(delta.x) > abs(delta.y):
		return Vector2i(signi(delta.x), 0)
	return Vector2i(0, signi(delta.y))


static func _pick_detour(game, enemy, enemy_index: int) -> Vector2i:
	var options: Array[Vector2i] = [
		Vector2i(-enemy.dir.y, enemy.dir.x),
		Vector2i(enemy.dir.y, -enemy.dir.x),
		-enemy.dir,
	]
	for option in options:
		var cell: Vector2i = enemy.body[0] + option
		var hit: Dictionary = game.enemy_cell_hit(cell, enemy_index)
		if hit["snake_index"] != -1 or cell in enemy.body or cell in game.player_body:
			continue
		var prop = game.prop_at_cell(cell)
		if prop != null and prop.kind != "swamp_pool":
			continue
		return option
	return enemy.dir
