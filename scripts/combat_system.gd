extends RefCounted
class_name CombatSystem

const GameDefsRef = preload("res://scripts/game_defs.gd")
const SnakeDataRef = preload("res://scripts/snake_data.gd")
const ActorSystemRef = preload("res://scripts/actor_system.gd")

static func update(game, delta: float) -> void:
	game.head_shot_timer -= delta
	game.side_shot_timer -= delta
	game.rear_shot_timer -= delta
	game.beam_tick_timer -= delta

	_fire_player_weapons(game)
	_update_bullets(game, delta)
	_update_poisons(game, delta)
	_update_orbits(game, delta)


static func _fire_player_weapons(game) -> void:
	var head_pos := GameDefsRef.cell_center(game.player_body[0])
	if game.head_shot_timer <= 0.0:
		var front: Vector2 = GameDefsRef.direction_vec(game.player_direction)
		ActorSystemRef.spawn_bullet(game, head_pos, front, 108.0, true, 1.1, Color(0.95, 1.0, 0.7), 2.0, 1)
		if game.upgrade_levels[GameDefsRef.WeaponUpgrade.FRONT_FAN] > 0:
			var left: Vector2 = Vector2(-front.y, front.x)
			var right := -left
			ActorSystemRef.spawn_bullet(game, head_pos, (front + left * 0.45).normalized(), 102.0, true, 0.95, Color(1.0, 0.82, 0.4), 1.9, 1)
			ActorSystemRef.spawn_bullet(game, head_pos, (front + right * 0.45).normalized(), 102.0, true, 0.95, Color(1.0, 0.82, 0.4), 1.9, 1)
			if game.upgrade_levels[GameDefsRef.WeaponUpgrade.FRONT_FAN] > 1:
				ActorSystemRef.spawn_bullet(game, head_pos, (front + left * 0.8).normalized(), 98.0, true, 0.9, Color(1.0, 0.62, 0.25), 1.7, 1)
				ActorSystemRef.spawn_bullet(game, head_pos, (front + right * 0.8).normalized(), 98.0, true, 0.9, Color(1.0, 0.62, 0.25), 1.7, 1)
		game.head_shot_timer = max(0.1, 0.24 - float(game.upgrade_levels[GameDefsRef.WeaponUpgrade.RAPID_HEAD]) * 0.035)

	if game.upgrade_levels[GameDefsRef.WeaponUpgrade.SIDE_SHOTS] > 0 and game.side_shot_timer <= 0.0:
		var left: Vector2 = Vector2(-game.player_direction.y, game.player_direction.x)
		var right := -left
		var stride: int = max(1, 4 - game.upgrade_levels[GameDefsRef.WeaponUpgrade.SIDE_SHOTS])
		for idx in range(1, game.player_body.size(), stride):
			var cell_pos := GameDefsRef.cell_center(game.player_body[idx])
			ActorSystemRef.spawn_bullet(game, cell_pos, left, 92.0, true, 0.95, Color(0.72, 0.95, 1.0), 2.0, 1)
			ActorSystemRef.spawn_bullet(game, cell_pos, right, 92.0, true, 0.95, Color(0.72, 0.95, 1.0), 2.0, 1)
		game.side_shot_timer = 0.52

	if game.upgrade_levels[GameDefsRef.WeaponUpgrade.REAR_SHOTS] > 0 and game.rear_shot_timer <= 0.0:
		var tail_pos: Vector2 = GameDefsRef.cell_center(game.player_body[game.player_body.size() - 1])
		var back: Vector2 = -GameDefsRef.direction_vec(game.player_direction)
		for _i in range(game.upgrade_levels[GameDefsRef.WeaponUpgrade.REAR_SHOTS]):
			ActorSystemRef.spawn_bullet(game, tail_pos, back, 100.0, true, 1.0, Color(1.0, 0.7, 0.35), 2.1, 1)
		game.rear_shot_timer = 0.4

	if game.upgrade_levels[GameDefsRef.WeaponUpgrade.BEAM_HEAD] > 0 and game.beam_tick_timer <= 0.0:
		var beam_length: float = 80.0 + float(game.upgrade_levels[GameDefsRef.WeaponUpgrade.BEAM_HEAD]) * 24.0
		damage_enemies_in_beam(game, head_pos, GameDefsRef.direction_vec(game.player_direction), beam_length)
		damage_props_in_beam(game, head_pos, GameDefsRef.direction_vec(game.player_direction), beam_length)
		game.beam_tick_timer = 0.1


