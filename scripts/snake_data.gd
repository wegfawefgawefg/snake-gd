extends RefCounted
class_name SnakeData

class SnakeActor:
	extends RefCounted
	var body: Array[Vector2i] = []
	var dir: Vector2i = Vector2i.RIGHT
	var queued_dir: Vector2i = Vector2i.RIGHT
	var color: Color = Color.WHITE
	var name: String = ""
	var biome: String = ""
	var is_boss := false
	var split_on_cut := false
	var can_shoot := false
	var head_hp := 1
	var shot_cooldown := 0.0
	var damage_flash := 0.0
	var poison_body := false
	var score_value := 20


class FoodPickup:
	extends RefCounted
	var cell: Vector2i
	var value: int
	var phase := 0.0
	var chunk_coord: Vector2i = Vector2i.ZERO


class BulletData:
	extends RefCounted
	var pos: Vector2
	var vel: Vector2
	var ttl: float
	var friendly := true
	var color: Color = Color.WHITE
	var radius := 2.0
	var damage := 1
	var beam_like := false


class PoisonPatch:
	extends RefCounted
	var cell: Vector2i
	var ttl: float


class WorldProp:
	extends RefCounted
	var cell: Vector2i
	var kind: String = ""
	var hp := 1
	var biome: String = ""
	var damage_flash := 0.0
	var chunk_coord: Vector2i = Vector2i.ZERO


class WorldChunk:
	extends RefCounted
	var coord: Vector2i
	var biome: String = ""
