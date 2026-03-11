extends Node2D

const TILE_TEXTURE := preload("res://assets/kenney_micro-roguelike/Tiles/Colored/tile_0020.png")

const GRID_WIDTH := 48
const GRID_HEIGHT := 36
const CELL_SIZE := 8.0
const STEP_TIME := 0.12
const BOARD_ORIGIN := Vector2.ZERO
const BOARD_PADDING := 8.0

const FOOD_TARGETS := {
	1: 36,
	3: 12,
	5: 5,
}

const PLAYER_HEAD_COLOR := Color(0.45, 1.0, 0.55, 1.0)
const PLAYER_BODY_COLOR := Color(0.1, 0.9, 0.3, 1.0)
const ENEMY_COLORS := [
	Color(1.0, 0.45, 0.55, 1.0),
	Color(0.95, 0.7, 0.3, 1.0),
	Color(0.7, 0.5, 1.0, 1.0),
]
const BOSS_NAMES := [
	"Orchard King",
	"Warden Coil",
	"Spiral Maw",
	"Ashmouth",
]
const FOOD_COLORS := {
	1: Color(0.95, 0.25, 0.25, 1.0),
	3: Color(1.0, 0.85, 0.25, 1.0),
	5: Color(0.4, 0.9, 1.0, 1.0),
}

enum GameState {
	TITLE,
	PLAYING,
	CHOOSING_UPGRADE,
	GAME_OVER,
}

enum WeaponUpgrade {
	SIDE_SHOTS,
	REAR_SHOTS,
	BEAM_HEAD,
	ORBIT_BULLETS,
	POISON_TRAIL,
}

const UPGRADE_DATA := {
	WeaponUpgrade.SIDE_SHOTS: {
		"name": "Side Shots",
		"desc": "Body segments fire left and right.",
	},
	WeaponUpgrade.REAR_SHOTS: {
		"name": "Rear Shots",
		"desc": "Tail fires backward volleys.",
	},
	WeaponUpgrade.BEAM_HEAD: {
		"name": "Beam Head",
		"desc": "Head projects a piercing beam.",
	},
	WeaponUpgrade.ORBIT_BULLETS: {
		"name": "Orbit Bullets",
		"desc": "Orbiting shots damage nearby snakes.",
	},
	WeaponUpgrade.POISON_TRAIL: {
		"name": "Poison Trail",
		"desc": "Movement leaves a damaging trail.",
	},
}

var rng := RandomNumberGenerator.new()

var game_state: GameState = GameState.TITLE
var score := 0
var xp := 0
var level := 1
var next_upgrade_xp := 5
var move_timer := 0.0

var player_body: Array[Vector2i] = []
var player_nodes: Array[Sprite2D] = []
var player_direction: Vector2i = Vector2i.RIGHT
var queued_direction: Vector2i = Vector2i.RIGHT

var foods: Array = []
var enemy_snakes: Array = []
var bullets: Array = []
var poisons: Array = []
var orbit_nodes: Array[Sprite2D] = []
var orbit_angles: Array[float] = []

var head_shot_timer := 0.0
var side_shot_timer := 0.0
var rear_shot_timer := 0.0
var beam_tick_timer := 0.0
var enemy_spawn_timer := 0.0
var boss_spawn_timer := 18.0

var upgrade_levels := {
	WeaponUpgrade.SIDE_SHOTS: 0,
	WeaponUpgrade.REAR_SHOTS: 0,
	WeaponUpgrade.BEAM_HEAD: 0,
	WeaponUpgrade.ORBIT_BULLETS: 0,
	WeaponUpgrade.POISON_TRAIL: 0,
}

var current_upgrade_choices: Array = []

@onready var board_fill: Polygon2D = $BoardFill
@onready var board_border: Line2D = $BoardBorder
@onready var debug_rect: Line2D = $DebugRect
@onready var beam_line: Line2D = $BeamLine
@onready var camera: Camera2D = $Camera2D

