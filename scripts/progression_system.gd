extends RefCounted
class_name ProgressionSystem

const GameDefsRef = preload("res://scripts/game_defs.gd")

static func reset_run(game) -> void:
	game.game_state = GameDefsRef.GameState.TITLE
	game.score = 0
	game.xp = 0
	game.level = 1
	game.next_upgrade_xp = 5
	game.move_timer = 0.0
	game.player_body.clear()
	for i in range(GameDefsRef.START_LENGTH):
		game.player_body.append(GameDefsRef.PLAYER_START - Vector2i(i, 0))
	game.player_direction = Vector2i.RIGHT
	game.queued_direction = Vector2i.RIGHT
	game.foods.clear()
	game.enemy_snakes.clear()
	game.bullets.clear()
	game.poisons.clear()
	game.props.clear()
	game.chunks.clear()
	game.orbit_angles.clear()
	game.head_shot_timer = 0.0
	game.side_shot_timer = 0.0
	game.rear_shot_timer = 0.0
	game.beam_tick_timer = 0.0
	game.enemy_spawn_timer = 0.0
	game.boss_spawn_timer = 10.0
	game.player_armor_charges = 0
	game.wood = 0
	game.scrap = 0
	game.crystal = 0
	game.rot = 0
	game.event_name = ""
	game.event_timer = 0.0
	game.event_cooldown = 8.0
	for key in game.upgrade_levels.keys():
		game.upgrade_levels[key] = 0
	game.current_upgrade_choices.clear()
	game.world_events_seen.clear()
	game.ensure_world_bootstrap()


static func gain_xp(game, amount: int) -> void:
	game.xp += amount
	while game.xp >= game.next_upgrade_xp:
		game.xp -= game.next_upgrade_xp
		game.level += 1
		game.next_upgrade_xp = int(round(game.next_upgrade_xp * 1.35)) + 2
		game.player_armor_charges = max(game.player_armor_charges, game.upgrade_levels[GameDefsRef.WeaponUpgrade.SEGMENT_ARMOR])
		roll_upgrade_choices(game)
		game.game_state = GameDefsRef.GameState.CHOOSING_UPGRADE
		break


static func roll_upgrade_choices(game) -> void:
	var pool = [
		GameDefsRef.WeaponUpgrade.SIDE_SHOTS,
		GameDefsRef.WeaponUpgrade.REAR_SHOTS,
		GameDefsRef.WeaponUpgrade.BEAM_HEAD,
		GameDefsRef.WeaponUpgrade.ORBIT_BULLETS,
		GameDefsRef.WeaponUpgrade.POISON_TRAIL,
		GameDefsRef.WeaponUpgrade.FRONT_FAN,
		GameDefsRef.WeaponUpgrade.RAPID_HEAD,
		GameDefsRef.WeaponUpgrade.FOOD_MAGNET,
		GameDefsRef.WeaponUpgrade.APPLE_BURST,
		GameDefsRef.WeaponUpgrade.PROP_BREAKER,
		GameDefsRef.WeaponUpgrade.BOSS_BOUNTY,
		GameDefsRef.WeaponUpgrade.THORNS,
		GameDefsRef.WeaponUpgrade.SEGMENT_ARMOR,
		GameDefsRef.WeaponUpgrade.DRILL_HEAD,
		GameDefsRef.WeaponUpgrade.CHAIN_HEAD,
		GameDefsRef.WeaponUpgrade.HARVESTER,
	]
	game.current_upgrade_choices.clear()
	while game.current_upgrade_choices.size() < 3 and not pool.is_empty():
		var idx: int = game.rng.randi_range(0, pool.size() - 1)
		var kind = pool[idx]
		pool.remove_at(idx)
		game.current_upgrade_choices.append({
			"kind": kind,
			"name": GameDefsRef.UPGRADE_DATA[kind].name,
			"desc": GameDefsRef.UPGRADE_DATA[kind].desc,
		})


static func apply_upgrade_choice(game, choice_index: int) -> void:
	if choice_index < 0 or choice_index >= game.current_upgrade_choices.size():
		return
	var chosen = game.current_upgrade_choices[choice_index]
	game.upgrade_levels[chosen.kind] += 1
	if chosen.kind == GameDefsRef.WeaponUpgrade.SEGMENT_ARMOR:
		game.player_armor_charges += 1
	game.game_state = GameDefsRef.GameState.PLAYING


static func handle_player_food_pickup(game, cell: Vector2i, food_value: int) -> void:
	game.score += food_value * 10
	gain_xp(game, food_value)
	if game.upgrade_levels[GameDefsRef.WeaponUpgrade.APPLE_BURST] > 0:
		var shot_count: int = 4 + game.upgrade_levels[GameDefsRef.WeaponUpgrade.APPLE_BURST] * 2
		for shot_index in range(shot_count):
			var angle := (TAU / float(shot_count)) * float(shot_index)
			var dir := Vector2(cos(angle), sin(angle))
			game.spawn_bullet(GameDefsRef.cell_center(cell), dir, 88.0, true, 0.7, Color(1.0, 0.5, 0.25), 1.8, 1)


static func try_craft_food_cache(game) -> void:
	if game.wood < 3 or game.game_state != GameDefsRef.GameState.PLAYING:
		return
	game.wood -= 3
	for _i in range(5):
		game.spawn_food(game.player_body[0] + Vector2i(game.rng.randi_range(-2, 2), game.rng.randi_range(-2, 2)), 1 if game.rng.randf() < 0.7 else 3)


static func try_craft_scrap_burst(game) -> void:
	if game.scrap < 4 or game.game_state != GameDefsRef.GameState.PLAYING:
		return
	game.scrap -= 4
	var shot_count: int = 10
	for shot_index in range(shot_count):
		var angle := (TAU / float(shot_count)) * float(shot_index)
		var dir := Vector2(cos(angle), sin(angle))
		game.spawn_bullet(GameDefsRef.cell_center(game.player_body[0]), dir, 110.0, true, 0.8, Color(0.55, 0.9, 1.0), 2.0, 1)


static func try_craft_dragon_bait(game) -> void:
	if game.crystal < 5 or game.game_state != GameDefsRef.GameState.PLAYING:
		return
	game.crystal -= 5
	game.boss_spawn_timer = min(game.boss_spawn_timer, 0.8)
	game.event_name = "Dragon Bait"
	game.event_timer = 2.0


static func build_upgrade_summary(game) -> String:
	var parts: Array[String] = []
	for key in game.upgrade_levels.keys():
		var amount: int = game.upgrade_levels[key]
		if amount > 0:
			parts.append("%s %d" % [GameDefsRef.UPGRADE_DATA[key].name, amount])
	if parts.is_empty():
		return "Weapons: Head Shot"
	return "Weapons: Head Shot | " + " | ".join(parts)


static func pretty_biome_name(biome: String) -> String:
	match biome:
		"orchard":
			return "Biome: Orchard"
		"forest":
			return "Biome: Forest"
		"city":
			return "Biome: City"
		"swamp":
			return "Biome: Swamp"
		"carnival":
			return "Biome: Carnival"
		"end":
			return "Biome: End"
		_:
			return "Biome: Desert"
