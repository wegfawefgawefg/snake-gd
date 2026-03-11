extends Node2D

const GameDefsRef = preload("res://scripts/game_defs.gd")
const SnakeDataRef = preload("res://scripts/snake_data.gd")
const WorldGenRef = preload("res://scripts/world_gen.gd")
const PlayerSystemRef = preload("res://scripts/player_system.gd")
const EnemySystemRef = preload("res://scripts/enemy_system.gd")
const CombatSystemRef = preload("res://scripts/combat_system.gd")
const SnakeRenderRef = preload("res://scripts/snake_render.gd")

var rng := RandomNumberGenerator.new()

var game_state = GameDefsRef.GameState.TITLE
var score := 0
var xp := 0
var level := 1
var next_upgrade_xp := 5
var move_timer := 0.0

var player_body: Array[Vector2i] = []
var player_direction := Vector2i.RIGHT
var queued_direction := Vector2i.RIGHT

var foods: Array = []
var enemy_snakes: Array = []
var bullets: Array = []
var poisons: Array = []
var props: Array = []
var chunks: Dictionary = {}
var orbit_angles: Array[float] = []

var head_shot_timer := 0.0
var side_shot_timer := 0.0
var rear_shot_timer := 0.0
var beam_tick_timer := 0.0
var enemy_spawn_timer := 0.0
var boss_spawn_timer := 14.0