static func _update_bullets(game, delta: float) -> void:
	for i in range(game.bullets.size() - 1, -1, -1):
		var bullet: SnakeDataRef.BulletData = game.bullets[i]
		bullet.ttl -= delta
		bullet.pos += bullet.vel * delta
		var remove: bool = bullet.ttl <= 0.0
		var hit_cell := GameDefsRef.point_to_cell(bullet.pos)
		if bullet.friendly:
			var prop = ActorSystemRef.prop_at_cell(game, hit_cell)
			if prop != null:
				ActorSystemRef.damage_prop(game, prop, bullet.damage + game.upgrade_levels[GameDefsRef.WeaponUpgrade.PROP_BREAKER])
				if bullet.pierce > 0:
					bullet.pierce -= 1
				else:
					remove = true
			else:
				var hit: Dictionary = ActorSystemRef.enemy_hit_by_point(game, bullet.pos)
				if hit["snake_index"] != -1:
					ActorSystemRef.damage_enemy_segment(game, hit["snake_index"], hit["segment_index"], bullet.damage)
					if bullet.chain > 0:
						_chain_bullet_to_nearby_enemy(game, bullet, hit["snake_index"], bullet.pos)
						bullet.chain -= 1
					if bullet.pierce > 0:
						bullet.pierce -= 1
					else:
						remove = true
		else:
			for segment in game.player_body:
				if segment == hit_cell:
					ActorSystemRef.cut_player_at(game, hit_cell)
					remove = true
					break

		if remove:
			game.bullets.remove_at(i)
		else:
			game.bullets[i] = bullet


static func _update_poisons(game, delta: float) -> void:
	for i in range(game.poisons.size() - 1, -1, -1):
		var poison: SnakeDataRef.PoisonPatch = game.poisons[i]
		poison.ttl -= delta
		if poison.ttl <= 0.0:
			game.poisons.remove_at(i)
			continue
		for j in range(game.enemy_snakes.size() - 1, -1, -1):
			var snake = game.enemy_snakes[j]
			var idx: int = snake.body.find(poison.cell)
			if idx != -1:
				ActorSystemRef.damage_enemy_segment(game, j, idx, 1)
				break
		if poison.cell in game.player_body:
			ActorSystemRef.cut_player_at(game, poison.cell)
		game.poisons[i] = poison


static func _update_orbits(game, delta: float) -> void:
	var target_count := int(game.upgrade_levels[GameDefsRef.WeaponUpgrade.ORBIT_BULLETS]) * 2
	while game.orbit_angles.size() < target_count:
		game.orbit_angles.append(float(game.orbit_angles.size()) * PI)
	while game.orbit_angles.size() > target_count:
		game.orbit_angles.pop_back()

	for i in range(game.orbit_angles.size()):
		game.orbit_angles[i] += delta * (1.8 + float(i) * 0.1)
		var radius: float = 14.0 + float(game.upgrade_levels[GameDefsRef.WeaponUpgrade.ORBIT_BULLETS]) * 4.0
		var pos: Vector2 = GameDefsRef.cell_center(game.player_body[0]) + Vector2(cos(game.orbit_angles[i]), sin(game.orbit_angles[i])) * radius
		var hit: Dictionary = ActorSystemRef.enemy_hit_by_point(game, pos)
		if hit["snake_index"] != -1:
			ActorSystemRef.damage_enemy_segment(game, hit["snake_index"], hit["segment_index"], 1)


static func damage_enemies_in_beam(game, start: Vector2, direction: Vector2, length: float) -> void:
	var dir: Vector2 = direction.normalized()
	var beam_end := start + dir * length
	for snake_index in range(game.enemy_snakes.size() - 1, -1, -1):
		var snake = game.enemy_snakes[snake_index]
		for segment_index in range(snake.body.size()):
			var center := GameDefsRef.cell_center(snake.body[segment_index])
			var closest := _closest_point_on_segment(center, start, beam_end)
			if center.distance_to(closest) <= GameDefsRef.CELL_SIZE * 0.55:
				ActorSystemRef.damage_enemy_segment(game, snake_index, segment_index, 1)
				break


static func damage_props_in_beam(game, start: Vector2, direction: Vector2, length: float) -> void:
	var dir: Vector2 = direction.normalized()
	var beam_end := start + dir * length
	for prop in game.props:
		var center: Vector2 = GameDefsRef.cell_center(prop.cell)
		var closest: Vector2 = _closest_point_on_segment(center, start, beam_end)
		if center.distance_to(closest) <= GameDefsRef.CELL_SIZE * 0.55:
			ActorSystemRef.damage_prop(game, prop, 1 + game.upgrade_levels[GameDefsRef.WeaponUpgrade.PROP_BREAKER])


static func _closest_point_on_segment(point: Vector2, a: Vector2, b: Vector2) -> Vector2:
	var ab: Vector2 = b - a
	var length_squared: float = ab.length_squared()
	if length_squared <= 0.0001:
		return a
	var t: float = clamp((point - a).dot(ab) / length_squared, 0.0, 1.0)
	return a + ab * t


static func _chain_bullet_to_nearby_enemy(game, bullet, snake_index: int, from_pos: Vector2) -> void:
	var target: Dictionary = ActorSystemRef.nearest_enemy_segment_except(game, from_pos, snake_index)
	if target["snake_index"] == -1 or target["distance"] > 44.0:
		return
	var target_center: Vector2 = GameDefsRef.cell_center(target["cell"])
	ActorSystemRef.spawn_bullet(game, from_pos, (target_center - from_pos).normalized(), 124.0, true, 0.45, bullet.color.lightened(0.2), max(1.5, bullet.radius - 0.2), bullet.damage)
