extends StaticBody2D

# Als je later een patroon of textuur op de grond zet, zet dit op de
# breedte van één patroonstukje, zodat het niet zichtbaar verspringt.
const STEP := 1307.2   # 1376 x 0.95  # breedte van de tegel in pixels (× scale als je schaalt)

var player: Node2D

func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")

func _physics_process(_delta: float) -> void:
	if player == null:
		return
	global_position.x = floor(player.global_position.x / STEP) * STEP