@onready var score_label: Label = $Ui/ScoreLabel
@onready var xp_label: Label = $Ui/XpLabel
@onready var boss_label: Label = $Ui/BossLabel
@onready var upgrade_summary: Label = $Ui/UpgradeSummary
@onready var center_panel: ColorRect = $Ui/CenterPanel
@onready var center_title: Label = $Ui/CenterTitle
@onready var center_body: Label = $Ui/CenterBody
@onready var upgrade_panel: ColorRect = $Ui/UpgradePanel
@onready var option_labels: Array[Label] = [
	$Ui/UpgradePanel/Option1,
	$Ui/UpgradePanel/Option2,
	$Ui/UpgradePanel/Option3,
]


func _ready() -> void:
	rng.randomize()
	_setup_board()
	_reset_run()
	_update_ui()
	_update_camera(1.0)


func _process(delta: float) -> void:
	_handle_input()
	_update_camera(delta)
	_update_ui()

	match game_state:
		GameState.TITLE:
			return
		GameState.CHOOSING_UPGRADE:
			_update_orbit_nodes(delta)
			return
		GameState.GAME_OVER:
			_update_orbit_nodes(delta)
			return
		GameState.PLAYING:
			pass

	enemy_spawn_timer += delta
	boss_spawn_timer -= delta
	if enemy_spawn_timer >= 2.4:
		enemy_spawn_timer = 0.0
		_spawn_enemy_snake()
	if boss_spawn_timer <= 0.0 and not _boss_exists():
		boss_spawn_timer = 28.0
		_spawn_boss_snake()

	head_shot_timer -= delta
	side_shot_timer -= delta
	rear_shot_timer -= delta
	beam_tick_timer -= delta

	_fire_player_weapons(delta)
	_update_bullets(delta)
	_update_poisons(delta)
	_update_orbit_nodes(delta)

	move_timer += delta
	while move_timer >= STEP_TIME:
		move_timer -= STEP_TIME
		_step_world()


func _handle_input() -> void:
	if game_state == GameState.TITLE:
		if Input.is_action_just_pressed("ui_accept") or Input.is_key_pressed(KEY_SPACE):
			game_state = GameState.PLAYING
		return

	if game_state == GameState.GAME_OVER:
		if Input.is_action_just_pressed("ui_accept") or Input.is_key_pressed(KEY_SPACE):
			_reset_run()
			game_state = GameState.PLAYING
		return

	if game_state == GameState.CHOOSING_UPGRADE:
		if Input.is_key_pressed(KEY_1):
			_apply_upgrade_choice(0)
		elif Input.is_key_pressed(KEY_2):
			_apply_upgrade_choice(1)
		elif Input.is_key_pressed(KEY_3):
			_apply_upgrade_choice(2)
		return

	if Input.is_action_just_pressed("ui_up") or Input.is_key_pressed(KEY_W):
		if player_direction != Vector2i.DOWN:
			queued_direction = Vector2i.UP
	elif Input.is_action_just_pressed("ui_down") or Input.is_key_pressed(KEY_S):
		if player_direction != Vector2i.UP:
			queued_direction = Vector2i.DOWN
	elif Input.is_action_just_pressed("ui_left") or Input.is_key_pressed(KEY_A):
		if player_direction != Vector2i.RIGHT:
			queued_direction = Vector2i.LEFT
	elif Input.is_action_just_pressed("ui_right") or Input.is_key_pressed(KEY_D):
		if player_direction != Vector2i.LEFT:
			queued_direction = Vector2i.RIGHT


func _setup_board() -> void:
	var x0 := BOARD_ORIGIN.x
	var y0 := BOARD_ORIGIN.y
	var x1 := BOARD_ORIGIN.x + GRID_WIDTH * CELL_SIZE
	var y1 := BOARD_ORIGIN.y + GRID_HEIGHT * CELL_SIZE

	board_fill.polygon = PackedVector2Array([
		Vector2(x0, y0),
		Vector2(x1, y0),
		Vector2(x1, y1),
		Vector2(x0, y1),
	])
	board_border.points = PackedVector2Array([
		Vector2(x0 - BOARD_PADDING * 0.5, y0 - BOARD_PADDING * 0.5),
		Vector2(x1 + BOARD_PADDING * 0.5, y0 - BOARD_PADDING * 0.5),
		Vector2(x1 + BOARD_PADDING * 0.5, y1 + BOARD_PADDING * 0.5),
		Vector2(x0 - BOARD_PADDING * 0.5, y1 + BOARD_PADDING * 0.5),
	])
	debug_rect.points = PackedVector2Array([
		Vector2(x0, y0),
		Vector2(x1, y0),
		Vector2(x1, y1),
		Vector2(x0, y1),
	])
	beam_line.visible = false


