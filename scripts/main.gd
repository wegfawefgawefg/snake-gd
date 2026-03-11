extends Node

const SNAKE_TILE_SCENE := preload("res://scenes/SnakeTile.tscn")
const APPLE_TILE_SCENE := preload("res://scenes/AppleTile.tscn")

const GRID_SIZE := 10
const CELL_SIZE := 8.0
const STEP_TIME := 0.18
const BOARD_ORIGIN := Vector2.ZERO
const BORDER_THICKNESS := 8.0

enum GameState {
	TITLE,
	PLAYING,
	GAME_OVER,
}

enum SnakeDirection {
	UP,
	DOWN,
	LEFT,
	RIGHT,
}

var score: int = 0
var move_timer: float = 0.0
var game_state: GameState = GameState.TITLE

var snake: Array[Vector2i] = []
var snake_tiles: Array[Sprite2D] = []
var apple: Vector2i
var apple_tile: Sprite2D

var current_direction: SnakeDirection = SnakeDirection.RIGHT
var queued_direction: SnakeDirection = SnakeDirection.RIGHT

@onready var camera: Camera2D = $Camera2D
@onready var tile_map: TileMap = $TileMap
@onready var playfield_fill: Polygon2D = $PlayfieldFill
@onready var board_border: Line2D = $BoardBorder
@onready var debug_rect: Line2D = $DebugRect
@onready var title_panel: ColorRect = $Ui/TitlePanel
@onready var score_label: Label = $Ui/ScoreLabel
@onready var center_text: Label = $Ui/CenterText
@onready var prompt_text: Label = $Ui/PromptText


func _ready() -> void:
	randomize()
	tile_map.visible = false
	_update_board_visuals()
	reset_game()
	_update_debug_rect()
	_update_ui()
	_focus_camera_on_board()


func _process(delta: float) -> void:
	_handle_input()
	_update_camera(delta)
	_update_ui()

	if game_state == GameState.TITLE:
		if Input.is_key_pressed(KEY_SPACE) or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			game_state = GameState.PLAYING
		return

	if game_state == GameState.GAME_OVER:
		if Input.is_key_pressed(KEY_SPACE) or Input.is_action_just_pressed("ui_accept") or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			reset_game()
			game_state = GameState.PLAYING
		return

	move_timer += delta
	while move_timer >= STEP_TIME:
		move_timer -= STEP_TIME
		_step_snake()


func _handle_input() -> void:
	if _just_pressed_up() and current_direction != SnakeDirection.DOWN:
		queued_direction = SnakeDirection.UP
	elif _just_pressed_down() and current_direction != SnakeDirection.UP:
		queued_direction = SnakeDirection.DOWN
	elif _just_pressed_left() and current_direction != SnakeDirection.RIGHT:
		queued_direction = SnakeDirection.LEFT
	elif _just_pressed_right() and current_direction != SnakeDirection.LEFT:
		queued_direction = SnakeDirection.RIGHT


func _just_pressed_up() -> bool:
	return Input.is_action_just_pressed("ui_up") or Input.is_key_pressed(KEY_W)


func _just_pressed_down() -> bool:
	return Input.is_action_just_pressed("ui_down") or Input.is_key_pressed(KEY_S)


func _just_pressed_left() -> bool:
	return Input.is_action_just_pressed("ui_left") or Input.is_key_pressed(KEY_A)


func _just_pressed_right() -> bool:
	return Input.is_action_just_pressed("ui_right") or Input.is_key_pressed(KEY_D)


func reset_game() -> void:
	score = 0
	move_timer = 0.0
	current_direction = SnakeDirection.RIGHT
	queued_direction = SnakeDirection.RIGHT
	game_state = GameState.TITLE

	for tile in snake_tiles:
		tile.queue_free()
	snake_tiles.clear()

	if apple_tile != null:
		apple_tile.queue_free()
		apple_tile = null

	snake.clear()
	var center := GRID_SIZE / 2
	snake.append(Vector2i(center, center))
	snake.append(Vector2i(center - 1, center))
	snake.append(Vector2i(center - 2, center))

	for _i in snake.size():
		var tile := SNAKE_TILE_SCENE.instantiate() as Sprite2D
		add_child(tile)
		snake_tiles.append(tile)

	apple_tile = APPLE_TILE_SCENE.instantiate() as Sprite2D
	add_child(apple_tile)

	_spawn_apple()
	_sync_visuals()


