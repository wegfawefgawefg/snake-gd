extends RefCounted
class_name WorldRuntime

const GameDefsRef = preload("res://scripts/game_defs.gd")
const WorldGenRef = preload("res://scripts/world_gen.gd")
const ActorSystemRef = preload("res://scripts/actor_system.gd")
const ProgressionSystemRef = preload("res://scripts/progression_system.gd")


static func update(game, delta: float) -> void:
	if game.player_body.is_empty():
		return
	for food in game.foods:
		food.phase += delta * 2.2

	if game.game_state == GameDefsRef.GameState.PLAYING and game.upgrade_levels[GameDefsRef.WeaponUpgrade.FOOD_MAGNET] > 0:
		_apply_food_magnet(game)

	for prop in game.props:
		prop.damage_flash = max(prop.damage_flash - delta * 4.0, 0.0)

	WorldGenRef.ensure_chunks(game)
	WorldGenRef.spawn_ambient_food(game)
	game.biome_name = ProgressionSystemRef.pretty_biome_name(ActorSystemRef.biome_for_cell(game, game.player_body[0]))


static func bootstrap(game) -> void:
	WorldGenRef.ensure_chunks(game)
	WorldGenRef.spawn_ambient_food(game)
	if not game.player_body.is_empty():
		game.biome_name = ProgressionSystemRef.pretty_biome_name(ActorSystemRef.biome_for_cell(game, game.player_body[0]))


static func _apply_food_magnet(game) -> void:
	var head: Vector2i = game.player_body[0]
	var magnet_radius: int = 2 + game.upgrade_levels[GameDefsRef.WeaponUpgrade.FOOD_MAGNET] * 2
	for i in range(game.foods.size() - 1, -1, -1):
		var food = game.foods[i]
		var dist: int = abs(food.cell.x - head.x) + abs(food.cell.y - head.y)
		if dist <= magnet_radius:
			var value: int = food.value
			var cell: Vector2i = food.cell
			game.foods.remove_at(i)
			ProgressionSystemRef.handle_player_food_pickup(game, cell, value)