func _reset_run() -> void:
	score = 0
	xp = 0
	level = 1
	next_upgrade_xp = 5
	move_timer = 0.0
	head_shot_timer = 0.0
	side_shot_timer = 0.0
	rear_shot_timer = 0.0
	beam_tick_timer = 0.0
	enemy_spawn_timer = 0.0
	boss_spawn_timer = 18.0
	game_state = GameState.TITLE
	current_upgrade_choices.clear()
	for key in upgrade_levels.keys():
		upgrade_levels[key] = 0

	_clear_nodes(player_nodes)
	player_nodes.clear()
	_clear_entities(foods)
	foods.clear()
	_clear_enemy_snakes()
	_clear_entities(bullets)
	bullets.clear()
	_clear_entities(poisons)
	poisons.clear()
	_clear_nodes(orbit_nodes)
	orbit_nodes.clear()
	orbit_angles.clear()

	player_body = [
		Vector2i(6, GRID_HEIGHT / 2),
		Vector2i(5, GRID_HEIGHT / 2),
		Vector2i(4, GRID_HEIGHT / 2),
	]
	player_direction = Vector2i.RIGHT
	queued_direction = Vector2i.RIGHT
	_sync_player_nodes()
	_fill_food_targets()


func _step_world() -> void:
	var old_tail := player_body[player_body.size() - 1]
	var new_head := player_body[0] + queued_direction
	player_direction = queued_direction

	if _cell_out_of_bounds(new_head) or new_head in player_body or _cell_in_any_enemy(new_head):
		game_state = GameState.GAME_OVER
		return

	player_body.push_front(new_head)
	var ate_food := _consume_food_at(new_head, true)
	if ate_food == 0:
		player_body.pop_back()
	else:
		_gain_xp(ate_food)
		score += ate_food * 10

	if upgrade_levels[WeaponUpgrade.POISON_TRAIL] > 0:
		_spawn_poison(old_tail)

	_step_enemy_snakes()
	_fill_food_targets()
	_sync_player_nodes()


func _step_enemy_snakes() -> void:
	var occupied_player := {}
	for cell in player_body:
		occupied_player[cell] = true

	for i in range(enemy_snakes.size() - 1, -1, -1):
		var enemy = enemy_snakes[i]
		var next_dir: Vector2i = _choose_enemy_direction(enemy)
		var head: Vector2i = enemy.body[0]
		var new_head := head + next_dir
		var enemy_cells := {}
		for cell in enemy.body:
			enemy_cells[cell] = true

		var blocked := _cell_out_of_bounds(new_head)
		if not blocked and new_head in occupied_player:
			if new_head == player_body[0]:
				game_state = GameState.GAME_OVER
				return
			blocked = true
		if not blocked and _cell_in_other_enemy(new_head, i):
			blocked = true
		if not blocked and new_head in enemy_cells:
			blocked = true
		if not blocked and _poison_at(new_head):
			blocked = true

		if blocked:
			_kill_enemy_snake(i, enemy.body)
			continue

		enemy.dir = next_dir
		enemy.body.push_front(new_head)
		var ate_food := _consume_food_at(new_head, false)
		if ate_food == 0:
			enemy.body.pop_back()
		else:
			enemy.length_score += ate_food
			if enemy.length_score > 15:
				enemy.length_score = 15

		enemy_snakes[i] = enemy
		_sync_enemy_nodes(i)


