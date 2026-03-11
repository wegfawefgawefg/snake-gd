extends RefCounted
class_name EnemySystem

const GameDefsRef = preload("res://scripts/game_defs.gd")
const SnakeDataRef = preload("res://scripts/snake_data.gd")
const ActorSystemRef = preload("res://scripts/actor_system.gd")
const CameraSystemRef = preload("res://scripts/camera_system.gd")

static func update(game, delta: float) -> void:
	game.enemy_spawn_timer += delta
	game.boss_spawn_timer -= delta
	var enemy_interval: float = max(0.7, 1.8 - float(game.level) * 0.04)

	if game.enemy_spawn_timer >= enemy_interval:
		game.enemy_spawn_timer = 0.0
		spawn_enemy(game)

	if game.boss_spawn_timer <= 0.0 and not ActorSystemRef.boss_exists(game) and game.level >= 2:
		game.boss_spawn_timer = max(10.0, 20.0 - float(game.level) * 0.45)
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
			ActorSystemRef.kill_player(game)
			return

		if new_head in game.player_body:
			ActorSystemRef.cut_player_at(game, new_head)
			ActorSystemRef.kill_enemy_snake(game, i, enemy.body, false)
			continue

		var prop = ActorSystemRef.prop_at_cell(game, new_head)
		if prop != null and prop.kind != "swamp_pool":
			enemy.dir = _pick_detour(game, enemy, i)
			new_head = enemy.body[0] + enemy.dir

		var first_hit: Dictionary = ActorSystemRef.enemy_cell_hit(game, new_head, i)
		if first_hit["snake_index"] != -1 or new_head in enemy.body:
			enemy.dir = _pick_detour(game, enemy, i)
			new_head = enemy.body[0] + enemy.dir

		var second_hit: Dictionary = ActorSystemRef.enemy_cell_hit(game, new_head, i)
		if second_hit["snake_index"] != -1 or new_head in enemy.body:
			ActorSystemRef.kill_enemy_snake(game, i, enemy.body, false)
			continue

		enemy.body.push_front(new_head)
		var ate_food: int = ActorSystemRef.consume_food_at(game, new_head)
		if ate_food == 0:
			enemy.body.pop_back()

		if enemy.can_shoot and enemy.shot_cooldown <= 0.0:
			_fire_enemy_attack(game, enemy)
			enemy.shot_cooldown = _enemy_shot_cooldown(enemy)

		if enemy.poison_body:
			ActorSystemRef.spawn_poison(game, enemy.body[enemy.body.size() - 1], 2.4)

		game.enemy_snakes[i] = enemy


static func choose_direction(game, enemy, enemy_index: int) -> Vector2i:
	var target: Vector2i = game.player_body[0]
	var nearest_food = ActorSystemRef.find_nearest_food(game, enemy.body[0], 18)
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
		var hit: Dictionary = ActorSystemRef.enemy_cell_hit(game, cell, enemy_index)
		if hit["snake_index"] != -1 or cell in enemy.body:
			continue
		var prop = ActorSystemRef.prop_at_cell(game, cell)
		if prop != null and prop.kind != "swamp_pool":
			continue
		var score: float = abs(cell.x - target.x) + abs(cell.y - target.y)
		if enemy.archetype == "soldier":
			score = abs(score - 8.0)
		elif enemy.archetype == "clown":
			score += game.rng.randf() * 4.0
		elif enemy.archetype == "ender":
			score *= 0.75
		elif enemy.archetype == "leech":
			score *= 0.9
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
	snake.biome = ActorSystemRef.biome_for_cell(game, head)
	snake.can_shoot = snake.biome == "city" or snake.biome == "carnival" or snake.biome == "end"
	snake.poison_body = snake.biome == "swamp" and game.rng.randf() < 0.2
	snake.head_hp = 1 + int(game.level / 8)
	snake.score_value = 20 + length * 3 + game.level * 2
	snake.archetype = "hunter"
	if snake.biome == "city":
		snake.archetype = "soldier"
	elif snake.biome == "swamp":
		snake.archetype = "leech"
	elif snake.biome == "carnival":
		snake.archetype = "clown"
	elif snake.biome == "end":
		snake.archetype = "ender"
	if snake.biome == "carnival":
		snake.color = Color(1.0, 0.25 + game.rng.randf() * 0.5, 0.7 + game.rng.randf() * 0.25)
		snake.split_on_cut = true
	elif snake.biome == "end":
		snake.color = Color(0.7, 0.55, 1.0)
		snake.head_hp += 1
	game.enemy_snakes.append(snake)


