extends RefCounted
class_name WorldEvents

const GameDefsRef = preload("res://scripts/game_defs.gd")
const ActorSystemRef = preload("res://scripts/actor_system.gd")
const EnemySystemRef = preload("res://scripts/enemy_system.gd")

static func update(game, delta: float) -> void:
	game.event_cooldown -= delta
	game.event_timer = max(game.event_timer - delta, 0.0)
	if game.event_timer <= 0.0:
		game.event_name = ""
	if game.game_state != GameDefsRef.GameState.PLAYING:
		return
	if game.event_cooldown > 0.0:
		return

	var biome := ActorSystemRef.biome_for_cell(game, game.player_body[0])
	var event_key := "%s:%d" % [biome, game.level / 3]
	if event_key in game.world_events_seen and game.rng.randf() < 0.7:
		game.event_cooldown = 6.0
		return
	game.world_events_seen[event_key] = true
	game.event_cooldown = 12.0

	match biome:
		"city":
			_spawn_city_raid(game)
		"orchard":
			_spawn_fruit_stampede(game)
		"swamp":
			_spawn_rot_bloom(game)
		"carnival":
			_spawn_clown_parade(game)
		"end":
			_spawn_ender_surge(game)
		_:
			_spawn_desert_hunt(game)


static func _spawn_city_raid(game) -> void:
	game.event_name = "City Raid"
	game.event_timer = 3.5
	for _i in range(3):
		EnemySystemRef.spawn_enemy(game)


static func _spawn_fruit_stampede(game) -> void:
	game.event_name = "Fruit Stampede"
	game.event_timer = 3.5
	for _i in range(8):
		ActorSystemRef.spawn_food(game, game.player_body[0] + Vector2i(game.rng.randi_range(-8, 8), game.rng.randi_range(-8, 8)), 3)


static func _spawn_rot_bloom(game) -> void:
	game.event_name = "Rot Bloom"
	game.event_timer = 3.5
	for _i in range(6):
		ActorSystemRef.spawn_poison(game, game.player_body[0] + Vector2i(game.rng.randi_range(-6, 6), game.rng.randi_range(-6, 6)), 4.5)


static func _spawn_clown_parade(game) -> void:
	game.event_name = "Clown Parade"
	game.event_timer = 3.5
	for _i in range(4):
		EnemySystemRef.spawn_enemy(game)


static func _spawn_ender_surge(game) -> void:
	game.event_name = "Ender Surge"
	game.event_timer = 3.5
	for _i in range(5):
		ActorSystemRef.spawn_food(game, game.player_body[0] + Vector2i(game.rng.randi_range(-10, 10), game.rng.randi_range(-10, 10)), 5)
	game.boss_spawn_timer = min(game.boss_spawn_timer, 3.0)


static func _spawn_desert_hunt(game) -> void:
	game.event_name = "Desert Hunt"
	game.event_timer = 3.5
	for _i in range(2):
		EnemySystemRef.spawn_enemy(game)
