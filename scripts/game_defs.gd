extends RefCounted
class_name GameDefs

const TILE_TEXTURE = preload("res://assets/kenney_micro-roguelike/Tiles/Colored/tile_0020.png")

const CELL_SIZE := 8.0
const STEP_TIME := 0.12
const START_LENGTH := 4
const CAMERA_LERP_RATE := 8.0
const CAMERA_ZOOM := Vector2(0.82, 0.82)

const CHUNK_SIZE := 14
const FOOD_DESPAWN_CHUNK_RADIUS := 4
const ENEMY_DESPAWN_DISTANCE := 80
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
	"orchard": Color(0.16, 0.28, 0.14, 1.0),
	"forest": Color(0.08, 0.22, 0.16, 1.0),
	"city": Color(0.2, 0.22, 0.3, 1.0),
	"swamp": Color(0.2, 0.16, 0.26, 1.0),
	"desert": Color(0.32, 0.26, 0.14, 1.0),
	"carnival": Color(0.34, 0.12, 0.24, 1.0),
	"end": Color(0.12, 0.1, 0.22, 1.0),
}

const PROP_COLORS := {
	"tree": Color(0.2, 0.75, 0.25, 1.0),
	"building": Color(0.55, 0.58, 0.68, 1.0),
	"swamp_pool": Color(0.42, 0.2, 0.6, 1.0),
	"rock": Color(0.55, 0.5, 0.4, 1.0),
	"tent": Color(0.95, 0.25, 0.55, 1.0),
	"ender_spire": Color(0.68, 0.48, 1.0, 1.0),
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
	FRONT_FAN,
	RAPID_HEAD,
	FOOD_MAGNET,
	APPLE_BURST,
	PROP_BREAKER,
	BOSS_BOUNTY,
	THORNS,
	SEGMENT_ARMOR,
	DRILL_HEAD,
	CHAIN_HEAD,
	HARVESTER,
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
	WeaponUpgrade.FRONT_FAN: {
		"name": "Front Fan",
		"desc": "Head shot adds angled side rounds.",
	},
	WeaponUpgrade.RAPID_HEAD: {
		"name": "Rapid Head",
		"desc": "Head gun fires much faster.",
	},
	WeaponUpgrade.FOOD_MAGNET: {
		"name": "Food Magnet",
		"desc": "Nearby food gets sucked into your head.",
	},
	WeaponUpgrade.APPLE_BURST: {
		"name": "Apple Burst",
		"desc": "Eating food emits a radial shot burst.",
	},
	WeaponUpgrade.PROP_BREAKER: {
		"name": "Prop Breaker",
		"desc": "Shots and beams wreck trees and buildings faster.",
	},
	WeaponUpgrade.BOSS_BOUNTY: {
		"name": "Boss Bounty",
		"desc": "Bosses and elites explode into richer rewards.",
	},
	WeaponUpgrade.THORNS: {
		"name": "Thorns",
		"desc": "Enemies that cut into you take return damage.",
	},
	WeaponUpgrade.SEGMENT_ARMOR: {
		"name": "Segment Armor",
		"desc": "Body hits can burn armor instead of chopping you.",
	},
	WeaponUpgrade.DRILL_HEAD: {
		"name": "Drill Head",
		"desc": "Head bullets pierce through extra targets.",
	},
	WeaponUpgrade.CHAIN_HEAD: {
		"name": "Chain Head",
		"desc": "Head bullets fork into nearby enemy snakes.",
	},
	WeaponUpgrade.HARVESTER: {
		"name": "Harvester",
		"desc": "Props and snakes spill extra food and resources.",
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


static func visible_world_rect(center: Vector2, viewport_size: Vector2, zoom: Vector2) -> Rect2:
	var half := viewport_size * zoom * 0.5
	return Rect2(center - half, half * 2.0)


static func visible_half_cells(viewport_size: Vector2, zoom: Vector2) -> Vector2i:
	var world_half: Vector2 = viewport_size * zoom * 0.5
	return Vector2i(
		int(ceili(world_half.x / CELL_SIZE)),
		int(ceili(world_half.y / CELL_SIZE))
	)
