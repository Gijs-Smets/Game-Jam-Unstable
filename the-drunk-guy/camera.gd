extends Camera2D

@onready var player: Node2D = get_parent()
# Vaste hoogte van het midden van het beeld = midden van de achtergrond
const CAMERA_Y := 340.0

func _ready() -> void:
	top_level = true

func _process(_delta: float) -> void:
	var t : float = Game.time
	var d : float = Game.drunk_strength

	# Volgen (alleen x), zoals voorheen
	global_position = Vector2(player.global_position.x + 200, CAMERA_Y)

	# Zatte camera
	rotation = sin(t * 1.8) * 0.04 * d
	zoom = Vector2.ONE * (1.0 + sin(t * 2.5) * 0.03 * d)

	# Zatte beweging omhoog/omlaag (via de camera, niet via de speler)
	offset.y = sin(t * 4.0) * 6.0 * d
