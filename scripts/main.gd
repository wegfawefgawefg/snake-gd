extends Node2D

const GameDefsRef = preload("res://scripts/game_defs.gd")
const SnakeDataRef = preload("res://scripts/snake_data.gd")
const WorldGenRef = preload("res://scripts/world_gen.gd")
const PlayerSystemRef = preload("res://scripts/player_system.gd")
const EnemySystemRef = preload("res://scripts/enemy_system.gd")
const CombatSystemRef = preload("res://scripts/combat_system.gd")
const SnakeRenderRef = preload("res://scripts/snake_render.gd")
const ProgressionSystemRef = preload("res://scripts/progression_system.gd")
const ActorSystemRef = preload("res://scripts/actor_system.gd")
const WorldEventsRef = preload("res://scripts/world_events.gd")

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
var boss_spawn_timer := 10.0

var biome_name := "Biome: Orchard"
var event_name := ""
var event_timer := 0.0
var event_cooldown := 8.0
var world_events_seen := {}
var player_armor_charges := 0

var wood := 0
var scrap := 0
var crystal := 0
var rot := 0

var upgrade_levels := {
	GameDefsRef.WeaponUpgrade.SIDE_SHOTS: 0,
	GameDefsRef.WeaponUpgrade.REAR_SHOTS: 0,
	GameDefsRef.WeaponUpgrade.BEAM_HEAD: 0,
	GameDefsRef.WeaponUpgrade.ORBIT_BULLETS: 0,
	GameDefsRef.WeaponUpgrade.POISON_TRAIL: 0,
	GameDefsRef.WeaponUpgrade.FRONT_FAN: 0,
	GameDefsRef.WeaponUpgrade.RAPID_HEAD: 0,
	GameDefsRef.WeaponUpgrade.FOOD_MAGNET: 0,
	GameDefsRef.WeaponUpgrade.APPLE_BURST: 0,
	GameDefsRef.WeaponUpgrade.PROP_BREAKER: 0,
	GameDefsRef.WeaponUpgrade.BOSS_BOUNTY: 0,
	GameDefsRef.WeaponUpgrade.THORNS: 0,
	GameDefsRef.WeaponUpgrade.SEGMENT_ARMOR: 0,
	GameDefsRef.WeaponUpgrade.DRILL_HEAD: 0,
	GameDefsRef.WeaponUpgrade.CHAIN_HEAD: 0,
	GameDefsRef.WeaponUpgrade.HARVESTER: 0,
}
var current_upgrade_choices: Array = []

@onready var camera: Camera2D = $Camera2D
@onready var score_label: Label = $Ui/ScoreLabel
@onready var xp_label: Label = $Ui/XpLabel
@onready var boss_label: Label = $Ui/BossLabel
@onready var event_label: Label = $Ui/EventLabel
@onready var biome_label: Label = $Ui/BiomeLabel
@onready var upgrade_summary: Label = $Ui/UpgradeSummary
@onready var resource_label: Label = $Ui/ResourceLabel
@onready var craft_label: Label = $Ui/CraftLabel
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
	camera.zoom = GameDefsRef.CAMERA_ZOOM
	reset_run()
	update_ui()
	update_camera(1.0)


func _process(delta: float) -> void:
	PlayerSystemRef.handle_input(self)

	if game_state == GameDefsRef.GameState.PLAYING:
		EnemySystemRef.update(self, delta)
		CombatSystemRef.update(self, delta)
		WorldEventsRef.update(self, delta)

		move_timer += delta
		while move_timer >= GameDefsRef.STEP_TIME:
			move_timer -= GameDefsRef.STEP_TIME
			PlayerSystemRef.step(self)
			if game_state == GameDefsRef.GameState.PLAYING:
				EnemySystemRef.step(self)

	_update_world_state(delta)
	update_camera(delta)
	update_ui()
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if game_state != GameDefsRef.GameState.PLAYING:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_Q:
				ProgressionSystemRef.try_craft_food_cache(self)
			KEY_E:
				ProgressionSystemRef.try_craft_scrap_burst(self)
			KEY_R:
				ProgressionSystemRef.try_craft_dragon_bait(self)


func _draw() -> void:
	SnakeRenderRef.draw_world(self)


func _update_world_state(delta: float) -> void:
	if player_body.is_empty():
		return
	for food in foods:
		food.phase += delta * 2.2
	if game_state == GameDefsRef.GameState.PLAYING and upgrade_levels[GameDefsRef.WeaponUpgrade.FOOD_MAGNET] > 0 and not player_body.is_empty():
		var head: Vector2i = player_body[0]
		var magnet_radius: int = 2 + upgrade_levels[GameDefsRef.WeaponUpgrade.FOOD_MAGNET] * 2
		for i in range(foods.size() - 1, -1, -1):
			var food = foods[i]
			var dist: int = abs(food.cell.x - head.x) + abs(food.cell.y - head.y)
			if dist <= magnet_radius:
				var value: int = food.value
				var cell: Vector2i = food.cell
				foods.remove_at(i)
				handle_player_food_pickup(cell, value)
	for prop in props:
		prop.damage_flash = max(prop.damage_flash - delta * 4.0, 0.0)

	WorldGenRef.ensure_chunks(self)
	WorldGenRef.spawn_ambient_food(self)

	biome_name = ProgressionSystemRef.pretty_biome_name(ActorSystemRef.biome_for_cell(self, player_body[0]))