func _fire_player_weapons(delta: float) -> void:
	var head_pos := _cell_center(player_body[0])
	if head_shot_timer <= 0.0:
		_spawn_bullet(head_pos, _dir_to_vec(player_direction), 110.0, true, 1.2, Color(0.95, 1.0, 0.7, 1.0))
		head_shot_timer = 0.26

	if upgrade_levels[WeaponUpgrade.SIDE_SHOTS] > 0 and side_shot_timer <= 0.0:
		var left := Vector2(-player_direction.y, player_direction.x)
		var right := -left
		var stride: int = max(1, 4 - int(upgrade_levels[WeaponUpgrade.SIDE_SHOTS]))
		for idx in range(1, player_body.size(), stride):
			var body_pos := _cell_center(player_body[idx])
			_spawn_bullet(body_pos, left, 90.0, true, 1.0, Color(0.7, 0.95, 1.0, 1.0))
			_spawn_bullet(body_pos, right, 90.0, true, 1.0, Color(0.7, 0.95, 1.0, 1.0))
		side_shot_timer = 0.55

	if upgrade_levels[WeaponUpgrade.REAR_SHOTS] > 0 and rear_shot_timer <= 0.0:
		var tail_pos := _cell_center(player_body[player_body.size() - 1])
		var back_dir := -_dir_to_vec(player_direction)
		for _i in range(upgrade_levels[WeaponUpgrade.REAR_SHOTS]):
			_spawn_bullet(tail_pos, back_dir, 105.0, true, 1.0, Color(1.0, 0.7, 0.35, 1.0))
		rear_shot_timer = 0.42

	if upgrade_levels[WeaponUpgrade.BEAM_HEAD] > 0:
		var beam_length: float = 80.0 + float(upgrade_levels[WeaponUpgrade.BEAM_HEAD]) * 24.0
		beam_line.visible = true
		beam_line.points = PackedVector2Array([
			head_pos,
			head_pos + _dir_to_vec(player_direction) * beam_length,
		])
		if beam_tick_timer <= 0.0:
			_damage_enemies_in_beam(head_pos, _dir_to_vec(player_direction), beam_length)
			beam_tick_timer = 0.12
	else:
		beam_line.visible = false


func _update_bullets(delta: float) -> void:
	for i in range(bullets.size() - 1, -1, -1):
		var bullet = bullets[i]
		bullet.ttl -= delta
		bullet.pos += bullet.vel * delta
		bullet.node.position = bullet.pos - Vector2(2, 2)

		var remove: bool = bullet.ttl <= 0.0 or _point_out_of_bounds(bullet.pos)
		if not remove and bullet.friendly:
			var hit_idx := _enemy_hit_by_point(bullet.pos)
			if hit_idx != -1:
				_damage_enemy_snake(hit_idx, bullet.pos)
				remove = true

		if remove:
			bullet.node.queue_free()
			bullets.remove_at(i)
		else:
			bullets[i] = bullet


func _update_poisons(delta: float) -> void:
	for i in range(poisons.size() - 1, -1, -1):
		var poison = poisons[i]
		poison.ttl -= delta
		poison.node.modulate.a = clamp(poison.ttl / 4.0, 0.15, 0.8)
		if poison.ttl <= 0.0:
			poison.node.queue_free()
			poisons.remove_at(i)
		else:
			poisons[i] = poison


func _update_orbit_nodes(delta: float) -> void:
	var orbit_count: int = int(upgrade_levels[WeaponUpgrade.ORBIT_BULLETS]) * 2
	while orbit_nodes.size() < orbit_count:
		var node := _make_sprite(Color(0.7, 0.85, 1.0, 1.0), Vector2(0.55, 0.55))
		add_child(node)
		orbit_nodes.append(node)
		orbit_angles.append(float(orbit_nodes.size()) * 1.6)
	while orbit_nodes.size() > orbit_count:
		orbit_nodes.pop_back().queue_free()
		orbit_angles.pop_back()

	for i in range(orbit_nodes.size()):
		orbit_angles[i] += delta * (1.8 + float(i) * 0.05)
		var radius: float = 14.0 + 4.0 * float(upgrade_levels[WeaponUpgrade.ORBIT_BULLETS])
		var offset: Vector2 = Vector2(cos(orbit_angles[i]), sin(orbit_angles[i])) * radius
		var pos: Vector2 = _cell_center(player_body[0]) + offset
		orbit_nodes[i].position = pos - Vector2(2, 2)
		var hit_idx := _enemy_hit_by_point(pos)
		if hit_idx != -1:
			_damage_enemy_snake(hit_idx, pos)


func _update_camera(delta: float) -> void:
	var target := _board_center()
	if game_state != GameState.TITLE and not player_body.is_empty():
		target = _cell_center(player_body[0])
	camera.position = camera.position.lerp(target, min(delta * 6.0, 1.0))