static func spawn_boss(game) -> void:
	var head := _spawn_ring_cell(game, 18)
	var dir := _dir_toward_player(game, head)
	var biome: String = ActorSystemRef.biome_for_cell(game, head)
	var snake = SnakeDataRef.SnakeActor.new()
	var length: int = game.rng.randi_range(12, 17)
	for i in range(length):
		snake.body.append(head - dir * i)
	snake.dir = dir
	snake.queued_dir = dir
	snake.color = GameDefsRef.BOSS_COLOR
	snake.is_boss = true
	snake.split_on_cut = true
	snake.can_shoot = biome == "city" or biome == "desert" or biome == "carnival" or biome == "end"
	snake.poison_body = biome == "swamp"
	snake.biome = biome
	snake.archetype = "boss"
	snake.score_value = 220 + game.level * 10
	snake.head_hp = 4 + int(game.level / 5)
	match biome:
		"orchard":
			snake.name = "Orchard King"
		"city":
			snake.name = "Warden Coil"
		"carnival":
			snake.name = "Clown Prince"
			snake.color = Color(1.0, 0.4, 0.72)
		"end":
			snake.name = "Ender Dragon"
			snake.color = Color(0.78, 0.58, 1.0)
			snake.head_hp += 4
		"swamp":
			snake.name = "Ashmouth"
		_:
			snake.name = "Spiral Maw"
	game.enemy_snakes.append(snake)


static func _fire_enemy_attack(game, enemy) -> void:
	var origin: Vector2 = GameDefsRef.cell_center(enemy.body[0])
	var aim: Vector2 = (GameDefsRef.cell_center(game.player_body[0]) - origin).normalized()
	if aim.length() <= 0.0:
		return
	if not enemy.is_boss:
		ActorSystemRef.spawn_bullet(game, origin, aim, 58.0, false, 1.8, enemy.color.lightened(0.15), 2.1, 1)
		return

	var phase := 1
	if enemy.head_hp <= 2:
		phase = 3
	elif enemy.head_hp <= 4:
		phase = 2

	match enemy.biome:
		"city":
			var side := Vector2(-aim.y, aim.x)
			ActorSystemRef.spawn_bullet(game, origin, aim, 82.0 + phase * 6.0, false, 2.0, enemy.color.lightened(0.2), 2.6, 1)
			ActorSystemRef.spawn_bullet(game, origin, (aim + side * 0.35).normalized(), 76.0 + phase * 4.0, false, 2.0, enemy.color.lightened(0.1), 2.3, 1)
			ActorSystemRef.spawn_bullet(game, origin, (aim - side * 0.35).normalized(), 76.0 + phase * 4.0, false, 2.0, enemy.color.lightened(0.1), 2.3, 1)
			if phase >= 3:
				ActorSystemRef.spawn_bullet(game, origin, (aim + side * 0.7).normalized(), 72.0, false, 2.0, enemy.color.lightened(0.25), 2.2, 1)
				ActorSystemRef.spawn_bullet(game, origin, (aim - side * 0.7).normalized(), 72.0, false, 2.0, enemy.color.lightened(0.25), 2.2, 1)
		"swamp":
			ActorSystemRef.spawn_bullet(game, origin, aim, 68.0, false, 2.2, enemy.color.lightened(0.1), 2.6, 1)
			ActorSystemRef.spawn_poison(game, enemy.body[enemy.body.size() - 1], 5.0)
		"carnival":
			var ring_count := 6 + (phase - 1) * 2
			for shot_index in range(ring_count):
				var angle := (TAU / float(ring_count)) * float(shot_index)
				ActorSystemRef.spawn_bullet(game, origin, Vector2(cos(angle), sin(angle)), 62.0, false, 1.9, enemy.color.lightened(0.2), 2.2, 1)
		"end":
			var wave_count := 8 + (phase - 1) * 2
			for shot_index in range(wave_count):
				var angle := (TAU / float(wave_count)) * float(shot_index)
				ActorSystemRef.spawn_bullet(game, origin, Vector2(cos(angle), sin(angle)), 74.0 + phase * 5.0, false, 2.3, Color(0.9, 0.78, 1.0), 2.5, 1)
			if phase >= 2:
				ActorSystemRef.spawn_poison(game, enemy.body[enemy.body.size() - 1], 4.0)
		_:
			ActorSystemRef.spawn_bullet(game, origin, aim, 84.0, false, 2.1, enemy.color.lightened(0.2), 2.7, 1)


static func _enemy_shot_cooldown(enemy) -> float:
	if not enemy.is_boss:
		return 1.3
	match enemy.biome:
		"city":
			return 0.65
		"carnival":
			return 0.9
		"end":
			return 1.1
		_:
			return 0.8


static func _spawn_ring_cell(game, extra_padding: int = 0) -> Vector2i:
	var center: Vector2i = game.player_body[0]
	var visible_half: Vector2i = CameraSystemRef.visible_half_cells(game)
	var half_x: int = visible_half.x + GameDefsRef.SPAWN_RING_PADDING + extra_padding
	var half_y: int = visible_half.y + GameDefsRef.SPAWN_RING_PADDING + extra_padding
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
		var hit: Dictionary = ActorSystemRef.enemy_cell_hit(game, cell, enemy_index)
		if hit["snake_index"] != -1 or cell in enemy.body or cell in game.player_body:
			continue
		var prop = ActorSystemRef.prop_at_cell(game, cell)
		if prop != null and prop.kind != "swamp_pool":
			continue
		return option
	return enemy.dir