var upgrade_levels := {
	GameDefsRef.WeaponUpgrade.SIDE_SHOTS: 0,
	GameDefsRef.WeaponUpgrade.REAR_SHOTS: 0,
	GameDefsRef.WeaponUpgrade.BEAM_HEAD: 0,
	GameDefsRef.WeaponUpgrade.ORBIT_BULLETS: 0,
	GameDefsRef.WeaponUpgrade.POISON_TRAIL: 0,
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
	board_fill.visible = false
	board_border.visible = false
	debug_rect.visible = false
	beam_line.visible = false
	camera.zoom = GameDefsRef.CAMERA_ZOOM
	reset_run()
	update_ui()
	update_camera(1.0)


func _process(delta: float) -> void:
	PlayerSystemRef.handle_input(self)
	if game_state == GameDefsRef.GameState.PLAYING:
		EnemySystemRef.update(self, delta)
		CombatSystemRef.update(self, delta)
		move_timer += delta
		while move_timer >= GameDefsRef.STEP_TIME:
			move_timer -= GameDefsRef.STEP_TIME
			PlayerSystemRef.step(self)
			if game_state == GameDefsRef.GameState.PLAYING:
				EnemySystemRef.step(self)
	_update_foods(delta)
	WorldGenRef.ensure_chunks(self)
	WorldGenRef.spawn_ambient_food(self)
	update_camera(delta)
	update_ui()
	queue_redraw()


func _draw() -> void:
	SnakeRenderRef.draw_world(self)


func reset_run() -> void:
	game_state = GameDefsRef.GameState.TITLE
	score = 0
	xp = 0
	level = 1
	next_upgrade_xp = 5
	move_timer = 0.0
	player_body = []
	for i in range(GameDefsRef.START_LENGTH):
		player_body.append(GameDefsRef.PLAYER_START - Vector2i(i, 0))
	player_direction = Vector2i.RIGHT
	queued_direction = Vector2i.RIGHT
	foods.clear()
	enemy_snakes.clear()
	bullets.clear()
	poisons.clear()
	props.clear()
	chunks.clear()
	orbit_angles.clear()
	head_shot_timer = 0.0
	side_shot_timer = 0.0
	rear_shot_timer = 0.0
	beam_tick_timer = 0.0
	enemy_spawn_timer = 0.0
	boss_spawn_timer = 14.0
	for key in upgrade_levels.keys():
		upgrade_levels[key] = 0
	current_upgrade_choices.clear()
	WorldGenRef.ensure_chunks(self)
	WorldGenRef.spawn_ambient_food(self)


func update_camera(delta: float) -> void:
	if player_body.is_empty():
		return
	var target := GameDefsRef.cell_center(player_body[0])
	camera.position = camera.position.lerp(target, min(delta * GameDefsRef.CAMERA_LERP_RATE, 1.0))


func update_ui() -> void:
	score_label.text = "Score: %d" % score
	xp_label.text = "XP: %d / %d" % [xp, next_upgrade_xp]
	boss_label.text = current_boss_name()
	upgrade_summary.text = build_upgrade_summary()
	center_panel.visible = game_state == GameDefsRef.GameState.TITLE or game_state == GameDefsRef.GameState.GAME_OVER
	upgrade_panel.visible = game_state == GameDefsRef.GameState.CHOOSING_UPGRADE

	match game_state:
		GameDefsRef.GameState.TITLE:
			center_title.text = "COMBAT SNAKE"
			center_body.text = "Eat food, cut rival snakes, and level up.\nWASD or arrows to turn.\nPress Space to start."
		GameDefsRef.GameState.GAME_OVER:
			center_title.text = "GAME OVER"
			center_body.text = "Score: %d\nPress Space again" % score

	if game_state == GameDefsRef.GameState.CHOOSING_UPGRADE:
		for i in range(option_labels.size()):
			var label = option_labels[i]
			if i >= current_upgrade_choices.size():
				label.text = ""
				continue
			var choice = current_upgrade_choices[i]
			label.text = "%d. %s\n%s" % [i + 1, choice.name, choice.desc]


func build_upgrade_summary() -> String:
	var parts: Array[String] = []
	for key in upgrade_levels.keys():
		var amount: int = upgrade_levels[key]
		if amount > 0:
			parts.append("%s %d" % [GameDefsRef.UPGRADE_DATA[key].name, amount])
	if parts.is_empty():
		return "Weapons: Head Shot"
	return "Weapons: Head Shot | " + " | ".join(parts)


func gain_xp(amount: int) -> void:
	xp += amount
	while xp >= next_upgrade_xp:
		xp -= next_upgrade_xp
		level += 1
		next_upgrade_xp += 4
		roll_upgrade_choices()
		game_state = GameDefsRef.GameState.CHOOSING_UPGRADE
		break


func roll_upgrade_choices() -> void:
	var pool = [
		GameDefsRef.WeaponUpgrade.SIDE_SHOTS,
		GameDefsRef.WeaponUpgrade.REAR_SHOTS,
		GameDefsRef.WeaponUpgrade.BEAM_HEAD,
		GameDefsRef.WeaponUpgrade.ORBIT_BULLETS,
		GameDefsRef.WeaponUpgrade.POISON_TRAIL,
	]
	current_upgrade_choices.clear()
	while current_upgrade_choices.size() < 3 and not pool.is_empty():
		var idx := rng.randi_range(0, pool.size() - 1)
		var kind = pool[idx]
		pool.remove_at(idx)
		current_upgrade_choices.append({
			"kind": kind,
			"name": GameDefsRef.UPGRADE_DATA[kind].name,
			"desc": GameDefsRef.UPGRADE_DATA[kind].desc,
		})


func apply_upgrade_choice(choice_index: int) -> void:
	if choice_index < 0 or choice_index >= current_upgrade_choices.size():
		return
	var chosen = current_upgrade_choices[choice_index]
	upgrade_levels[chosen.kind] += 1
	game_state = GameDefsRef.GameState.PLAYING


func spawn_bullet(pos: Vector2, dir: Vector2, speed: float, friendly: bool, ttl: float, color: Color, radius: float, damage: int) -> void:
	var bullet = SnakeDataRef.BulletData.new()
	bullet.pos = pos
	bullet.vel = dir.normalized() * speed
	bullet.ttl = ttl
	bullet.friendly = friendly
	bullet.color = color
	bullet.radius = radius
	bullet.damage = damage
	bullets.append(bullet)


func spawn_poison(cell: Vector2i, ttl: float = 3.0) -> void:
	if poison_at(cell):
		return
	var poison = SnakeDataRef.PoisonPatch.new()
	poison.cell = cell
	poison.ttl = ttl
	poisons.append(poison)


func poison_at(cell: Vector2i) -> bool:
	for poison in poisons:
		if poison.cell == cell:
			return true
	return false


func consume_food_at(cell: Vector2i) -> int:
	for i in range(foods.size() - 1, -1, -1):
		if foods[i].cell == cell:
			var value: int = foods[i].value
			foods.remove_at(i)
			return value
	return 0


func spawn_food(cell: Vector2i, value: int) -> void:
	if cell_occupied(cell):
		return
	var food = SnakeDataRef.FoodPickup.new()
	food.cell = cell
	food.value = value
	food.phase = rng.randf() * TAU
	food.chunk_coord = GameDefsRef.chunk_for_cell(cell)
	foods.append(food)


func cell_occupied(cell: Vector2i) -> bool:
	if cell in player_body:
		return true
	var hit: Dictionary = enemy_cell_hit(cell)
	if hit["snake_index"] != -1:
		return true
	if prop_at_cell(cell) != null:
		return true
	for food in foods:
		if food.cell == cell:
			return true
	return false


func prop_at_cell(cell: Vector2i):
	for prop in props:
		if prop.cell == cell:
			return prop
	return null


func enemy_cell_hit(cell: Vector2i, ignored_index: int = -1) -> Dictionary:
	for snake_index in range(enemy_snakes.size()):
		if snake_index == ignored_index:
			continue
		var segment_index: int = enemy_snakes[snake_index].body.find(cell)
		if segment_index != -1:
			return {"snake_index": snake_index, "segment_index": segment_index}
	return {"snake_index": -1, "segment_index": -1}


func enemy_hit_by_point(point: Vector2) -> Dictionary:
	return enemy_cell_hit(GameDefsRef.point_to_cell(point))


func find_nearest_food(origin: Vector2i, max_distance: int):
	var best = null
	var best_score: float = INF
	for food in foods:
		var dist: int = abs(food.cell.x - origin.x) + abs(food.cell.y - origin.y)
		if dist < best_score and dist <= max_distance:
			best_score = dist
			best = food
	return best


func damage_enemy_segment(snake_index: int, segment_index: int, world_pos: Vector2, damage: int) -> void:
	if snake_index < 0 or snake_index >= enemy_snakes.size():
		return
	var snake = enemy_snakes[snake_index]
	snake.damage_flash = 0.8
	if segment_index == 0:
		snake.head_hp -= damage
		if snake.head_hp > 0:
			enemy_snakes[snake_index] = snake
			return
		kill_enemy_snake(snake_index, snake.body, snake.is_boss)
		return

	var tail: Array = snake.body.slice(segment_index + 1)
	snake.body = snake.body.slice(0, segment_index)
	if snake.body.size() <= 1:
		kill_enemy_snake(snake_index, snake.body + tail, snake.is_boss)
		return
	enemy_snakes[snake_index] = snake
	score += int(snake.score_value / 3)
	gain_xp(1)
	spawn_food(snake.body[snake.body.size() - 1], 1)
	if snake.split_on_cut and tail.size() >= 3:
		var split = SnakeDataRef.SnakeActor.new()
		split.body = tail
		split.dir = snake.dir
		split.queued_dir = snake.dir
		split.color = snake.color.lightened(0.1)
		split.split_on_cut = false
		split.can_shoot = snake.can_shoot
		split.biome = snake.biome
		split.poison_body = snake.poison_body
		split.score_value = max(10, snake.score_value / 2)
		enemy_snakes.append(split)
	else:
		for segment in tail:
			spawn_food(segment, 1 if rng.randf() < 0.7 else 3)


func kill_enemy_snake(index: int, cells: Array, was_boss: bool) -> void:
	if index >= 0 and index < enemy_snakes.size():
		enemy_snakes.remove_at(index)
	for segment in cells:
		spawn_food(segment, 1 if rng.randf() < 0.7 else (5 if was_boss and rng.randf() < 0.25 else 3))
	score += 160 if was_boss else 40
	gain_xp(5 if was_boss else 2)


func damage_prop(prop, _world_pos: Vector2, damage: int) -> void:
	prop.damage_flash = 0.9
	prop.hp -= damage
	if prop.hp > 0:
		return
	var cell: Vector2i = prop.cell
	match prop.kind:
		"tree":
			for _i in range(3):
				spawn_food(cell + Vector2i(rng.randi_range(-1, 1), rng.randi_range(-1, 1)), 1 if rng.randf() < 0.7 else 3)
		"building":
			for _i in range(4):
				spawn_food(cell + Vector2i(rng.randi_range(-1, 1), rng.randi_range(-1, 1)), 3 if rng.randf() < 0.8 else 5)
			if rng.randf() < 0.35:
				EnemySystemRef.spawn_enemy(self)
		_:
			spawn_food(cell, 1)
	props.erase(prop)
	score += 12


func cut_player_at(cell: Vector2i) -> void:
	var segment_index := player_body.find(cell)
	if segment_index == -1:
		return
	if segment_index == 0:
		kill_player()
		return
	var tail := player_body.slice(segment_index + 1)
	player_body = player_body.slice(0, segment_index)
	if player_body.size() <= 1:
		kill_player()
		return
	for segment in tail:
		spawn_food(segment, 1)


func kill_player() -> void:
	game_state = GameDefsRef.GameState.GAME_OVER


func boss_exists() -> bool:
	for snake in enemy_snakes:
		if snake.is_boss:
			return true
	return false


func current_boss_name() -> String:
	for snake in enemy_snakes:
		if snake.is_boss:
			return snake.name
	return ""


func biome_for_cell(cell: Vector2i) -> String:
	return WorldGenRef.biome_for_chunk(GameDefsRef.chunk_for_cell(cell))


func _update_foods(delta: float) -> void:
	for food in foods:
		food.phase += delta * 2.2
	for prop in props:
		prop.damage_flash = max(prop.damage_flash - delta * 4.0, 0.0)