func _update_ui() -> void:
	score_label.text = "Score: %d" % score
	xp_label.text = "XP: %d / %d" % [xp, next_upgrade_xp]
	boss_label.text = _current_boss_name()
	upgrade_summary.text = _build_upgrade_summary()

	center_panel.visible = game_state != GameState.PLAYING and game_state != GameState.CHOOSING_UPGRADE
	upgrade_panel.visible = game_state == GameState.CHOOSING_UPGRADE

	match game_state:
		GameState.TITLE:
			center_title.text = "COMBAT SNAKE"
			center_body.text = "Eat food. Kill rival snakes.\\nWASD / Arrows to turn.\\nPress Space to start."
		GameState.GAME_OVER:
			center_title.text = "GAME OVER"
			center_body.text = "Score: %d\\nPress Space again" % score
		_:
			pass

	if game_state == GameState.CHOOSING_UPGRADE:
		for i in range(3):
			var data = current_upgrade_choices[i]
			option_labels[i].text = "%d. %s\\n%s" % [i + 1, data.name, data.desc]


func _build_upgrade_summary() -> String:
	var parts: Array[String] = []
	for key in upgrade_levels.keys():
		var amount: int = upgrade_levels[key]
		if amount > 0:
			parts.append("%s %d" % [UPGRADE_DATA[key].name, amount])
	if parts.is_empty():
		return "Weapons: Head Shot"
	return "Weapons: Head Shot | " + " | ".join(parts)


func _sync_player_nodes() -> void:
	while player_nodes.size() < player_body.size():
		var node := _make_sprite(PLAYER_BODY_COLOR)
		add_child(node)
		player_nodes.append(node)
	while player_nodes.size() > player_body.size():
		player_nodes.pop_back().queue_free()

	for i in range(player_body.size()):
		player_nodes[i].position = _grid_to_world(player_body[i])
		player_nodes[i].modulate = PLAYER_HEAD_COLOR if i == 0 else PLAYER_BODY_COLOR


func _sync_enemy_nodes(index: int) -> void:
	var enemy = enemy_snakes[index]
	while enemy.nodes.size() < enemy.body.size():
		var node := _make_sprite(enemy.color.darkened(0.15))
		add_child(node)
		enemy.nodes.append(node)
	while enemy.nodes.size() > enemy.body.size():
		enemy.nodes.pop_back().queue_free()

	for i in range(enemy.body.size()):
		enemy.nodes[i].position = _grid_to_world(enemy.body[i])
		enemy.nodes[i].modulate = enemy.color if i == 0 else enemy.color.darkened(0.2)
	enemy_snakes[index] = enemy


func _fill_food_targets() -> void:
	for value in FOOD_TARGETS.keys():
		while _food_count_for_value(value) < FOOD_TARGETS[value]:
			_spawn_food(value)


func _spawn_food(value: int) -> void:
	var tries := 0
	while tries < 100:
		tries += 1
		var cell := Vector2i(rng.randi_range(0, GRID_WIDTH - 1), rng.randi_range(0, GRID_HEIGHT - 1))
		if _cell_occupied(cell):
			continue
		var scale := 0.7 if value == 1 else (0.95 if value == 3 else 1.15)
		var node := _make_sprite(FOOD_COLORS[value], Vector2(scale, scale))
		add_child(node)
		node.position = _grid_to_world(cell)
		foods.append({
			"cell": cell,
			"value": value,
			"node": node,
		})
		return


