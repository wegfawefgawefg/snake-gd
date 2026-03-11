extends RefCounted
class_name PlayerSystem

const GameDefsRef = preload("res://scripts/game_defs.gd")

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
			game.apply_upgrade_choice(0)
		elif Input.is_key_pressed(KEY_2):
			game.apply_upgrade_choice(1)
		elif Input.is_key_pressed(KEY_3):
			game.apply_upgrade_choice(2)
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

	var enemy_hit: Dictionary = game.enemy_cell_hit(new_head)
	if new_head in game.player_body or enemy_hit["snake_index"] != -1:
		game.kill_player()
		return

	var prop = game.prop_at_cell(new_head)
	if prop != null:
		if prop.kind == "swamp_pool":
			game.kill_player()
			return
		game.kill_player()
		return

	game.player_body.push_front(new_head)
	var food_value: int = game.consume_food_at(new_head)
	if food_value > 0:
		game.handle_player_food_pickup(new_head, food_value)
	else:
		game.player_body.pop_back()

	if game.upgrade_levels[GameDefsRef.WeaponUpgrade.POISON_TRAIL] > 0:
		game.spawn_poison(old_tail)
