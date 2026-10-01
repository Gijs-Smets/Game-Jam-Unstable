extends Area2D

const DELETE_BEHIND := 1500.0
const OBSTACLE_HEIGHT := 64.0   # hoe hoog de box in het spel is (in pixels)

var passed := false
var player: Node2D

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	_fit_to_texture()
	body_entered.connect(_on_body_entered)
	player = get_tree().get_first_node_in_group("player")

# Schaalt box.png naar OBSTACLE_HEIGHT en maakt de hitbox even groot als de afbeelding,
# ongeacht hoe groot de png zelf is.
func _fit_to_texture() -> void:
	var tex := sprite.texture
	if tex == null:
		return
	var s := OBSTACLE_HEIGHT / tex.get_height()
	sprite.scale = Vector2(s, s)
	var shape := RectangleShape2D.new()
	shape.size = tex.get_size() * s
	collision.shape = shape

func _process(_delta: float) -> void:
	if player == null or not Game.running:
		return

	if not passed and player.global_position.x > global_position.x + 20:
		passed = true
		Game.add_score()

	if player.global_position.x > global_position.x + DELETE_BEHIND:
		print("Obstacle VERWIJDERD: ", name)
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D:
		Game.end_game()