func _spawn_enemy_snake() -> void:
	if enemy_snakes.size() >= 8:
		return

	var edge := rng.randi_range(0, 3)
	var length := rng.randi_range(4, 7)
	var head := Vector2i.ZERO
	var dir := Vector2i.ZERO
	match edge:
		0:
			head = Vector2i(0, rng.randi_range(0, GRID_HEIGHT - 1))
			dir = Vector2i.RIGHT
		1:
			head = Vector2i(GRID_WIDTH - 1, rng.randi_range(0, GRID_HEIGHT - 1))
			dir = Vector2i.LEFT
		2:
			head = Vector2i(rng.randi_range(0, GRID_WIDTH - 1), 0)
			dir = Vector2i.DOWN
		_:
			head = Vector2i(rng.randi_range(0, GRID_WIDTH - 1), GRID_HEIGHT - 1)
			dir = Vector2i.UP

	var body: Array[Vector2i] = []
	for i in range(length):
		body.append(head - dir * i)

	var color: Color = ENEMY_COLORS[rng.randi_range(0, ENEMY_COLORS.size() - 1)]
	var enemy = {
		"body": body,
		"dir": dir,
		"nodes": [],
		"color": color,
		"length_score": 0,
		"is_boss": false,
		"name": "",
		"split_on_cut": rng.randf() < 0.35,
	}
	enemy_snakes.append(enemy)
	_sync_enemy_nodes(enemy_snakes.size() - 1)


func _spawn_boss_snake() -> void:
	if _boss_exists():
		return

	var edge := rng.randi_range(0, 3)
	var length := rng.randi_range(10, 14)
	var head := Vector2i.ZERO
	var dir := Vector2i.ZERO
	match edge:
		0:
			head = Vector2i(0, rng.randi_range(2, GRID_HEIGHT - 3))
			dir = Vector2i.RIGHT
		1:
			head = Vector2i(GRID_WIDTH - 1, rng.randi_range(2, GRID_HEIGHT - 3))
			dir = Vector2i.LEFT
		2:
			head = Vector2i(rng.randi_range(2, GRID_WIDTH - 3), 0)
			dir = Vector2i.DOWN
		_:
			head = Vector2i(rng.randi_range(2, GRID_WIDTH - 3), GRID_HEIGHT - 1)
			dir = Vector2i.UP

	var body: Array[Vector2i] = []
	for i in range(length):
		body.append(head - dir * i)

	var enemy = {
		"body": body,
		"dir": dir,
		"nodes": [],
		"color": Color(1.0, 0.82, 0.25, 1.0),
		"length_score": 0,
		"is_boss": true,
		"name": BOSS_NAMES[rng.randi_range(0, BOSS_NAMES.size() - 1)],
		"split_on_cut": true,
	}
	enemy_snakes.append(enemy)
	_sync_enemy_nodes(enemy_snakes.size() - 1)


func _spawn_split_enemy(body: Array[Vector2i], color: Color) -> void:
	if body.size() < 2:
		return
	var dir := Vector2i.RIGHT
	if body.size() >= 2:
		dir = (body[0] - body[1]).sign()
		if dir == Vector2i.ZERO:
			dir = Vector2i.RIGHT
	var enemy = {
		"body": body,
		"dir": dir,
		"nodes": [],
		"color": color.lightened(0.12),
		"length_score": 0,
		"is_boss": false,
		"name": "",
		"split_on_cut": false,
	}
	enemy_snakes.append(enemy)
	_sync_enemy_nodes(enemy_snakes.size() - 1)


func _spawn_bullet(pos: Vector2, dir: Vector2, speed: float, friendly: bool, ttl: float, color: Color) -> void:
	var node := _make_sprite(color, Vector2(0.45, 0.45))
	add_child(node)
	node.position = pos - Vector2(2, 2)
	bullets.append({
		"pos": pos,
		"vel": dir.normalized() * speed,
		"ttl": ttl,
		"friendly": friendly,
		"node": node,
	})


func _spawn_poison(cell: Vector2i) -> void:
	if _poison_at(cell):
		return
	var node := _make_sprite(Color(0.55, 0.2, 0.85, 0.6), Vector2(0.8, 0.8))
	add_child(node)
	node.position = _grid_to_world(cell)
	poisons.append({
		"cell": cell,
		"ttl": 4.0 + upgrade_levels[WeaponUpgrade.POISON_TRAIL] * 0.5,
		"node": node,
	})


func _choose_enemy_direction(enemy: Dictionary) -> Vector2i:
	var options = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	var best_dir: Vector2i = enemy.dir
	var best_score := INF
	var target := _nearest_food_to(enemy.body[0])
	if rng.randf() < 0.25:
		target = player_body[0]

	for dir in options:
		if dir == -enemy.dir:
			continue
		var next_cell: Vector2i = enemy.body[0] + dir
		if _cell_out_of_bounds(next_cell):
			continue
		var score_val: float = next_cell.distance_squared_to(target)
		if next_cell in player_body:
			score_val += 10000.0
		if _poison_at(next_cell):
			score_val += 5000.0
		if _cell_in_other_enemy(next_cell, enemy_snakes.find(enemy)):
			score_val += 5000.0
		if score_val < best_score:
			best_score = score_val
			best_dir = dir

	return best_dir


