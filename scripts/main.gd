extends Node

var snake_tile_scene = preload("res://scenes/SnakeTile.tscn")

var score: int
var game_started: bool = false
var lost: bool = false

var game_dim = 10
var cell_size = 50

var snake = []
var apple = null

var snake_tiles = []
var apple_tile = null

func new_snake_part(x, y):
	snake.append(Vector2(x, y))
	var snake_tile = snake_tile_scene.instantiate()
	add_child(snake_tile)
	snake_tiles.append(snake_tile)

enum SnakeDirection { 
	UP = 0, 
	DOWN = 1, 
	LEFT = 2, 
	RIGHT = 3 
}

func move_snake(dir: SnakeDirection):
	var head = snake[0]
	var new_head_position = Vector2(head.x, head.y)
	match dir:
		SnakeDirection.UP:
			new_head_position = head + Vector2(0, 1)
		SnakeDirection.DOWN:
			new_head_position = head + Vector2(0, -1)
		SnakeDirection.LEFT:
			new_head_position = head + Vector2(-1, 0)
		SnakeDirection.RIGHT:
			new_head_position = head + Vector2(1, 0)
	
	# check if new position is out of bounds
	# if yes, lose
	if new_head_position.x < 0:
		lost = true
	elif new_head_position.x >= game_dim:
		lost = true
	elif new_head_position.y < 0:
		lost = true
	elif new_head_position.y >= game_dim:
		lost = true
		
	# check if new position is on the snake
	# if yes, lose
	for snake_part in snake:
		if new_head_position == snake_part:
			lost = true
	
	# check if new position is on the apple, if yes, dont delete the tail
	# if no, delete the tail
	snake.append(new_head_position)
	if !(new_head_position == apple):
		snake.pop_back()
	
	
func new_random_apple():
	while true:
		var rng = RandomNumberGenerator.new()
		var x = rng.randi_range(0, game_dim)
		var y = rng.randi_range(0, game_dim)
		apple = Vector2(x, y)
		var head = snake[0]
		if !(apple == head):
			break
	
func reset():
	lost = false
	
	# put the snake in the middle
	snake = []
	var x = int(game_dim) / 2
	var y = int(game_dim) / 2
	new_snake_part(x, y)
	
	new_random_apple()

func _ready():
	reset()
	
func _process(delta):
	pass
