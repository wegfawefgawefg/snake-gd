extends RefCounted
class_name PlayerSystem

const GameDefsRef = preload("res://scripts/game_defs.gd")
const ProgressionSystemRef = preload("res://scripts/progression_system.gd")
const ActorSystemRef = preload("res://scripts/actor_system.gd")

static func handle_input(game) -> void:
	if game.game_state == GameDefsRef.GameState.TITLE:
		if Input.is_action_just_pressed("ui_accept") or Input.is_key_pressed(KEY_SPACE):
			game.game_state = GameDefsRef.GameState.PLAYING
		return

	if game.game_state == GameDefsRef.GameState.GAME_OVER:
		if Input.is_action_just_pressed("ui_accept") or Input.is_key_pressed(KEY_SPACE):
			game.reset_run()
			game.game_state = GameDefsRef.GameState.PLAYING
		return

	if game.game_state == GameDefsRef.GameState.CHOOSING_UPGRADE:
		if Input.is_action_just_pressed("ui_accept") or Input.is_key_pressed(KEY_1):
			ProgressionSystemRef.apply_upgrade_choice(game, 0)
		elif Input.is_key_pressed(KEY_2):
			ProgressionSystemRef.apply_upgrade_choice(game, 1)
		elif Input.is_key_pressed(KEY_3):
			ProgressionSystemRef.apply_upgrade_choice(game, 2)
		return

	var next_dir: Vector2i = game.player_direction
	if Input.is_action_just_pressed("ui_up") or Input.is_key_pressed(KEY_W):
		next_dir = Vector2i.UP
	elif Input.is_action_just_pressed("ui_down") or Input.is_key_pressed(KEY_S):
		next_dir = Vector2i.DOWN
	elif Input.is_action_just_pressed("ui_left") or Input.is_key_pressed(KEY_A):
		next_dir = Vector2i.LEFT
	elif Input.is_action_just_pressed("ui_right") or Input.is_key_pressed(KEY_D):
		next_dir = Vector2i.RIGHT

	if not GameDefsRef.is_reverse_dir(game.player_direction, next_dir):
		game.queued_direction = next_dir


static func step(game) -> void:
	var old_tail: Vector2i = game.player_body[game.player_body.size() - 1]
	var new_head: Vector2i = game.player_body[0] + game.queued_direction
	game.player_direction = game.queued_direction

	var enemy_hit: Dictionary = ActorSystemRef.enemy_cell_hit(game, new_head)
	if new_head in game.player_body or enemy_hit["snake_index"] != -1:
		if enemy_hit["snake_index"] != -1 and game.upgrade_levels[GameDefsRef.WeaponUpgrade.THORNS] > 0:
			ActorSystemRef.damage_enemy_segment(game, enemy_hit["snake_index"], enemy_hit["segment_index"], 1 + game.upgrade_levels[GameDefsRef.WeaponUpgrade.THORNS])
		ActorSystemRef.kill_player(game)
		return

	var prop = ActorSystemRef.prop_at_cell(game, new_head)
	if prop != null:
		if prop.kind == "swamp_pool":
			ActorSystemRef.kill_player(game)
			return
		ActorSystemRef.kill_player(game)
		return

	game.player_body.push_front(new_head)
	var food_value: int = ActorSystemRef.consume_food_at(game, new_head)
	if food_value > 0:
		ProgressionSystemRef.handle_player_food_pickup(game, new_head, food_value)
	else:
		game.player_body.pop_back()

	if game.upgrade_levels[GameDefsRef.WeaponUpgrade.POISON_TRAIL] > 0:
		ActorSystemRef.spawn_poison(game, old_tail)
