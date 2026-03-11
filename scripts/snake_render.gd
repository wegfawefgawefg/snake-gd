extends RefCounted
class_name SnakeRender

const GameDefsRef = preload("res://scripts/game_defs.gd")

static func draw_world(game) -> void:
	var view_rect: Rect2 = game.visible_world_rect()
	_draw_chunks(game, view_rect)
	_draw_props(game, view_rect)
	_draw_foods(game, view_rect)
	_draw_poisons(game, view_rect)
	_draw_snakes(game, view_rect)
	_draw_bullets(game, view_rect)
	_draw_player_beam(game, view_rect)


static func _draw_chunks(game, view_rect: Rect2) -> void:
	for chunk in game.chunks.values():
		var rect := GameDefsRef.chunk_rect(chunk.coord)
		if not rect.intersects(view_rect.grow(GameDefsRef.CELL_SIZE * 2.0)):
			continue
		game.draw_rect(rect, GameDefsRef.BIOME_COLORS[chunk.biome])
		if chunk.biome == "city":
			for offset in [2, 7, 12]:
				var x := rect.position.x + float(offset) * GameDefsRef.CELL_SIZE
				var y := rect.position.y + float(offset) * GameDefsRef.CELL_SIZE
				game.draw_line(Vector2(x, rect.position.y), Vector2(x, rect.end.y), Color(0.32, 0.34, 0.4, 0.8), 1.0)
				game.draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), Color(0.32, 0.34, 0.4, 0.8), 1.0)
		elif chunk.biome == "carnival":
			game.draw_circle(rect.get_center(), rect.size.x * 0.08, Color(0.98, 0.4, 0.72, 0.18))
		elif chunk.biome == "end":
			game.draw_line(rect.position, rect.end, Color(0.6, 0.45, 1.0, 0.12), 1.0)
			game.draw_line(Vector2(rect.end.x, rect.position.y), Vector2(rect.position.x, rect.end.y), Color(0.6, 0.45, 1.0, 0.12), 1.0)
		game.draw_rect(rect, Color(0.15, 0.16, 0.18, 0.4), false, 1.0)


static func _draw_props(game, view_rect: Rect2) -> void:
	for prop in game.props:
		var rect := GameDefsRef.cell_rect(prop.cell)
		if not rect.intersects(view_rect):
			continue
		var color: Color = GameDefsRef.PROP_COLORS.get(prop.kind, Color.WHITE)
		if prop.damage_flash > 0.0:
			color = color.lightened(prop.damage_flash * 0.8)
		match prop.kind:
			"tree":
				game.draw_circle(rect.get_center() + Vector2(0, -1), 3.4, color)
				game.draw_rect(Rect2(rect.position + Vector2(3, 4), Vector2(2, 4)), Color(0.45, 0.28, 0.12))
			"building":
				game.draw_rect(rect, color)
				game.draw_rect(rect.grow(-1.0), Color(0.18, 0.2, 0.26))
			"tent":
				game.draw_polygon(
					PackedVector2Array([
						rect.position + Vector2(0, rect.size.y),
						rect.position + Vector2(rect.size.x * 0.5, 1),
						rect.position + Vector2(rect.size.x, rect.size.y),
					]),
					PackedColorArray([color, color.lightened(0.2), color])
				)
			"ender_spire":
				game.draw_rect(Rect2(rect.position + Vector2(3, 0), Vector2(2, 8)), color)
				game.draw_circle(rect.get_center() + Vector2(0, 1), 2.2, Color(1.0, 0.9, 1.0))
			"swamp_pool":
				game.draw_circle(rect.get_center(), 3.5, color)
			_:
				game.draw_rect(rect.grow(-1.0), color)


static func _draw_foods(game, view_rect: Rect2) -> void:
	for food in game.foods:
		var center := GameDefsRef.cell_center(food.cell)
		if not view_rect.has_point(center):
			continue
		var bob := sin(food.phase) * 1.2
		var radius := 2.1 if food.value == 1 else (3.2 if food.value == 3 else 4.2)
		game.draw_circle(center + Vector2(0, bob), radius, GameDefsRef.FOOD_COLORS[food.value])
		if food.value >= 3:
			game.draw_circle(center + Vector2(0, bob), radius - 1.5, Color.WHITE)


static func _draw_poisons(game, view_rect: Rect2) -> void:
	for poison in game.poisons:
		var rect := GameDefsRef.cell_rect(poison.cell)
		if not rect.intersects(view_rect):
			continue
		game.draw_rect(rect, Color(0.55, 0.2, 0.85, clamp(poison.ttl / 4.0, 0.12, 0.45)))


static func _draw_snakes(game, view_rect: Rect2) -> void:
	for snake in game.enemy_snakes:
		for segment_index in range(snake.body.size()):
			var cell: Vector2i = snake.body[segment_index]
			var rect := GameDefsRef.cell_rect(cell)
			if not rect.intersects(view_rect):
				continue
			var tint: Color = snake.color if segment_index == 0 else snake.color.darkened(0.22)
			if snake.damage_flash > 0.0:
				tint = tint.lightened(snake.damage_flash)
			game.draw_texture_rect(GameDefsRef.TILE_TEXTURE, rect, false, tint)
		if snake.is_boss:
			var head_center := GameDefsRef.cell_center(snake.body[0])
			game.draw_circle(head_center, 5.5, Color(snake.color, 0.14))

	for segment_index in range(game.player_body.size()):
		var rect := GameDefsRef.cell_rect(game.player_body[segment_index])
		if not rect.intersects(view_rect):
			continue
		var tint := GameDefsRef.PLAYER_HEAD_COLOR if segment_index == 0 else GameDefsRef.PLAYER_BODY_COLOR
		game.draw_texture_rect(GameDefsRef.TILE_TEXTURE, rect, false, tint)
	if game.player_armor_charges > 0 and not game.player_body.is_empty():
		var head_center := GameDefsRef.cell_center(game.player_body[0])
		for armor_index in range(game.player_armor_charges):
			var angle := -PI * 0.5 + armor_index * 0.55
			var armor_pos := head_center + Vector2(cos(angle), sin(angle)) * 6.0
			game.draw_circle(armor_pos, 1.8, Color(0.55, 0.9, 1.0))

	for angle in game.orbit_angles:
		var radius := 14.0 + float(game.upgrade_levels[GameDefsRef.WeaponUpgrade.ORBIT_BULLETS]) * 4.0
		var pos := GameDefsRef.cell_center(game.player_body[0]) + Vector2(cos(angle), sin(angle)) * radius
		if view_rect.has_point(pos):
			game.draw_circle(pos, 2.3, Color(0.55, 0.85, 1.0))


static func _draw_bullets(game, view_rect: Rect2) -> void:
	for bullet in game.bullets:
		if not view_rect.has_point(bullet.pos):
			continue
		game.draw_circle(bullet.pos, bullet.radius, bullet.color)


static func _draw_player_beam(game, view_rect: Rect2) -> void:
	if game.upgrade_levels[GameDefsRef.WeaponUpgrade.BEAM_HEAD] <= 0 or game.game_state != GameDefsRef.GameState.PLAYING:
		return
	var start := GameDefsRef.cell_center(game.player_body[0])
	var dir := GameDefsRef.direction_vec(game.player_direction)
	var length := 80.0 + float(game.upgrade_levels[GameDefsRef.WeaponUpgrade.BEAM_HEAD]) * 24.0
	var end := start + dir * length
	if view_rect.has_point(start) or view_rect.has_point(end):
		game.draw_line(start, end, Color(0.5, 1.0, 1.0, 0.95), 3.0)
