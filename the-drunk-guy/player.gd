extends CharacterBody2D

const SPEED = 250.0
const JUMP_FORCE = -700.0
const GRAVITY = 2000.0

func _ready() -> void:
	add_to_group("player")

func _physics_process(delta):
	if not Game.running:
		return

	var t: float = Game.time
	var d: float = Game.drunk_strength

	if not is_on_floor():
		velocity.y += GRAVITY * delta

	velocity.x = SPEED * Game.speed_factor + sin(t * 2.5) * 80.0 * d

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_FORCE

	move_and_slide()

	rotation = sin(t * 2.0) * 0.15 * d

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	draw_boy()

func draw_boy() -> void:
	var x := 0.0
	var y := 0.0
	var anim_t: float = Game.time
	var skin := Color("#D9A066")
	var red := Color("#D62828")
	var blue := Color("#1E3A8A")
	var hair := Color("#4A2815")

	# Loopanimatie (alleen als hij op de grond loopt, in de lucht staan de benen gespreid)
	var walk: float = sin(anim_t * 10.0) * 5.0
	if not is_on_floor():
		walk = 4.0

	# Zatte wiebel van het hoofd
	var drunk: float = sin(anim_t * 2.0) * 4.0 * Game.drunk_strength
	var head := Vector2(drunk, 0.0)

	# Benen
	draw_rect(Rect2(x - 13 + walk, y - 5, 10, 25), blue)
	draw_rect(Rect2(x + 3 - walk, y - 5, 10, 25), blue)

	# Schoenen
	draw_rect(Rect2(x - 17 + walk, y + 17, 16, 8), Color("#5B321A"))
	draw_rect(Rect2(x + 2 - walk, y + 17, 16, 8), Color("#5B321A"))

	# Lichaam / shirt
	draw_rect(Rect2(x - 18, y - 45, 36, 40), red)

	# Blauwe broek
	draw_rect(Rect2(x - 18, y - 15, 36, 15), blue)

	# Armen
	draw_rect(Rect2(x - 29, y - 42 + walk, 11, 28), skin)
	draw_rect(Rect2(x + 18, y - 42 - walk, 11, 28), skin)

	# Handen
	draw_circle(Vector2(x - 24, y - 13 + walk), 7, skin)
	draw_circle(Vector2(x + 24, y - 13 - walk), 7, skin)

	# Nek
	draw_rect(Rect2(x - 7, y - 53, 14, 10), skin)

	# Hoofd
	draw_circle(Vector2(x, y - 65) + head, 22, skin)

	# Haar
	draw_arc(Vector2(x, y - 67) + head, 21, PI, TAU, 20, hair, 8)

	# Snor
	draw_line(Vector2(x - 8, y - 62) + head, Vector2(x, y - 58) + head, hair, 4)
	draw_line(Vector2(x, y - 58) + head, Vector2(x + 8, y - 62) + head, hair, 4)

	# Ogen - beetje zat
	draw_circle(Vector2(x - 8, y - 68) + head, 3, Color("#111111"))
	draw_circle(Vector2(x + 8, y - 68) + head, 3, Color("#111111"))

	# Zatte rode wangen
	draw_circle(Vector2(x - 15, y - 61) + head, 4, Color("#E57373"))
	draw_circle(Vector2(x + 15, y - 61) + head, 4, Color("#E57373"))

	# Pet
	draw_rect(Rect2(x - 20 + head.x, y - 86, 40, 8), red)
	draw_rect(Rect2(x - 15 + head.x, y - 91, 30, 8), red)
