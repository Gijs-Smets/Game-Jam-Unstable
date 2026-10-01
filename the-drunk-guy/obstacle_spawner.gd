extends Node2D

const OBSTACLE_SCENE := preload("res://obstacle.tscn")
const SPAWN_AHEAD := 1500.0       # hoever voor de speler obstakels klaarstaan
const FIRST_DISTANCE := 800.0     # afstand tot het eerste obstacle
const MIN_GAP := 450.0            # kleinste ruimte tussen twee obstakels
const MAX_GAP := 800.0            # grootste ruimte

var player: Node2D
var next_x := 0.0
var count := 0

func _physics_process(_delta: float) -> void:
	if not Game.running:
		return

	if player == null:
		player = get_tree().get_first_node_in_group("player")
		if player == null:
			return
		next_x = player.global_position.x + FIRST_DISTANCE

	while next_x < player.global_position.x + SPAWN_AHEAD:
		_spawn(next_x)
		# Ruimte groeit mee met de snelheid, zodat er altijd genoeg tijd is om te landen
		next_x += randf_range(MIN_GAP, MAX_GAP) * Game.speed_factor

func _spawn(x: float) -> void:
	var obstacle: Node2D = OBSTACLE_SCENE.instantiate()
	obstacle.name = "Obstacle_%d" % count
	add_child(obstacle)
	obstacle.global_position = Vector2(x, global_position.y)
	print("Obstacle AANGEMAAKT: ", obstacle.name, " (x = ", int(x), ")")
	count += 1
