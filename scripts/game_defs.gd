extends RefCounted
class_name GameDefs

const TILE_TEXTURE = preload("res://assets/kenney_micro-roguelike/Tiles/Colored/tile_0020.png")

const CELL_SIZE := 8.0
const STEP_TIME := 0.12
const START_LENGTH := 4
const CAMERA_LERP_RATE := 8.0
const CAMERA_ZOOM := Vector2(1.3, 1.3)

const CHUNK_SIZE := 14
const CHUNK_LOAD_RADIUS := 2
const FOOD_DESPAWN_CHUNK_RADIUS := 4
const ENEMY_DESPAWN_DISTANCE := 80
const VISIBLE_CELLS_X := 46
const VISIBLE_CELLS_Y := 32
const SPAWN_RING_PADDING := 8
const PLAYER_START := Vector2i(0, 0)

const PLAYER_HEAD_COLOR := Color(0.45, 1.0, 0.55, 1.0)
const PLAYER_BODY_COLOR := Color(0.1, 0.9, 0.3, 1.0)
const ENEMY_COLORS := [
	Color(1.0, 0.45, 0.55, 1.0),
	Color(0.95, 0.7, 0.3, 1.0),
	Color(0.7, 0.5, 1.0, 1.0),
]
const BOSS_COLOR := Color(1.0, 0.82, 0.25, 1.0)
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

const BIOME_COLORS := {
	"orchard": Color(0.08, 0.12, 0.07, 1.0),
	"forest": Color(0.06, 0.1, 0.08, 1.0),
	"city": Color(0.09, 0.09, 0.11, 1.0),
	"swamp": Color(0.08, 0.1, 0.06, 1.0),
	"desert": Color(0.12, 0.1, 0.07, 1.0),
}

const PROP_COLORS := {
	"tree": Color(0.2, 0.75, 0.25, 1.0),
	"building": Color(0.55, 0.58, 0.68, 1.0),
	"swamp_pool": Color(0.42, 0.2, 0.6, 1.0),
	"rock": Color(0.55, 0.5, 0.4, 1.0),
}

const FOOD_TARGETS := {
	1: 36,
	3: 12,
	5: 5,
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

static func grid_to_world(cell: Vector2i) -> Vector2:
	return Vector2(cell.x, cell.y) * CELL_SIZE


static func cell_center(cell: Vector2i) -> Vector2:
	return grid_to_world(cell) + Vector2(CELL_SIZE * 0.5, CELL_SIZE * 0.5)


static func direction_vec(dir: Vector2i) -> Vector2:
	return Vector2(dir.x, dir.y)


static func cell_rect(cell: Vector2i) -> Rect2:
	return Rect2(grid_to_world(cell), Vector2.ONE * CELL_SIZE)


static func point_to_cell(point: Vector2) -> Vector2i:
	return Vector2i(floori(point.x / CELL_SIZE), floori(point.y / CELL_SIZE))


static func is_reverse_dir(a: Vector2i, b: Vector2i) -> bool:
	return a + b == Vector2i.ZERO


static func chunk_for_cell(cell: Vector2i) -> Vector2i:
	return Vector2i(
		floori(float(cell.x) / float(CHUNK_SIZE)),
		floori(float(cell.y) / float(CHUNK_SIZE))
	)


static func chunk_key(chunk_coord: Vector2i) -> String:
	return "%d:%d" % [chunk_coord.x, chunk_coord.y]


static func chunk_origin(chunk_coord: Vector2i) -> Vector2i:
	return chunk_coord * CHUNK_SIZE


static func chunk_rect(chunk_coord: Vector2i) -> Rect2:
	return Rect2(
		grid_to_world(chunk_origin(chunk_coord)),
		Vector2.ONE * CHUNK_SIZE * CELL_SIZE
	)


static func visible_world_rect(center: Vector2) -> Rect2:
	var half := Vector2(VISIBLE_CELLS_X, VISIBLE_CELLS_Y) * CELL_SIZE * 0.5
	return Rect2(center - half, half * 2.0)