func reset_run() -> void:
	ProgressionSystemRef.reset_run(self)


func ensure_world_bootstrap() -> void:
	WorldGenRef.ensure_chunks(self)
	WorldGenRef.spawn_ambient_food(self)
	if not player_body.is_empty():
		biome_name = ProgressionSystemRef.pretty_biome_name(ActorSystemRef.biome_for_cell(self, player_body[0]))


func update_camera(delta: float) -> void:
	if player_body.is_empty():
		return
	var target: Vector2 = GameDefsRef.cell_center(player_body[0])
	camera.position = camera.position.lerp(target, min(delta * GameDefsRef.CAMERA_LERP_RATE, 1.0))


func visible_world_rect() -> Rect2:
	return GameDefsRef.visible_world_rect(camera.position, get_viewport_rect().size, camera.zoom)


func visible_half_cells() -> Vector2i:
	return GameDefsRef.visible_half_cells(get_viewport_rect().size, camera.zoom)


func update_ui() -> void:
	score_label.text = "Score: %d" % score
	xp_label.text = "XP: %d / %d" % [xp, next_upgrade_xp]
	biome_label.text = biome_name
	boss_label.text = ActorSystemRef.current_boss_name(self)
	event_label.text = event_name
	upgrade_summary.text = ProgressionSystemRef.build_upgrade_summary(self)
	resource_label.text = "Wood %d | Scrap %d | Crystal %d | Rot %d | Armor %d" % [wood, scrap, crystal, rot, player_armor_charges]
	craft_label.text = "Craft: Q Food Crate (3 wood) | E Scrap Burst (4 scrap) | R Dragon Bait (5 crystal)"
	center_panel.visible = game_state == GameDefsRef.GameState.TITLE or game_state == GameDefsRef.GameState.GAME_OVER
	upgrade_panel.visible = game_state == GameDefsRef.GameState.CHOOSING_UPGRADE

	match game_state:
		GameDefsRef.GameState.TITLE:
			center_title.text = "COMBAT SNAKE"
			center_body.text = "Eat food, cut rival snakes, craft junk, and hunt bosses.\nWASD or arrows to turn.\nPress Space to start."
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


func gain_xp(amount: int) -> void:
	ProgressionSystemRef.gain_xp(self, amount)


func apply_upgrade_choice(choice_index: int) -> void:
	ProgressionSystemRef.apply_upgrade_choice(self, choice_index)


func handle_player_food_pickup(cell: Vector2i, food_value: int) -> void:
	ProgressionSystemRef.handle_player_food_pickup(self, cell, food_value)


func spawn_bullet(pos: Vector2, dir: Vector2, speed: float, friendly: bool, ttl: float, color: Color, radius: float, damage: int) -> void:
	ActorSystemRef.spawn_bullet(self, pos, dir, speed, friendly, ttl, color, radius, damage)


func spawn_poison(cell: Vector2i, ttl: float = 3.0) -> void:
	ActorSystemRef.spawn_poison(self, cell, ttl)


func poison_at(cell: Vector2i) -> bool:
	return ActorSystemRef.poison_at(self, cell)


func consume_food_at(cell: Vector2i) -> int:
	return ActorSystemRef.consume_food_at(self, cell)


func spawn_food(cell: Vector2i, value: int) -> void:
	ActorSystemRef.spawn_food(self, cell, value)


func cell_occupied(cell: Vector2i) -> bool:
	return ActorSystemRef.cell_occupied(self, cell)


func prop_at_cell(cell: Vector2i):
	return ActorSystemRef.prop_at_cell(self, cell)


func enemy_cell_hit(cell: Vector2i, ignored_index: int = -1) -> Dictionary:
	return ActorSystemRef.enemy_cell_hit(self, cell, ignored_index)


func enemy_hit_by_point(point: Vector2) -> Dictionary:
	return ActorSystemRef.enemy_hit_by_point(self, point)


func nearest_enemy_segment_except(origin: Vector2, ignored_snake: int) -> Dictionary:
	return ActorSystemRef.nearest_enemy_segment_except(self, origin, ignored_snake)


func find_nearest_food(origin: Vector2i, max_distance: int):
	return ActorSystemRef.find_nearest_food(self, origin, max_distance)


func damage_enemy_segment(snake_index: int, segment_index: int, _world_pos: Vector2, damage: int) -> void:
	ActorSystemRef.damage_enemy_segment(self, snake_index, segment_index, damage)


func kill_enemy_snake(index: int, cells: Array, was_boss: bool) -> void:
	ActorSystemRef.kill_enemy_snake(self, index, cells, was_boss)


func damage_prop(prop, _world_pos: Vector2, damage: int) -> void:
	ActorSystemRef.damage_prop(self, prop, damage)


func cut_player_at(cell: Vector2i) -> void:
	ActorSystemRef.cut_player_at(self, cell)


func kill_player() -> void:
	ActorSystemRef.kill_player(self)


func boss_exists() -> bool:
	return ActorSystemRef.boss_exists(self)


func current_boss_name() -> String:
	return ActorSystemRef.current_boss_name(self)


func biome_for_cell(cell: Vector2i) -> String:
	return ActorSystemRef.biome_for_cell(self, cell)
