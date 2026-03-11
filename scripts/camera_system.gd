extends RefCounted
class_name CameraSystem

const GameDefsRef = preload("res://scripts/game_defs.gd")


static func update(game, delta: float) -> void:
	if game.player_body.is_empty():
		return
	var target: Vector2 = GameDefsRef.cell_center(game.player_body[0])
	game.camera.position = game.camera.position.lerp(target, min(delta * GameDefsRef.CAMERA_LERP_RATE, 1.0))


static func visible_world_rect(game) -> Rect2:
	return GameDefsRef.visible_world_rect(game.camera.position, game.get_viewport_rect().size, game.camera.zoom)


static func visible_half_cells(game) -> Vector2i:
	return GameDefsRef.visible_half_cells(game.get_viewport_rect().size, game.camera.zoom)


static func change_zoom(game, delta: float) -> void:
	var current: float = game.camera.zoom.x
	var next: float = clamp(current + delta, GameDefsRef.CAMERA_ZOOM_MIN, GameDefsRef.CAMERA_ZOOM_MAX)
	game.camera.zoom = Vector2(next, next)