func _nearest_food_to(cell: Vector2i) -> Vector2i:
	var best := player_body[0]
	var best_dist := INF
	for food in foods:
		var dist = cell.distance_squared_to(food.cell)
		if dist < best_dist:
			best_dist = dist
			best = food.cell
	return best


func _consume_food_at(cell: Vector2i, is_player: bool) -> int:
	for i in range(foods.size() - 1, -1, -1):
		if foods[i].cell == cell:
			var value: int = foods[i].value
			foods[i].node.queue_free()
			foods.remove_at(i)
			if is_player:
				score += value * 2
			return value
	return 0


func _gain_xp(amount: int) -> void:
	xp += amount
	while xp >= next_upgrade_xp:
		xp -= next_upgrade_xp
		level += 1
		next_upgrade_xp += 4
		_roll_upgrade_choices()
		game_state = GameState.CHOOSING_UPGRADE
		break


func _roll_upgrade_choices() -> void:
	var pool = [
		WeaponUpgrade.SIDE_SHOTS,
		WeaponUpgrade.REAR_SHOTS,
		WeaponUpgrade.BEAM_HEAD,
		WeaponUpgrade.ORBIT_BULLETS,
		WeaponUpgrade.POISON_TRAIL,
	]
	current_upgrade_choices.clear()
	while current_upgrade_choices.size() < 3 and not pool.is_empty():
		var idx := rng.randi_range(0, pool.size() - 1)
		var kind = pool[idx]
		pool.remove_at(idx)
		current_upgrade_choices.append({
			"kind": kind,
			"name": UPGRADE_DATA[kind].name,
			"desc": UPGRADE_DATA[kind].desc,
		})


func _apply_upgrade_choice(choice_index: int) -> void:
	if choice_index < 0 or choice_index >= current_upgrade_choices.size():
		return
	var chosen = current_upgrade_choices[choice_index]
	upgrade_levels[chosen.kind] += 1
	game_state = GameState.PLAYING


func _damage_enemies_in_beam(origin: Vector2, dir: Vector2, length: float) -> void:
	for i in range(enemy_snakes.size() - 1, -1, -1):
		for cell in enemy_snakes[i].body:
			var center := _cell_center(cell)
			var to_point := center - origin
			var along := to_point.dot(dir)
			if along < 0.0 or along > length:
				continue
			var perp := (to_point - dir * along).length()
			if perp <= 5.0:
				_damage_enemy_snake(i, center)
				break


func _damage_enemy_snake(index: int, hit_pos: Vector2) -> void:
	if index < 0 or index >= enemy_snakes.size():
		return
	var enemy = enemy_snakes[index]
	var hit_segment := _enemy_segment_index_at_point(enemy, hit_pos)
	if hit_segment == -1:
		return

	if hit_segment == 0:
		var body = enemy.body
		_spawn_food_burst(body, hit_pos)
		_kill_enemy_snake(index, body)
		score += 50 if enemy.is_boss else 25
		_gain_xp(5 if enemy.is_boss else 2)
		return

	var head_section: Array[Vector2i] = []
	for i in range(hit_segment):
		head_section.append(enemy.body[i])

	var tail_section: Array[Vector2i] = []
	for i in range(hit_segment + 1, enemy.body.size()):
		tail_section.append(enemy.body[i])

	_spawn_food_burst([enemy.body[hit_segment]], hit_pos)

	if head_section.size() < 2:
		var body = enemy.body
		_spawn_food_burst(body, hit_pos)
		_kill_enemy_snake(index, body)
		score += 25
		_gain_xp(2)
		return

	enemy.body = head_section
	enemy_snakes[index] = enemy
	_sync_enemy_nodes(index)

	if tail_section.size() >= 2:
		if enemy.split_on_cut:
			_spawn_split_enemy(tail_section, enemy.color)
		else:
			_spawn_food_burst(tail_section, hit_pos)

	score += 12
	_gain_xp(1)