func _step_snake() -> void:
	current_direction = queued_direction
	var head := snake[0]
	var new_head := head

	match current_direction:
		SnakeDirection.UP:
			new_head += Vector2i(0, -1)
		SnakeDirection.DOWN:
			new_head += Vector2i(0, 1)
		SnakeDirection.LEFT:
			new_head += Vector2i(-1, 0)
		SnakeDirection.RIGHT:
			new_head += Vector2i(1, 0)

	if new_head.x < 0 or new_head.x >= GRID_SIZE or new_head.y < 0 or new_head.y >= GRID_SIZE:
		game_state = GameState.GAME_OVER
		return

	if new_head in snake:
		game_state = GameState.GAME_OVER
		return

	snake.push_front(new_head)

	if new_head == apple:
		score += 1
		var new_tile := SNAKE_TILE_SCENE.instantiate() as Sprite2D
		add_child(new_tile)
		snake_tiles.append(new_tile)
		_spawn_apple()
	else:
		snake.pop_back()

	_sync_visuals()


func _spawn_apple() -> void:
	while true:
		apple = Vector2i(randi_range(0, GRID_SIZE - 1), randi_range(0, GRID_SIZE - 1))
		if not (apple in snake):
			break

	if apple_tile != null:
		apple_tile.position = _grid_to_world(apple)


func _sync_visuals() -> void:
	for i in snake.size():
		snake_tiles[i].position = _grid_to_world(snake[i])

	if apple_tile != null:
		apple_tile.position = _grid_to_world(apple)


func _grid_to_world(cell: Vector2i) -> Vector2:
	return BOARD_ORIGIN + Vector2(cell.x, cell.y) * CELL_SIZE


func _head_world() -> Vector2:
	if snake.is_empty():
		return _board_center()
	return _grid_to_world(snake[0]) + Vector2(4, 4)


func _board_center() -> Vector2:
	return _grid_to_world(Vector2i(GRID_SIZE / 2, GRID_SIZE / 2)) + Vector2(4, 4)


func _focus_camera_on_board() -> void:
	camera.position = _board_center()


func _update_camera(delta: float) -> void:
	var target := _board_center()
	if game_state == GameState.PLAYING or game_state == GameState.GAME_OVER:
		target = _head_world()
	camera.position = camera.position.lerp(target, min(delta * 8.0, 1.0))


func _update_debug_rect() -> void:
	var x0 := _grid_to_world(Vector2i(0, 0)).x
	var y0 := _grid_to_world(Vector2i(0, 0)).y
	var x1 := _grid_to_world(Vector2i(GRID_SIZE - 1, 0)).x + 8.0
	var y1 := _grid_to_world(Vector2i(0, GRID_SIZE - 1)).y + 8.0
	debug_rect.z_index = 20
	debug_rect.width = 1.25
	debug_rect.points = PackedVector2Array([
		Vector2(x0, y0),
		Vector2(x1, y0),
		Vector2(x1, y1),
		Vector2(x0, y1),
	])


func _update_board_visuals() -> void:
	var x0 := BOARD_ORIGIN.x
	var y0 := BOARD_ORIGIN.y
	var x1 := BOARD_ORIGIN.x + GRID_SIZE * CELL_SIZE
	var y1 := BOARD_ORIGIN.y + GRID_SIZE * CELL_SIZE
	playfield_fill.polygon = PackedVector2Array([
		Vector2(x0, y0),
		Vector2(x1, y0),
		Vector2(x1, y1),
		Vector2(x0, y1),
	])

	board_border.z_index = 5
	board_border.points = PackedVector2Array([
		Vector2(x0 - BORDER_THICKNESS * 0.5, y0 - BORDER_THICKNESS * 0.5),
		Vector2(x1 + BORDER_THICKNESS * 0.5, y0 - BORDER_THICKNESS * 0.5),
		Vector2(x1 + BORDER_THICKNESS * 0.5, y1 + BORDER_THICKNESS * 0.5),
		Vector2(x0 - BORDER_THICKNESS * 0.5, y1 + BORDER_THICKNESS * 0.5),
	])


func _update_ui() -> void:
	score_label.text = "Score: %d" % score

	match game_state:
		GameState.TITLE:
			title_panel.visible = true
			center_text.visible = true
			prompt_text.visible = true
			center_text.text = "SNAKE"
			prompt_text.text = "Press Space to start"
		GameState.PLAYING:
			title_panel.visible = false
			center_text.visible = false
			prompt_text.visible = false
		GameState.GAME_OVER:
			title_panel.visible = true
			center_text.visible = true
			prompt_text.visible = true
			center_text.text = "GAME OVER"
			prompt_text.text = "Press Space again"
