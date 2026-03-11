extends RefCounted
class_name UiSystem

const GameDefsRef = preload("res://scripts/game_defs.gd")
const ActorSystemRef = preload("res://scripts/actor_system.gd")
const ProgressionSystemRef = preload("res://scripts/progression_system.gd")


static func update(game) -> void:
	game.score_label.text = "Score: %d" % game.score
	game.xp_label.text = "XP: %d / %d" % [game.xp, game.next_upgrade_xp]
	game.zoom_label.text = "Zoom: %.2f" % game.camera.zoom.x
	game.fps_label.text = "FPS: %d" % Engine.get_frames_per_second()
	game.biome_label.text = game.biome_name
	game.boss_label.text = ActorSystemRef.current_boss_name(game)
	game.event_label.text = game.event_name
	game.upgrade_summary.text = ProgressionSystemRef.build_upgrade_summary(game)
	game.resource_label.text = "Wood %d | Scrap %d | Crystal %d | Rot %d | Armor %d" % [game.wood, game.scrap, game.crystal, game.rot, game.player_armor_charges]
	game.craft_label.text = "Craft: Q Food Crate (3 wood) | E Scrap Burst (4 scrap) | R Dragon Bait (5 crystal)"
	game.center_panel.visible = game.game_state == GameDefsRef.GameState.TITLE or game.game_state == GameDefsRef.GameState.GAME_OVER
	game.upgrade_panel.visible = game.game_state == GameDefsRef.GameState.CHOOSING_UPGRADE

	match game.game_state:
		GameDefsRef.GameState.TITLE:
			game.center_title.text = "COMBAT SNAKE"
			game.center_body.text = "Eat food, cut rival snakes, craft junk, and hunt bosses.\nWASD or arrows to turn.\nPress Space to start."
		GameDefsRef.GameState.GAME_OVER:
			game.center_title.text = "GAME OVER"
			game.center_body.text = "Score: %d\nPress Space again" % game.score

	if game.game_state == GameDefsRef.GameState.CHOOSING_UPGRADE:
		for i in range(game.option_labels.size()):
			var label = game.option_labels[i]
			if i >= game.current_upgrade_choices.size():
				label.text = ""
				continue
			var choice = game.current_upgrade_choices[i]
			label.text = "%d. %s\n%s" % [i + 1, choice.name, choice.desc]