func _kill_enemy_snake(index: int, body: Array) -> void:
	for node in enemy_snakes[index].nodes:
		node.queue_free()
	enemy_snakes.remove_at(index)


func _spawn_food_burst(body: Array, origin: Vector2) -> void:
	for cell in body:
		var value := 1 if rng.randf() < 0.7 else (3 if rng.randf() < 0.9 else 5)
		var node := _make_sprite(FOOD_COLORS[value], Vector2(0.7, 0.7))
		add_child(node)
		var spawn_cell: Vector2i = cell
		if _cell_out_of_bounds(spawn_cell):
			continue
		node.position = _grid_to_world(spawn_cell)
		foods.append({
			"cell": spawn_cell,
			"value": value,
			"node": node,
		})


func _food_count_for_value(value: int) -> int:
	var count := 0
	for food in foods:
		if food.value == value:
			count += 1
	return count


func _boss_exists() -> bool:
	for enemy in enemy_snakes:
		if enemy.is_boss:
			return true
	return false


func _current_boss_name() -> String:
	for enemy in enemy_snakes:
		if enemy.is_boss:
			return enemy.name
	return ""


func _cell_occupied(cell: Vector2i) -> bool:
	if cell in player_body:
		return true
	for enemy in enemy_snakes:
		if cell in enemy.body:
			return true
	for food in foods:
		if food.cell == cell:
			return true
	return false


func _cell_in_any_enemy(cell: Vector2i) -> bool:
	for enemy in enemy_snakes:
		if cell in enemy.body:
			return true
	return false


func _cell_in_other_enemy(cell: Vector2i, skip_index: int) -> bool:
	for i in range(enemy_snakes.size()):
		if i == skip_index:
			continue
		if cell in enemy_snakes[i].body:
			return true
	return false


func _enemy_hit_by_point(point: Vector2) -> int:
	for i in range(enemy_snakes.size()):
		for cell in enemy_snakes[i].body:
			if point.distance_to(_cell_center(cell)) <= 5.0:
				return i
	return -1


func _enemy_segment_index_at_point(enemy: Dictionary, point: Vector2) -> int:
	for i in range(enemy.body.size()):
		if point.distance_to(_cell_center(enemy.body[i])) <= 5.0:
			return i
	return -1


func _poison_at(cell: Vector2i) -> bool:
	for poison in poisons:
		if poison.cell == cell:
			return true
	return false


func _cell_out_of_bounds(cell: Vector2i) -> bool:
	return cell.x < 0 or cell.y < 0 or cell.x >= GRID_WIDTH or cell.y >= GRID_HEIGHT


func _point_out_of_bounds(point: Vector2) -> bool:
	return point.x < BOARD_ORIGIN.x or point.y < BOARD_ORIGIN.y or point.x > BOARD_ORIGIN.x + GRID_WIDTH * CELL_SIZE or point.y > BOARD_ORIGIN.y + GRID_HEIGHT * CELL_SIZE


func _grid_to_world(cell: Vector2i) -> Vector2:
	return BOARD_ORIGIN + Vector2(cell.x, cell.y) * CELL_SIZE


func _cell_center(cell: Vector2i) -> Vector2:
	return _grid_to_world(cell) + Vector2(CELL_SIZE * 0.5, CELL_SIZE * 0.5)


func _dir_to_vec(dir: Vector2i) -> Vector2:
	return Vector2(dir.x, dir.y)


func _board_center() -> Vector2:
	return BOARD_ORIGIN + Vector2(GRID_WIDTH, GRID_HEIGHT) * CELL_SIZE * 0.5


func _make_sprite(color: Color, scale_value: Vector2 = Vector2.ONE) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = TILE_TEXTURE
	sprite.centered = false
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.modulate = color
	sprite.scale = scale_value
	return sprite


func _clear_nodes(nodes: Array) -> void:
	for node in nodes:
		node.queue_free()


func _clear_entities(entities: Array) -> void:
	for entity in entities:
		entity.node.queue_free()


func _clear_enemy_snakes() -> void:
	for enemy in enemy_snakes:
		for node in enemy.nodes:
			node.queue_free()
	enemy_snakes.clear()
