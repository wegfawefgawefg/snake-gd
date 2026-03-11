extends Node2D

const GameDefsRef = preload("res://scripts/game_defs.gd")
const PlayerSystemRef = preload("res://scripts/player_system.gd")
const EnemySystemRef = preload("res://scripts/enemy_system.gd")
const CombatSystemRef = preload("res://scripts/combat_system.gd")
const SnakeRenderRef = preload("res://scripts/snake_render.gd")
const ProgressionSystemRef = preload("res://scripts/progression_system.gd")
const WorldEventsRef = preload("res://scripts/world_events.gd")
const CameraSystemRef = preload("res://scripts/camera_system.gd")
const UiSystemRef = preload("res://scripts/ui_system.gd")
const WorldRuntimeRef = preload("res://scripts/world_runtime.gd")

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
@onready var zoom_label: Label = $Ui/ZoomLabel
@onready var fps_label: Label = $Ui/FpsLabel
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
	UiSystemRef.update(self)
	CameraSystemRef.update(self, 1.0)


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

	WorldRuntimeRef.update(self, delta)
	CameraSystemRef.update(self, delta)
	UiSystemRef.update(self)
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_EQUAL, KEY_PLUS, KEY_KP_ADD:
				CameraSystemRef.change_zoom(self, -GameDefsRef.CAMERA_ZOOM_STEP)
			KEY_MINUS, KEY_KP_SUBTRACT:
				CameraSystemRef.change_zoom(self, GameDefsRef.CAMERA_ZOOM_STEP)

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


func reset_run() -> void:
	ProgressionSystemRef.reset_run(self)


func ensure_world_bootstrap() -> void:
	WorldRuntimeRef.bootstrap(self)
